import 'package:screenshot_desktop/screenshot_desktop.dart';
import 'package:test/test.dart';

void main() {
  group('ScreenshotDesktop', () {
    test('instance returns a ScreenshotDesktop', () {
      expect(ScreenshotDesktop.instance, isA<ScreenshotDesktop>());
    });
  });
}
