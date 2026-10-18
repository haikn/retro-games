import 'package:flutter_test/flutter_test.dart';
import 'package:hop/core/generator.dart';
import 'package:hop/core/lanes.dart';

List<Lane> lanes(int seed, int n) {
  final g = LaneGenerator(seed);
  return [for (var i = 0; i < n; i++) g.next()];
}

int bits(int v) {
  var n = 0;
  for (; v != 0; v &= v - 1) {
    n++;
  }
  return n;
}

void main() {
  test('same seed gives the same lanes', () {
    final a = lanes(4, 400).map((l) => l.describe()).toList();
    final b = lanes(4, 400).map((l) => l.describe()).toList();
    expect(a, b);
    expect(lanes(5, 400).map((l) => l.describe()).toList(), isNot(a));
  });

  test('the start area is grass with the start column free', () {
    for (var seed = 1; seed <= 50; seed++) {
      final ls = lanes(seed, 5);
      for (final l in ls) {
        expect(l.kind, LaneKind.grass);
        expect(l.blocked(HopRules.startColumn), isFalse);
      }
      expect(ls[0].trees | ls[1].trees, 0);
    }
  });

  test('traffic, logs and trains stay within crossable bounds', () {
    for (var seed = 1; seed <= 100; seed++) {
      var riverRun = 0;
      var roadRun = 0;
      Lane? prev;
      for (final l in lanes(seed, 1500)) {
        switch (l.kind) {
          case LaneKind.road:
            final gap = HopRules.minTrafficGap(l.speed);
            final xs = [for (final m in l.objects) m.start]..sort();
            final sorted = [...l.objects]
              ..sort((a, b) => a.start.compareTo(b.start));
            for (var i = 0; i < sorted.length; i++) {
              final m = sorted[i];
              final next = i + 1 < sorted.length
                  ? sorted[i + 1].start
                  : sorted.first.start + HopRules.loop;
              expect(
                next - (m.start + m.length),
                greaterThanOrEqualTo(gap - 1e-9),
                reason: 'seed $seed lane ${l.index}',
              );
            }
            expect(xs, isNotEmpty);
            expect(l.speed, inInclusiveRange(0.25, 1.5));
          case LaneKind.river:
            final sorted = [...l.objects]
              ..sort((a, b) => a.start.compareTo(b.start));
            for (var i = 0; i < sorted.length; i++) {
              final m = sorted[i];
              expect(m.length, greaterThanOrEqualTo(HopRules.minLogLength));
              final next = i + 1 < sorted.length
                  ? sorted[i + 1].start
                  : sorted.first.start + HopRules.loop;
              final gap = next - (m.start + m.length);
              expect(
                gap,
                inInclusiveRange(HopRules.minLogGap, HopRules.maxLogGap),
                reason: 'seed $seed lane ${l.index}',
              );
            }
            if (prev?.kind == LaneKind.river) expect(l.dir, -prev!.dir);
          case LaneKind.rail:
            expect(l.trainPeriod, greaterThanOrEqualTo(240));
            expect(prev?.kind, isNot(LaneKind.rail));
          case LaneKind.grass:
            expect(bits(l.trees), lessThanOrEqualTo(6));
        }
        riverRun = l.kind == LaneKind.river ? riverRun + 1 : 0;
        roadRun = l.kind == LaneKind.road ? roadRun + 1 : 0;
        expect(riverRun, lessThanOrEqualTo(3));
        expect(roadRun, lessThanOrEqualTo(4));
        prev = l;
      }
    }
  });

  test('path property: a walkable route through the trees always exists '
      '(200 seeds × 3000 lanes)', () {
    for (var seed = 1; seed <= 200; seed++) {
      // Independent check: columns reachable on each lane. Non-grass lanes
      // allow free sideways movement; grass allows sideways movement only
      // through contiguous free columns.
      var reach = 1 << HopRules.startColumn;
      for (final l in lanes(seed, 3000)) {
        if (l.kind != LaneKind.grass) {
          reach = HopRules.allColumns;
          continue;
        }
        final free = HopRules.allColumns & ~l.trees;
        var r = reach & free;
        expect(r, isNonZero, reason: 'seed $seed lane ${l.index}');
        // Spread sideways through free neighbours.
        while (true) {
          final grown = (r | (r << 1) | (r >> 1)) & free;
          if (grown == r) break;
          r = grown;
        }
        reach = r;
      }
    }
  });

  test('no dead ends: every reachable stretch on grass continues into the '
      'next grass lane (200 seeds × 3000 lanes)', () {
    for (var seed = 1; seed <= 200; seed++) {
      var reach = 1 << HopRules.startColumn;
      Lane? prev;
      for (final l in lanes(seed, 3000)) {
        if (l.kind != LaneKind.grass) {
          reach = HopRules.allColumns;
          prev = l;
          continue;
        }
        final free = HopRules.allColumns & ~l.trees;
        if (prev?.kind == LaneKind.grass) {
          // Every run of reachable columns on the previous lane must have a
          // free column straight ahead.
          var run = 0;
          for (var c = 0; c <= HopRules.columns; c++) {
            if (c < HopRules.columns && reach & (1 << c) != 0) {
              run |= 1 << c;
            } else if (run != 0) {
              expect(
                run & free,
                isNonZero,
                reason:
                    'seed $seed lane ${l.index} run ${run.toRadixString(2)}',
              );
              run = 0;
            }
          }
        }
        var r = reach & free;
        while (true) {
          final grown = (r | (r << 1) | (r >> 1)) & free;
          if (grown == r) break;
          r = grown;
        }
        reach = r;
        prev = l;
      }
    }
  });

  test('difficulty ramps: later lanes are busier', () {
    double avgSpeed(Iterable<Lane> ls) {
      final roads = ls.where((l) => l.kind == LaneKind.road).toList();
      return roads.map((l) => l.speed).reduce((a, b) => a + b) / roads.length;
    }

    final all = lanes(3, 2000);
    expect(avgSpeed(all.skip(1500)), greaterThan(avgSpeed(all.take(300))));
  });
}
