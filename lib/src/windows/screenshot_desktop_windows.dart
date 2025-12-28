import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

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
