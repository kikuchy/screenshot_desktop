import 'package:desktop_screenshot/desktop_screenshot.dart';
import 'dart:io';

void main() async {
  if (!DesktopScreenshot.instance.hasPermission()) {
    await DesktopScreenshot.instance.requestPermission();
  }
  final availableMonitors = await DesktopScreenshot.instance
      .getAvailableMonitors();

  print('Available Monitors:');
  for (final monitor in availableMonitors) {
    print(' - ${monitor.name} (${monitor.width}x${monitor.height})');
  }

  if (availableMonitors.isNotEmpty) {
    print(
      'Taking screenshot of the first monitor: ${availableMonitors.first.name}',
    );
    final screenshot = await DesktopScreenshot.instance.takeScreenshot(
      availableMonitors.first,
    );
    await File('screenshot.png').writeAsBytes(screenshot);
    print('Screenshot saved to screenshot.png');
  }
}
