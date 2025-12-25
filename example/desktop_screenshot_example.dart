import 'package:desktop_screenshot/desktop_screenshot.dart';
import 'dart:io';

void main() async {
  if (!DesktopScreenshot.instance.hasPermission()) {
    await DesktopScreenshot.instance.requestPermission();
  }
  final availableMonitors = await DesktopScreenshot.instance
      .getAvailableMonitors();

  if (availableMonitors.isNotEmpty) {
    final screenshot = await DesktopScreenshot.instance.takeScreenshot(
      availableMonitors.first,
    );
    await File('screenshot.png').writeAsBytes(screenshot);
    print('Screenshot saved to screenshot.png');
  }
}
