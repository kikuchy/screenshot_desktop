import 'package:screenshot_desktop/screenshot_desktop.dart';
import 'dart:io';

void main() async {
  if (!ScreenshotDesktop.instance.hasPermission()) {
    await ScreenshotDesktop.instance.requestPermission();
  }
  final availableMonitors = await ScreenshotDesktop.instance
      .getAvailableMonitors();

  print('Available Monitors:');
  for (final monitor in availableMonitors) {
    print(' - ${monitor.name} (${monitor.width}x${monitor.height})');
  }

  if (availableMonitors.isNotEmpty) {
    print(
      'Taking screenshot of the first monitor: ${availableMonitors.first.name}',
    );
    final screenshot = await ScreenshotDesktop.instance.takeScreenshot(
      availableMonitors.first,
    );
    await File('screenshot.png').writeAsBytes(screenshot);
    print('Screenshot saved to screenshot.png');
  }
}
