import 'dart:async';
import 'dart:ffi';
import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:objective_c/objective_c.dart' as objc;
import '../desktop_screenshot_interface.dart';
import '../monitor.dart';
import 'bindings.g.dart';

class DesktopScreenshotMacOS extends DesktopScreenshot {
  DesktopScreenshotMacOS() : super();

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
    config.contentType = UTTypePNG;
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
          final pngData = _convertCGImageToPng(sdrImage);
          pixelCompleter.complete(pngData);
        } catch (e) {
          pixelCompleter.completeError(e);
        }
      }, keepIsolateAlive: true),
    );

    return pixelCompleter.future;
  }

  Uint8List _convertCGImageToPng(ffi.Pointer<CGImage> cgImage) {
    if (cgImage == ffi.nullptr) throw ArgumentError('cgImage is null');

    final mutableData = CFDataCreateMutable(ffi.nullptr, 0);
    if (mutableData == ffi.nullptr) {
      throw Exception('Failed to create CFMutableData');
    }

    final destination = CGImageDestinationCreateWithData(
      mutableData,
      kUTTypePNG,
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
  final String name;
  final int width;
  final int height;
  const _MacosMonitor({
    required this.displayId,
    required this.name,
    required this.width,
    required this.height,
  });
}
