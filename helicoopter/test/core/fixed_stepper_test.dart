import 'package:cave_copter/core/rng.dart';
import 'package:cave_copter/core/simulation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hold for 0.5 s, release for 0.5 s, repeating. Boundaries are multiples of
/// 1/30 s, so every tested frame rate samples them identically.
bool timeline(double t) => (t * 2 + 1e-9).floor().isEven;

/// Result of feeding [frames] (each a frame delta in 1/120 s units) to a
/// fresh simulation for up to [seconds] of game time.
({int ticks, int scrollPx, double y, bool crashed}) play(Iterable<int> frames) {
  final sim = GameSimulation(seed: 21);
  final stepper = FixedStepper(sim);
  var units = 0;
  for (final f in frames) {
    stepper.advance(f / 120, timeline(units / 120));
    units += f;
    if (sim.state.crashed) break;
  }
  final s = sim.state;
  return (
    ticks: s.ticks,
    scrollPx: s.scrollPx,
    y: s.heli.y,
    crashed: s.crashed,
  );
}

Iterable<int> steady(int unitsPerFrame, int seconds) =>
    Iterable.generate(seconds * 120 ~/ unitsPerFrame, (_) => unitsPerFrame);

/// Random 1–4 unit frames that never straddle a 0.5 s (60 unit) boundary.
Iterable<int> jittery(int seconds) sync* {
  final rng = Rng(5);
  var t = 0;
  while (t < seconds * 120) {
    final toBoundary = 60 - t % 60;
    final f = 1 + rng.nextInt(4);
    final clipped = f < toBoundary ? f : toBoundary;
    t += clipped;
    yield clipped;
  }
}

void main() {
  test('30, 60, 120 Hz and jittery frames give the identical run', () {
    final at60 = play(steady(2, 30));
    expect(play(steady(4, 30)), at60);
    expect(play(steady(1, 30)), at60);
    expect(play(jittery(30)), at60);
    expect(at60.ticks, greaterThan(0));
  });

  test('a 1 s hitch runs at most 6 ticks and drops the backlog', () {
    final sim = GameSimulation(seed: 1);
    final stepper = FixedStepper(sim);
    stepper.advance(1.0, true);
    expect(stepper.lastSteps, 6);
    expect(sim.state.ticks, 6);
    stepper.advance(1 / 60, true);
    expect(stepper.lastSteps, 1);
  });

  test('alpha is the fraction of a tick left in the accumulator', () {
    final sim = GameSimulation(seed: 1);
    final stepper = FixedStepper(sim);
    stepper.advance(1 / 120, false);
    expect(stepper.lastSteps, 0);
    expect(stepper.alpha, closeTo(0.5, 1e-9));
    stepper.advance(1 / 120, false);
    expect(stepper.lastSteps, 1);
    expect(stepper.alpha, closeTo(0, 1e-6));
  });

  test('negative frame deltas are ignored', () {
    final sim = GameSimulation(seed: 1);
    final stepper = FixedStepper(sim);
    stepper.advance(-1, true);
    expect(sim.state.ticks, 0);
  });

  test('reports the crash and stops stepping', () {
    final sim = GameSimulation(seed: 1);
    final stepper = FixedStepper(sim);
    var event = SimEvent.none;
    for (var i = 0; i < 2000 && event == SimEvent.none; i++) {
      event = stepper.advance(0.1, false);
    }
    expect(event, SimEvent.crashed);
    final ticks = sim.state.ticks;
    stepper.advance(0.1, false);
    expect(sim.state.ticks, ticks);
  });
}
