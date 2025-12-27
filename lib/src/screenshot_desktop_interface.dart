import 'dart:typed_data';
import 'dart:io';
import 'monitor.dart';
import 'macos/screenshot_desktop_macos.dart';

abstract class ScreenshotDesktop {
  static ScreenshotDesktop? _instance;

  static ScreenshotDesktop get instance {
    if (_instance != null) return _instance!;
    if (Platform.isMacOS) {
      _instance = ScreenshotDesktopMacOS();
    } else {
      throw UnsupportedError('Platform not supported');
    }
    return _instance!;
  }

  /// Checks if the application has screen recording permission.
  bool hasPermission();

  /// Requests screen recording permission from the OS.
  Future<void> requestPermission();

  /// Lists all available monitors.
  Future<List<Monitor>> getAvailableMonitors();

  /// Takes a screenshot of the specified monitor and returns the image data as a Uint8List.
  Future<Uint8List> takeScreenshot(Monitor monitor);
}
