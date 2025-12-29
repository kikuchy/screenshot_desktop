# screenshot_desktop

A Dart package for taking desktop screenshots on macOS and Windows.

Unlike many other screenshot packages, this one **does not depend on Flutter**. It can be used in command-line tools or any other pure Dart environment, while remaining fully compatible with Flutter applications.

## Features

- **Multi-monitor support**: List all available monitors and their resolutions.
- **Specific monitor capture**: Take a high-resolution screenshot of a specific monitor.
- **Window capture**: List all available windows and capture screenshots of specific windows.
- **Pure Dart**: No Flutter dependency required.

## Getting started

Add `screenshot_desktop` to your `pubspec.yaml`:

```yaml
dependencies:
  screenshot_desktop: ^1.1.0
```

## Usage

### Monitor Screenshot

```dart
import 'package:screenshot_desktop/screenshot_desktop.dart';
import 'dart:io';

void main() async {
  // 1. Get available monitors
  final monitors = await ScreenshotDesktop.instance.getAvailableMonitors();

  if (monitors.isNotEmpty) {
    // 2. Capture a specific monitor
    final screenshot = await ScreenshotDesktop.instance.takeScreenshot(monitors.first);

    // 3. Save as a file (BMP)
    await File('monitor_screenshot.bmp').writeAsBytes(screenshot);
  }
}
```

### Window Screenshot

```dart
import 'package:screenshot_desktop/screenshot_desktop.dart';
import 'dart:io';

void main() async {
  // 1. Get available windows
  final windows = await ScreenshotDesktop.instance.getAvailableWindows();

  for (final window in windows) {
    print('Window: ${window.title} (App: ${window.appName})');
  }

  if (windows.isNotEmpty) {
    // 2. Capture a specific window
    final screenshot = await ScreenshotDesktop.instance.takeWindowScreenshot(windows.first);

    // 3. Save as a file (BMP)
    await File('window_screenshot.bmp').writeAsBytes(screenshot);
  }
}
```

## Additional information

For more information, issues, or contributions, please visit the [repository](https://github.com/kikuchy/screenshot_desktop).
