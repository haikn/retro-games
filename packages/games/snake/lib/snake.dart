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
      'Swipe up, down, left or right to steer.',
      'Eat food to grow and score. Every fifth food brings a bonus bug for '
          'five seconds.',
      'The walls wrap around. Do not bite your own tail.',
      'Higher levels are faster and score more.',
    ],
    startHint: const ['Swipe to', 'start'],
    levels: 9,
    defaultLevel: 5,
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

  /// Field cell (x, y) → its top-left LCD pixel.
  static (int, int) origin(Cell c) => (2 + 4 * c.x, 11 + 4 * c.y);

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
    // Field border: 1 LCD px around the 76×148 interior at (2, 11).
    b.fillRect(1, 10, 78, 1);
    b.fillRect(1, 159, 78, 1);
    b.fillRect(1, 10, 1, 150);
    b.fillRect(78, 10, 1, 150);
    if (g == null) return;

    final body = g.body;
    for (var i = 0; i < body.length; i++) {
      final (x, y) = origin(body[i]);
      b.fillRect(x, y, 3, 3);
      if (i == 0) {
        b.clearRect(x + 1, y + 1, 1, 1); // eye
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
    // The bug blinks during its last second.
    if (bonus != null && (g.bonusLeft > 60 || g.bonusLeft % 10 < 5)) {
      final (x, y) = origin(bonus);
      b.set(x, y);
      b.set(x + 2, y);
      b.set(x + 1, y + 1);
      b.set(x, y + 2);
      b.set(x + 2, y + 2);
    }
  }
}
