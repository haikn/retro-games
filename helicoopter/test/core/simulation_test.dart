import 'package:cave_copter/core/collision.dart';
import 'package:cave_copter/core/config.dart';
import 'package:cave_copter/core/simulation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = Config();

  void expectCoversScreen(GameSimulation sim) {
    final ring = sim.state.columns;
    final w = config.columnWidth;
    expect(ring.firstIndex * w - sim.state.scrollPx, lessThanOrEqualTo(0));
    expect(
      (ring.lastIndex + 1) * w - sim.state.scrollPx,
      greaterThanOrEqualTo(config.worldWidth),
    );
  }

  SimEvent runUntilCrash(
    GameSimulation sim,
    bool Function(int tick) holding, {
    int maxTicks = 20000,
  }) {
    var event = SimEvent.none;
    for (var t = 0; t < maxTicks && event == SimEvent.none; t++) {
      event = sim.step(holding(t));
    }
    return event;
  }

  test('starts alive with the helicopter inside the gap', () {
    final sim = GameSimulation(seed: 1);
    expect(sim.state.crashed, isFalse);
    expect(sim.state.distance, 0);
    expect(collides(sim.state, config), isFalse);
    expectCoversScreen(sim);
  });

  test('scrolls exactly 5 px per tick; distance is px / 10', () {
    final sim = GameSimulation(seed: 1);
    sim.step(true);
    expect(sim.state.scrollPx, 5);
    expect(sim.state.ticks, 1);
    sim.step(false);
    expect(sim.state.distance, 1);
  });

  test('stores the previous y for interpolation', () {
    final sim = GameSimulation(seed: 1);
    final y0 = sim.state.heli.y;
    sim.step(false);
    expect(sim.state.heli.prevY, y0);
    expect(sim.state.heli.y, greaterThan(y0));
  });

  test('columns keep covering the screen while scrolling', () {
    final sim = GameSimulation(seed: 4);
    // Hover: alternate thrust to stay roughly level for a while.
    for (var t = 0; t < 400 && !sim.state.crashed; t++) {
      sim.step(t % 2 == 0);
      if (!sim.state.crashed) expectCoversScreen(sim);
    }
  });

  test('holding forever crashes into the ceiling', () {
    final sim = GameSimulation(seed: 2);
    expect(runUntilCrash(sim, (_) => true), SimEvent.crashed);
    expect(sim.state.heli.vy, lessThan(0));
  });

  test('releasing forever crashes into the floor', () {
    final sim = GameSimulation(seed: 2);
    expect(runUntilCrash(sim, (_) => false), SimEvent.crashed);
    expect(sim.state.heli.vy, greaterThan(0));
  });

  test('a crashed run is frozen', () {
    final sim = GameSimulation(seed: 3);
    runUntilCrash(sim, (_) => false);
    final ticks = sim.state.ticks;
    final y = sim.state.heli.y;
    expect(sim.step(true), SimEvent.crashed);
    expect(sim.state.ticks, ticks);
    expect(sim.state.heli.y, y);
  });

  test('same seed and inputs give the same run', () {
    bool pattern(int t) => (t ~/ 20).isEven;
    final a = GameSimulation(seed: 9);
    final b = GameSimulation(seed: 9);
    runUntilCrash(a, pattern);
    runUntilCrash(b, pattern);
    expect(a.state.ticks, b.state.ticks);
    expect(a.state.heli.y, b.state.heli.y);
  });

  test('invalid config is rejected', () {
    expect(
      () => GameSimulation(seed: 1, config: const Config(scrollSpeed: 900)),
      throwsStateError,
    );
  });
}
