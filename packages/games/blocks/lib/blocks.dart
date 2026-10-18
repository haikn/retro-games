/// Blocks: falling-block puzzle, as an LCD Arcade module.
///
/// Not cleared for release (collection decision C4: IP review pending), so
/// release builds show it as "Coming soon".
library;

import 'package:flutter/widgets.dart';
import 'package:lcd_kit/lcd_kit.dart';

import 'core/blocks.dart';

class BlocksModule extends GameModule {
  const BlocksModule();

  @override
  String get id => 'blocks';

  @override
  String get title => 'Blocks';

  @override
  List<String> get icon => const [
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

  @override
  GameOrientation get orientation => GameOrientation.portrait;

  @override
  LeaderboardIds get leaderboard => const LeaderboardIds(
    ios: 'lcd_arcade_blocks',
    android: 'REPLACE_WITH_PLAY_CONSOLE_LEADERBOARD_ID',
  );

  /// Decision C4 (IP review) is open.
  @override
  bool get releaseCleared => false;

  static final spec = ArcadeSpec(
    title: 'Blocks',
    package: 'blocks',
    orientation: GameOrientation.portrait,
    create: BlocksArcade.new,
    sounds: const [
      'rotate.wav',
      'lock.wav',
      'clear.wav',
      'four.wav',
      'crash.wav',
    ],
    instructions: const [
      'Tap to rotate. Drag left or right to move, drag down to drop faster, '
          'flick down to drop at once.',
      'Fill a whole row to clear it. Clearing four rows at once scores '
          'most.',
      'Every 10 rows the level goes up and pieces fall faster.',
      'The game ends when the stack reaches the top.',
    ],
    startHint: const ['Tap to', 'start'],
    levels: 9,
    defaultLevel: 1,
  );

  @override
  Widget build(BuildContext context, GameHost host) =>
      ArcadeGameView(host: host, spec: spec);
}

/// Draws a [BlocksGame] on the portrait LCD (canvas board 4) and maps
/// gestures: tap = rotate, horizontal drag = move a column per 25 px, drag
/// down = soft drop a row per 25 px, flick down = hard drop.
class BlocksArcade extends ArcadeGame {
  static const dragStep = 25.0;
  static const flickSpeed = 1500.0; // virtual px/s

  BlocksGame? _game;
  final _sounds = <String>[];
  double _dragX = 0;
  double _dragY = 0;

  BlocksGame get core => _game!;

  /// Visible well cell (c, r) → top-left LCD pixel of its brick.
  static (int, int) origin(int c, int r) => (2 + 5 * c, 12 + 5 * r);

  @override
  void start({required int level, required int seed}) {
    _game = BlocksGame(startLevel: level, seed: seed);
    _sounds.clear();
  }

  @override
  void tick() {
    core.tick();
    _drain();
  }

  void _drain() {
    for (final e in core.takeEvents()) {
      _sounds.add('$e.wav');
    }
  }

  @override
  void input(GameInput input) {
    final g = core;
    switch (input) {
      case PressInput():
        _dragX = 0;
        _dragY = 0;
      case DragInput(:final dx, :final dy):
        _dragX += dx;
        _dragY += dy;
        while (_dragX >= dragStep) {
          g.moveRight();
          _dragX -= dragStep;
        }
        while (_dragX <= -dragStep) {
          g.moveLeft();
          _dragX += dragStep;
        }
        while (_dragY >= dragStep) {
          g.softDrop();
          _dragY -= dragStep;
        }
        if (_dragY < 0) _dragY = 0; // upward drags do nothing
      case ReleaseInput(:final tap, :final vy):
        if (tap) {
          g.rotate();
        } else if (vy > flickSpeed) {
          g.hardDrop();
        }
      case SwipeInput():
        break;
    }
    _drain();
  }

  @override
  int get score => _game?.score ?? 0;

  @override
  bool get over => _game?.over ?? false;

  @override
  List<HudText> get texts {
    final g = _game;
    return [
      const HudText('NEXT', Offset(275, 60)),
      HudText(
        'LV ${(g?.level ?? 1).toString().padLeft(2, '0')}',
        const Offset(10, 590),
      ),
      HudText(
        'LN ${(g?.lines ?? 0).toString().padLeft(3, '0')}',
        const Offset(390, 590),
        alignRight: true,
      ),
    ];
  }

  @override
  List<String> takeSounds() {
    final s = List.of(_sounds);
    _sounds.clear();
    return s;
  }

  @override
  void draw(LcdBuffer b) {
    b.fillRect(0, 8, b.width, 1); // HUD rule
    // Well frame: 1 LCD px around the 50×100 interior at (2, 12).
    b.fillRect(1, 11, 52, 1);
    b.fillRect(1, 112, 52, 1);
    b.fillRect(1, 11, 1, 102);
    b.fillRect(52, 11, 1, 102);
    final g = _game;
    if (g == null) return;

    // Clearing rows blink: shown solid or empty every 4 ticks.
    final blinkOn = (g.clearingTicksLeft ~/ 4).isEven;
    for (var r = 0; r < BlockRules.rows; r++) {
      final isClearing = g.clearing.contains(r);
      for (var c = 0; c < BlockRules.cols; c++) {
        final on = isClearing ? blinkOn : g.filled(c, r);
        if (on) {
          final (x, y) = origin(c, r);
          b.fillRect(x, y, 4, 4);
        }
      }
    }
    if (g.active) {
      for (final (c, r) in g.pieceCells()) {
        if (r < 0) continue;
        final (x, y) = origin(c, r);
        b.fillRect(x, y, 4, 4);
      }
    }
    // Next piece, in its rotation-0 shape, under the NEXT label.
    for (final (c, r) in shapeCells(g.next, 0)) {
      b.fillRect(57 + 5 * c, 22 + 5 * r, 4, 4);
    }
  }
}
