import 'dart:async';
import 'dart:ffi';
import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:objective_c/objective_c.dart' as objc;
import '../desktop_screenshot_interface.dart';
import '../monitor.dart';
import 'bindings.g.dart';

class DesktopScreenshotMacOS extends DesktopScreenshot {
  DesktopScreenshotMacOS() : super() {
    // DynamicLibrary.open(
    //   '/System/Library/Frameworks/ScreenCaptureKit.framework/ScreenCaptureKit',
    // );
  }

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
    final completer = Completer<(List<SCDisplay>, objc.NSArray)>();

    SCShareableContent.getShareableContentWithCompletionHandler(
      ObjCBlock_ffiVoid_SCShareableContent_NSError.listener((
        scDisplays,
        error,
      ) {
        if (error != null) {
          print(error.localizedDescription.toDartString());
          completer.completeError(error);
          return;
        }
        print(
          scDisplays!.windows
              .toDartList()
              .cast<SCWindow>()
              .map((e) => e.description.toDartString())
              .toList(),
        );
        print(
          scDisplays!.applications
              .toDartList()
              .cast<SCRunningApplication>()
              .map((e) => e.description.toDartString())
              .toList(),
        );
        completer.complete((
          scDisplays!.displays.toDartList().cast<SCDisplay>(),
          scDisplays.applications,
        ));
      }, keepIsolateAlive: true),
    );
    final (displays, applications) = await completer.future;
    return displays
        .map(
          (display) => _MacosMonitor(
            display: display,
            applications: applications,
            name: display.description.toDartString(),
          ),
        )
        .toList();
  }

  @override
  Future<Uint8List> takeScreenshot(Monitor monitor) async {
    if (monitor is! _MacosMonitor) {
      throw ArgumentError('Invalid monitor type');
    }

    final display = monitor.display;
    final frame = display.frame;
    print(
      'Display: ${display.width}x${display.height}, Frame: (${frame.origin.x}, ${frame.origin.y}) ${frame.size.width}x${frame.size.height}',
    );

    final filter = SCContentFilter.alloc().initWithDisplay$2(
      display,
      includingApplications: monitor.applications,
      exceptingWindows: objc.NSArray.alloc().init(),
    );

    final completer = Completer<Uint8List>();

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
          print('Capture error: ${error.localizedDescription.toDartString()}');
          print(error.debugDescription.toDartString());
          print(error.code);
          completer.completeError(error);
          return;
        }
        if (screenshotOutput == null) {
          completer.completeError(Exception('Captured image is null'));
          return;
        }
        try {
          final pngData = _convertCGImageToPng(screenshotOutput.sdrImage);
          completer.complete(pngData);
        } catch (e) {
          completer.completeError(e);
        }
      }, keepIsolateAlive: true),
    );

    return completer.future;
  }

  Uint8List _convertCGImageToPng(ffi.Pointer<CGImage> cgImage) {
    if (cgImage == ffi.nullptr) throw Exception('cgImage is null');
    final w = CGImageGetWidth(cgImage);
    final h = CGImageGetHeight(cgImage);
    print('Starting _convertCGImageToPng, cgImage size: ${w}x${h}');
    final mutableData = CFDataCreateMutable(ffi.nullptr, 0);

    final destination = CGImageDestinationCreateWithData(
      mutableData,
      kUTTypePNG,
      1,
      ffi.nullptr,
    );

    if (destination == ffi.nullptr) {
      throw Exception('Failed to create CGImageDestination');
    }
    print('CGImageDestination created');

    try {
      CGImageDestinationAddImage(destination, cgImage, ffi.nullptr);
      print('Added image to destination');
      if (!CGImageDestinationFinalize(destination)) {
        throw Exception('Failed to finalize CGImageDestination');
      }
      print('Finalized destination');

      final length = CFDataGetLength(mutableData);
      print('Data length: $length');
      final bytes = CFDataGetBytePtr(mutableData);

      if (bytes == ffi.nullptr) {
        throw Exception('Failed to get bytes from NSData');
      }

      return bytes.cast<Uint8>().asTypedList(length).sublist(0);
    } finally {
      CFRelease(mutableData.cast());
      CFRelease(destination.cast());
    }
  }
}

class _MacosMonitor implements Monitor {
  final SCDisplay display;
  final objc.NSArray applications;
  final String name;
  const _MacosMonitor({
    required this.display,
    required this.applications,
    required this.name,
  });

  @override
  int get width => display.width;

  @override
  int get height => display.height;
}

class _DisplayListCallback
    extends
        objc.ObjCBlock<ffi.Void Function(SCShareableContent?, objc.NSError?)> {
  final Completer<List<SCDisplay>> completer;
  _DisplayListCallback(
    super.ptr, {
    required super.retain,
    required super.release,
    required this.completer,
  });

  void call(SCShareableContent? content, objc.NSError? error) {
    if (error != null) {
      completer.completeError(error);
      return;
    }
    if (content == null) {
      completer.completeError(Exception('Shareable content is null'));
      return;
    }
    completer.complete(content.displays.toDartList().cast());
  }
}
