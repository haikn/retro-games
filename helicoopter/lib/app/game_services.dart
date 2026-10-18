import 'dart:async';

import '../game/helicopter_game.dart';
import '../services/audio_service.dart';
import '../services/leaderboard_service.dart';
import '../services/local_store.dart';

/// Maps game events to sound and persistence, keeping the game itself free
/// of service code.
class GameServices {
  GameServices({
    required this.game,
    required this.audio,
    required this.store,
    this.leaderboard,
  });

  final HelicopterGame game;
  final AudioService audio;
  final LocalStore store;
  final LeaderboardService? leaderboard;
  GamePhase? _last;

  void attach() {
    _last = game.phase.value;
    game.phase.addListener(_onPhase);
    game.gameOverVisible.addListener(_onGameOver);
  }

  void detach() {
    game.phase.removeListener(_onPhase);
    game.gameOverVisible.removeListener(_onGameOver);
  }

  void _onPhase() {
    final phase = game.phase.value;
    if (phase == GamePhase.playing) {
      unawaited(audio.startRotor());
    } else {
      unawaited(audio.stopRotor());
    }
    if (phase == GamePhase.crashed && _last != GamePhase.crashed) {
      unawaited(audio.crash());
      if (game.lastRunNewBest) {
        unawaited(store.recordBest(game.best));
        unawaited(leaderboard?.submitBest(game.best));
      }
    }
    _last = phase;
  }

  void _onGameOver() {
    if (game.gameOverVisible.value && game.lastRunNewBest) {
      unawaited(audio.newBest());
    }
  }

  Future<void> setSound(bool on) async {
    await audio.setMuted(!on);
    await store.setMuted(!on);
  }

  Future<void> click() => audio.click();
}
