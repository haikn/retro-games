import 'dart:async';

import 'package:blocks/blocks.dart';
import 'package:copter/copter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hop/hop.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lcd_kit/lcd_kit.dart';
import 'package:snake/snake.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ads/ads.dart';
import 'launcher/launcher_screen.dart';
import 'launcher/orientation.dart';
import 'remote/firebase_settings.dart';
import 'remote/remote_settings.dart';
import 'update/update_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // v1 monitoring is the stores' crash reporting; log everything else.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Uncaught Flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };
  registerLcdKitLicenses();
  await lockOrientation(GameOrientation.portrait);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final store = await LocalStore.open();
  await store.migrateLegacyScores('copter'); // Cave Copter 1.x scores
  final services = ArcadeServices.create(store, games);
  final info = await PackageInfo.fromPlatform();
  final remote = RemoteSettingsController(
    adsPreview
        ? const FixedRemoteSettings(
            RemoteSettings(
              adsEnabled: true,
              bannerAndroid: testBannerAndroid,
              bannerIos: testBannerIos,
            ),
          )
        : FirebaseSettingsSource(),
  );
  unawaited(remote.start());
  runApp(
    LcdArcadeApp(
      services: services,
      remote: remote,
      version: info.version,
      ads: AdsController(),
      testAds: !kReleaseMode || playtest,
      openStore: (settings) => openStore(settings, info.packageName),
    ),
  );
  // Sign in once, while the launcher shows (never mid-run).
  unawaited(services.signIn());
}

/// The collection, in launcher order.
const games = <GameModule>[
  CopterModule(),
  SnakeModule(),
  BlocksModule(),
  HopModule(),
];

/// `--dart-define=PLAYTEST=true`: a release build for our own phones that
/// still opens games not yet cleared for release.
const playtest = bool.fromEnvironment('PLAYTEST');

/// `--dart-define=ADS_PREVIEW=true`: show Google's test banner without
/// Firebase, to check the ad layout and consent flow on a phone.
const adsPreview = bool.fromEnvironment('ADS_PREVIEW');

/// Launcher tiles. A game not cleared for release (e.g. Blocks, pending its
/// IP review) is shown as "Coming soon" in release builds.
List<LauncherEntry> launcherEntriesFor(
  List<GameModule> games, {
  bool release = kReleaseMode && !playtest,
}) => [
  for (final g in games)
    if (g.releaseCleared || !release)
      LauncherEntry.of(g)
    else
      LauncherEntry(title: g.title, icon: g.icon),
];

/// Storage, sound and one leaderboard per game, shared by the whole app.
class ArcadeServices {
  ArcadeServices({
    required this.store,
    required this.sound,
    required this.leaderboards,
  });

  factory ArcadeServices.create(
    LocalStore store,
    List<GameModule> games, {
    LeaderboardBackend Function(GameModule game)? backend,
  }) => ArcadeServices(
    store: store,
    sound: SoundSetting(store),
    leaderboards: {
      for (final g in games)
        g.id: LeaderboardService(
          backend?.call(g) ?? platformLeaderboardBackend(g.leaderboard),
          store.scoped(g.id),
        ),
    },
  );

  final LocalStore store;
  final SoundSetting sound;
  final Map<String, LeaderboardService> leaderboards;

  /// Signs in once (the platform account is per app) and shares the result
  /// with every game's leaderboard; a declined sign-in is not retried here.
  Future<void> signIn() async {
    final all = leaderboards.values.toList();
    if (all.isEmpty) return;
    await all.first.init();
    if (!all.first.signedIn) return;
    for (final l in all.skip(1)) {
      await l.adoptSignIn();
    }
  }

  GameHost hostFor(GameModule game, {required VoidCallback exit}) => GameHost(
    store: store.scoped(game.id),
    sound: sound,
    leaderboard: leaderboards[game.id]!,
    exitToLauncher: exit,
  );
}

/// Opens this app's store page (for an update).
Future<void> openStore(RemoteSettings settings, String packageName) async {
  final uri = switch (defaultTargetPlatform) {
    TargetPlatform.iOS when settings.iosAppId.isNotEmpty => Uri.parse(
      'https://apps.apple.com/app/id${settings.iosAppId}',
    ),
    TargetPlatform.iOS => null,
    _ => Uri.parse(
      'https://play.google.com/store/apps/details?id=$packageName',
    ),
  };
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Store link failed: $e');
  }
}

class LcdArcadeApp extends StatelessWidget {
  const LcdArcadeApp({
    super.key,
    required this.services,
    this.palette = LcdPalette.active,
    this.remote,
    this.version = '',
    this.ads,
    this.testAds = true,
    this.openStore,
  });

  final ArcadeServices services;
  final LcdPalette palette;

  /// Remote ads and update settings (none in tests: the defaults).
  final ValueListenable<RemoteSettings>? remote;

  /// This app's version, e.g. `1.0.0`, for the update check.
  final String version;

  /// Ads, or null for none.
  final AdsController? ads;

  /// Use Google's test ad units (debug and playtest builds).
  final bool testAds;
  final Future<void> Function(RemoteSettings settings)? openStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LCD Arcade',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: palette.bezel),
      home: Builder(
        builder: (context) =>
            _Home(app: this, onOpen: (module) => openGame(context, module)),
      ),
    );
  }

  /// Rotates to the game's orientation, shows it, and rotates back to the
  /// portrait launcher when it closes.
  Future<void> openGame(BuildContext context, GameModule module) async {
    final navigator = Navigator.of(context);
    await lockOrientation(module.orientation);
    await navigator.push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => OrientationGate(
          orientation: module.orientation,
          color: palette.bezel,
          child: module.build(
            context,
            services.hostFor(module, exit: navigator.pop),
          ),
        ),
      ),
    );
    await lockOrientation(GameOrientation.portrait);
  }
}

/// The launcher with the remote parts: update prompt, banner, `Ads` key.
class _Home extends StatefulWidget {
  const _Home({required this.app, required this.onOpen});

  final LcdArcadeApp app;
  final void Function(GameModule module) onOpen;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  static const _dismissedKey = 'update.dismissed';
  static const _none = AlwaysStoppedAnimation(RemoteSettings.defaults);

  bool _privacyKey = false;

  LocalStore get _store => widget.app.services.store.scoped('app');

  ValueListenable<RemoteSettings> get _remote => widget.app.remote ?? _none;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final ads = app.ads;
    return ValueListenableBuilder<RemoteSettings>(
      valueListenable: _remote,
      builder: (context, settings, _) {
        final need = updateNeed(
          app.version,
          settings,
          dismissed: _store.intSetting(_dismissedKey, 0),
        );
        return LauncherScreen(
          entries: launcherEntriesFor(games),
          palette: app.palette,
          onOpen: widget.onOpen,
          update: need,
          onUpdate: () => app.openStore?.call(settings),
          onLater: () async {
            final latest = versionCode(settings.latestVersion);
            if (latest == null) return;
            await _store.setIntSetting(_dismissedKey, latest);
            if (mounted) setState(() {});
          },
          onAdPrivacy: ads != null && _privacyKey
              ? () => unawaited(ads.showPrivacyOptions())
              : null,
          banner: ads == null
              ? null
              : BannerSlot(
                  settings: _remote,
                  ads: ads,
                  testAds: app.testAds,
                  onPrivacyRequired: () =>
                      mounted ? setState(() => _privacyKey = true) : null,
                ),
        );
      },
    );
  }
}
