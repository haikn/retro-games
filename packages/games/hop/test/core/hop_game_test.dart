import 'package:flutter_test/flutter_test.dart';
import 'package:hop/core/hop_game.dart';
import 'package:hop/core/lanes.dart';

void main() {
  /// A world of empty grass except for [special] lanes.
  HopGame world(Map<int, Lane> special) =>
      HopGame.debug((i) => special[i] ?? Lane.grass(index: i, trees: 0));

  void ticks(HopGame g, int n) {
    for (var i = 0; i < n; i++) {
      g.tick();
    }
  }

  test('starts on lane 2, column 4, score 0', () {
    final g = HopGame(seed: 1);
    expect(g.lane, 2);
    expect(g.x, 32);
    expect(g.score, 0);
    expect(g.over, isFalse);
  });

  test('a hop forward takes 8 ticks and scores', () {
    final g = world({});
    g.move(HopMove.forward);
    ticks(g, 7);
    expect(g.lane, 2);
    expect(g.hopping, isTrue);
    g.tick();
    expect(g.lane, 3);
    expect(g.hopping, isFalse);
    expect(g.score, 1);
    expect(g.takeEvents(), ['hop']);
  });

  test('sideways hops move one column and stop at the edges', () {
    final g = world({});
    g.move(HopMove.left);
    ticks(g, 8);
    expect(g.x, 24);
    for (var i = 0; i < 6; i++) {
      g.move(HopMove.left);
      ticks(g, 8);
    }
    expect(g.x, 0);
  });

  test('trees block hops', () {
    final g = world({3: Lane.grass(index: 3, trees: 1 << 4)});
    g.move(HopMove.forward);
    ticks(g, 8);
    expect(g.lane, 2);
  });

  test('one move is buffered during a hop', () {
    final g = world({});
    g.move(HopMove.forward);
    ticks(g, 3);
    g.move(HopMove.forward);
    g.move(HopMove.forward); // ignored: buffer holds one
    ticks(g, 20);
    expect(g.lane, 4);
  });

  test('a car hit ends the run', () {
    // A stationary car covering columns 3–5 on lane 3.
    final g = world({
      3: const Lane.road(index: 3, dir: 1, speed: 0, objects: [Mover(56, 12)]),
    });
    g.move(HopMove.forward);
    ticks(g, 8);
    expect(g.over, isTrue);
    expect(g.takeEvents(), contains('crash'));
  });

  test('landing in water drowns; landing on a log is carried', () {
    final drown = world({
      3: const Lane.river(index: 3, dir: 1, speed: 0, objects: [Mover(32, 16)]),
    });
    drown.move(HopMove.forward); // x 32..40, log at 0..16
    ticks(drown, 8);
    expect(drown.over, isTrue);
    expect(drown.takeEvents(), contains('splash'));

    final ride = world({
      3: const Lane.river(
        index: 3,
        dir: 1,
        speed: 0.5,
        objects: [Mover(60, 24)],
      ),
    });
    // Log at screen 28..52 at tick 0, moving right 0.5 px/tick.
    ride.move(HopMove.forward);
    ticks(ride, 8);
    expect(ride.over, isFalse);
    final x = ride.x;
    ticks(ride, 10);
    expect(ride.x, closeTo(x + 5, 1e-9));
  });

  test('a log carrying the chicken off screen drowns it', () {
    final g = world({
      3: const Lane.river(index: 3, dir: 1, speed: 1, objects: [Mover(60, 24)]),
    });
    g.move(HopMove.forward);
    ticks(g, 120);
    expect(g.over, isTrue);
  });

  test('trains hit, and a warning bell rings first', () {
    final g = world({
      3: const Lane.rail(index: 3, dir: 1, trainPeriod: 300, trainOffset: 50),
    });
    g.move(HopMove.forward);
    ticks(g, 8);
    expect(g.over, isFalse);
    final events = <String>[];
    for (var i = 0; i < 400 && !g.over; i++) {
      g.tick();
      events.addAll(g.takeEvents());
    }
    expect(events, contains('bell'));
    expect(g.over, isTrue);
  });

  test('the screen edge waits for the first move, then catches idlers', () {
    final idle = world({});
    ticks(idle, 3000);
    expect(idle.over, isFalse);

    final g = world({});
    g.move(HopMove.forward);
    ticks(g, 8);
    for (var i = 0; i < 6000 && !g.over; i++) {
      g.tick();
    }
    expect(g.over, isTrue);
    expect(g.takeEvents(), contains('crash'));
  });

  test('the camera follows the chicken up', () {
    final g = world({});
    for (var i = 0; i < 12; i++) {
      g.move(HopMove.forward);
      ticks(g, 8);
    }
    ticks(g, 60);
    expect(g.lane - g.camera, inInclusiveRange(3.0, 5.5));
  });

  test('score is the furthest lane reached', () {
    final g = world({});
    g.move(HopMove.forward);
    ticks(g, 8);
    g.move(HopMove.forward);
    ticks(g, 8);
    g.move(HopMove.back);
    ticks(g, 8);
    expect(g.score, 2);
  });

  test('same seed and moves give the same run', () {
    (int, double, bool) run(int seed) {
      final g = HopGame(seed: seed);
      for (var i = 0; i < 600; i++) {
        if (i % 20 == 0) g.move(HopMove.values[(i ~/ 20) % 3 == 0 ? 2 : 0]);
        g.tick();
      }
      return (g.lane, g.x, g.over);
    }

    expect(run(8), run(8));
  });
}
