/// Snake: the classic phone game, as an LCD Arcade module.
library;

import 'package:flutter/widgets.dart';
import 'package:lcd_kit/lcd_kit.dart';

import 'core/snake.dart';

class SnakeModule extends GameModule {
  const SnakeModule();

  @override
  String get id => 'snake';

  @override
  String get title => 'Snake';

  @override
  List<String> get icon => const [
    '............',
    '..#######...',
    '..#.........',
    '..#.........',
    '..#######...',
    '........#...',
    '........#...',
    '.########...',
    '.#..........',
    '.#.......#..',
    '.##.........',
    '............',
  ];

  @override
  GameOrientation get orientation => GameOrientation.portrait;

  @override
  LeaderboardIds get leaderboard => const LeaderboardIds(
    ios: 'lcd_arcade_snake',
    android: 'REPLACE_WITH_PLAY_CONSOLE_LEADERBOARD_ID',
  );

  static final spec = ArcadeSpec(
    title: 'Snake',
    package: 'snake',
    orientation: GameOrientation.portrait,
    create: SnakeArcade.new,
    sounds: const ['eat.wav', 'bonus.wav', 'crash.wav'],
    instructions: const [
      'Swipe up, down, left or right to steer. You can keep your finger down and slide it to turn again.',
      'Eat food to grow and score. Every fifth food brings a bomb for eight '
          'seconds: the sooner you eat it, the more it is worth.',
      'The walls wrap around. Do not bite your own tail.',
      'Higher levels are faster and score more.',
      'Tap the score bar to pause.',
    ],
    startHint: const ['Swipe to', 'start'],
    levels: 9,
    defaultLevel: 5,
    // Turn as soon as the finger moves ~4 mm, and keep turning within one
    // stroke without lifting the finger.
    swipeThreshold: 18,
    continuousSwipes: true,
  );

  @override
  Widget build(BuildContext context, GameHost host) =>
      ArcadeGameView(host: host, spec: spec);
}

/// Draws a [SnakeGame] on the portrait LCD (canvas board 3) and maps swipes
/// to turns.
class SnakeArcade extends ArcadeGame {
  SnakeGame? _game;
  final _sounds = <String>[];

  SnakeGame get core => _game!;

  /// Field cell (x, y) → its top-left LCD pixel (border at LCD y 13–158).
  static (int, int) origin(Cell c) => (2 + 4 * c.x, 14 + 4 * c.y);

  /// Head (F6): a full 4×4 cell, facing right here; rotated for the
  /// heading. Eye at (1, 1), mouth notch on the front edge.
  static const _headRight = ['####', '#.##', '###.', '####'];

  static bool _headPixel(Heading h, int x, int y) {
    // Map (x, y) of the drawn cell back into the right-facing grid.
    final (u, v) = switch (h) {
      Heading.right => (x, y),
      Heading.left => (3 - x, y),
      Heading.down => (y, 3 - x),
      Heading.up => (3 - y, x),
    };
    return _headRight[v][u] == '#';
  }

  /// Bomb (F7): 8×8 over its 2×2 cells; the fuse spark flickers.
  static final bombFrames = [
    Sprite1.parse(const [
      '.....#.#',
      '....#.#.',
      '...##...',
      '..####..',
      '.######.',
      '.##.###.',
      '.######.',
      '..####..',
    ]),
    Sprite1.parse(const [
      '......#.',
      '....#..#',
      '...##...',
      '..####..',
      '.######.',
      '.##.###.',
      '.######.',
      '..####..',
    ]),
  ];

  @override
  void start({required int level, required int seed}) {
    _game = SnakeGame(level: level, seed: seed);
    _sounds.clear();
  }

  @override
  void tick() {
    core.tick();
    for (final e in core.takeEvents()) {
      _sounds.add('$e.wav');
    }
  }

  @override
  void input(GameInput input) {
    if (input is SwipeInput) {
      core.turn(switch (input.dir) {
        Dir.up => Heading.up,
        Dir.down => Heading.down,
        Dir.left => Heading.left,
        Dir.right => Heading.right,
      });
    }
  }

  @override
  int get score => _game?.score ?? 0;

  @override
  bool get over => _game?.over ?? false;

  @override
  List<String> takeSounds() {
    final s = List.of(_sounds);
    _sounds.clear();
    return s;
  }

  @override
  void draw(LcdBuffer b) {
    final g = _game;
    b.fillRect(0, 8, b.width, 1); // HUD rule
    // Field border: 1 LCD px around the 76×144 interior at (2, 14), with a
    // 1-px margin at the sides and bottom (F8).
    b.fillRect(1, 13, 78, 1);
    b.fillRect(1, 158, 78, 1);
    b.fillRect(1, 13, 1, 146);
    b.fillRect(78, 13, 1, 146);
    if (g == null) return;

    final body = g.body;
    for (var i = 0; i < body.length; i++) {
      final (x, y) = origin(body[i]);
      if (i == 0) {
        for (var py = 0; py < 4; py++) {
          for (var px = 0; px < 4; px++) {
            if (_headPixel(g.heading, px, py)) b.set(x + px, y + py);
          }
        }
      } else {
        b.fillRect(x, y, 3, 3);
      }
      if (i + 1 < body.length) {
        final n = body[i + 1];
        final dx = n.x - body[i].x;
        final dy = n.y - body[i].y;
        // Join neighbours into one line (not across a wrap).
        if (dx == 1) b.fillRect(x + 3, y, 1, 3);
        if (dx == -1) b.fillRect(x - 1, y, 1, 3);
        if (dy == 1) b.fillRect(x, y + 3, 3, 1);
        if (dy == -1) b.fillRect(x, y - 1, 3, 1);
      }
    }
    final food = g.food;
    if (food != null) {
      final (x, y) = origin(food);
      b.fillRect(x + 1, y, 1, 3); // plus
      b.fillRect(x, y + 1, 3, 1);
    }
    final bonus = g.bonus;
    // The bomb blinks during its last 2 s.
    if (bonus != null && (g.bonusLeft > 120 || (g.bonusLeft ~/ 8).isOdd)) {
      final (x, y) = origin(bonus);
      b.blit(bombFrames[(g.ticks ~/ 8) % 2], x, y);
    }
  }
}
