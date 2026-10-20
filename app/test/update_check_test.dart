import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_arcade/remote/remote_settings.dart';
import 'package:lcd_arcade/update/update_check.dart';

void main() {
  test('version codes: 1.2.3 → 1002003; build numbers and gaps', () {
    expect(versionCode('1.2.3'), 1002003);
    expect(versionCode('1.2.3+45'), 1002003);
    expect(versionCode('2'), 2000000);
    expect(versionCode('1.10'), 1010000);
    expect(versionCode(''), isNull);
    expect(versionCode('1.x'), isNull);
    expect(versionCode('1.2.3.4'), isNull);
  });

  test('no settings: no prompt', () {
    expect(updateNeed('1.0.0', RemoteSettings.defaults), UpdateNeed.none);
  });

  test('a newer version is offered until dismissed', () {
    const s = RemoteSettings(latestVersion: '1.1.0');
    expect(updateNeed('1.0.0', s), UpdateNeed.optional);
    expect(updateNeed('1.1.0', s), UpdateNeed.none);
    expect(updateNeed('1.2.0', s), UpdateNeed.none);
    expect(updateNeed('1.0.0', s, dismissed: 1001000), UpdateNeed.none);
    // A later release asks again.
    const next = RemoteSettings(latestVersion: '1.2.0');
    expect(updateNeed('1.0.0', next, dismissed: 1001000), UpdateNeed.optional);
  });

  test(
    'below the minimum version an update is required, even if dismissed',
    () {
      const s = RemoteSettings(latestVersion: '1.2.0', minVersion: '1.1.0');
      expect(updateNeed('1.0.9', s, dismissed: 1002000), UpdateNeed.required);
      expect(updateNeed('1.1.0', s), UpdateNeed.optional);
    },
  );

  test('a malformed remote value never locks the games', () {
    const s = RemoteSettings(latestVersion: 'soon', minVersion: 'v2');
    expect(updateNeed('1.0.0', s), UpdateNeed.none);
  });
}
