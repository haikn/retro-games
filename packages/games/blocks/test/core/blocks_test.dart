import 'package:blocks/core/blocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BlocksGame game({int level = 1, int seed = 1}) =>
      BlocksGame(startLevel: level, seed: seed);

  void ticks(BlocksGame g, int n) {
    for (var i = 0; i < n; i++) {
      g.tick();
    }
  }

  /// Fills visible row [r] except the columns in [holes].
  void fillRow(BlocksGame g, int r, {Set<int> holes = const {}}) {
    for (var c = 0; c < BlockRules.cols; c++) {
      if (!holes.contains(c)) g.debugSet(c, r);
    }
  }

  test('gravity: 48 ticks per row at level 1, faster per level', () {
    expect(gravityTicksFor(1), 48);
    expect(gravityTicksFor(5), 28);
    expect(gravityTicksFor(9), 8);
    expect(gravityTicksFor(15), 3);
  });

  test('the bag deals every piece once per 7', () {
    final g = game(seed: 3);
    final seen = <PieceKind>[g.piece.kind, g.next];
    while (seen.length < 7) {
      g.debugSpawnNext();
      seen.add(g.next);
    }
    expect(seen.toSet(), PieceKind.values.toSet());
  });

  test('a new piece appears at the top middle', () {
    final g = game();
    final cells = g.pieceCells().toList();
    expect(cells.every((c) => c.$1 >= 3 && c.$1 <= 6), isTrue);
    expect(
      cells.map((c) => c.$2).reduce((a, b) => a < b ? a : b),
      lessThanOrEqualTo(1),
    );
  });

  test('falls one row per gravity interval', () {
    final g = game();
    final y = g.piece.y;
    ticks(g, 47);
    expect(g.piece.y, y);
    g.tick();
    expect(g.piece.y, y + 1);
  });

  test('moves left and right, stopping at the walls', () {
    final g = game()..debugSetPiece(PieceKind.o);
    for (var i = 0; i < 10; i++) {
      g.moveLeft();
    }
    expect(g.pieceCells().map((c) => c.$1).reduce((a, b) => a < b ? a : b), 0);
    for (var i = 0; i < 10; i++) {
      g.moveRight();
    }
    expect(g.pieceCells().map((c) => c.$1).reduce((a, b) => a > b ? a : b), 9);
  });

  test('rotation turns the piece; walls kick it back inside', () {
    final g = game()..debugSetPiece(PieceKind.i);
    final flat = g.pieceCells().toSet();
    g.rotate();
    final upright = g.pieceCells().toList();
    expect(upright.map((c) => c.$1).toSet(), hasLength(1));
    expect(upright.toSet(), isNot(flat));
    // Push the upright bar to the right wall and rotate back: it must kick.
    for (var i = 0; i < 10; i++) {
      g.moveRight();
    }
    g.rotate();
    final kicked = g.pieceCells().toList();
    expect(kicked.every((c) => c.$1 >= 0 && c.$1 < BlockRules.cols), isTrue);
    expect(kicked.map((c) => c.$2).toSet(), hasLength(1));
  });

  test('the O piece does not change when rotated', () {
    final g = game()..debugSetPiece(PieceKind.o);
    final before = g.pieceCells().toSet();
    g.rotate();
    expect(g.pieceCells().toSet(), before);
  });

  test('a landed piece locks after the lock delay, then the next appears', () {
    final g = game()..debugSetPiece(PieceKind.o);
    final first = g.next;
    g.hardDrop();
    expect(g.piece.kind, first);
    expect(g.filled(4, 19) || g.filled(5, 19), isTrue);
    expect(g.takeEvents(), contains('lock'));
  });

  test('soft drop moves down a row and scores 1', () {
    final g = game();
    final y = g.piece.y;
    g.softDrop();
    expect(g.piece.y, y + 1);
    expect(g.score, 1);
  });

  test('hard drop lands at once and scores 2 per row', () {
    final g = game()..debugSetPiece(PieceKind.o);
    g.hardDrop();
    expect(g.score, 2 * 19); // O spawns with its bottom on visible row 0
  });

  test('a full row blinks for 24 ticks, then clears and scores', () {
    final g = game(level: 2)..debugSetPiece(PieceKind.o);
    fillRow(g, 19, holes: {4, 5});
    g.hardDrop();
    expect(g.clearing, [19]);
    expect(g.takeEvents(), contains('clear'));
    ticks(g, 23);
    expect(g.clearing, isNotEmpty);
    g.tick();
    expect(g.clearing, isEmpty);
    expect(g.lines, 1);
    expect(g.score, 2 * 19 + 40 * 2);
    // The O's top half dropped into row 19.
    expect(g.filled(4, 19), isTrue);
    expect(g.filled(0, 19), isFalse);
  });

  test('four rows at once score 1200 × level', () {
    final g = game()..debugSetPiece(PieceKind.i);
    g.rotate(); // upright
    final col = g.pieceCells().first.$1;
    for (var r = 16; r < 20; r++) {
      fillRow(g, r, holes: {col});
    }
    final before = g.score;
    g.hardDrop();
    expect(g.clearing, [16, 17, 18, 19]);
    expect(g.takeEvents(), contains('four'));
    ticks(g, 24);
    expect(g.lines, 4);
    expect(g.score - before, greaterThanOrEqualTo(1200));
  });

  test('every 10 rows the level goes up', () {
    final g = game(level: 3);
    g.debugAddLines(9);
    expect(g.level, 3);
    g.debugAddLines(1);
    expect(g.level, 4);
  });

  test('the game ends when a new piece cannot appear', () {
    final g = game();
    for (var r = 0; r < 20; r++) {
      fillRow(g, r, holes: {0});
    }
    g.hardDrop();
    expect(g.over, isTrue);
    expect(g.takeEvents(), contains('crash'));
    final y = g.piece.y;
    ticks(g, 200);
    expect(g.piece.y, y);
  });

  test('same seed and inputs give the same game', () {
    String run(int seed) {
      final g = game(seed: seed);
      final kinds = <PieceKind>[];
      for (var i = 0; i < 3000 && !g.over; i++) {
        if (i % 50 == 0) g.moveLeft();
        if (i % 70 == 0) g.rotate();
        g.tick();
        kinds.add(g.piece.kind);
      }
      return '${g.score}/${g.lines}/${kinds.take(40)}';
    }

    expect(run(4), run(4));
    expect(run(4), isNot(run(5)));
  });

  group('lock delay (F3)', () {
    /// An O piece resting on the floor, not yet locked.
    BlocksGame grounded() {
      final g = game()..debugSetPiece(PieceKind.o);
      while (g.piece.y < 18) {
        g.softDrop();
      }
      return g;
    }

    test('a landed piece locks after 30 ticks', () {
      final g = grounded();
      final kind = g.piece.kind;
      ticks(g, 29);
      expect(g.piece.kind, kind);
      expect(g.filled(4, 19), isFalse);
      g.tick();
      expect(g.filled(4, 19), isTrue);
    });

    test('moving or rotating on the floor restarts the delay', () {
      final g = grounded();
      ticks(g, 25);
      g.moveLeft();
      ticks(g, 25);
      expect(g.filled(3, 19), isFalse); // still sliding
      g.moveLeft();
      ticks(g, 29);
      expect(g.filled(2, 19), isFalse);
      g.tick();
      expect(g.filled(2, 19), isTrue);
    });

    test('at most 15 restarts per piece', () {
      final g = grounded();
      for (var i = 0; i < 15; i++) {
        ticks(g, 20);
        i.isEven ? g.moveLeft() : g.moveRight();
      }
      ticks(g, 20);
      g.moveLeft(); // 16th move: no restart
      ticks(g, 10);
      expect(g.takeEvents(), contains('lock'));
    });
  });
}
