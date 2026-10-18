import 'package:cave_copter/core/cave_generator.dart';
import 'package:cave_copter/core/config.dart';
import 'package:cave_copter/core/world_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cave_samples.dart';

void main() {
  const config = Config();

  test('same seed gives the same cave', () {
    final a = sampleCave(42, 3000);
    final b = sampleCave(42, 3000);
    expect(a.length, b.length);
    for (var i = 0; i < a.length; i++) {
      expect(a[i], b[i]);
    }
  });

  test('different seeds give different caves', () {
    final a = sampleCave(1, 200).map((c) => c.top).toList();
    final b = sampleCave(2, 200).map((c) => c.top).toList();
    expect(a, isNot(equals(b)));
  });

  test('gap ramps from 300 to 170 px by 20 000 px', () {
    final gen = CaveGenerator(config, 1);
    expect(gen.gapAt(0), 300);
    expect(gen.gapAt(10000), 235);
    expect(gen.gapAt(20000), 170);
    expect(gen.gapAt(1e9), 170);
  });

  test('obstacle spacing ramps from 600 to 300 px', () {
    final gen = CaveGenerator(config, 1);
    expect(gen.obstacleSpacingAt(0), 600);
    expect(gen.obstacleSpacingAt(20000), 300);
    expect(gen.obstacleSpacingAt(1e9), 300);
  });

  test('walls respect the gap, margins and LCD grid', () {
    for (final c in sampleCave(7, 6000)) {
      final gap = c.bottom - c.top;
      expect(gap, greaterThanOrEqualTo(config.minGap));
      expect(gap, lessThanOrEqualTo(config.initialGap));
      expect(c.top, greaterThanOrEqualTo(config.playTop + config.edgeMargin));
      expect(
        c.bottom,
        lessThanOrEqualTo(config.worldHeight - config.edgeMargin),
      );
      expect(onLcdGrid(c.top), isTrue, reason: 'top ${c.top}');
      expect(onLcdGrid(c.bottom), isTrue, reason: 'bottom ${c.bottom}');
    }
  });

  test(
    'walls move at most one walk step plus one rounding step per column',
    () {
      final cave = sampleCave(9, 6000);
      for (var i = 1; i < cave.length; i++) {
        expect((cave[i].top - cave[i - 1].top).abs(), lessThanOrEqualTo(10));
      }
    },
  );

  test('no obstacle on the first screen', () {
    final cave = sampleCave(5, 200);
    for (final c in cave.where((c) => c.x < config.firstObstacleX)) {
      expect(c.hasObstacle, isFalse, reason: 'column at x ${c.x}');
    }
  });

  test('obstacles are 2 identical columns, sized and spaced per spec', () {
    final cave = sampleCave(3, 8000);
    final starts = <int>[];
    for (var i = 0; i < cave.length; i++) {
      final c = cave[i];
      if (!c.hasObstacle) continue;
      final startsHere =
          i == 0 ||
          !cave[i - 1].hasObstacle ||
          cave[i - 1].obstacleTop != c.obstacleTop;
      if (!startsHere) continue;
      starts.add(i);
      final twin = cave[i + 1];
      expect(twin.hasObstacle, isTrue);
      expect(twin.top, c.top);
      expect(twin.bottom, c.bottom);
      expect(twin.obstacleTop, c.obstacleTop);
      expect(twin.obstacleBottom, c.obstacleBottom);
      expect(
        cave[i + 2].obstacleTop == c.obstacleTop && cave[i + 2].hasObstacle,
        isFalse,
      );

      final h = c.obstacleBottom - c.obstacleTop;
      expect(
        h,
        inInclusiveRange(config.obstacleMinHeight, config.obstacleMaxHeight),
      );
      expect(h % config.obstacleHeightStep, 0);
      expect(onLcdGrid(c.obstacleTop), isTrue);
      expect(c.obstacleTop, greaterThanOrEqualTo(c.top));
      expect(c.obstacleBottom, lessThanOrEqualTo(c.bottom));
      final window = [
        c.obstacleTop - c.top,
        c.bottom - c.obstacleBottom,
      ].reduce((a, b) => a > b ? a : b);
      expect(window, greaterThanOrEqualTo(config.minPassableHeight));
    }
    expect(starts.length, greaterThan(50));
    for (var k = 1; k < starts.length; k++) {
      final spacing = (starts[k] - starts[k - 1]) * config.columnWidth;
      expect(spacing, greaterThanOrEqualTo(config.minObstacleSpacing));
    }
  });

  test(
    'passability: reachable band never empty (1 000 seeds × 10 000 columns)',
    () {
      var obstacles = 0;
      for (var seed = 1; seed <= 1000; seed++) {
        final gen = CaveGenerator(config, seed);
        final ring = ColumnRing(2);
        final band = ReferenceBand(config);
        for (var i = 0; i < 10000; i++) {
          gen.next(ring);
          final c = SampleColumn.read(ring, ring.lastIndex, config);
          ring.dropFirst();
          if (c.hasObstacle) obstacles++;
          band.advance(c);
          if (band.isEmpty) {
            fail('seed $seed: band empty at column $i ($c)');
          }
        }
        expect(gen.forcedColumns, 0, reason: 'seed $seed');
      }
      expect(obstacles, greaterThan(1000 * 100));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
