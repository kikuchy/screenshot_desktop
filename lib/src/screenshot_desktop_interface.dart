import 'dart:typed_data';
import 'dart:io';
import 'monitor.dart';
import 'macos/screenshot_desktop_macos.dart';
import 'windows/screenshot_desktop_windows.dart';

/// The interface for capturing desktop screenshots across different platforms.
///
/// Use [ScreenshotDesktop.instance] to get the platform-specific implementation.
abstract class ScreenshotDesktop {
  static ScreenshotDesktop? _instance;

  /// Returns the singleton instance of the [ScreenshotDesktop] for the current platform.
  ///
  /// Currently supports macOS and Windows. Throws an [UnsupportedError] on other platforms.
  static ScreenshotDesktop get instance {
    if (_instance != null) return _instance!;
    if (Platform.isMacOS) {
      _instance = ScreenshotDesktopMacOS();
    } else if (Platform.isWindows) {
      _instance = ScreenshotDesktopWindows();
    } else {
      throw UnsupportedError('Platform not supported');
    }
    return _instance!;
  }

  /// Checks if the application has screen recording permission from the operating system.
  ///
  /// Returns `true` if permission is granted, `false` otherwise.
  bool hasPermission();

  /// Requests screen recording permission from the operating system.
  ///
  /// This typically triggers a system dialog asking the user for permission.
  Future<void> requestPermission();

  /// Retrieves a list of all monitors currently available on the system.
  ///
  /// Throws a [StateError] if screen capture permission has not been granted.
  Future<List<Monitor>> getAvailableMonitors();

  /// Takes a screenshot of the specified [monitor] and returns the image data.
  ///
  /// The returned [Uint8List] contains the raw BMP image data.
  /// Throws a [StateError] if screen capture permission is missing, or an [ArgumentError]
  /// if the provided [monitor] is invalid for the current platform.
  Future<Uint8List> takeScreenshot(Monitor monitor);
}
