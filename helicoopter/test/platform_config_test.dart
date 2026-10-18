import 'dart:io';

import 'package:cave_copter/services/leaderboard_ids.dart';
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

  test('Game Center entitlement: Release and Profile only', () {
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(
      'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'
          .allMatches(pbx)
          .length,
      2,
    );
    final entitlements = File('ios/Runner/Runner.entitlements')
        .readAsStringSync();
    expect(entitlements, contains('com.apple.developer.game-center'));
  });

  test('Play Games project ID is wired exactly when the IDs are real', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      manifest.contains('com.google.android.gms.games.APP_ID'),
      LeaderboardIds.androidConfigured,
    );
  });
}
