import 'dart:async';
import 'dart:ffi';
import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:objective_c/objective_c.dart' as objc;
import '../desktop_window.dart';
import '../screenshot_desktop_interface.dart';
import '../monitor.dart';
import 'bindings.g.dart';

/// The macOS implementation of [ScreenshotDesktop].
///
/// This implementation uses ScreenCaptureKit to capture high-quality screenshots.
class ScreenshotDesktopMacOS extends ScreenshotDesktop {
  ScreenshotDesktopMacOS() : super();

  @override
  bool hasPermission() {
    return CGPreflightScreenCaptureAccess();
  }

  @override
  Future<void> requestPermission() async {
    CGRequestScreenCaptureAccess();
  }

  @override
  Future<List<Monitor>> getAvailableMonitors() async {
    if (!hasPermission()) {
      throw StateError('Screen capture permission not granted');
    }

    final screens = NSScreen.getScreens();
    final monitors = <Monitor>[];

    for (final screen in screens.toDartList().cast<NSScreen>()) {
      final displayId = screen.CGDirectDisplayID;
      final frame = screen.frame;
      final name = screen.localizedName.toDartString();

      monitors.add(
        _MacosMonitor(
          displayId: displayId,
          name: name,
          width: frame.size.width.toInt(),
          height: frame.size.height.toInt(),
        ),
      );
    }

    return monitors;
  }

  @override
  Future<Uint8List> takeScreenshot(Monitor monitor) async {
    if (!hasPermission()) {
      throw StateError('Screen capture permission not granted');
    }

    if (monitor is! _MacosMonitor) {
      throw ArgumentError('Invalid monitor type');
    }

    final (display, applications) = await _getLatestShareableDisplayAndContent(
      monitor.displayId,
    );
    return await _takeScreenshot(display, applications);
  }

  @override
  Future<List<DesktopWindow>> getAvailableWindows() async {
    if (!hasPermission()) {
      throw StateError('Screen capture permission not granted');
    }

    // Ensure AppKit is initialized to avoid CGS_REQUIRE_INIT assertion
    NSScreen.getScreens();

    final shareableContent = await _getShareableContent();
    final windows = <DesktopWindow>[];

    for (final window
        in shareableContent.windows.toDartList().cast<SCWindow>()) {
      // Filter out windows that are not on screen or have no title/app name
      if (!window.isOnScreen) continue;
      if (window.windowLayer != 0) continue; // Only want main windows

      final title = window.title?.toDartString() ?? '';
      final appName =
          window.owningApplication?.applicationName.toDartString() ?? '';

      // Skip internal windows or windows without identifying info
      if (title.isEmpty && appName.isEmpty) continue;

      windows.add(
        _MacosWindow(
          windowId: window.windowID,
          title: title,
          appName: appName,
          width: window.frame.size.width.toInt(),
          height: window.frame.size.height.toInt(),
        ),
      );
    }

    return windows;
  }

  @override
  Future<Uint8List> takeWindowScreenshot(DesktopWindow window) async {
    if (!hasPermission()) {
      throw StateError('Screen capture permission not granted');
    }

    // Ensure AppKit is initialized
    NSScreen.getScreens();

    if (window is! _MacosWindow) {
      throw ArgumentError('Invalid window type');
    }

    final shareableContent = await _getShareableContent();
    final scWindow = shareableContent.windows
        .toDartList()
        .cast<SCWindow>()
        .firstWhere((w) => w.windowID == window.windowId);

    final filter = SCContentFilter.alloc().initWithDesktopIndependentWindow(
      scWindow,
    );

    return await _takeWindowScreenshot(filter, scWindow.frame);
  }

  Future<SCShareableContent> _getShareableContent() {
    final completer = Completer<SCShareableContent>();
    SCShareableContent.getShareableContentWithCompletionHandler(
      ObjCBlock_ffiVoid_SCShareableContent_NSError.listener((scContent, error) {
        if (error != null) {
          completer.completeError(
            Exception(
              'Failed to get shareable content: ${error.localizedDescription.toDartString()}',
            ),
          );
          return;
        }
        if (scContent == null) {
          completer.completeError(Exception('Shareable content is null'));
          return;
        }
        completer.complete(scContent);
      }, keepIsolateAlive: true),
    );
    return completer.future;
  }

  Future<(SCDisplay, objc.NSArray)> _getLatestShareableDisplayAndContent(
    int displayId,
  ) {
    final displayCompleter = Completer<(SCDisplay, objc.NSArray)>();

    SCShareableContent.getShareableContentWithCompletionHandler(
      ObjCBlock_ffiVoid_SCShareableContent_NSError.listener((
        scDisplays,
        error,
      ) {
        if (error != null) {
          displayCompleter.completeError(
            Exception(
              'Failed to get shareable content: ${error.localizedDescription.toDartString()}',
            ),
          );
          return;
        }
        if (scDisplays == null) {
          displayCompleter.completeError(
            Exception('Shareable content is null'),
          );
          return;
        }
        displayCompleter.complete((
          scDisplays.displays.toDartList().cast<SCDisplay>().firstWhere(
            (display) => display.displayID == displayId,
          ),
          scDisplays.applications,
        ));
      }, keepIsolateAlive: true),
    );

    return displayCompleter.future;
  }

  Future<Uint8List> _takeScreenshot(
    SCDisplay display,
    objc.NSArray applications,
  ) {
    final filter = SCContentFilter.alloc().initWithDisplay$2(
      display,
      includingApplications: applications,
      exceptingWindows: objc.NSArray.alloc().init(),
    );

    final pixelCompleter = Completer<Uint8List>();

    final config = SCScreenshotConfiguration.alloc().init();
    config.contentType = UTTypeBMP;
    config.destinationRect = display.frame;

    SCScreenshotManager.captureScreenshotWithFilter(
      filter,
      configuration: config,
      completionHandler: ObjCBlock_ffiVoid_SCScreenshotOutput_NSError.listener((
        screenshotOutput,
        error,
      ) {
        if (error != null) {
          pixelCompleter.completeError(
            Exception(
              'Capture error: ${error.localizedDescription.toDartString()}',
            ),
          );
          return;
        }
        if (screenshotOutput == null) {
          pixelCompleter.completeError(Exception('Captured output is null'));
          return;
        }
        final sdrImage = screenshotOutput.sdrImage;
        if (sdrImage == ffi.nullptr) {
          pixelCompleter.completeError(Exception('Captured image is null'));
          return;
        }
        try {
          final bmpData = _convertCGImageToBmp(sdrImage);
          pixelCompleter.complete(bmpData);
        } catch (e) {
          pixelCompleter.completeError(e);
        }
      }, keepIsolateAlive: true),
    );

    return pixelCompleter.future;
  }

  Future<Uint8List> _takeWindowScreenshot(
    SCContentFilter filter,
    objc.CGRect frame,
  ) {
    final pixelCompleter = Completer<Uint8List>();

    final config = SCScreenshotConfiguration.alloc().init();
    config.contentType = UTTypeBMP;
    config.destinationRect = frame;

    SCScreenshotManager.captureScreenshotWithFilter(
      filter,
      configuration: config,
      completionHandler: ObjCBlock_ffiVoid_SCScreenshotOutput_NSError.listener((
        screenshotOutput,
        error,
      ) {
        if (error != null) {
          pixelCompleter.completeError(
            Exception(
              'Capture error: ${error.localizedDescription.toDartString()}',
            ),
          );
          return;
        }
        if (screenshotOutput == null) {
          pixelCompleter.completeError(Exception('Captured output is null'));
          return;
        }
        final sdrImage = screenshotOutput.sdrImage;
        if (sdrImage == ffi.nullptr) {
          pixelCompleter.completeError(Exception('Captured image is null'));
          return;
        }
        try {
          final bmpData = _convertCGImageToBmp(sdrImage);
          pixelCompleter.complete(bmpData);
        } catch (e) {
          pixelCompleter.completeError(e);
        }
      }, keepIsolateAlive: true),
    );

    return pixelCompleter.future;
  }

  Uint8List _convertCGImageToBmp(ffi.Pointer<CGImage> cgImage) {
    if (cgImage == ffi.nullptr) throw ArgumentError('cgImage is null');

    final mutableData = CFDataCreateMutable(ffi.nullptr, 0);
    if (mutableData == ffi.nullptr) {
      throw Exception('Failed to create CFMutableData');
    }

    final destination = CGImageDestinationCreateWithData(
      mutableData,
      kUTTypeBMP,
      1,
      ffi.nullptr,
    );

    if (destination == ffi.nullptr) {
      CFRelease(mutableData.cast());
      throw Exception('Failed to create CGImageDestination');
    }

    try {
      CGImageDestinationAddImage(destination, cgImage, ffi.nullptr);
      if (!CGImageDestinationFinalize(destination)) {
        throw Exception('Failed to finalize CGImageDestination');
      }

      final length = CFDataGetLength(mutableData);
      final bytes = CFDataGetBytePtr(mutableData);

      if (bytes == ffi.nullptr && length > 0) {
        throw Exception('Failed to get bytes from CFData');
      }

      return bytes.cast<Uint8>().asTypedList(length).sublist(0);
    } finally {
      CFRelease(mutableData.cast());
      CFRelease(destination.cast());
    }
  }
}

class _MacosMonitor implements Monitor {
  final int displayId;
  @override
  final String name;
  @override
  final int width;
  @override
  final int height;
  const _MacosMonitor({
    required this.displayId,
    required this.name,
    required this.width,
    required this.height,
  });
}

class _MacosWindow implements DesktopWindow {
  final int windowId;
  @override
  final String title;
  @override
  final String appName;
  @override
  final int width;
  @override
  final int height;

  const _MacosWindow({
    required this.windowId,
    required this.title,
    required this.appName,
    required this.width,
    required this.height,
  });
}
