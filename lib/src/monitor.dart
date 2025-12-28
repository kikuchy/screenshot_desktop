/// Represents a physical or virtual display monitor attached to the system.
abstract class Monitor {
  /// The hardware name or identifier of the monitor.
  final String name;

  /// The horizontal resolution of the monitor in pixels.
  final int width;

  /// The vertical resolution of the monitor in pixels.
  final int height;

  /// Creates a [Monitor] instance with the specified properties.
  const Monitor({
    required this.name,
    required this.width,
    required this.height,
  });
}
