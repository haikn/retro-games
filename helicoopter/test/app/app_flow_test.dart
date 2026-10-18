import 'package:cave_copter/app/app_flow.dart';
import 'package:cave_copter/game/helicopter_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HelicopterGame game;
  late AppFlow flow;
  var exits = 0;
  var online = 0;

  setUp(() {
    exits = 0;
    online = 0;
    game = HelicopterGame(seedSource: () => 1);
    flow = AppFlow(
      game: game,
      onExit: () => exits++,
      onOnlineScores: () => online++,
    );
  });

  test('cold start shows the title; a tap opens the main menu', () {
    expect(flow.screen, AppScreen.title);
    flow.start();
    expect(flow.screen, AppScreen.menu);
  });

  test('New game starts a fresh run in Ready', () {
    flow.start();
    flow.newGame();
    expect(flow.screen, AppScreen.game);
    expect(game.phase.value, GamePhase.ready);
    expect(game.sim.state.ticks, 0);
  });

  test('menu items open their screens and Back returns to the menu', () {
    flow.start();
    flow.openTopScore();
    expect(flow.screen, AppScreen.topScore);
    expect(flow.back(), isTrue);
    expect(flow.screen, AppScreen.menu);
    flow.openInstructions();
    expect(flow.screen, AppScreen.instructions);
    flow.back();
    expect(flow.screen, AppScreen.menu);
  });

  test('back on the title or main menu exits the app', () {
    expect(flow.back(), isFalse);
    expect(exits, 1);
    flow.start();
    expect(flow.back(), isFalse);
    expect(exits, 2);
  });

  test('back while playing pauses; back while paused continues via Ready', () {
    flow.start();
    flow.newGame();
    game.pointerDown();
    expect(game.phase.value, GamePhase.playing);

    expect(flow.back(), isTrue);
    expect(game.phase.value, GamePhase.paused);
    expect(game.holding, isFalse);

    expect(flow.back(), isTrue);
    expect(game.phase.value, GamePhase.ready);
    expect(flow.screen, AppScreen.game);
  });

  test('Continue keeps the run; New game from pause starts a new one', () {
    flow.start();
    flow.newGame();
    game.pointerDown();
    game.sim.step(true);
    game.pause();
    flow.continueRun();
    expect(game.phase.value, GamePhase.ready);
    expect(game.sim.state.ticks, 1);

    game.pointerDown();
    game.pause();
    flow.newGame();
    expect(game.sim.state.ticks, 0);
  });

  test('back in Ready or after a crash returns to the menu', () {
    flow.start();
    flow.newGame();
    expect(flow.back(), isTrue);
    expect(flow.screen, AppScreen.menu);

    flow.newGame();
    game.phase.value = GamePhase.crashed;
    flow.back();
    expect(flow.screen, AppScreen.menu);
  });

  test('backgrounding pauses only a run in progress', () {
    flow.start();
    flow.appBackgrounded();
    expect(flow.screen, AppScreen.menu);

    flow.newGame();
    game.pointerDown();
    flow.appBackgrounded();
    expect(game.phase.value, GamePhase.paused);
    expect(game.holding, isFalse);
  });

  test('sound toggle notifies listeners', () {
    var notified = 0;
    flow.addListener(() => notified++);
    expect(flow.soundOn, isTrue);
    flow.toggleSound();
    expect(flow.soundOn, isFalse);
    expect(notified, 1);
  });

  test('online scores are delegated', () {
    flow.showOnlineScores();
    expect(online, 1);
  });

  test('changing screens forgets held pointers', () {
    flow.start();
    flow.newGame();
    game.pointerDown();
    flow.openMenu();
    expect(game.holding, isFalse);
  });

  test('sound changes and key clicks are reported', () {
    final sounds = <bool>[];
    var clicks = 0;
    final f = AppFlow(
      game: game,
      soundOn: false,
      onSoundChanged: sounds.add,
      onKeyClick: () => clicks++,
    );
    expect(f.soundOn, isFalse);
    f.start();
    expect(clicks, 1);
    f.toggleSound(); // turning sound on clicks
    f.toggleSound(); // turning it off is silent
    expect(sounds, [true, false]);
    expect(clicks, 2);
  });
}
