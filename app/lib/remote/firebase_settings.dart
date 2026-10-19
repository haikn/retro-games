import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'remote_settings.dart';

/// [RemoteSettings] from Firebase Remote Config. Until the Firebase project
/// files are added (docs/ads-and-updates-setup.md), initialisation fails and
/// the app keeps the defaults: no ads, no update prompts.
class FirebaseSettingsSource implements RemoteSettingsSource {
  FirebaseRemoteConfig? _config;

  @override
  Future<RemoteSettings> load() async {
    try {
      await Firebase.initializeApp();
      final config = FirebaseRemoteConfig.instance;
      await config.setDefaults(RemoteSettings.defaults.toMap());
      await config.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kReleaseMode
              ? const Duration(hours: 1)
              : Duration.zero,
        ),
      );
      await config.activate(); // values fetched on the last run
      _config = config;
      return _read(config);
    } catch (e) {
      debugPrint('Firebase not set up, remote settings off: $e');
      return RemoteSettings.defaults;
    }
  }

  @override
  Stream<RemoteSettings> updates() async* {
    final config = _config;
    if (config == null) return;
    try {
      if (await config.fetchAndActivate()) yield _read(config);
    } catch (e) {
      debugPrint('Remote settings fetch failed: $e');
    }
    // Live updates: a switch flipped in the console reaches running apps.
    await for (final _ in config.onConfigUpdated) {
      await config.activate();
      yield _read(config);
    }
  }

  static RemoteSettings _read(FirebaseRemoteConfig c) => RemoteSettings(
    adsEnabled: c.getBool(RemoteSettings.adsEnabledKey),
    bannerAndroid: c.getString(RemoteSettings.bannerAndroidKey).trim(),
    bannerIos: c.getString(RemoteSettings.bannerIosKey).trim(),
    latestVersion: c.getString(RemoteSettings.latestVersionKey).trim(),
    minVersion: c.getString(RemoteSettings.minVersionKey).trim(),
    iosAppId: c.getString(RemoteSettings.iosAppIdKey).trim(),
  );
}
