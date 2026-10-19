import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../remote/remote_settings.dart';

/// Google's sample banner units: always used in debug and playtest builds,
/// because tapping our own real ads breaks AdMob policy.
const testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
const testBannerIos = 'ca-app-pub-3940256099942544/2934735716';

/// The banner unit for [platform], or null for no banner.
String? bannerUnit(
  RemoteSettings settings, {
  required TargetPlatform platform,
  required bool testAds,
}) {
  if (!settings.adsEnabled) return null;
  final (real, test) = switch (platform) {
    TargetPlatform.android => (settings.bannerAndroid, testBannerAndroid),
    TargetPlatform.iOS => (settings.bannerIos, testBannerIos),
    _ => ('', ''),
  };
  if (real.isEmpty) return null; // no unit set up for this platform
  return testAds ? test : real;
}

/// Starts the ads SDK only once ads are switched on, after the consent
/// form Google requires in the EEA, the UK and Switzerland. With ads off
/// nothing is initialised and no ad data is collected.
class AdsController {
  Future<bool>? _ready;

  /// True once ads may be requested (consent given or not needed).
  Future<bool> ensureReady() => _ready ??= _start();

  Future<bool> _start() async {
    try {
      final info = ConsentInformation.instance;
      final updated = Completer<void>();
      info.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        updated.complete,
        (error) => updated.completeError(error.message),
      );
      await updated.future;
      final shown = Completer<void>();
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {
        shown.complete();
      });
      await shown.future;
      if (!await info.canRequestAds()) return false;
      await MobileAds.instance.initialize();
      return true;
    } catch (e) {
      debugPrint('Ads unavailable: $e');
      _ready = null; // try again next time ads are wanted
      return false;
    }
  }

  /// Whether the player must be able to change their ad consent (shows the
  /// launcher's `Ads` key).
  Future<bool> privacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  Future<void> showPrivacyOptions() =>
      ConsentForm.showPrivacyOptionsForm((_) {});
}

/// The home-screen banner under the LCD. Takes no space until an ad has
/// loaded, and goes away when ads are switched off remotely.
class BannerSlot extends StatefulWidget {
  const BannerSlot({
    super.key,
    required this.settings,
    required this.ads,
    required this.testAds,
    this.onPrivacyRequired,
  });

  final ValueListenable<RemoteSettings> settings;
  final AdsController ads;
  final bool testAds;

  /// Called once consent shows that the player needs the `Ads` key.
  final VoidCallback? onPrivacyRequired;

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  String? _unit;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_sync);
    unawaited(_ad?.dispose());
    super.dispose();
  }

  Future<void> _sync() async {
    final unit = bannerUnit(
      widget.settings.value,
      platform: defaultTargetPlatform,
      testAds: widget.testAds,
    );
    if (unit == _unit) return;
    _unit = unit;
    _drop();
    if (unit == null || !await widget.ads.ensureReady()) return;
    if (!mounted || unit != _unit) return;
    if (await widget.ads.privacyOptionsRequired()) {
      widget.onPrivacyRequired?.call();
    }
    final ad = BannerAd(
      adUnitId: unit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => mounted ? setState(() => _loaded = true) : null,
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner failed: ${error.message}');
          unawaited(ad.dispose());
          if (mounted && identical(ad, _ad)) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  void _drop() {
    final ad = _ad;
    _ad = null;
    unawaited(ad?.dispose());
    if (_loaded && mounted) setState(() => _loaded = false);
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
