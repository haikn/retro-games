import 'package:flutter/widgets.dart';

import '../game_module.dart';
import '../lcd_buffer.dart';
import 'input.dart';

/// Text an arcade game shows on its screen besides the HUD (e.g. `NEXT`),
/// at [position] in virtual px, in the ink colour.
class HudText {
  const HudText(this.text, this.position, {this.alignRight = false});

  final String text;
  final Offset position;

  /// Right-align at [position] (its x is the right edge).
  final bool alignRight;
}

/// One run of a grid arcade game, driven by [ArcadeGameView].
///
/// Games keep their rules in a pure-Dart core and implement this adapter for
/// input, drawing and sounds. Rows 0–7 of the LCD stay empty for the HUD
/// text; the game draws everything else, including the HUD rule.
abstract class ArcadeGame {
  /// Starts a new run at [level] (1 when the game has no levels).
  void start({required int level, required int seed});

  /// Advances exactly one fixed 60 Hz tick.
  void tick();

  void input(GameInput input);

  void draw(LcdBuffer buffer);

  int get score;

  /// True once the run has ended (the host then shows the crash flash and
  /// the game-over dialog; [tick] is no longer called).
  bool get over;

  /// Extra texts drawn by the host in the ink colour.
  List<HudText> get texts => const [];

  /// Sound files requested since the last call; the host drains this after
  /// every tick and plays them.
  List<String> takeSounds();
}

/// Everything [ArcadeGameView] needs to run one game.
class ArcadeSpec {
  const ArcadeSpec({
    required this.title,
    required this.package,
    required this.orientation,
    required this.create,
    required this.sounds,
    required this.instructions,
    required this.startHint,
    this.levels,
    this.defaultLevel = 1,
  });

  /// Menu header.
  final String title;

  /// Package holding `assets/audio/` with [sounds], `click.wav`, `best.wav`.
  final String package;
  final GameOrientation orientation;
  final ArcadeGame Function() create;

  /// The game's own sound files (besides click and jingle).
  final List<String> sounds;
  final List<String> instructions;

  /// Lines of the Ready dialog, e.g. `['Swipe to', 'start']`.
  final List<String> startHint;

  /// Number of selectable levels (menu `Level: N`), or null for none.
  final int? levels;
  final int defaultLevel;
}
