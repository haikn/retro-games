import 'package:flutter/widgets.dart';

/// All shared UI text in one place (decision C6). v1 ships in English; a
/// translation is one more instance of this class, checked by the slot-width
/// test with the real font (portrait rows fit about 10 letters). `%s` marks
/// where a value goes.
class LcdStrings {
  const LcdStrings({
    this.games = 'Games',
    this.comingSoon = 'Coming soon',
    this.select = 'Select',
    this.back = 'Back',
    this.menu = 'Menu',
    this.newGame = 'New game',
    this.level = 'Level: %s',
    this.topScore = 'Top score',
    this.topScoreTitle = 'Top score:',
    this.soundOn = 'Sound: On',
    this.soundOff = 'Sound: Off',
    this.howToPlay = 'How to play',
    this.allGames = 'All games',
    this.paused = 'Paused',
    this.continueRun = 'Continue',
    this.mainMenu = 'Main menu',
    this.gameOver = 'Game over!',
    this.score = 'Score %s',
    this.best = 'Best %s',
    this.hi = 'HI %s',
    this.newBest = 'New best!',
    this.tapToPlay = 'Tap to play',
    this.onThisPhone = 'On this phone',
    this.onlineScores = 'Online scores',
    this.signInFailed = 'Sign-in failed',
    this.tryAgainLater = 'Try later', // 'Try again later' is 405 px
    this.notAvailable = 'Not available',
    this.pause = 'Pause',
    this.newVersion = 'New version',
    this.updateNeeded = 'Must update',
    this.update = 'Update',
    this.later = 'Later',
    this.ads = 'Ads',
  });

  static const en = LcdStrings();

  final String games;
  final String comingSoon;
  final String select;
  final String back;
  final String menu;
  final String newGame;
  final String level;
  final String topScore;
  final String topScoreTitle;
  final String soundOn;
  final String soundOff;
  final String howToPlay;
  final String allGames;
  final String paused;
  final String continueRun;
  final String mainMenu;
  final String gameOver;
  final String score;
  final String best;
  final String hi;
  final String newBest;
  final String tapToPlay;
  final String onThisPhone;
  final String onlineScores;
  final String signInFailed;
  final String tryAgainLater;
  final String notAvailable;
  final String pause;

  /// Launcher update prompt (optional / required) and its items.
  final String newVersion;
  final String updateNeeded;
  final String update;
  final String later;

  /// Launcher soft key that opens the ad privacy options.
  final String ads;

  /// [template] with its `%s` replaced by [value].
  static String fill(String template, Object value) =>
      template.replaceAll('%s', '$value');

  /// The strings for [context] (English unless an [LcdStringsScope] says
  /// otherwise).
  static LcdStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LcdStringsScope>()?.strings ??
      en;
}

/// Provides [LcdStrings] below it (for a translation).
class LcdStringsScope extends InheritedWidget {
  const LcdStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final LcdStrings strings;

  @override
  bool updateShouldNotify(LcdStringsScope old) => old.strings != strings;
}
