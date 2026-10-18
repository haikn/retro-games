import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_kit/lcd_kit.dart';
import 'package:lcd_kit/testing.dart';
import 'package:snake/core/snake.dart';
import 'package:snake/snake.dart';

import '../tool/snake_sounds.dart';

void main() {
  LcdBuffer frame(SnakeArcade a) {
    final b = LcdBuffer(width: 80, height: 160)..beginFrame(0);
    a.draw(b);
    return b;
  }

  test('draws the HUD rule and the 1-px field border', () {
    final a = SnakeArcade()..start(level: 5, seed: 1);
    final b = frame(a);
    for (var x = 0; x < 80; x++) {
      expect(b.isLit(x, 8), isTrue);
    }
    expect(b.isLit(1, 10), isTrue);
    expect(b.isLit(78, 159), isTrue);
    expect(b.isLit(1, 100), isTrue);
    expect(b.isLit(78, 100), isTrue);
    expect(b.isLit(0, 100), isFalse);
    expect(b.isLit(79, 100), isFalse);
  });

  test('segments are 3×3 joined into a line; the head has an eye', () {
    final a = SnakeArcade()..start(level: 5, seed: 1);
    final b = frame(a);
    final (hx, hy) = SnakeArcade.origin(const Cell(7, 18));
    expect(b.isLit(hx, hy), isTrue);
    expect(b.isLit(hx + 1, hy + 1), isFalse); // eye
    expect(b.isLit(hx - 1, hy + 1), isTrue); // joined to the next segment
    final (tx, ty) = SnakeArcade.origin(const Cell(3, 18));
    expect(b.isLit(tx + 1, ty + 1), isTrue); // body is solid
    expect(b.isLit(tx - 1, ty + 1), isFalse); // nothing before the tail
    expect(b.isLit(hx + 3, hy + 1), isFalse); // nothing ahead of the head
  });

  test('food is a plus inside its cell', () {
    final a = SnakeArcade()..start(level: 5, seed: 1);
    a.core.debugPlaceFood(const Cell(10, 5));
    final b = frame(a);
    final (x, y) = SnakeArcade.origin(const Cell(10, 5));
    expect(b.isLit(x + 1, y + 1), isTrue);
    expect(b.isLit(x + 1, y), isTrue);
    expect(b.isLit(x, y), isFalse);
    expect(b.isLit(x + 2, y + 2), isFalse);
  });

  test('swipes turn the snake; events become sounds', () {
    final a = SnakeArcade()..start(level: 5, seed: 1);
    a.input(const SwipeInput(Dir.up));
    a.core.debugPlaceFood(const Cell(7, 17));
    for (var i = 0; i < a.core.stepTicks; i++) {
      a.tick();
    }
    expect(a.core.heading, Heading.up);
    expect(a.takeSounds(), ['eat.wav']);
    expect(a.takeSounds(), isEmpty);
  });

  test('every sound the game can request ships as an asset', () {
    for (final f in SnakeModule.spec.sounds) {
      expect(allSounds.containsKey(f.replaceAll('.wav', '')), isTrue);
    }
    expect(allSounds.keys, containsAll(['click', 'best']));
  });

  testWidgets('a full game: menu → swipe → crash → game over', (tester) async {
    await tester.runAsync(loadLcdFont);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final app = LocalStore.memory();
    final store = app.scoped('snake');
    await tester.pumpWidget(
      MaterialApp(
        home: ArcadeGameView(
          host: GameHost(
            store: store,
            sound: SoundSetting(app),
            leaderboard: LeaderboardService(FakeBackend(), store),
            exitToLauncher: () {},
          ),
          spec: SnakeModule.spec,
          player: FakePlayer(),
          seedSource: () => 3,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Level: 5'), findsOneWidget);
    await tester.tap(find.text('New game'));
    await tester.pump();
    expect(find.text('Swipe to'), findsOneWidget);

    final s = tester.state<ArcadeGameViewState>(find.byType(ArcadeGameView));
    final g = await tester.startGesture(const Offset(200, 400));
    await g.moveBy(const Offset(0, -40));
    await g.up();
    await tester.pump();
    expect(s.phase, ArcadePhase.playing);
    final snake = (s.game as SnakeArcade).core;
    expect(snake.heading, Heading.right); // turn is queued until the next step
    for (var i = 0; i < 9; i++) {
      s.advance(1 / 60);
    }
    expect(snake.heading, Heading.up);

    // Force a crash: grow and turn back into the body.
    snake.debugGrow(4);
    for (final d in [Dir.left, Dir.down, Dir.right]) {
      final gg = await tester.startGesture(const Offset(200, 400));
      await gg.moveBy(switch (d) {
        Dir.left => const Offset(-40, 0),
        Dir.down => const Offset(0, 40),
        _ => const Offset(40, 0),
      });
      await gg.up();
      for (var i = 0; i < 9; i++) {
        s.advance(1 / 60);
      }
    }
    for (var i = 0; i < 60 && s.phase != ArcadePhase.over; i++) {
      s.advance(1 / 60);
    }
    expect(s.phase, ArcadePhase.over);
    for (var i = 0; i < 45; i++) {
      s.advance(1 / 60);
    }
    await tester.pump();
    expect(find.text('Game over!'), findsOneWidget);
  });
}
