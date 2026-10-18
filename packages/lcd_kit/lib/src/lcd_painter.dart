import 'dart:typed_data';
import 'dart:ui';

import 'lcd_buffer.dart';
import 'palette.dart';

/// Paints an [LcdBuffer] onto a canvas in virtual px.
///
/// Lit cells are drawn in a single `drawRawPoints` call (square caps sized to
/// one cell), ghosts in two more (two fade levels). Grid lines come from a
/// cached picture. Buffers are reused, so painting does not allocate per cell.
class LcdPainter {
  LcdPainter({required this.palette, required this.cellSize, int cells = 0})
    : _points = Float32List(cells * 2),
      _ghostHigh = Float32List(cells * 2),
      _ghostLow = Float32List(cells * 2);

  final LcdPalette palette;
  final double cellSize;

  Float32List _points;
  Float32List _ghostHigh;
  Float32List _ghostLow;

  final _ground = Paint()..isAntiAlias = false;
  final _cell = Paint()
    ..isAntiAlias = false
    ..strokeCap = StrokeCap.square;

  Picture? _gridNormal;
  Picture? _gridInverted;

  void paint(Canvas canvas, LcdBuffer b) {
    final ink = b.inverted ? palette.lcd : palette.ink;
    final ground = b.inverted ? palette.ink : palette.lcd;
    final w = b.width * cellSize;
    final h = b.height * cellSize;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _ground..color = ground);

    final n = b.width * b.height;
    if (_points.length < n * 2) {
      _points = Float32List(n * 2);
      _ghostHigh = Float32List(n * 2);
      _ghostLow = Float32List(n * 2);
    }
    final cells = b.cells;
    final ghosts = b.ghosts;
    final half = cellSize / 2;
    final ghostSplit = b.ghostDuration / 2;
    var lit = 0;
    var high = 0;
    var low = 0;
    for (var i = 0; i < n; i++) {
      final x = (i % b.width) * cellSize + half;
      final y = (i ~/ b.width) * cellSize + half;
      if (cells[i] == 1) {
        _points[lit++] = x;
        _points[lit++] = y;
      } else {
        final g = ghosts[i];
        if (g <= 0) continue;
        if (g > ghostSplit) {
          _ghostHigh[high++] = x;
          _ghostHigh[high++] = y;
        } else {
          _ghostLow[low++] = x;
          _ghostLow[low++] = y;
        }
      }
    }

    _cell.strokeWidth = cellSize;
    _drawPoints(canvas, _ghostLow, low, ink.withValues(alpha: 0.25));
    _drawPoints(canvas, _ghostHigh, high, ink.withValues(alpha: 0.5));
    _drawPoints(canvas, _points, lit, ink);

    if (palette.gridOpacity > 0) {
      canvas.drawPicture(_grid(b, inverted: b.inverted, ink: ink));
    }
  }

  void _drawPoints(Canvas canvas, Float32List data, int length, Color color) {
    if (length == 0) return;
    _cell.color = color;
    canvas.drawRawPoints(
      PointMode.points,
      Float32List.sublistView(data, 0, length),
      _cell,
    );
  }

  Picture _grid(LcdBuffer b, {required bool inverted, required Color ink}) {
    final cached = inverted ? _gridInverted : _gridNormal;
    if (cached != null) return cached;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = ink.withValues(alpha: palette.gridOpacity)
      ..strokeWidth = 0; // hairline: one device pixel at any scale
    final w = b.width * cellSize;
    final h = b.height * cellSize;
    for (var x = 1; x < b.width; x++) {
      canvas.drawLine(Offset(x * cellSize, 0), Offset(x * cellSize, h), paint);
    }
    for (var y = 1; y < b.height; y++) {
      canvas.drawLine(Offset(0, y * cellSize), Offset(w, y * cellSize), paint);
    }
    final picture = recorder.endRecording();
    if (inverted) {
      _gridInverted = picture;
    } else {
      _gridNormal = picture;
    }
    return picture;
  }
}
