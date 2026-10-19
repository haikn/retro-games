import 'dart:typed_data';

import 'config.dart';
import 'world_state.dart';

import 'package:arcade_core/rng.dart';

/// Seeded generator of cave columns and obstacles.
///
/// Passability is guaranteed by construction: the generator tracks the
/// reachable band (possible y positions of the hitbox top edge) column by
/// column and rejects any walk step or obstacle that would empty it.
class CaveGenerator {
  CaveGenerator(this.config, int seed)
    : _rng = Rng(seed),
      _center = (config.playTop + config.worldHeight) / 2 {
    _band.setAll(-1e9, 1e9);
  }

  final Config config;
  final Rng _rng;

  double _center;
  int _index = 0;
  double _sinceObstacle = double.infinity;

  int _lockLeft = 0;
  double _lockTop = 0;
  double _lockBottom = 0;
  double _lockObstacleTop = 0;
  double _lockObstacleBottom = 0;

  final _band = _Intervals();
  final _grown = _Intervals();
  final _trial = _Intervals();
  final _trial2 = _Intervals();

  /// Columns where no walk step kept the band non-empty. Always 0 with a
  /// valid [Config]; exposed for tests.
  int forcedColumns = 0;

  /// Current reachable band, as `(lo, hi)` pairs (debug overlay / tests).
  List<(double, double)> get band => _band.toList();

  double _snap(double v) => (v / config.lcdPixel).round() * config.lcdPixel;

  double _ramp(double worldX) =>
      (worldX / config.rampDistancePx).clamp(0.0, 1.0).toDouble();

  /// 0 until the first ramp ends, then up to 1 at [Config.lateRampDistancePx].
  double _lateRamp(double worldX) =>
      ((worldX - config.rampDistancePx) /
              (config.lateRampDistancePx - config.rampDistancePx))
          .clamp(0.0, 1.0)
          .toDouble();

  double gapAt(double worldX) => _snap(
    config.initialGap +
        (config.minGap - config.initialGap) * _ramp(worldX) +
        (config.lateMinGap - config.minGap) * _lateRamp(worldX),
  );

  double obstacleSpacingAt(double worldX) =>
      config.initialObstacleSpacing +
      (config.minObstacleSpacing - config.initialObstacleSpacing) *
          _ramp(worldX) +
      (config.lateMinObstacleSpacing - config.minObstacleSpacing) *
          _lateRamp(worldX);

  /// Appends the next column to [ring].
  void next(ColumnRing ring) {
    final worldX = _index * config.columnWidth;
    _index++;
    _sinceObstacle += config.columnWidth;

    if (_lockLeft > 0) {
      _lockLeft--;
      _propagate(
        _band,
        _trial,
        _lockTop,
        _lockBottom,
        true,
        _lockObstacleTop,
        _lockObstacleBottom,
      );
      _band.copyFrom(_trial);
      ring.push(
        top: _lockTop,
        bottom: _lockBottom,
        obstacleTop: _lockObstacleTop,
        obstacleBottom: _lockObstacleBottom,
      );
      return;
    }

    final gap = gapAt(worldX);
    final first = _rng.nextInt(3) - 1;
    final steps = first == 0 ? const [0, 1, -1] : [first, 0, -first];
    var top = 0.0;
    var accepted = false;
    for (final step in steps) {
      final c = _clampCenter(_center + step * config.walkStep, gap);
      top = _snap(c - gap / 2);
      if (_propagate(_band, _trial, top, top + gap, false, 0, 0)) {
        _center = c;
        accepted = true;
        break;
      }
    }
    if (!accepted) {
      forcedColumns++;
      _center = _clampCenter(_center, gap);
      top = _snap(_center - gap / 2);
    }
    final bottom = top + gap;

    if (worldX >= config.firstObstacleX &&
        _sinceObstacle >= obstacleSpacingAt(worldX) &&
        _tryObstacle(ring, top, bottom)) {
      return;
    }

    if (accepted) {
      _band.copyFrom(_trial);
    } else {
      _band.setAll(top, bottom - config.hitboxHeight);
    }
    ring.push(top: top, bottom: bottom);
  }

  bool _tryObstacle(ColumnRing ring, double top, double bottom) {
    final lcd = config.lcdPixel;
    final minPass = config.minPassableHeight;
    // Blocks leave at least minPass free: at most gap − minPass tall.
    final maxHeight = (bottom - top - minPass).clamp(
      config.obstacleMinHeight,
      config.obstacleMaxHeight,
    );
    final heights =
        ((maxHeight - config.obstacleMinHeight) / config.obstacleHeightStep)
            .floor() +
        1;
    for (var r = 0; r < config.placementRetries; r++) {
      final h =
          config.obstacleMinHeight +
          config.obstacleHeightStep * _rng.nextInt(heights);
      // Positions leaving a minPass window below the block are
      // [top, bottom - h - minPass]; leaving it above, the same range shifted
      // by minPass. Both ranges have the same number of grid slots.
      final slots = ((bottom - h - minPass - top) / lcd).floor() + 1;
      if (slots <= 0) continue;
      final windowAbove = _rng.nextInt(2) == 1;
      final y = top + (windowAbove ? minPass : 0) + _rng.nextInt(slots) * lcd;
      final yBottom = y + h;
      if (!_propagate(_band, _trial, top, bottom, true, y, yBottom)) continue;
      if (!_propagate(_trial, _trial2, top, bottom, true, y, yBottom)) continue;

      _band.copyFrom(_trial);
      _lockLeft = config.obstacleColumns - 1;
      _lockTop = top;
      _lockBottom = bottom;
      _lockObstacleTop = y;
      _lockObstacleBottom = yBottom;
      _sinceObstacle = 0;
      ring.push(
        top: top,
        bottom: bottom,
        obstacleTop: y,
        obstacleBottom: yBottom,
      );
      return true;
    }
    return false;
  }

  double _clampCenter(double c, double gap) => c
      .clamp(
        config.playTop + config.edgeMargin + gap / 2,
        config.worldHeight - config.edgeMargin - gap / 2,
      )
      .toDouble();

  /// Grows [src] by the climb margin and intersects it with the column's free
  /// space into [dst]. Returns whether [dst] is non-empty.
  bool _propagate(
    _Intervals src,
    _Intervals dst,
    double top,
    double bottom,
    bool hasObstacle,
    double obstacleTop,
    double obstacleBottom,
  ) {
    final h = config.hitboxHeight;
    _grown.growFrom(src, config.climbMargin);
    dst.clear();
    if (hasObstacle) {
      dst.intersectFrom(_grown, top, obstacleTop - h);
      dst.intersectFrom(_grown, obstacleBottom, bottom - h);
      dst.sort();
    } else {
      dst.intersectFrom(_grown, top, bottom - h);
    }
    return dst.count > 0;
  }
}

/// Small fixed-capacity set of sorted closed intervals.
class _Intervals {
  static const _capacity = 16;

  final _lo = Float64List(_capacity);
  final _hi = Float64List(_capacity);
  int count = 0;

  void clear() => count = 0;

  void setAll(double lo, double hi) {
    count = 0;
    if (lo <= hi) _add(lo, hi);
  }

  void _add(double lo, double hi) {
    if (count == _capacity) throw StateError('Reachable band overflow');
    _lo[count] = lo;
    _hi[count] = hi;
    count++;
  }

  void copyFrom(_Intervals o) {
    count = o.count;
    for (var i = 0; i < count; i++) {
      _lo[i] = o._lo[i];
      _hi[i] = o._hi[i];
    }
  }

  /// Every interval of [src] widened by [m] on both sides, merged.
  void growFrom(_Intervals src, double m) {
    count = 0;
    for (var i = 0; i < src.count; i++) {
      final lo = src._lo[i] - m;
      final hi = src._hi[i] + m;
      if (count > 0 && lo <= _hi[count - 1]) {
        if (hi > _hi[count - 1]) _hi[count - 1] = hi;
      } else {
        _add(lo, hi);
      }
    }
  }

  /// Appends the intersection of each interval of [src] with `[lo, hi]`.
  void intersectFrom(_Intervals src, double lo, double hi) {
    if (lo > hi) return;
    for (var i = 0; i < src.count; i++) {
      final a = src._lo[i] > lo ? src._lo[i] : lo;
      final b = src._hi[i] < hi ? src._hi[i] : hi;
      if (a <= b) _add(a, b);
    }
  }

  void sort() {
    for (var i = 1; i < count; i++) {
      final lo = _lo[i];
      final hi = _hi[i];
      var j = i - 1;
      while (j >= 0 && _lo[j] > lo) {
        _lo[j + 1] = _lo[j];
        _hi[j + 1] = _hi[j];
        j--;
      }
      _lo[j + 1] = lo;
      _hi[j + 1] = hi;
    }
  }

  List<(double, double)> toList() => [
    for (var i = 0; i < count; i++) (_lo[i], _hi[i]),
  ];
}
