import 'package:flutter_test/flutter_test.dart';
import 'package:snake/core/snake.dart';

void main() {
  SnakeGame game({int level = 5, int seed = 1}) =>
      SnakeGame(level: level, seed: seed);

  /// Runs ticks until the snake has stepped [n] times.
  void steps(SnakeGame g, int n) {
    for (var i = 0; i < n * g.stepTicks; i++) {
      g.tick();
    }
  }

  test('step interval is 250 ms at level 1 down to 50 ms at level 9', () {
    expect(stepTicksFor(1), 15);
    expect(stepTicksFor(5), 9);
    expect(stepTicksFor(9), 3);
  });

  test('starts with length 5 heading right in the middle', () {
    final g = game();
    expect(g.body, hasLength(5));
    expect(g.heading, Heading.right);
    expect(g.body.first, const Cell(7, 18));
    expect(g.body.last, const Cell(3, 18));
    expect(g.over, isFalse);
  });

  test('moves one cell per step, keeping its length', () {
    final g = game();
    steps(g, 1);
    expect(g.body.first, const Cell(8, 18));
    expect(g.body, hasLength(5));
  });

  test('walls wrap around', () {
    final g = game();
    steps(g, 12); // head from x 7 to 19 → wraps to 0
    expect(g.body.first, const Cell(0, 18));
    g.turn(Heading.up);
    steps(g, 19);
    expect(g.body.first, const Cell(0, 35)); // 18 - 19 wraps to 35 (36 rows)
  });

  test('reversing and repeating the heading are ignored', () {
    final g = game();
    g.turn(Heading.left);
    g.turn(Heading.right);
    steps(g, 1);
    expect(g.heading, Heading.right);
    expect(g.body.first, const Cell(8, 18));
  });

  test('two turns can be queued and apply on consecutive steps', () {
    final g = game();
    g.turn(Heading.up);
    g.turn(Heading.left);
    g.turn(Heading.down); // queue full: ignored
    steps(g, 1);
    expect(g.body.first, const Cell(7, 17));
    steps(g, 1);
    expect(g.body.first, const Cell(6, 17));
  });

  test('a queued turn is checked against the previous queued one', () {
    final g = game();
    g.turn(Heading.up);
    g.turn(Heading.down); // reverse of the queued up: ignored
    steps(g, 2);
    expect(g.body.first, const Cell(7, 16));
  });

  test('eating grows by one and scores the level', () {
    final g = game(level: 3);
    g.debugPlaceFood(const Cell(8, 18));
    steps(g, 1);
    expect(g.body, hasLength(6));
    expect(g.score, 3);
    expect(g.takeEvents(), ['eat']);
    expect(g.food, isNot(const Cell(8, 18)));
  });

  test('food never appears on the snake', () {
    for (var seed = 1; seed <= 200; seed++) {
      final g = game(seed: seed);
      expect(g.body.contains(g.food), isFalse, reason: 'seed $seed');
    }
  });

  test('every 5th food brings a 2×2 bomb on free cells', () {
    final g = game(level: 2);
    for (var i = 0; i < 5; i++) {
      final ahead = Cell((g.body.first.x + 1) % 19, g.body.first.y);
      g.debugPlaceFood(ahead);
      steps(g, 1);
    }
    expect(g.bonus, isNotNull);
    expect(g.bonusCells, hasLength(4));
    for (final c in g.bonusCells) {
      expect(g.body.contains(c), isFalse);
      expect(c, isNot(g.food));
      expect(c.x, lessThan(SnakeRules.cols));
      expect(c.y, lessThan(SnakeRules.rows));
    }
  });

  test('the bomb is eaten by touching any of its cells; worth more early', () {
    final g = game(level: 2);
    // Bomb whose lower-left cell is right ahead of the head (7, 18).
    g.debugPlaceBonus(const Cell(8, 17));
    expect(g.bonusValue, 20); // 10 × level when fresh
    final before = g.score;
    steps(g, 1);
    expect(g.bonus, isNull);
    expect(g.score - before, inInclusiveRange(4, 20));
    expect(g.takeEvents(), contains('bonus'));
  });

  test('bomb value drops to 2 × level at the end', () {
    final g = game(level: 3);
    g.debugPlaceBonus(const Cell(0, 0));
    for (var i = 0; i < 479; i++) {
      g.tick();
    }
    expect(g.bonusValue, 6);
  });

  test('food never lands on the bomb', () {
    final g = game();
    g.debugPlaceBonus(const Cell(0, 0));
    for (var i = 0; i < 50; i++) {
      final ahead = Cell((g.body.first.x + 1) % 19, g.body.first.y);
      g.debugPlaceFood(ahead);
      steps(g, 1);
      expect(g.bonusCells.contains(g.food), isFalse);
      if (g.bonus == null) g.debugPlaceBonus(const Cell(0, 0));
    }
  });

  test('biting itself ends the game', () {
    final g = game();
    g.debugGrow(4); // length 9
    for (final h in [Heading.up, Heading.left, Heading.down]) {
      g.turn(h);
      steps(g, 1);
    }
    expect(g.over, isTrue);
    expect(g.takeEvents(), contains('crash'));
  });

  test('moving into the cell the tail is leaving is allowed', () {
    final g = game();
    // Length 4 in a 2×2 loop: the head always enters the tail's old cell.
    final loop = SnakeGame.debug(
      body: const [Cell(5, 5), Cell(6, 5), Cell(6, 6), Cell(5, 6)],
      heading: Heading.left,
    );
    loop.turn(Heading.down);
    steps(loop, 1);
    expect(loop.over, isFalse);
    expect(g.over, isFalse);
  });

  test('a finished game ignores ticks', () {
    final g = game();
    g.debugGrow(4);
    for (final h in [Heading.up, Heading.left, Heading.down]) {
      g.turn(h);
      steps(g, 1);
    }
    final head = g.body.first;
    steps(g, 3);
    expect(g.body.first, head);
  });

  test('same seed and inputs give the same game', () {
    List<Cell?> run(int seed) {
      final g = game(seed: seed);
      final foods = <Cell?>[];
      for (var i = 0; i < 400; i++) {
        if (i % 37 == 0) g.turn(Heading.values[(i ~/ 37) % 4]);
        g.tick();
        foods.add(g.food);
      }
      return foods;
    }

    expect(run(9), run(9));
    expect(run(9), isNot(run(10)));
  });
}
