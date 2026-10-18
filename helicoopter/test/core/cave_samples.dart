import 'package:cave_copter/core/cave_generator.dart';
import 'package:cave_copter/core/config.dart';
import 'package:cave_copter/core/world_state.dart';

/// Plain copy of one generated column, for assertions.
class SampleColumn {
  const SampleColumn({
    required this.x,
    required this.top,
    required this.bottom,
    required this.hasObstacle,
    required this.obstacleTop,
    required this.obstacleBottom,
  });

  factory SampleColumn.read(ColumnRing ring, int i, Config config) {
    final has = ring.hasObstacleAt(i);
    return SampleColumn(
      x: i * config.columnWidth,
      top: ring.topAt(i),
      bottom: ring.bottomAt(i),
      hasObstacle: has,
      obstacleTop: has ? ring.obstacleTopAt(i) : 0,
      obstacleBottom: has ? ring.obstacleBottomAt(i) : 0,
    );
  }

  final double x;
  final double top;
  final double bottom;
  final bool hasObstacle;
  final double obstacleTop;
  final double obstacleBottom;

  @override
  bool operator ==(Object other) =>
      other is SampleColumn &&
      other.x == x &&
      other.top == top &&
      other.bottom == bottom &&
      other.hasObstacle == hasObstacle &&
      other.obstacleTop == obstacleTop &&
      other.obstacleBottom == obstacleBottom;

  @override
  int get hashCode =>
      Object.hash(x, top, bottom, hasObstacle, obstacleTop, obstacleBottom);

  @override
  String toString() =>
      'x=$x top=$top bottom=$bottom'
      '${hasObstacle ? ' obstacle=$obstacleTop..$obstacleBottom' : ''}';
}

List<SampleColumn> sampleCave(
  int seed,
  int count, {
  Config config = const Config(),
}) {
  final gen = CaveGenerator(config, seed);
  final ring = ColumnRing(2);
  final out = <SampleColumn>[];
  for (var i = 0; i < count; i++) {
    gen.next(ring);
    out.add(SampleColumn.read(ring, ring.lastIndex, config));
    ring.dropFirst();
  }
  return out;
}

bool onLcdGrid(double v, {double lcdPixel = 5}) =>
    (v / lcdPixel - (v / lcdPixel).round()).abs() < 1e-9;

/// Independent, allocation-happy implementation of the spec's reachable band
/// (positions of the hitbox top edge), used to check the generator.
class ReferenceBand {
  ReferenceBand(this.config);

  final Config config;
  List<(double, double)>? _band;

  bool get isEmpty => _band != null && _band!.isEmpty;

  List<(double, double)> _free(SampleColumn c) {
    final h = config.hitboxHeight;
    final spans = c.hasObstacle
        ? [(c.top, c.obstacleTop - h), (c.obstacleBottom, c.bottom - h)]
        : [(c.top, c.bottom - h)];
    return [
      for (final s in spans)
        if (s.$1 <= s.$2) s,
    ];
  }

  void advance(SampleColumn c) {
    final free = _free(c);
    final band = _band;
    if (band == null) {
      _band = free;
      return;
    }
    final m = config.climbMargin;
    final widened = [for (final (lo, hi) in band) (lo - m, hi + m)]
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final grown = <(double, double)>[];
    for (final s in widened) {
      if (grown.isNotEmpty && s.$1 <= grown.last.$2) {
        final last = grown.removeLast();
        grown.add((last.$1, s.$2 > last.$2 ? s.$2 : last.$2));
      } else {
        grown.add(s);
      }
    }
    final next = <(double, double)>[];
    for (final (a0, a1) in grown) {
      for (final (b0, b1) in free) {
        final lo = a0 > b0 ? a0 : b0;
        final hi = a1 < b1 ? a1 : b1;
        if (lo <= hi) next.add((lo, hi));
      }
    }
    _band = next;
  }
}
