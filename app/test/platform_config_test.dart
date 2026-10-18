import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_arcade/main.dart';

/// Guards platform settings that code generators (icons, splash) have
/// silently reverted before, and the orientation setup of the collection.
void main() {
  test('Android leaves orientation to the app (portrait launcher, each game '
      'picks its own)', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, isNot(contains('android:screenOrientation')));
  });

  test('iOS allows portrait and landscape, full screen, no status bar', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('UIInterfaceOrientationPortrait</string>'));
    expect(plist, isNot(contains('UIInterfaceOrientationPortraitUpsideDown')));
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

  test('Game Center entitlement: Release and Profile only', () {
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(
      'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'
          .allMatches(pbx)
          .length,
      2,
    );
    expect(
      File('ios/Runner/Runner.entitlements').readAsStringSync(),
      contains('com.apple.developer.game-center'),
    );
  });

  test('Play Games project ID is wired exactly when a game has real IDs', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      manifest.contains('com.google.android.gms.games.APP_ID'),
      games.any((g) => g.leaderboard.androidConfigured),
    );
  });

  test('Xcode asset symbol setting intact (flutter_launcher_icons rewrites '
      'it to "AppIcon")', () {
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(pbx, isNot(contains('SYMBOL_EXTENSIONS = AppIcon')));
  });
}
