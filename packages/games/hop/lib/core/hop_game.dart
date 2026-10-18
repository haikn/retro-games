import 'dart:math' as math;

import 'generator.dart';
import 'lanes.dart';

enum HopMove { forward, back, left, right }

/// One run of Hop, advanced in fixed 60 Hz ticks. Pure Dart.
class HopGame {
  HopGame({required int seed})
    : _gen = LaneGenerator(seed),
      _source = null,
      _lanes = [];

  /// A world whose lanes come from [lanes] (tests).
  HopGame.debug(Lane Function(int index) lanes)
    : _gen = null,
      _source = lanes,
      _lanes = [];

  HopGame._copy(HopGame o)
    : _gen = o._gen,
      _source = o._source,
      _lanes = o._lanes {
    lane = o.lane;
    x = o.x;
    camera = o.camera;
    ticks = o.ticks;
    over = o.over;
    _maxLane = o._maxLane;
    _started = o._started;
    _hopLeft = o._hopLeft;
    _fromLane = o._fromLane;
    _toLane = o._toLane;
    _fromX = o._fromX;
    _toX = o._toX;
    _queued = o._queued;
  }

  /// An independent copy of this run's state (lanes are shared; they are
  /// immutable and generated in order). For look-ahead in tests and bots.
  HopGame copy() => HopGame._copy(this);

  final LaneGenerator? _gen;
  final Lane Function(int index)? _source;
  final List<Lane> _lanes;
  final _events = <String>[];

  int lane = HopRules.startLane;
  double x = (HopRules.startColumn * HopRules.columnWidth).toDouble();

  /// Bottom of the view, in lanes (fractional while scrolling).
  double camera = 0;
  int ticks = 0;
  bool over = false;
  int _maxLane = HopRules.startLane;
  bool _started = false;

  int _hopLeft = 0;
  int _fromLane = 0;
  int _toLane = 0;
  double _fromX = 0;
  double _toX = 0;
  HopMove? _queued;

  bool get hopping => _hopLeft > 0;
  int get score => _maxLane - HopRules.startLane;

  /// 0 at the start of a hop, 1 at landing.
  double get hopProgress => hopping ? 1 - _hopLeft / HopRules.hopTicks : 0;

  /// Lane used for collisions: the start lane during the first half of a
  /// hop, the target lane during the second half.
  int get effectiveLane => hopping
      ? (_hopLeft > HopRules.hopTicks ~/ 2 ? _fromLane : _toLane)
      : lane;

  /// Drawn lane position (fractional mid-hop).
  double get drawLane => hopping
      ? _fromLane + (_toLane - _fromLane) * hopProgress
      : lane.toDouble();

  double get drawX => hopping ? _fromX + (_toX - _fromX) * hopProgress : x;

  Lane laneAt(int i) {
    final source = _source;
    if (source != null) return source(i);
    if (i < 0) return Lane.grass(index: i, trees: 0);
    while (_lanes.length <= i) {
      _lanes.add(_gen!.next());
    }
    return _lanes[i];
  }

  /// Event names since the last call: `hop`, `splash`, `crash`, `bell`.
  List<String> takeEvents() {
    final e = List.of(_events);
    _events.clear();
    return e;
  }

  /// Requests a hop; one move is buffered while a hop is in progress.
  void move(HopMove m) {
    if (over) return;
    if (hopping) {
      _queued ??= m;
      return;
    }
    _tryHop(m);
  }

  void _tryHop(HopMove m) {
    const w = HopRules.columnWidth;
    var toLane = lane;
    var toX = x;
    switch (m) {
      case HopMove.forward:
        toLane++;
      case HopMove.back:
        toLane--;
      case HopMove.left:
        toX -= w;
      case HopMove.right:
        toX += w;
    }
    final maxX = (HopRules.screenWidth - HopRules.chickenWidth).toDouble();
    if (toX < -0.5 || toX > maxX + 0.5) return;
    final target = laneAt(toLane);
    if (target.kind != LaneKind.river) {
      toX = ((toX / w).round() * w).toDouble().clamp(0, maxX);
    }
    if (target.kind == LaneKind.grass && target.blocked((toX / w).round())) {
      return;
    }
    _fromLane = lane;
    _fromX = x;
    _toLane = toLane;
    _toX = toX;
    _hopLeft = HopRules.hopTicks;
    _started = true;
    _events.add('hop');
  }

  void _die(String event) {
    over = true;
    _events.add(event);
  }

  void tick() {
    if (over) return;
    ticks++;

    if (hopping && --_hopLeft == 0) {
      lane = _toLane;
      x = _toX;
      final here = laneAt(lane);
      if (here.kind == LaneKind.river &&
          !here.onLog(x + HopRules.chickenWidth / 2, ticks)) {
        _die('splash');
        return;
      }
    }
    if (!hopping && _queued != null) {
      final m = _queued!;
      _queued = null;
      _tryHop(m);
    }

    final here = laneAt(lane);
    if (!hopping && here.kind == LaneKind.river) {
      x += here.dir * here.speed;
      final center = x + HopRules.chickenWidth / 2;
      if (center < 0 || center > HopRules.screenWidth) {
        _die('splash');
        return;
      }
    }

    final eff = laneAt(effectiveLane);
    final ex = drawX;
    if ((eff.kind == LaneKind.road || eff.kind == LaneKind.rail) &&
        eff.hits(ex + 1, ex + HopRules.chickenWidth - 1, ticks)) {
      _die('crash');
      return;
    }

    _ringBells();
    _moveCamera();
    if (effectiveLane + 0.5 < camera) {
      _die('crash');
      return;
    }
    _maxLane = math.max(_maxLane, lane);
  }

  void _ringBells() {
    final first = camera.floor();
    for (var i = first; i <= first + HopRules.visibleLanes; i++) {
      final l = laneAt(i);
      if (l.kind == LaneKind.rail &&
          l.warning(ticks) &&
          !l.warning(ticks - 1)) {
        _events.add('bell');
      }
    }
  }

  void _moveCamera() {
    if (_started) {
      final d = math.min(1.0, score / 300);
      camera += 0.004 + 0.008 * d;
    }
    final target = effectiveLane - 4.0;
    if (target > camera) camera += (target - camera) * 0.15;
  }
}
