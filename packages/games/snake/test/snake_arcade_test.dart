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
    expect(b.isLit(1, 13), isTrue);
    expect(b.isLit(78, 158), isTrue);
    expect(b.isLit(1, 100), isTrue);
    expect(b.isLit(78, 100), isTrue);
    // Equal 1-px margins left, right and bottom (F8).
    expect(b.isLit(0, 100), isFalse);
    expect(b.isLit(79, 100), isFalse);
    expect(b.isLit(40, 159), isFalse);
  });

  test('body segments are 3×3 joined into a line; the head is a bigger '
      '4×4 with an eye and a mouth facing its heading', () {
    final a = SnakeArcade()..start(level: 5, seed: 1);
    final b = frame(a);
    final (hx, hy) = SnakeArcade.origin(const Cell(7, 18));
    expect(b.isLit(hx + 3, hy), isTrue); // 4 px wide (body is 3)
    expect(b.isLit(hx, hy + 3), isTrue); // 4 px tall
    expect(b.isLit(hx + 1, hy + 1), isFalse); // eye
    expect(b.isLit(hx + 3, hy + 2), isFalse); // mouth at the front (right)
    expect(b.isLit(hx - 1, hy + 1), isTrue); // joined to the next segment
    final (tx, ty) = SnakeArcade.origin(const Cell(3, 18));
    expect(b.isLit(tx + 1, ty + 1), isTrue); // body is solid
    expect(b.isLit(tx + 1, ty + 3), isFalse); // body is 3 thick
    expect(b.isLit(tx - 1, ty + 1), isFalse); // nothing before the tail
  });

  test('the head turns with the snake', () {
    final a = SnakeArcade()..start(level: 5, seed: 1);
    a.input(const SwipeInput(Dir.up));
    for (var i = 0; i < a.core.stepTicks; i++) {
      a.tick();
    }
    final b = frame(a);
    final (hx, hy) = SnakeArcade.origin(a.core.body.first);
    expect(b.isLit(hx + 2, hy), isFalse); // mouth on the top edge
    expect(b.isLit(hx + 3, hy + 2), isTrue); // no longer on the right
  });

  test('the bomb is an 8×8 sprite over 2×2 cells and its fuse flickers', () {
    final a = SnakeArcade()..start(level: 5, seed: 1);
    a.core.debugPlaceBonus(const Cell(10, 4));
    final (x, y) = SnakeArcade.origin(const Cell(10, 4));
    final f0 = frame(a);
    expect(f0.isLit(x + 3, y + 6), isTrue); // body
    for (var i = 0; i < 8; i++) {
      a.tick();
    }
    final f1 = frame(a);
    expect(f1.isLit(x + 7, y), isNot(f0.isLit(x + 7, y))); // spark moved
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
