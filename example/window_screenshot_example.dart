import 'package:screenshot_desktop/screenshot_desktop.dart';
import 'dart:io';

void main() async {
  final screenshotter = ScreenshotDesktop.instance;

  if (!screenshotter.hasPermission()) {
    print('Requesting screen recording permission...');
    await screenshotter.requestPermission();
    // In a real app, you might want to wait or check again.
  }

  print('Listing available windows...');
  final windows = await screenshotter.getAvailableWindows();

  print('Found ${windows.length} windows:');
  for (int i = 0; i < windows.length; i++) {
    final window = windows[i];
    print(
      '[$i] "${window.title}" (${window.appName}) - ${window.width}x${window.height}',
    );
  }

  if (windows.isNotEmpty) {
    // Try to find a window with a title, otherwise take the first one
    final targetWindow = windows.firstWhere(
      (w) => w.title.isNotEmpty,
      orElse: () => windows.first,
    );

    print(
      '\nTaking screenshot of window: "${targetWindow.title}" (${targetWindow.appName})',
    );
    try {
      final screenshot = await screenshotter.takeWindowScreenshot(targetWindow);
      final outputFile = File('window_screenshot.bmp');
      await outputFile.writeAsBytes(screenshot);
      print('Screenshot saved to ${outputFile.path}');
    } catch (e) {
      print('Error taking window screenshot: $e');
    }
  } else {
    print('No windows found.');
  }
}
