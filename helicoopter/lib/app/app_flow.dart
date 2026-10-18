import 'package:flutter/foundation.dart';

import '../game/helicopter_game.dart';

enum AppScreen { title, menu, game, topScore, instructions }

/// Which screen is shown, and the Android back-button routing (spec 1.3).
///
/// While [screen] is [AppScreen.game], the game's own phase (ready, playing,
/// paused, crashed) decides the overlay.
class AppFlow extends ChangeNotifier {
  AppFlow({required this.game, this.onExit, this.onOnlineScores});

  final HelicopterGame game;

  /// Leaves the app (Android back on title / main menu).
  final VoidCallback? onExit;

  /// Opens the platform leaderboard (wired in M5).
  final VoidCallback? onOnlineScores;

  AppScreen _screen = AppScreen.title;
  AppScreen get screen => _screen;

  /// In-memory for now; persisted with the audio service in M4.
  bool soundOn = true;

  void _go(AppScreen next) {
    game.releaseAll();
    _screen = next;
    notifyListeners();
  }

  /// Title splash → main menu.
  void start() => _go(AppScreen.menu);

  void openMenu() => _go(AppScreen.menu);
  void openTopScore() => _go(AppScreen.topScore);
  void openInstructions() => _go(AppScreen.instructions);

  /// Fresh run, waiting in Ready for the first press.
  void newGame() {
    game.newRun();
    _go(AppScreen.game);
  }

  /// Paused → Ready, same run.
  void continueRun() {
    game.resume();
    _go(AppScreen.game);
  }

  void toggleSound() {
    soundOn = !soundOn;
    notifyListeners();
  }

  void showOnlineScores() => onOnlineScores?.call();

  /// Handles the Android back button. Returns false when the app exits.
  bool back() {
    switch (_screen) {
      case AppScreen.title:
      case AppScreen.menu:
        onExit?.call();
        return false;
      case AppScreen.topScore:
      case AppScreen.instructions:
        openMenu();
      case AppScreen.game:
        switch (game.phase.value) {
          case GamePhase.playing:
            game.pause();
          case GamePhase.paused:
            continueRun();
          case GamePhase.ready:
          case GamePhase.crashed:
            openMenu();
        }
    }
    return true;
  }

  /// App went to the background or lost focus.
  void appBackgrounded() {
    game.releaseAll();
    if (_screen == AppScreen.game) game.pause();
  }
}
