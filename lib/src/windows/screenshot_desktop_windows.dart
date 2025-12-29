import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../desktop_window.dart';
import '../screenshot_desktop_interface.dart';
import '../monitor.dart';

/// The Windows implementation of [ScreenshotDesktop].
///
/// This implementation uses GDI and Win32 APIs to capture screenshots.
class ScreenshotDesktopWindows extends ScreenshotDesktop {
  @override
  bool hasPermission() => true;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<List<Monitor>> getAvailableMonitors() async {
    SetProcessDPIAware();
    final monitors = <Monitor>[];

    final lpEnumFunc =
        NativeCallable<
          Int32 Function(IntPtr, IntPtr, Pointer<RECT>, IntPtr)
        >.isolateLocal((
          int hMonitor,
          int hdcMonitor,
          Pointer<RECT> lprcMonitor,
          int dwData,
        ) {
          final monitorInfo = calloc<MONITORINFOEX>();
          monitorInfo.ref.monitorInfo.cbSize = sizeOf<MONITORINFOEX>();

          if (GetMonitorInfo(hMonitor, monitorInfo.cast<MONITORINFO>()) != 0) {
            final info = monitorInfo.ref;
            final name = info.szDevice;
            final width =
                (info.monitorInfo.rcMonitor.right -
                        info.monitorInfo.rcMonitor.left)
                    .abs();
            final height =
                (info.monitorInfo.rcMonitor.bottom -
                        info.monitorInfo.rcMonitor.top)
                    .abs();

            monitors.add(
              _WindowsMonitor(
                hMonitor: hMonitor,
                name: name,
                width: width,
                height: height,
                left: info.monitorInfo.rcMonitor.left,
                top: info.monitorInfo.rcMonitor.top,
              ),
            );
          }
          free(monitorInfo);
          return 1; // Continue enumeration
        }, exceptionalReturn: 0);

    try {
      EnumDisplayMonitors(NULL, nullptr, lpEnumFunc.nativeFunction.cast(), 0);
    } finally {
      lpEnumFunc.close();
    }

    return monitors;
  }

  @override
  Future<Uint8List> takeScreenshot(Monitor monitor) async {
    SetProcessDPIAware();
    if (monitor is! _WindowsMonitor) {
      throw ArgumentError('Invalid monitor type');
    }

    final width = monitor.width;
    final height = monitor.height;

    final hdcScreen = GetDC(NULL);
    final hdcMem = CreateCompatibleDC(hdcScreen);
    final hBitmap = CreateCompatibleBitmap(hdcScreen, width, height);
    final hOld = SelectObject(hdcMem, hBitmap);

    BitBlt(
      hdcMem,
      0,
      0,
      width,
      height,
      hdcScreen,
      monitor.left,
      monitor.top,
      SRCCOPY,
    );

    final bmi = calloc<BITMAPINFO>();
    bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
    bmi.ref.bmiHeader.biWidth = width;
    bmi.ref.bmiHeader.biHeight = height; // Bottom-up
    bmi.ref.bmiHeader.biPlanes = 1;
    bmi.ref.bmiHeader.biBitCount = 32;
    bmi.ref.bmiHeader.biCompression = BI_RGB;

    final pixelCount = width * height;
    final pPixels = calloc<Uint8>(pixelCount * 4);

    GetDIBits(hdcMem, hBitmap, 0, height, pPixels, bmi, DIB_RGB_COLORS);

    final pixels = pPixels.asTypedList(pixelCount * 4);
    final bmpBytes = _encodeToBmp(pixels, width, height);

    free(pPixels);
    free(bmi);
    SelectObject(hdcMem, hOld);
    DeleteObject(hBitmap);
    DeleteDC(hdcMem);
    ReleaseDC(NULL, hdcScreen);

    return bmpBytes;
  }

  @override
  Future<List<DesktopWindow>> getAvailableWindows() async {
    SetProcessDPIAware();
    final windows = <DesktopWindow>[];

    final lpEnumFunc =
        NativeCallable<Int32 Function(IntPtr, IntPtr)>.isolateLocal((
          int hwnd,
          int lParam,
        ) {
          if (IsWindowVisible(hwnd) == 0) return 1;

          final titleLength = GetWindowTextLength(hwnd);
          if (titleLength == 0) return 1;

          final titlePtr = calloc<Uint16>(titleLength + 1);
          GetWindowText(hwnd, titlePtr.cast(), titleLength + 1);
          final title = titlePtr.cast<Utf16>().toDartString();
          free(titlePtr);

          final rect = calloc<RECT>();
          GetWindowRect(hwnd, rect);
          final width = (rect.ref.right - rect.ref.left).abs();
          final height = (rect.ref.bottom - rect.ref.top).abs();
          free(rect);

          if (width == 0 || height == 0) return 1;

          final processIdPtr = calloc<Uint32>();
          GetWindowThreadProcessId(hwnd, processIdPtr);
          final processId = processIdPtr.value;
          free(processIdPtr);

          String appName = '';
          final hProcess = OpenProcess(
            PROCESS_QUERY_LIMITED_INFORMATION,
            FALSE,
            processId,
          );
          if (hProcess != NULL) {
            final buffer = calloc<Uint16>(MAX_PATH);
            final size = calloc<Uint32>();
            size.value = MAX_PATH;
            if (QueryFullProcessImageName(hProcess, 0, buffer.cast(), size) !=
                0) {
              final fullPath = buffer.cast<Utf16>().toDartString();
              appName = fullPath.split('\\').last;
            }
            free(buffer);
            free(size);
            CloseHandle(hProcess);
          }

          windows.add(
            _WindowsWindow(
              hwnd: hwnd,
              title: title,
              appName: appName,
              width: width,
              height: height,
            ),
          );

          return 1;
        }, exceptionalReturn: 0);

    try {
      EnumWindows(lpEnumFunc.nativeFunction.cast(), 0);
    } finally {
      lpEnumFunc.close();
    }

    return windows;
  }

  @override
  Future<Uint8List> takeWindowScreenshot(DesktopWindow window) async {
    SetProcessDPIAware();
    if (window is! _WindowsWindow) {
      throw ArgumentError('Invalid window type');
    }

    final hwnd = window.hwnd;
    final width = window.width;
    final height = window.height;

    final hdcScreen = GetDC(NULL);
    final hdcMem = CreateCompatibleDC(hdcScreen);
    final hBitmap = CreateCompatibleBitmap(hdcScreen, width, height);
    final hOld = SelectObject(hdcMem, hBitmap);

    // Try PrintWindow first, then fall back to BitBlt if it fails
    // PW_RENDERFULLCONTENT = 2
    int result = PrintWindow(hwnd, hdcMem, 2);
    if (result == 0) {
      final hdcWindow = GetWindowDC(hwnd);
      BitBlt(hdcMem, 0, 0, width, height, hdcWindow, 0, 0, SRCCOPY);
      ReleaseDC(hwnd, hdcWindow);
    }

    final bmi = calloc<BITMAPINFO>();
    bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
    bmi.ref.bmiHeader.biWidth = width;
    bmi.ref.bmiHeader.biHeight = height;
    bmi.ref.bmiHeader.biPlanes = 1;
    bmi.ref.bmiHeader.biBitCount = 32;
    bmi.ref.bmiHeader.biCompression = BI_RGB;

    final pixelCount = width * height;
    final pPixels = calloc<Uint8>(pixelCount * 4);

    GetDIBits(hdcMem, hBitmap, 0, height, pPixels, bmi, DIB_RGB_COLORS);

    final pixels = pPixels.asTypedList(pixelCount * 4);
    final bmpBytes = _encodeToBmp(pixels, width, height);

    free(pPixels);
    free(bmi);
    SelectObject(hdcMem, hOld);
    DeleteObject(hBitmap);
    DeleteDC(hdcMem);
    ReleaseDC(NULL, hdcScreen);

    return bmpBytes;
  }

  Uint8List _encodeToBmp(Uint8List pixels, int width, int height) {
    const headerSize = 14;
    const dibHeaderSize = 40;
    final totalSize = headerSize + dibHeaderSize + pixels.length;

    final bmp = Uint8List(totalSize);
    final bd = ByteData.view(bmp.buffer);

    // File Header
    bd.setUint8(0, 0x42); // B
    bd.setUint8(1, 0x4D); // M
    bd.setUint32(2, totalSize, Endian.little);
    bd.setUint32(10, headerSize + dibHeaderSize, Endian.little);

    // DIB Header
    bd.setUint32(14, dibHeaderSize, Endian.little);
    bd.setUint32(18, width, Endian.little);
    bd.setUint32(22, height, Endian.little);
    bd.setUint16(26, 1, Endian.little);
    bd.setUint16(28, 32, Endian.little);
    bd.setUint32(30, 0, Endian.little); // BI_RGB
    bd.setUint32(34, pixels.length, Endian.little);

    bmp.setRange(headerSize + dibHeaderSize, totalSize, pixels);
    return bmp;
  }
}

class _WindowsMonitor implements Monitor {
  final int hMonitor;
  final int left;
  final int top;

  @override
  final String name;
  @override
  final int width;
  @override
  final int height;

  _WindowsMonitor({
    required this.hMonitor,
    required this.name,
    required this.width,
    required this.height,
    required this.left,
    required this.top,
  });
}

class _WindowsWindow implements DesktopWindow {
  final int hwnd;
  @override
  final String title;
  @override
  final String appName;
  @override
  final int width;
  @override
  final int height;

  _WindowsWindow({
    required this.hwnd,
    required this.title,
    required this.appName,
    required this.width,
    required this.height,
  });
}
