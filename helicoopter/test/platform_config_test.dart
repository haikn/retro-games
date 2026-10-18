import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards platform settings that code generators (icons, splash) have
/// silently reverted before.
void main() {
  test('Android activity is locked to landscape', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:screenOrientation="sensorLandscape"'));
  });

  test('iOS supports landscape only, full screen, no status bar', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, isNot(contains('UIInterfaceOrientationPortrait')));
    expect(plist, contains('UIInterfaceOrientationLandscapeLeft'));
    expect(plist, contains('UIInterfaceOrientationLandscapeRight'));
    expect(plist, contains('<key>UIRequiresFullScreen</key>'));
    expect(plist, contains('<key>UIStatusBarHidden</key>'));
  });

  test('iOS root view controller defers edge gestures', () {
    final storyboard = File('ios/Runner/Base.lproj/Main.storyboard')
        .readAsStringSync();
    expect(storyboard, contains('customClass="GameViewController"'));
  });
}
