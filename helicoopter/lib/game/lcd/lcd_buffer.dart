import 'dart:typed_data';

import 'sprites.dart';

/// The LCD screen as a grid of on/off pixels plus ghost timers.
///
/// Each frame: [beginFrame], draw with [set] / [fillRect] / [blit], then
/// [endFrame]. With [ghostDuration] > 0, pixels that were on last frame and
/// are off now leave a ghost that fades over that many seconds (slow-LCD
/// look). Off by default: playtesting showed it reads as an echo on moving
/// walls (spec 1.3). No allocation after construction.
class LcdBuffer {
  LcdBuffer({this.width = 160, this.height = 80, this.ghostDuration = 0})
    : _cells = Uint8List(width * height),
      _prev = Uint8List(width * height),
      _ghost = Float32List(width * height);

  final int width;
  final int height;
  final double ghostDuration;

  Uint8List _cells;
  Uint8List _prev;
  final Float32List _ghost;

  /// Swap ink and LCD colours when painting (crash flash).
  bool inverted = false;

  /// Current frame's cells, row-major, 1 = ink. For the painter.
  Uint8List get cells => _cells;

  /// Remaining ghost time per cell in seconds. For the painter.
  Float32List get ghosts => _ghost;

  int get litCount {
    var n = 0;
    for (final c in _cells) {
      n += c;
    }
    return n;
  }

  void beginFrame(double dt) {
    final t = _prev;
    _prev = _cells;
    _cells = t..fillRange(0, t.length, 0);
    for (var i = 0; i < _ghost.length; i++) {
      final g = _ghost[i];
      if (g > 0) _ghost[i] = g > dt ? g - dt : 0;
    }
  }

  void endFrame() {
    if (ghostDuration <= 0) return;
    for (var i = 0; i < _cells.length; i++) {
      if (_cells[i] == 1) {
        _ghost[i] = 0;
      } else if (_prev[i] == 1) {
        _ghost[i] = ghostDuration;
      }
    }
  }

  bool isLit(int x, int y) =>
      x >= 0 && y >= 0 && x < width && y < height && _cells[y * width + x] == 1;

  /// Ghost brightness in [0, 1] for a cell that is off.
  double ghostLevel(int x, int y) =>
      ghostDuration <= 0 ? 0 : _ghost[y * width + x] / ghostDuration;

  void set(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    _cells[y * width + x] = 1;
  }

  void fillRect(int x, int y, int w, int h) {
    final x0 = x < 0 ? 0 : x;
    final y0 = y < 0 ? 0 : y;
    final x1 = x + w > width ? width : x + w;
    final y1 = y + h > height ? height : y + h;
    for (var cy = y0; cy < y1; cy++) {
      final row = cy * width;
      for (var cx = x0; cx < x1; cx++) {
        _cells[row + cx] = 1;
      }
    }
  }

  void blit(Sprite1 sprite, int x, int y) {
    for (var sy = 0; sy < sprite.height; sy++) {
      for (var sx = 0; sx < sprite.width; sx++) {
        if (sprite.at(sx, sy)) set(x + sx, y + sy);
      }
    }
  }
}
