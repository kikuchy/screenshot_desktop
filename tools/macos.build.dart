// Regenerate bindings with `dart run tools/macos.build.dart`.
import 'dart:io';
import 'package:ffigen/ffigen.dart';

String get macSdkPath {
  final result = Process.runSync('xcrun', [
    '--show-sdk-path',
    '--sdk',
    'macosx',
  ]);
  if (result.exitCode != 0) {
    throw Exception('Failed to get macOS SDK path: ${result.stderr}');
  }
  return result.stdout.toString().trim();
}

final config = FfiGenerator(
  headers: Headers(
    entryPoints: [
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/ScreenCaptureKit.framework/Headers/ScreenCaptureKit.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/ImageIO.framework/Headers/ImageIO.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/CoreGraphics.framework/Headers/CoreGraphics.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/UniformTypeIdentifiers.framework/Headers/UniformTypeIdentifiers.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/AppKit.framework/Headers/AppKit.h',
      ),
    ],
  ),
  objectiveC: ObjectiveC(
    interfaces: Interfaces.includeSet({
      // ScreenCaptureKit
      'SCDisplay',
      'SCScreenshotManager',
      'SCShareableContent',
      'SCContentFilter',
      'SCScreenshotConfiguration',
      'SCScreenshotOutput',
      // AppKit
      'NSScreen',
    }),
  ),
  output: Output(
    dartFile: Uri.file('lib/src/macos/bindings.g.dart'),
    objectiveCFile: Uri.file('src/bindings.g.m'),
  ),
  functions: Functions.includeSet({
    // Core Graphics
    'CGPreflightScreenCaptureAccess',
    'CGRequestScreenCaptureAccess',
    'CFRelease',
    // ImageIO
    'CGImageDestinationCreateWithData',
    'CGImageDestinationAddImage',
    'CGImageDestinationFinalize',
    'CFDataCreateMutable',
    'CFDataGetLength',
    'CFDataGetBytePtr',
  }),
  globals: Globals.includeSet({'kUTTypePNG', 'UTTypePNG'}),
  typedefs: Typedefs.includeSet({}),
  enums: Enums.includeSet({}),
);

void main() => config.generate();
