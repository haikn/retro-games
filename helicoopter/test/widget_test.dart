import 'package:cave_copter/game/helicopter_game.dart';
import 'package:cave_copter/main.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to the title, then title → menu → play', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late HelicopterGame game;
    await tester.pumpWidget(
      CaveCopterApp(
        gameFactory: () => game = HelicopterGame(seedSource: () => 1),
      ),
    );
    await tester.pump();
    expect(find.byType(GameWidget<HelicopterGame>), findsOneWidget);
    expect(find.text('CAVE COPTER'), findsOneWidget);

    await tester.tapAt(const Offset(400, 200));
    await tester.pump();
    await tester.tap(find.text('New game'));
    await tester.pump();
    expect(game.phase.value, GamePhase.ready);

    final gesture = await tester.startGesture(const Offset(400, 120));
    await tester.pump();
    expect(game.phase.value, GamePhase.playing);
    expect(game.holding, isTrue);

    await gesture.cancel(); // system gesture steals the pointer
    await tester.pump();
    expect(game.holding, isFalse);
  });
}
