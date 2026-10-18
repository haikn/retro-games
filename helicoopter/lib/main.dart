import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_flow.dart';
import 'app/game_screen.dart';
import 'app/game_services.dart';
import 'game/helicopter_game.dart';
import 'services/audio_service.dart';
import 'services/leaderboard_service.dart';
import 'services/local_store.dart';

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
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Silkscreen font',
    ], await rootBundle.loadString('assets/fonts/Silkscreen-OFL.txt'));
  });

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final store = await LocalStore.open();
  final audio = AudioService(FlameSoundPlayer(), muted: store.muted);
  unawaited(audio.load()); // never delays the first frame
  final leaderboard = LeaderboardService(platformLeaderboardBackend(), store);
  runApp(
    CaveCopterApp(
      flow: buildFlow(store: store, audio: audio, leaderboard: leaderboard),
    ),
  );
  // Sign in once, while the title screen shows (never mid-run).
  unawaited(leaderboard.init());
}

/// Builds the game and connects it to storage and sound.
AppFlow buildFlow({
  required LocalStore store,
  required AudioService audio,
  LeaderboardService? leaderboard,
  HelicopterGame? game,
}) {
  final g = (game ?? HelicopterGame())..best = store.best;
  final services = GameServices(
    game: g,
    audio: audio,
    store: store,
    leaderboard: leaderboard,
  )..attach();
  return AppFlow(
    game: g,
    soundOn: !store.muted,
    onExit: SystemNavigator.pop,
    onSoundChanged: (on) => unawaited(services.setSound(on)),
    onKeyClick: () => unawaited(services.click()),
    onOnlineScores: () async => switch (await leaderboard?.show()) {
      LeaderboardResult.shown => null,
      LeaderboardResult.signInFailed => 'Sign-in failed',
      LeaderboardResult.showFailed => 'Try again later',
      LeaderboardResult.unavailable || null => 'Not available',
    },
  );
}

class CaveCopterApp extends StatelessWidget {
  const CaveCopterApp({super.key, required this.flow});

  final AppFlow flow;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cave Copter',
      debugShowCheckedModeBanner: false,
      home: GameScreen(flow: flow),
    );
  }
}
