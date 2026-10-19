import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_arcade/remote/remote_settings.dart';

class _Source implements RemoteSettingsSource {
  _Source(this.cached, {this.fail = false});

  final RemoteSettings cached;
  final bool fail;
  final live = StreamController<RemoteSettings>();

  @override
  Future<RemoteSettings> load() async {
    if (fail) throw Exception('offline');
    return cached;
  }

  @override
  Stream<RemoteSettings> updates() => live.stream;
}

void main() {
  test('starts from the cached values, then follows updates', () async {
    final source = _Source(const RemoteSettings(adsEnabled: true));
    final c = RemoteSettingsController(source);
    expect(c.value, RemoteSettings.defaults);
    await c.start();
    expect(c.value.adsEnabled, isTrue);
    source.live.add(const RemoteSettings()); // switched off remotely
    await Future<void>.delayed(Duration.zero);
    expect(c.value.adsEnabled, isFalse);
    c.dispose();
  });

  test('a failing source leaves the defaults and never throws', () async {
    final c = RemoteSettingsController(
      _Source(RemoteSettings.defaults, fail: true),
    );
    await c.start();
    expect(c.value, RemoteSettings.defaults);
  });

  test('defaults: ads off, no update prompts', () {
    expect(RemoteSettings.defaults.toMap(), {
      'ads_enabled': false,
      'ads_banner_android': '',
      'ads_banner_ios': '',
      'update_latest_version': '',
      'update_min_version': '',
      'ios_app_store_id': '',
    });
  });
}
