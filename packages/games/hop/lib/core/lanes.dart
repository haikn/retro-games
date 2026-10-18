/// Lanes of the Hop world. Positions of cars, logs and trains are pure
/// functions of the tick, so there is no moving state to keep in sync.
library;

enum LaneKind { grass, road, river, rail }

/// Sizes in LCD pixels and timings in 60 Hz ticks (collection spec: Hop).
abstract final class HopRules {
  static const columns = 10;
  static const columnWidth = 8;
  static const screenWidth = 80;
  static const laneHeight = 10;
  static const visibleLanes = 15;
  static const allColumns = (1 << columns) - 1;
  static const startLane = 2;
  static const startColumn = 4;
  static const hopTicks = 8;
  static const chickenWidth = 8;

  /// Moving lanes loop over 144 px: the 80-px screen plus 32 px on each side,
  /// so an object (≤ 32 px) leaves the screen fully before it wraps.
  static const loop = 144.0;
  static const loopMargin = 32.0;

  static const trainLength = 64;
  static const trainSpeed = 4.0;
  static const trainWarnTicks = 60;
  static int get trainPassTicks =>
      ((screenWidth + trainLength) / trainSpeed).ceil();

  static const minLogLength = 16;
  static const minLogGap = 8;
  static const maxLogGap = 24;

  /// Smallest gap between vehicles that a chicken can always cross: its
  /// width, the distance traffic covers during two hops, and a margin.
  static double minTrafficGap(double speed) =>
      chickenWidth + speed * hopTicks * 2 + 6;
}

/// A car, truck or log: [start] on the 144-px loop at tick 0, [length] px.
class Mover {
  const Mover(this.start, this.length);
  final double start;
  final int length;
}

class Lane {
  const Lane.grass({required this.index, required this.trees})
    : kind = LaneKind.grass,
      dir = 0,
      speed = 0,
      objects = const [],
      trainPeriod = 0,
      trainOffset = 0;

  const Lane.road({
    required this.index,
    required this.dir,
    required this.speed,
    required this.objects,
  }) : kind = LaneKind.road,
       trees = 0,
       trainPeriod = 0,
       trainOffset = 0;

  const Lane.river({
    required this.index,
    required this.dir,
    required this.speed,
    required this.objects,
  }) : kind = LaneKind.river,
       trees = 0,
       trainPeriod = 0,
       trainOffset = 0;

  const Lane.rail({
    required this.index,
    required this.dir,
    required this.trainPeriod,
    required this.trainOffset,
  }) : kind = LaneKind.rail,
       trees = 0,
       speed = 0,
       objects = const [];

  final int index;
  final LaneKind kind;

  /// Grass: bit c set = tree in column c.
  final int trees;

  /// +1 moves right, −1 moves left.
  final int dir;

  /// px per tick.
  final double speed;
  final List<Mover> objects;
  final int trainPeriod;
  final int trainOffset;

  /// Columns off screen count as blocked.
  bool blocked(int column) =>
      column < 0 ||
      column >= HopRules.columns ||
      (kind == LaneKind.grass && trees & (1 << column) != 0);

  /// Screen x (left edge) and length of each moving object at tick [t].
  Iterable<(double, int)> objectsAt(int t) sync* {
    for (final m in objects) {
      final u = (m.start + dir * speed * t) % HopRules.loop;
      yield (u - HopRules.loopMargin, m.length);
    }
  }

  int _phase(int t) => (t + trainOffset) % trainPeriod;

  /// Rail: the warning light is on during the last 60 ticks before a train.
  bool warning(int t) =>
      kind == LaneKind.rail &&
      _phase(t) >= trainPeriod - HopRules.trainWarnTicks;

  /// Rail: the train's left edge at tick [t], or null when no train is on
  /// screen.
  double? trainX(int t) {
    if (kind != LaneKind.rail) return null;
    final p = _phase(t);
    if (p >= HopRules.trainPassTicks) return null;
    return dir > 0
        ? -HopRules.trainLength + p * HopRules.trainSpeed
        : HopRules.screenWidth - p * HopRules.trainSpeed;
  }

  /// Whether anything dangerous (vehicle, train) overlaps [x0, x1) at [t].
  bool hits(double x0, double x1, int t) {
    if (kind == LaneKind.rail) {
      final tx = trainX(t);
      return tx != null && x0 < tx + HopRules.trainLength && x1 > tx;
    }
    for (final (x, len) in objectsAt(t)) {
      if (x0 < x + len && x1 > x) return true;
    }
    return false;
  }

  /// River: whether screen x [px] is on a log at tick [t].
  bool onLog(double px, int t) {
    for (final (x, len) in objectsAt(t)) {
      if (px >= x && px < x + len) return true;
    }
    return false;
  }

  /// Stable text form (determinism tests).
  String describe() => switch (kind) {
    LaneKind.grass => 'g$index:$trees',
    LaneKind.rail => 't$index:$dir:$trainPeriod:$trainOffset',
    _ =>
      '${kind.name[0]}$index:$dir:${speed.toStringAsFixed(4)}:'
          '${objects.map((m) => '${m.start.toStringAsFixed(2)}/${m.length}').join(',')}',
  };
}
