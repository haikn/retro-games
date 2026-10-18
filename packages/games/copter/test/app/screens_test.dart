import 'package:copter/app/app_flow.dart';
import 'package:copter/app/game_screen.dart';
import 'package:copter/game/helicopter_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Logical surface of exactly 800×400, so virtual px = logical px.
Future<(AppFlow, HelicopterGame)> pumpApp(
  WidgetTester tester, {
  Future<String?> Function()? onOnlineScores,
}) async {
  tester.view.physicalSize = const Size(1600, 800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final game = HelicopterGame(seedSource: () => 1);
  var exits = 0;
  final flow = AppFlow(
    game: game,
    onExit: () => exits++,
    onOnlineScores: onOnlineScores,
  );
  await tester.pumpWidget(MaterialApp(home: GameScreen(flow: flow)));
  await tester.pump();
  await tester.pump();
  return (flow, game);
}

void crashAndWait(HelicopterGame game) {
  game.pointerDown();
  game.pointerUp();
  for (var i = 0; i < 3000 && game.phase.value == GamePhase.playing; i++) {
    game.update(1 / 60);
  }
  for (var i = 0; i < 45; i++) {
    game.update(1 / 60);
  }
}

void main() {
  testWidgets('title → tap anywhere → main menu', (tester) async {
    final (flow, _) = await pumpApp(tester);
    expect(find.text('CAVE COPTER'), findsOneWidget);
    expect(find.text('Tap to start'), findsOneWidget);

    await tester.tapAt(const Offset(700, 50));
    await tester.pump();
    expect(flow.screen, AppScreen.menu);
    expect(find.text('Copter'), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
    for (final item in [
      'New game',
      'Top score',
      'Sound: On',
      'Instructions',
      'All games',
    ]) {
      expect(find.text(item), findsOneWidget);
    }
  });

  testWidgets('menu taps never reach the game', (tester) async {
    final (flow, game) = await pumpApp(tester);
    flow.start();
    await tester.pump();
    await tester.tapAt(const Offset(400, 320)); // empty menu area
    await tester.pump();
    expect(game.holding, isFalse);
    expect(game.phase.value, GamePhase.ready);
    expect(flow.screen, AppScreen.menu);
  });

  testWidgets('Sound row toggles its label', (tester) async {
    final (flow, _) = await pumpApp(tester);
    flow.start();
    await tester.pump();
    await tester.tap(find.text('Sound: On'));
    await tester.pump();
    expect(find.text('Sound: Off'), findsOneWidget);
    expect(find.text('3/5'), findsOneWidget); // selection followed the tap
    expect(flow.soundOn, isFalse);
  });

  testWidgets('Select soft key activates the selected row', (tester) async {
    final (flow, _) = await pumpApp(tester);
    flow.start();
    await tester.pump();
    await tester.tap(find.text('Select'));
    await tester.pump();
    expect(flow.screen, AppScreen.game); // New game is selected by default
  });

  testWidgets('Top score shows the best and returns with Back', (tester) async {
    final (flow, game) = await pumpApp(tester);
    game.best = 482;
    flow.start();
    await tester.pump();
    await tester.tap(find.text('Top score'));
    await tester.pump();
    expect(find.text('Top score:'), findsOneWidget);
    expect(find.text('00482'), findsOneWidget);
    expect(find.text('On this phone'), findsOneWidget);
    expect(find.text('Online scores'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(flow.screen, AppScreen.menu);
  });

  testWidgets('Instructions show and scroll', (tester) async {
    final (flow, _) = await pumpApp(tester);
    flow.start();
    await tester.pump();
    await tester.tap(find.text('Instructions'));
    await tester.pump();
    expect(find.textContaining('Hold anywhere'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(flow.screen, AppScreen.menu);
  });

  testWidgets('Ready: Menu soft key does not start the run', (tester) async {
    final (flow, game) = await pumpApp(tester);
    flow.start();
    flow.newGame();
    await tester.pump();
    expect(find.text('Hold to fly'), findsOneWidget);
    await tester.tap(find.text('Menu'));
    await tester.pump();
    expect(flow.screen, AppScreen.menu);
    expect(game.phase.value, GamePhase.ready);
    expect(game.holding, isFalse);
  });

  testWidgets('Ready: pressing the play area starts flying', (tester) async {
    final (flow, game) = await pumpApp(tester);
    flow.start();
    flow.newGame();
    await tester.pump();
    final g = await tester.startGesture(const Offset(400, 120));
    await tester.pump();
    expect(game.phase.value, GamePhase.playing);
    expect(game.holding, isTrue);
    expect(find.text('Hold to fly'), findsNothing);
    await g.up();
  });

  testWidgets('game over dialog, then Menu', (tester) async {
    final (flow, game) = await pumpApp(tester);
    flow.start();
    flow.newGame();
    await tester.pump();
    crashAndWait(game);
    await tester.pump();
    expect(find.text('Game over!'), findsOneWidget);
    expect(find.text('New best!'), findsOneWidget);
    expect(find.text('Tap to play'), findsOneWidget);
    await tester.tap(find.text('Menu'));
    await tester.pump();
    expect(flow.screen, AppScreen.menu);
  });

  testWidgets('game over: tapping the dialog restarts the run', (tester) async {
    final (flow, game) = await pumpApp(tester);
    flow.start();
    flow.newGame();
    await tester.pump();
    crashAndWait(game);
    await tester.pump();
    await tester.tapAt(const Offset(400, 200)); // on the dialog text
    await tester.pump();
    expect(game.phase.value, GamePhase.playing);
    expect(game.sim.state.ticks, 0);
  });

  testWidgets('second run without a new best shows Best', (tester) async {
    final (flow, game) = await pumpApp(tester);
    flow.start();
    flow.newGame();
    game.best = 99999;
    await tester.pump();
    crashAndWait(game);
    await tester.pump();
    expect(find.text('Best 99999'), findsOneWidget);
    expect(find.text('New best!'), findsNothing);
  });

  testWidgets('back while playing opens the pause menu; Continue → Ready', (
    tester,
  ) async {
    final (flow, game) = await pumpApp(tester);
    flow.start();
    flow.newGame();
    game.pointerDown();
    game.pointerUp();
    for (var i = 0; i < 20; i++) {
      game.update(1 / 60);
    }
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(game.phase.value, GamePhase.paused);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('00010'), findsOneWidget); // 20 ticks × 5 px / 10

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(game.phase.value, GamePhase.ready);
    expect(find.text('Hold to fly'), findsOneWidget);
    expect(game.sim.state.ticks, 20);
  });

  testWidgets('app going to the background pauses the run', (tester) async {
    final (flow, game) = await pumpApp(tester);
    flow.start();
    flow.newGame();
    game.pointerDown();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(game.phase.value, GamePhase.paused);
    expect(game.holding, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('Online scores failure shows a short notice', (tester) async {
    final (flow, _) = await pumpApp(
      tester,
      onOnlineScores: () async => 'Sign-in failed',
    );
    flow.start();
    flow.openTopScore();
    await tester.pump();
    expect(find.text('On this phone'), findsOneWidget);
    await tester.tap(find.text('Online scores'));
    await tester.pump();
    expect(find.text('Sign-in failed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('On this phone'), findsOneWidget);
  });

  testWidgets('All games leaves Copter', (tester) async {
    final (flow, _) = await pumpApp(tester);
    var left = false;
    final f = AppFlow(
      game: flow.game,
      initialScreen: AppScreen.menu,
      onExit: () => left = true,
    );
    await tester.pumpWidget(MaterialApp(home: GameScreen(flow: f)));
    await tester.pump();
    await tester.tap(find.text('All games'));
    await tester.pump();
    expect(left, isTrue);
  });
}
