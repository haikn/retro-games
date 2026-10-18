import 'dart:typed_data';

import 'package:cave_copter/core/cave_generator.dart';
import 'package:cave_copter/core/config.dart';
import 'package:cave_copter/core/simulation.dart';
import 'package:cave_copter/core/world_state.dart';

/// Exhaustive check of whether *any* hold/release sequence survives a seed.
///
/// The cave does not depend on input, and with the default config each tick
/// changes vy by exactly ±15 px/s and y by vy/60 px, so (4·y, vy/15) are
/// integers. The oracle tracks the full set of reachable integer states tick by
/// tick and reports the first tick where it becomes empty (or -1 if the run
/// survives [ticks]).
int firstUnsurvivableTick(
  int seed,
  int ticks, {
  Config config = const Config(),
}) {
  assert(
    config.gravity * config.fixedDt == 15 &&
        config.thrust == 2 * config.gravity,
  );
  final w = config.columnWidth;
  final columns =
      ((ticks * config.scrollPxPerTick + config.worldWidth) / w).ceil() + 2;
  final top = List<double>.filled(columns, 0);
  final bottom = List<double>.filled(columns, 0);
  final oTop = List<double>.filled(columns, 0);
  final oBottom = List<double>.filled(columns, 0);
  final has = List<bool>.filled(columns, false);
  final gen = CaveGenerator(config, seed);
  final ring = ColumnRing(2);
  for (var i = 0; i < columns; i++) {
    gen.next(ring);
    top[i] = ring.topAt(i);
    bottom[i] = ring.bottomAt(i);
    has[i] = ring.hasObstacleAt(i);
    if (has[i]) {
      oTop[i] = ring.obstacleTopAt(i);
      oBottom[i] = ring.obstacleBottomAt(i);
    }
    ring.dropFirst();
  }

  final vMax = (config.maxVerticalSpeed / 15).round();
  final left = config.heliX + config.hitboxInset;
  final right = left + config.hitboxWidth;

  bool crashed(int yq, int scroll) {
    final hTop = yq / 4 + config.hitboxInset;
    final hBottom = hTop + config.hitboxHeight;
    if (hTop <= config.playTop || hBottom >= config.worldHeight) return true;
    final first = ((left + scroll - w) / w).floor();
    final last = ((right + scroll) / w).floor();
    for (var i = first; i <= last; i++) {
      final x = i * w - scroll;
      if (x > right || x + w < left) continue;
      if (hTop <= top[i] || hBottom >= bottom[i]) return true;
      if (has[i] && hTop <= oBottom[i] && hBottom >= oTop[i]) return true;
    }
    return false;
  }

  // State index = yq * vSpan + (v + vMax); yq = 4·y covers the whole screen.
  final vSpan = 2 * vMax + 1;
  final size = (config.worldHeight * 4).round() * vSpan;
  var seen = Uint8List(size);
  var nextSeen = Uint8List(size);
  var active = Int32List(size);
  var nextActive = Int32List(size);
  final start = GameSimulation(seed: seed, config: config).state.heli.y;
  active[0] = (start * 4).round() * vSpan + vMax;
  var count = 1;

  for (var t = 1; t <= ticks; t++) {
    final scroll = t * config.scrollPxPerTick;
    var nextCount = 0;
    for (var a = 0; a < count; a++) {
      final s = active[a];
      seen[s] = 0;
      final yq = s ~/ vSpan;
      final v = s % vSpan - vMax;
      for (final dv in const [-1, 1]) {
        final nv = (v + dv).clamp(-vMax, vMax);
        final ny = yq + nv;
        final ns = ny * vSpan + nv + vMax;
        if (nextSeen[ns] == 1 || crashed(ny, scroll)) continue;
        nextSeen[ns] = 1;
        nextActive[nextCount++] = ns;
      }
    }
    if (nextCount == 0) return t;
    (seen, nextSeen) = (nextSeen, seen);
    (active, nextActive) = (nextActive, active);
    count = nextCount;
  }
  return -1;
}
