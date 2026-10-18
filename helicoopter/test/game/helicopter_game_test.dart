import 'package:cave_copter/game/helicopter_game.dart';
import 'package:cave_copter/game/render/effects.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  HelicopterGame build() => HelicopterGame(seedSource: () => 1);
  const tick = 1 / 60;

  void crash(HelicopterGame game) {
    for (var i = 0; i < 2000 && game.phase.value == GamePhase.playing; i++) {
      game.update(tick);
    }
    expect(game.phase.value, GamePhase.crashed);
  }

  void runTicks(HelicopterGame game, int n) {
    for (var i = 0; i < n; i++) {
      game.update(tick);
    }
  }

  testWithGame<HelicopterGame>('starts ready and the world is frozen', build, (
    game,
  ) async {
    expect(game.phase.value, GamePhase.ready);
    runTicks(game, 30);
    expect(game.sim.state.ticks, 0);
  });

  testWithGame<HelicopterGame>(
    'first press starts the run and already counts as thrust',
    build,
    (game) async {
      game.pointerDown();
      expect(game.phase.value, GamePhase.playing);
      expect(game.holding, isTrue);
      runTicks(game, 1);
      expect(game.sim.state.heli.vy, lessThan(0));
    },
  );

  testWithGame<HelicopterGame>(
    'multi-touch holds until the last finger lifts',
    build,
    (game) async {
      game.pointerDown();
      game.pointerDown();
      game.pointerUp();
      expect(game.holding, isTrue);
      game.pointerUp();
      expect(game.holding, isFalse);
      game.pointerUp(); // extra up never goes negative
      game.pointerDown();
      expect(game.holding, isTrue);
    },
  );

  testWithGame<HelicopterGame>('releasing forever crashes', build, (
    game,
  ) async {
    game.pointerDown();
    game.pointerUp();
    crash(game);
    expect(game.effects.crashed, isTrue);
  });

  testWithGame<HelicopterGame>(
    'a finger held since the crash never restarts',
    build,
    (game) async {
      game.pointerDown(); // held through the crash
      crash(game);
      runTicks(game, 120);
      expect(game.phase.value, GamePhase.crashed);
    },
  );

  testWithGame<HelicopterGame>(
    'a new press restarts only once 600 ms have passed',
    build,
    (game) async {
      game.pointerDown();
      game.pointerUp();
      crash(game);

      runTicks(game, Effects.restartTicks - 1);
      game.pointerDown();
      game.pointerUp();
      expect(game.phase.value, GamePhase.crashed);

      runTicks(game, 1);
      game.pointerDown();
      expect(game.phase.value, GamePhase.playing);
      expect(game.sim.state.ticks, 0);
      expect(game.effects.crashed, isFalse);
    },
  );

  testWithGame<HelicopterGame>('renders the frame into the LCD buffer', build, (
    game,
  ) async {
    runTicks(game, 1);
    expect(game.buffer.litCount, greaterThan(160)); // rule + cave + heli
    expect(game.buffer.isLit(0, 8), isTrue);
  });

  testWithGame<HelicopterGame>('crash inverts the screen briefly', build, (
    game,
  ) async {
    game.pointerDown();
    game.pointerUp();
    crash(game);
    expect(game.buffer.inverted, isTrue);
    runTicks(game, 30);
    expect(game.buffer.inverted, isFalse);
  });
}
