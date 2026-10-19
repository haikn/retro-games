import 'dart:collection';

import 'package:arcade_core/rng.dart';

enum Heading { up, down, left, right }

class Cell {
  const Cell(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is Cell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// Field size and rules (collection spec: Snake).
abstract final class SnakeRules {
  static const cols = 19;

  /// 36 rows leave a bottom margin equal to the side margins (F8).
  static const rows = 36;
  static const startLength = 5;
  static const maxQueuedTurns = 2;
  static const bonusEvery = 5;

  /// The bomb (F7) lasts 8 s and covers 2×2 cells.
  static const bonusTicks = 480;
  static const bonusSize = 2;
}

/// Ticks between steps: 250 ms at level 1 down to 50 ms at level 9.
int stepTicksFor(int level) => ((250 - 25 * (level - 1)) * 60 / 1000).round();

/// One game of Snake, advanced in fixed 60 Hz ticks. Pure Dart.
class SnakeGame {
  SnakeGame({required this.level, required int seed}) : _rng = Rng(seed) {
    const y = SnakeRules.rows ~/ 2;
    for (var i = 0; i < SnakeRules.startLength; i++) {
      _body.addLast(Cell(SnakeRules.startLength + 2 - i, y));
    }
    food = _randomFreeCell();
  }

  /// A snake with a given [body] (head first), for tests.
  SnakeGame.debug({required List<Cell> body, required this._heading})
    : level = 1,
      _rng = Rng(1) {
    _body.addAll(body);
    food = _randomFreeCell();
  }

  final int level;
  final Rng _rng;
  final _body = ListQueue<Cell>();
  final _queue = ListQueue<Heading>();
  final _events = <String>[];
  Heading _heading = Heading.right;
  int _ticks = 0;
  int _grow = 0;
  int _foods = 0;

  Cell? food;

  /// Top-left cell of the 2×2 bomb, or null.
  Cell? bonus;
  int bonusLeft = 0;
  int score = 0;
  bool over = false;

  /// Head first.
  List<Cell> get body => _body.toList(growable: false);
  Heading get heading => _heading;
  int get stepTicks => stepTicksFor(level);
  int get ticks => _ticks;

  /// The 4 cells the bomb covers.
  List<Cell> get bonusCells {
    final b = bonus;
    if (b == null) return const [];
    return [
      for (var dy = 0; dy < SnakeRules.bonusSize; dy++)
        for (var dx = 0; dx < SnakeRules.bonusSize; dx++)
          Cell(b.x + dx, b.y + dy),
    ];
  }

  /// What the bomb is worth now: `level × (2 + whole seconds left)`, so
  /// 10 × level right away and 2 × level at the end.
  int get bonusValue => level * (2 + bonusLeft ~/ 60);

  /// Event names since the last call: `eat`, `bonus`, `crash`.
  List<String> takeEvents() {
    final e = List.of(_events);
    _events.clear();
    return e;
  }

  static bool _opposite(Heading a, Heading b) => switch (a) {
    Heading.up => b == Heading.down,
    Heading.down => b == Heading.up,
    Heading.left => b == Heading.right,
    Heading.right => b == Heading.left,
  };

  /// Queues a turn; same direction and reversals are ignored.
  void turn(Heading h) {
    if (over || _queue.length >= SnakeRules.maxQueuedTurns) return;
    final last = _queue.isEmpty ? _heading : _queue.last;
    if (h == last || _opposite(h, last)) return;
    _queue.addLast(h);
  }

  void tick() {
    if (over) return;
    _ticks++;
    if (bonus != null && --bonusLeft <= 0) bonus = null;
    if (_ticks % stepTicks == 0) _step();
  }

  void _step() {
    if (_queue.isNotEmpty) _heading = _queue.removeFirst();
    final head = _body.first;
    final next = switch (_heading) {
      Heading.up => Cell(head.x, (head.y - 1) % SnakeRules.rows),
      Heading.down => Cell(head.x, (head.y + 1) % SnakeRules.rows),
      Heading.left => Cell((head.x - 1) % SnakeRules.cols, head.y),
      Heading.right => Cell((head.x + 1) % SnakeRules.cols, head.y),
    };
    final eating = next == food;
    final growing = eating || _grow > 0;
    // The tail cell is free this step unless the snake grows.
    final hit = _body.any((c) => c == next && (growing || c != _body.last));
    if (hit) {
      over = true;
      _events.add('crash');
      return;
    }
    _body.addFirst(next);
    if (growing) {
      if (!eating) _grow--;
    } else {
      _body.removeLast();
    }
    if (eating) {
      score += level;
      _foods++;
      _events.add('eat');
      food = _randomFreeCell();
      if (_foods % SnakeRules.bonusEvery == 0) {
        bonus = _randomFreeBlock();
        bonusLeft = SnakeRules.bonusTicks;
      }
    }
    if (bonusCells.contains(next)) {
      score += bonusValue;
      bonus = null;
      _events.add('bonus');
    }
  }

  /// A random 2×2 block of free cells inside the field (no wrap), or null.
  Cell? _randomFreeBlock() {
    final taken = <Cell>{..._body, ?food};
    const n = SnakeRules.bonusSize;
    final options = <Cell>[
      for (var y = 0; y <= SnakeRules.rows - n; y++)
        for (var x = 0; x <= SnakeRules.cols - n; x++)
          if ([
            for (var dy = 0; dy < n; dy++)
              for (var dx = 0; dx < n; dx++) Cell(x + dx, y + dy),
          ].every((c) => !taken.contains(c)))
            Cell(x, y),
    ];
    return options.isEmpty ? null : options[_rng.nextInt(options.length)];
  }

  Cell? _randomFreeCell() {
    final taken = <Cell>{..._body, ?food, ...bonusCells};
    final free = SnakeRules.cols * SnakeRules.rows - taken.length;
    if (free <= 0) return null;
    var k = _rng.nextInt(free);
    for (var y = 0; y < SnakeRules.rows; y++) {
      for (var x = 0; x < SnakeRules.cols; x++) {
        final c = Cell(x, y);
        if (taken.contains(c)) continue;
        if (k-- == 0) return c;
      }
    }
    return null;
  }

  // ---- test hooks ----

  void debugPlaceFood(Cell c) => food = c;

  void debugPlaceBonus(Cell c) {
    bonus = c;
    bonusLeft = SnakeRules.bonusTicks;
  }

  void debugGrow(int n) => _grow += n;
}
