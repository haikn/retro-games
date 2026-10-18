import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/helicopter_game.dart';

enum AppScreen { title, menu, game, topScore, instructions }

/// Which screen is shown, and the Android back-button routing (spec 1.3).
///
/// While [screen] is [AppScreen.game], the game's own phase (ready, playing,
/// paused, crashed) decides the overlay.
class AppFlow extends ChangeNotifier {
  AppFlow({
    required this.game,
    this.soundOn = true,
    this.onExit,
    this.onOnlineScores,
    this.onSoundChanged,
    this.onKeyClick,
    AppScreen initialScreen = AppScreen.title,
  }) : _screen = initialScreen;

  final HelicopterGame game;

  /// Leaves the game: back to the collection's launcher (or out of the app
  /// when Copter runs alone). Android back on title / main menu, and the
  /// `All games` menu item.
  final VoidCallback? onExit;

  /// Opens the platform leaderboard; returns a short message to show when
  /// that was not possible.
  final Future<String?> Function()? onOnlineScores;

  /// Sound setting changed (audio + persistence).
  final void Function(bool soundOn)? onSoundChanged;

  /// A menu key was activated (key-click sound).
  final VoidCallback? onKeyClick;

  AppScreen _screen;
  AppScreen get screen => _screen;

  bool soundOn;

  /// Short non-blocking message (e.g. sign-in failed), cleared after 2 s.
  final ValueNotifier<String?> notice = ValueNotifier(null);
  Timer? _noticeTimer;

  void _go(AppScreen next) {
    onKeyClick?.call();
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
    onSoundChanged?.call(soundOn);
    if (soundOn) onKeyClick?.call();
    notifyListeners();
  }

  /// `All games`: back to the collection's launcher.
  void exitToGames() {
    onKeyClick?.call();
    game.releaseAll();
    onExit?.call();
  }

  Future<void> showOnlineScores() async {
    onKeyClick?.call();
    final message = await onOnlineScores?.call();
    if (message == null) return;
    _noticeTimer?.cancel();
    notice.value = message;
    _noticeTimer = Timer(const Duration(seconds: 2), () => notice.value = null);
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    notice.dispose();
    super.dispose();
  }

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
