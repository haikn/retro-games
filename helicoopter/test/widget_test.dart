import 'package:cave_copter/game/helicopter_game.dart';
import 'package:cave_copter/main.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping the screen starts flight; lifting releases', (
    tester,
  ) async {
    late HelicopterGame game;
    await tester.pumpWidget(
      CaveCopterApp(
        gameFactory: () => game = HelicopterGame(seedSource: () => 1),
      ),
    );
    await tester.pump();
    expect(find.byType(GameWidget<HelicopterGame>), findsOneWidget);
    expect(game.phase.value, GamePhase.ready);

    final gesture = await tester.startGesture(const Offset(400, 200));
    await tester.pump();
    expect(game.phase.value, GamePhase.playing);
    expect(game.holding, isTrue);

    await gesture.up();
    await tester.pump();
    expect(game.holding, isFalse);
  });

  testWidgets('a cancelled pointer (system gesture) releases thrust', (
    tester,
  ) async {
    late HelicopterGame game;
    await tester.pumpWidget(
      CaveCopterApp(
        gameFactory: () => game = HelicopterGame(seedSource: () => 1),
      ),
    );
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(400, 200));
    await tester.pump();
    await gesture.cancel();
    await tester.pump();
    expect(game.holding, isFalse);
  });
}
