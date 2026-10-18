import 'cave_generator.dart';
import 'collision.dart';
import 'config.dart';
import 'physics.dart';
import 'world_state.dart';

enum SimEvent { none, crashed }

/// One run of the game, advanced one fixed tick at a time.
class GameSimulation {
  GameSimulation({required int seed, this.config = const Config()}) {
    config.assertInvariants();
    generator = CaveGenerator(config, seed);
    state = WorldState(config, heliY: 0);
    _fill();
    final ring = state.columns;
    final column = ((config.heliX + config.heliWidth / 2) / config.columnWidth)
        .floor();
    final mid = (ring.topAt(column) + ring.bottomAt(column)) / 2;
    state.heli
      ..y = mid - config.heliHeight / 2
      ..prevY = state.heli.y;
  }

  final Config config;
  late final CaveGenerator generator;
  late final WorldState state;

  /// Advances exactly one tick (per the spec's per-tick data flow).
  SimEvent step(bool holding) {
    if (state.crashed) return SimEvent.crashed;
    final heli = state.heli;
    heli.prevY = heli.y;
    stepVertical(heli, holding: holding, config: config);

    state.ticks++;
    state.scrollPx += config.scrollPxPerTick;
    _recycle();
    _fill();

    if (collides(state, config)) {
      state.crashed = true;
      return SimEvent.crashed;
    }
    return SimEvent.none;
  }

  void _recycle() {
    final ring = state.columns;
    while (ring.length > 0 &&
        (ring.firstIndex + 1) * config.columnWidth <= state.scrollPx) {
      ring.dropFirst();
    }
  }

  void _fill() {
    final ring = state.columns;
    while (ring.nextIndex * config.columnWidth <
        state.scrollPx + config.worldWidth) {
      generator.next(ring);
    }
  }
}

/// Fixed-timestep accumulator: identical simulation at any frame rate.
class FixedStepper {
  FixedStepper(this.sim);

  final GameSimulation sim;
  double _accumulator = 0;

  /// Render interpolation factor in [0, 1).
  double alpha = 0;

  /// Ticks run by the latest [advance] (debug overlay).
  int lastSteps = 0;

  SimEvent advance(double frameDt, bool holding) {
    final c = sim.config;
    const eps = 1e-9;
    _accumulator += frameDt.clamp(0, c.maxFrameDt);
    var steps = 0;
    var event = SimEvent.none;
    while (_accumulator >= c.fixedDt - eps && steps < c.maxStepsPerFrame) {
      _accumulator -= c.fixedDt;
      steps++;
      if (sim.step(holding) == SimEvent.crashed) {
        event = SimEvent.crashed;
        _accumulator = 0;
        break;
      }
    }
    if (_accumulator >= c.fixedDt - eps) _accumulator = 0;
    if (_accumulator < 0) _accumulator = 0;
    lastSteps = steps;
    alpha = _accumulator / c.fixedDt;
    return event;
  }

  void reset() {
    _accumulator = 0;
    alpha = 0;
    lastSteps = 0;
  }
}
