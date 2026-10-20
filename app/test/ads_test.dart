import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_arcade/ads/ads.dart';
import 'package:lcd_arcade/remote/remote_settings.dart';

void main() {
  const on = RemoteSettings(
    adsEnabled: true,
    bannerAndroid: 'ca-app-pub-1/111',
    bannerIos: 'ca-app-pub-1/222',
  );

  String? unit(RemoteSettings s, TargetPlatform p, {bool test = false}) =>
      bannerUnit(s, platform: p, testAds: test);

  test('ads off (the default): no banner', () {
    expect(unit(RemoteSettings.defaults, TargetPlatform.android), isNull);
    expect(
      unit(
        const RemoteSettings(bannerAndroid: 'ca-app-pub-1/111'),
        TargetPlatform.android,
      ),
      isNull,
    );
  });

  test('ads on: the real unit per platform', () {
    expect(unit(on, TargetPlatform.android), 'ca-app-pub-1/111');
    expect(unit(on, TargetPlatform.iOS), 'ca-app-pub-1/222');
    expect(unit(on, TargetPlatform.macOS), isNull);
  });

  test("test builds always use Google's test units", () {
    expect(unit(on, TargetPlatform.android, test: true), testBannerAndroid);
    expect(unit(on, TargetPlatform.iOS, test: true), testBannerIos);
  });

  test('no unit set up for a platform: no banner there', () {
    const androidOnly = RemoteSettings(
      adsEnabled: true,
      bannerAndroid: 'ca-app-pub-1/111',
    );
    expect(unit(androidOnly, TargetPlatform.iOS), isNull);
  });
}
