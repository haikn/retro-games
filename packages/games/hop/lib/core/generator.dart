import 'dart:math' as math;

import 'package:arcade_core/rng.dart';

import 'lanes.dart';

/// Seeded lane generator, passable by construction:
/// - every grass lane leaves a column reachable from the previous lane
///   (walking sideways through free columns on grass, freely elsewhere);
/// - no dead ends: on consecutive grass lanes, every stretch of reachable
///   free columns continues into the next lane, so hopping straight on
///   never leads into a pocket that forces backtracking;
/// - vehicles are spaced at least [HopRules.minTrafficGap] apart;
/// - logs are ≥ 16 px with gaps of 8–24 px, so one always comes soon;
/// - at most 3 rivers and 4 roads in a row, never two railways in a row.
/// Speed and density rise with distance.
class LaneGenerator {
  LaneGenerator(int seed) : _rng = Rng(seed);

  final Rng _rng;
  int _index = 0;
  int _reach = HopRules.allColumns;
  Lane? _prev;
  int _riverRun = 0;
  int _roadRun = 0;

  /// 0 at the start, 1 from lane 250 on.
  static double difficulty(int index) => math.min(1, index / 250);

  Lane next() {
    final i = _index++;
    final lane = i < 5 ? _grass(i, start: true) : _choose(i);
    _riverRun = lane.kind == LaneKind.river ? _riverRun + 1 : 0;
    _roadRun = lane.kind == LaneKind.road ? _roadRun + 1 : 0;
    if (lane.kind != LaneKind.grass) _reach = HopRules.allColumns;
    _prev = lane;
    return lane;
  }

  Lane _choose(int i) {
    final d = difficulty(i);
    final weights = <LaneKind, double>{
      LaneKind.grass: 0.36 - 0.12 * d,
      LaneKind.road: _roadRun < 4 ? 0.34 + 0.04 * d : 0,
      LaneKind.river: _riverRun < 3 ? 0.20 + 0.04 * d : 0,
      LaneKind.rail: _prev?.kind != LaneKind.rail ? 0.10 + 0.04 * d : 0,
    };
    final total = weights.values.reduce((a, b) => a + b);
    var r = _rng.nextDouble() * total;
    var kind = LaneKind.grass;
    for (final MapEntry(key: k, value: w) in weights.entries) {
      if (r < w) {
        kind = k;
        break;
      }
      r -= w;
    }
    return switch (kind) {
      LaneKind.grass => _grass(i, start: false),
      LaneKind.road => _road(i, d),
      LaneKind.river => _river(i, d),
      LaneKind.rail => Lane.rail(
        index: i,
        dir: _rng.nextInt(2) == 0 ? 1 : -1,
        trainPeriod: 240 + _rng.nextInt(180),
        trainOffset: _rng.nextInt(240),
      ),
    };
  }

  Lane _grass(int i, {required bool start}) {
    var trees = 0;
    if (!start || i >= 2) {
      final max = start ? 2 : 2 + (4 * difficulty(i)).round();
      final count = _rng.nextInt(max + 1);
      for (var k = 0; k < count; k++) {
        trees |= 1 << _rng.nextInt(HopRules.columns);
      }
      if (start) trees &= ~(1 << HopRules.startColumn);
    }
    const all = HopRules.allColumns;
    if (_prev?.kind == LaneKind.grass) {
      for (final segment in _segments(_reach)) {
        if (segment & ~trees == 0) {
          final cols = [
            for (var c = 0; c < HopRules.columns; c++)
              if (segment & (1 << c) != 0) c,
          ];
          trees &= ~(1 << cols[_rng.nextInt(cols.length)]);
        }
      }
    }
    var free = all & ~trees;
    if (_reach & free == 0) {
      // Clear a tree in a reachable column so a path continues.
      final options = [
        for (var c = 0; c < HopRules.columns; c++)
          if (_reach & (1 << c) != 0) c,
      ];
      trees &= ~(1 << options[_rng.nextInt(options.length)]);
      free = all & ~trees;
    }
    var r = _reach & free;
    while (true) {
      final grown = (r | (r << 1) | (r >> 1)) & free;
      if (grown == r) break;
      r = grown;
    }
    _reach = r;
    return Lane.grass(index: i, trees: trees);
  }

  /// Contiguous runs of set bits in [mask], each as its own mask.
  static Iterable<int> _segments(int mask) sync* {
    var run = 0;
    for (var c = 0; c <= HopRules.columns; c++) {
      if (c < HopRules.columns && mask & (1 << c) != 0) {
        run |= 1 << c;
      } else if (run != 0) {
        yield run;
        run = 0;
      }
    }
  }

  Lane _road(int i, double d) {
    final dir = _rng.nextInt(2) == 0 ? 1 : -1;
    final speed = 0.25 + 0.75 * d + 0.25 * _rng.nextDouble();
    final gapMin = HopRules.minTrafficGap(speed);
    final s0 = _rng.nextDouble() * 20;
    final movers = <Mover>[];
    var pos = s0;
    while (true) {
      final len = _rng.nextDouble() < 0.25 + 0.2 * d ? 22 : 12;
      if (pos + len + gapMin > s0 + HopRules.loop) break;
      movers.add(Mover(pos, len));
      pos += len + gapMin + _rng.nextDouble() * (10 + 40 * (1 - d));
    }
    return Lane.road(index: i, dir: dir, speed: speed, objects: movers);
  }

  Lane _river(int i, double d) {
    final prev = _prev;
    final dir = prev?.kind == LaneKind.river
        ? -prev!.dir
        : (_rng.nextInt(2) == 0 ? 1 : -1);
    final speed = 0.2 + 0.3 * d + 0.15 * _rng.nextDouble();
    final s0 = _rng.nextDouble() * 20;
    final logs = <(double, int)>[];
    var pos = s0;
    while (true) {
      final len = [16, 24, 32][_rng.nextInt(d > 0.5 ? 2 : 3)];
      if (pos + len + HopRules.minLogGap > s0 + HopRules.loop) break;
      logs.add((pos, len));
      final gap =
          HopRules.minLogGap +
          _rng.nextDouble() * (HopRules.maxLogGap - HopRules.minLogGap);
      pos += len + gap;
    }
    // Close the loop: the wrap-around gap must also be ≤ maxLogGap.
    final (lastStart, lastLen) = logs.last;
    final wrap = s0 + HopRules.loop - (lastStart + lastLen);
    if (wrap > HopRules.maxLogGap) {
      logs[logs.length - 1] = (
        lastStart,
        lastLen + (wrap - HopRules.maxLogGap).ceil(),
      );
    }
    return Lane.river(
      index: i,
      dir: dir,
      speed: speed,
      objects: [for (final (s, l) in logs) Mover(s, l)],
    );
  }
}
