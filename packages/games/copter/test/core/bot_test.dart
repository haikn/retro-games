import 'package:copter/core/config.dart';
import 'package:copter/core/simulation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simple look-ahead pilot. It scans ahead from the hitbox, narrowing a
/// corridor by the cave walls; at the first obstacle within ~250 px it narrows
/// the corridor to the window nearest the helicopter and stops scanning.
/// Without an obstacle it looks 120 px ahead. It then steers to the corridor's
/// middle. If the generator's reachable-band model matched real physics badly,
/// a pilot like this would crash early.
bool pilot(GameSimulation sim) {
  final c = sim.config;
  final s = sim.state;
  final ring = s.columns;
  final hitboxTop = s.heli.y + c.hitboxInset;
  final hitboxMid = hitboxTop + c.hitboxHeight / 2;
  final front = c.heliX + c.hitboxInset;
  int col(double screenX) => ((screenX + s.scrollPx) / c.columnWidth)
      .floor()
      .clamp(ring.firstIndex, ring.lastIndex);

  var lo = double.negativeInfinity;
  var hi = double.infinity;
  final wallsEnd = col(front + c.hitboxWidth + 120);
  for (var i = col(front); i <= col(front + c.hitboxWidth + 250); i++) {
    final top = ring.topAt(i);
    final bottom = ring.bottomAt(i);
    if (ring.hasObstacleAt(i)) {
      final oTop = ring.obstacleTopAt(i);
      final oBottom = ring.obstacleBottomAt(i);
      final aboveFits = oTop - top >= c.minPassableHeight;
      final belowFits = bottom - oBottom >= c.minPassableHeight;
      final useAbove = aboveFits && belowFits
          ? ((top + oTop) / 2 - hitboxMid).abs() <=
                ((oBottom + bottom) / 2 - hitboxMid).abs()
          : aboveFits;
      final wLo = useAbove ? top : oBottom;
      final wHi = useAbove ? oTop : bottom;
      lo = lo > wLo ? lo : wLo;
      hi = hi < wHi ? hi : wHi;
      if (hi - lo < c.hitboxHeight + 10) {
        lo = wLo; // walls before the block disagree: trust the window
        hi = wHi;
      }
      break;
    }
    if (i > wallsEnd) continue;
    if (top > lo) lo = top;
    if (bottom < hi) hi = bottom;
  }
  final half = c.hitboxHeight / 2 + 15;
  var target = (lo + hi) / 2;
  if (hi - lo > 2 * half) target = target.clamp(lo + half, hi - half);
  final targetTop = target - c.hitboxHeight / 2;
  // Where the hitbox would stop if it braked now (net 900 px/s² both ways),
  // plus one tick of reaction.
  final vy = s.heli.vy;
  final predicted =
      hitboxTop + vy * c.fixedDt + vy * vy.abs() / (2 * c.gravity);
  return predicted > targetTop;
}

void main() {
  // The pilot is a heuristic, so this is a smoke check that the band model
  // and real physics agree; the exact guarantee is in passability_oracle_test.
  test(
    'look-ahead pilot reaches distance 5 000 on at least 85 of 100 seeds',
    () {
      const goal = 5000;
      final failures = <String>[];
      for (var seed = 1; seed <= 100; seed++) {
        final sim = GameSimulation(seed: seed, config: const Config());
        while (!sim.state.crashed && sim.state.distance < goal) {
          sim.step(pilot(sim));
        }
        if (sim.state.crashed) {
          failures.add('seed $seed crashed at ${sim.state.distance}');
        }
      }
      expect(
        failures.length,
        lessThanOrEqualTo(15),
        reason: failures.join('\n'),
      );
    },
  );
}
