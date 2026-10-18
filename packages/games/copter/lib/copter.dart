/// Copter: the one-touch helicopter cave game, as an LCD Arcade module.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lcd_kit/lcd_kit.dart';

import 'app/app_flow.dart';
import 'app/game_screen.dart';
import 'app/game_services.dart';
import 'copter_leaderboard.dart';
import 'copter_sounds.dart';
import 'game/helicopter_game.dart';

export 'copter_leaderboard.dart';

class CopterModule extends GameModule {
  const CopterModule();

  @override
  String get id => 'copter';

  @override
  String get title => 'Copter';

  @override
  List<String> get icon => const [
    '............',
    '............',
    '.########...',
    '......#.....',
    '#...#####...',
    '#######.##..',
    '#...#####...',
    '...######...',
    '............',
    '##..#..#....',
    '............',
    '............',
  ];

  @override
  GameOrientation get orientation => GameOrientation.landscape;

  @override
  LeaderboardIds get leaderboard => copterLeaderboard;

  @override
  Widget build(BuildContext context, GameHost host) => CopterView(host: host);
}

/// Owns one Copter session: game, sounds and screens, starting at its menu.
class CopterView extends StatefulWidget {
  const CopterView({super.key, required this.host, this.player, this.game});

  final GameHost host;

  /// Overrides the sound backend (tests).
  final SoundPlayer? player;

  /// Overrides the game (tests).
  final HelicopterGame? game;

  @override
  State<CopterView> createState() => _CopterViewState();
}

class _CopterViewState extends State<CopterView> {
  late final HelicopterGame _game;
  late final AudioService _audio;
  late final GameServices _services;
  late final AppFlow _flow;

  @override
  void initState() {
    super.initState();
    final host = widget.host;
    _game = (widget.game ?? HelicopterGame())..best = host.store.best;
    _audio = AudioService(
      widget.player ?? FlameSoundPlayer.forPackage('copter'),
      files: CopterSounds.all,
      muted: !host.sound.on,
    );
    unawaited(_audio.load());
    _services = GameServices(
      game: _game,
      audio: _audio,
      store: host.store,
      leaderboard: host.leaderboard,
    )..attach();
    _flow = AppFlow(
      game: _game,
      soundOn: host.sound.on,
      initialScreen: AppScreen.menu,
      onExit: host.exitToLauncher,
      onSoundChanged: (on) {
        unawaited(host.sound.set(on));
        unawaited(_audio.setMuted(!on));
      },
      onKeyClick: () => unawaited(_services.click()),
      onOnlineScores: () async => switch (await host.leaderboard.show()) {
        LeaderboardResult.shown => null,
        LeaderboardResult.signInFailed => 'Sign-in failed',
        LeaderboardResult.showFailed => 'Try again later',
        LeaderboardResult.unavailable => 'Not available',
      },
    );
  }

  @override
  void dispose() {
    _services.detach();
    unawaited(_audio.stopLoop());
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameScreen(flow: _flow);
}
