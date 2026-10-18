import 'dart:async';

import 'package:copter/copter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lcd_kit/lcd_kit.dart';
import 'package:snake/snake.dart';

import 'launcher/launcher_screen.dart';
import 'launcher/orientation.dart';

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
  runApp(LcdArcadeApp(services: services));
  // Sign in once, while the launcher shows (never mid-run).
  unawaited(services.signIn());
}

/// The collection, in launcher order.
const games = <GameModule>[CopterModule(), SnakeModule()];

/// Launcher tiles: playable games, then games still to come.
final launcherEntries = <LauncherEntry>[
  for (final g in games) LauncherEntry.of(g),
  const LauncherEntry(title: 'Blocks', icon: _blocksIcon),
  const LauncherEntry(title: 'Hop', icon: _hopIcon),
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

  Future<void> signIn() async {
    for (final l in leaderboards.values) {
      await l.init();
    }
  }

  GameHost hostFor(GameModule game, {required VoidCallback exit}) => GameHost(
    store: store.scoped(game.id),
    sound: sound,
    leaderboard: leaderboards[game.id]!,
    exitToLauncher: exit,
  );
}

class LcdArcadeApp extends StatelessWidget {
  const LcdArcadeApp({
    super.key,
    required this.services,
    this.palette = LcdPalette.active,
  });

  final ArcadeServices services;
  final LcdPalette palette;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LCD Arcade',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: palette.bezel),
      home: Builder(
        builder: (context) => LauncherScreen(
          entries: launcherEntries,
          palette: palette,
          onOpen: (module) => openGame(context, module),
        ),
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

const _blocksIcon = [
  '............',
  '....##......',
  '....##......',
  '............',
  '............',
  '............',
  '##....##..##',
  '##....##..##',
  '####..######',
  '####..######',
  '############',
  '############',
];

const _hopIcon = [
  '....##......',
  '...####.....',
  '..#####.#...',
  '...####.....',
  '...####.....',
  '....#.#.....',
  '............',
  '#.#.#.#.#.#.',
  '............',
  '..######....',
  '.########...',
  '..#....#....',
];
