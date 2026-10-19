import 'dart:async';

import 'package:flutter/foundation.dart';

/// Values read from Firebase Remote Config, so ads and update prompts can
/// change without a new release. [defaults] apply until the first fetch
/// succeeds, and always when Firebase is not set up: no ads, no prompts.
@immutable
class RemoteSettings {
  const RemoteSettings({
    this.adsEnabled = false,
    this.bannerAndroid = '',
    this.bannerIos = '',
    this.latestVersion = '',
    this.minVersion = '',
    this.iosAppId = '',
  });

  static const defaults = RemoteSettings();

  // Remote Config parameter names (docs/ads-and-updates-setup.md).
  static const adsEnabledKey = 'ads_enabled';
  static const bannerAndroidKey = 'ads_banner_android';
  static const bannerIosKey = 'ads_banner_ios';
  static const latestVersionKey = 'update_latest_version';
  static const minVersionKey = 'update_min_version';
  static const iosAppIdKey = 'ios_app_store_id';

  /// Show the home-screen banner.
  final bool adsEnabled;

  /// AdMob banner unit ids per platform (empty: no banner).
  final String bannerAndroid;
  final String bannerIos;

  /// Newest version in the stores, e.g. `1.2.0`; older apps offer an
  /// update once per version (empty: no prompt).
  final String latestVersion;

  /// Oldest version still allowed to play; older apps must update (empty:
  /// none).
  final String minVersion;

  /// App Store id (digits) for the iPhone update link.
  final String iosAppId;

  /// The values Remote Config starts from.
  Map<String, Object> toMap() => {
    adsEnabledKey: adsEnabled,
    bannerAndroidKey: bannerAndroid,
    bannerIosKey: bannerIos,
    latestVersionKey: latestVersion,
    minVersionKey: minVersion,
    iosAppIdKey: iosAppId,
  };

  @override
  bool operator ==(Object other) =>
      other is RemoteSettings &&
      other.adsEnabled == adsEnabled &&
      other.bannerAndroid == bannerAndroid &&
      other.bannerIos == bannerIos &&
      other.latestVersion == latestVersion &&
      other.minVersion == minVersion &&
      other.iosAppId == iosAppId;

  @override
  int get hashCode => Object.hash(
    adsEnabled,
    bannerAndroid,
    bannerIos,
    latestVersion,
    minVersion,
    iosAppId,
  );
}

/// Where [RemoteSettings] come from (Firebase in the app, fakes in tests).
abstract interface class RemoteSettingsSource {
  /// Settings available now (from the last fetch), or the defaults.
  Future<RemoteSettings> load();

  /// Newer settings as they arrive: the background fetch, then live
  /// updates while the app runs.
  Stream<RemoteSettings> updates();
}

/// No remote settings: always the defaults.
class NoRemoteSettings implements RemoteSettingsSource {
  const NoRemoteSettings();

  @override
  Future<RemoteSettings> load() async => RemoteSettings.defaults;

  @override
  Stream<RemoteSettings> updates() => const Stream.empty();
}

/// Fixed settings (e.g. an ads preview build before Firebase exists).
class FixedRemoteSettings implements RemoteSettingsSource {
  const FixedRemoteSettings(this.settings);

  final RemoteSettings settings;

  @override
  Future<RemoteSettings> load() async => settings;

  @override
  Stream<RemoteSettings> updates() => const Stream.empty();
}

/// The current [RemoteSettings] for the whole app.
class RemoteSettingsController extends ValueNotifier<RemoteSettings> {
  RemoteSettingsController(this._source) : super(RemoteSettings.defaults);

  final RemoteSettingsSource _source;
  StreamSubscription<RemoteSettings>? _sub;

  /// Applies cached settings, then follows updates. Never throws.
  Future<void> start() async {
    try {
      value = await _source.load();
      _sub = _source.updates().listen(
        (s) => value = s,
        onError: (Object e) => debugPrint('Remote settings update: $e'),
      );
    } catch (e) {
      debugPrint('Remote settings off: $e');
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
