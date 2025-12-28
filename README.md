# screenshot_desktop

A Dart package for taking desktop screenshots on macOS and Windows.

Unlike many other screenshot packages, this one **does not depend on Flutter**. It can be used in command-line tools or any other pure Dart environment, while remaining fully compatible with Flutter applications.

## Features

- **Multi-monitor support**: List all available monitors and their resolutions.
- **Specific monitor capture**: Take a high-resolution screenshot of a specific monitor.
- **Pure Dart**: No Flutter dependency required.

## Getting started

Add `screenshot_desktop` to your `pubspec.yaml`:

```yaml
dependencies:
  screenshot_desktop: ^1.0.0+1
```

## Usage

```dart
import 'package:screenshot_desktop/screenshot_desktop.dart';
import 'dart:io';

void main() async {
  // 1. Get available monitors
  final monitors = await ScreenshotDesktop.instance.getAvailableMonitors();

  for (final monitor in monitors) {
    print('Monitor: ${monitor.name} (${monitor.width}x${monitor.height})');
  }

  if (monitors.isNotEmpty) {
    // 2. Capture a specific monitor
    final screenshot = await ScreenshotDesktop.instance.takeScreenshot(monitors.first);

    // 3. Save as a file (BMP)
    await File('screenshot.bmp').writeAsBytes(screenshot);
  }
}
```

## Additional information

For more information, issues, or contributions, please visit the [repository](https://github.com/kikuchy/screenshot_desktop).
