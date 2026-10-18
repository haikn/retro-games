import 'dart:typed_data';

import 'package:arcade_core/rng.dart';

/// Rules (collection spec: Blocks — subject to decision C4).
abstract final class BlockRules {
  static const cols = 10;
  static const rows = 20;

  /// Spawn rows above the visible well.
  static const hidden = 2;
  static const lockDelayTicks = 15;
  static const clearTicks = 24;
  static const linesPerLevel = 10;

  /// Score for 0–4 rows cleared at once, times the level.
  static const lineScores = [0, 40, 100, 300, 1200];
}

const _gravity = [48, 43, 38, 33, 28, 23, 18, 13, 8, 6, 5, 4];

/// Ticks per row of gravity at [level] (3 at the fastest).
int gravityTicksFor(int level) =>
    level - 1 < _gravity.length ? _gravity[level - 1] : 3;

enum PieceKind { i, o, t, s, z, j, l }

class _Shape {
  const _Shape(this.size, this.cells);
  final int size;
  final List<(int, int)> cells;
}

const _shapes = {
  PieceKind.i: _Shape(4, [(0, 1), (1, 1), (2, 1), (3, 1)]),
  PieceKind.o: _Shape(2, [(0, 0), (1, 0), (0, 1), (1, 1)]),
  PieceKind.t: _Shape(3, [(1, 0), (0, 1), (1, 1), (2, 1)]),
  PieceKind.s: _Shape(3, [(1, 0), (2, 0), (0, 1), (1, 1)]),
  PieceKind.z: _Shape(3, [(0, 0), (1, 0), (1, 1), (2, 1)]),
  PieceKind.j: _Shape(3, [(0, 0), (0, 1), (1, 1), (2, 1)]),
  PieceKind.l: _Shape(3, [(2, 0), (0, 1), (1, 1), (2, 1)]),
};

/// Cells of [kind] in rotation [rot] (clockwise quarter turns), relative to
/// the top-left of its box.
List<(int, int)> shapeCells(PieceKind kind, int rot) {
  final shape = _shapes[kind]!;
  final n = shape.size;
  return [
    for (var (x, y) in shape.cells)
      () {
        for (var k = 0; k < rot % 4; k++) {
          (x, y) = (n - 1 - y, x);
        }
        return (x, y);
      }(),
  ];
}

class Piece {
  const Piece(this.kind, this.rot, this.x, this.y);
  final PieceKind kind;
  final int rot;
  final int x;

  /// Top of the box in visible rows (negative = above the well).
  final int y;

  Piece moved(int dx, int dy, [int dr = 0]) =>
      Piece(kind, (rot + dr) % 4, x + dx, y + dy);

  Iterable<(int, int)> get cells sync* {
    for (final (cx, cy) in shapeCells(kind, rot)) {
      yield (x + cx, y + cy);
    }
  }
}

/// One game of Blocks, advanced in fixed 60 Hz ticks. Pure Dart.
class BlocksGame {
  BlocksGame({required this.startLevel, required int seed})
    : _rng = Rng(seed),
      level = startLevel {
    next = _draw();
    _spawn();
  }

  final int startLevel;
  final Rng _rng;
  final _board = Uint8List(
    BlockRules.cols * (BlockRules.rows + BlockRules.hidden),
  );
  final _bag = <PieceKind>[];
  final _events = <String>[];

  late Piece piece;
  late PieceKind next;
  int level;
  int score = 0;
  int lines = 0;
  bool over = false;

  /// Visible rows blinking before they are removed.
  List<int> clearing = const [];
  int _clearLeft = 0;
  int _gravityCount = 0;
  int _lockCount = 0;

  /// Event names since the last call: `rotate`, `lock`, `clear`, `four`,
  /// `crash`.
  List<String> takeEvents() {
    final e = List.of(_events);
    _events.clear();
    return e;
  }

  bool get active => !over && clearing.isEmpty;

  /// Ticks left in the row-clear blink (0 when not clearing).
  int get clearingTicksLeft => clearing.isEmpty ? 0 : _clearLeft;

  PieceKind _draw() {
    if (_bag.isEmpty) {
      _bag.addAll(PieceKind.values);
      for (var i = _bag.length - 1; i > 0; i--) {
        final j = _rng.nextInt(i + 1);
        final t = _bag[i];
        _bag[i] = _bag[j];
        _bag[j] = t;
      }
    }
    return _bag.removeLast();
  }

  int _index(int c, int r) => (r + BlockRules.hidden) * BlockRules.cols + c;

  /// Whether visible cell (c, r) is filled; outside the well counts as filled
  /// (above the well does not).
  bool filled(int c, int r) {
    if (c < 0 || c >= BlockRules.cols || r >= BlockRules.rows) return true;
    if (r < -BlockRules.hidden) return false;
    return _board[_index(c, r)] != 0;
  }

  bool _fits(Piece p) => p.cells.every((cell) => !filled(cell.$1, cell.$2));

  Iterable<(int, int)> pieceCells() => piece.cells;

  void _spawn() {
    final kind = next;
    next = _draw();
    final size = _shapes[kind]!.size;
    piece = Piece(kind, 0, (BlockRules.cols - size) ~/ 2, -1);
    _gravityCount = 0;
    _lockCount = 0;
    if (!_fits(piece)) _end();
  }

  void _end() {
    over = true;
    _events.add('crash');
  }

  bool _try(Piece p) {
    if (!_fits(p)) return false;
    piece = p;
    return true;
  }

  void moveLeft() {
    if (active) _try(piece.moved(-1, 0));
  }

  void moveRight() {
    if (active) _try(piece.moved(1, 0));
  }

  /// Clockwise, with wall kicks.
  void rotate() {
    if (!active || piece.kind == PieceKind.o) return;
    const kicks = [(0, 0), (-1, 0), (1, 0), (0, -1), (-2, 0), (2, 0)];
    for (final (dx, dy) in kicks) {
      if (_try(piece.moved(dx, dy, 1))) {
        _lockCount = 0;
        _events.add('rotate');
        return;
      }
    }
  }

  /// One row down now (+1 point).
  void softDrop() {
    if (!active) return;
    if (_try(piece.moved(0, 1))) {
      score += 1;
      _gravityCount = 0;
    }
  }

  /// Straight down and lock (+2 points per row).
  void hardDrop() {
    if (!active) return;
    var rows = 0;
    while (_try(piece.moved(0, 1))) {
      rows++;
    }
    score += 2 * rows;
    _lock();
  }

  void tick() {
    if (over) return;
    if (clearing.isNotEmpty) {
      if (--_clearLeft == 0) _collapse();
      return;
    }
    if (++_gravityCount >= gravityTicksFor(level)) {
      _gravityCount = 0;
      _try(piece.moved(0, 1));
    }
    if (_fits(piece.moved(0, 1))) {
      _lockCount = 0;
    } else if (++_lockCount >= BlockRules.lockDelayTicks) {
      _lock();
    }
  }

  void _lock() {
    var above = false;
    for (final (c, r) in piece.cells) {
      if (r < 0) above = true;
      if (r >= -BlockRules.hidden) _board[_index(c, r)] = 1;
    }
    _events.add('lock');
    if (above) {
      _end();
      return;
    }
    final full = [
      for (var r = 0; r < BlockRules.rows; r++)
        if (List.generate(BlockRules.cols, (c) => filled(c, r)).every((f) => f))
          r,
    ];
    if (full.isEmpty) {
      _spawn();
      return;
    }
    clearing = full;
    _clearLeft = BlockRules.clearTicks;
    _events.add(full.length == 4 ? 'four' : 'clear');
  }

  void _collapse() {
    final n = clearing.length;
    for (final r in clearing) {
      for (var rr = r; rr > -BlockRules.hidden; rr--) {
        for (var c = 0; c < BlockRules.cols; c++) {
          _board[_index(c, rr)] = _board[_index(c, rr - 1)];
        }
      }
      for (var c = 0; c < BlockRules.cols; c++) {
        _board[_index(c, -BlockRules.hidden)] = 0;
      }
    }
    score += BlockRules.lineScores[n] * level;
    _addLines(n);
    clearing = const [];
    _spawn();
  }

  void _addLines(int n) {
    lines += n;
    level = startLevel + lines ~/ BlockRules.linesPerLevel;
  }

  // ---- test hooks ----

  void debugSet(int c, int r) => _board[_index(c, r)] = 1;

  void debugSetPiece(PieceKind kind) {
    final size = _shapes[kind]!.size;
    piece = Piece(kind, 0, (BlockRules.cols - size) ~/ 2, -1);
  }

  void debugSpawnNext() => _spawn();

  void debugAddLines(int n) => _addLines(n);
}
