/// Represents a window on the desktop.
abstract class DesktopWindow {
  /// The title of the window.
  final String title;

  /// The name of the application that owns the window.
  final String appName;

  /// The width of the window in pixels.
  final int width;

  /// The height of the window in pixels.
  final int height;

  /// Creates a [DesktopWindow] instance.
  const DesktopWindow({
    required this.title,
    required this.appName,
    required this.width,
    required this.height,
  });
}
