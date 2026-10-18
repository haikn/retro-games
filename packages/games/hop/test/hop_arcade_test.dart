import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hop/core/hop_game.dart';
import 'package:hop/core/lanes.dart';
import 'package:hop/hop.dart';
import 'package:lcd_kit/lcd_kit.dart';
import 'package:lcd_kit/testing.dart';

import '../tool/hop_sounds.dart';

void main() {
  HopArcade arcade(Map<int, Lane> special) => HopArcade(
    factory: (_) =>
        HopGame.debug((i) => special[i] ?? Lane.grass(index: i, trees: 0)),
  )..start(level: 1, seed: 1);

  LcdBuffer frame(HopArcade a) {
    final b = LcdBuffer(width: 80, height: 160)..beginFrame(0);
    a.draw(b);
    return b;
  }

  test('lane 2 sits 3 lanes above the bottom; the chicken stands on it', () {
    expect(HopArcade.laneTop(0, 0), 150);
    expect(HopArcade.laneTop(2, 0), 130);
    final b = frame(arcade({}));
    final s = HopSprites.chicken;
    for (var y = 0; y < s.height; y++) {
      for (var x = 0; x < s.width; x++) {
        expect(b.isLit(32 + x, 131 + y), s.at(x, y));
      }
    }
  });

  test('the HUD strip stays clear except the rule', () {
    final b = frame(arcade({}));
    for (var x = 0; x < 80; x++) {
      expect(b.isLit(x, 8), isTrue);
      for (var y = 0; y < 8; y++) {
        expect(b.isLit(x, y), isFalse);
      }
    }
  });

  test('trees, cars, logs and rails are drawn in their lanes', () {
    final b = frame(
      arcade({
        3: const Lane.grass(index: 3, trees: 1 << 0),
        4: const Lane.road(
          index: 4,
          dir: 1,
          speed: 0,
          objects: [Mover(72, 12)],
        ),
        5: const Lane.river(
          index: 5,
          dir: 1,
          speed: 0,
          objects: [Mover(32, 24)],
        ),
        6: const Lane.rail(index: 6, dir: 1, trainPeriod: 300, trainOffset: 0),
      }),
    );
    // Tree in column 0 of lane 3 (top 120): trunk row.
    expect(b.isLit(3, 121 + 6), isTrue);
    // Car at screen x 40 in lane 4 (top 110), body row 2 of the sprite.
    expect(b.isLit(45, 112 + 2), isTrue);
    // Log at screen x 0..24 in lane 5 (top 100): outline top and bottom.
    expect(b.isLit(10, 102), isTrue);
    expect(b.isLit(10, 107), isTrue);
    // Rails in lane 6 (top 90).
    expect(b.isLit(50, 92), isTrue);
    expect(b.isLit(50, 97), isTrue);
  });

  test('taps hop forward, swipes hop sideways and back', () {
    final a = arcade({});
    a.input(const ReleaseInput(tap: true));
    for (var i = 0; i < 8; i++) {
      a.tick();
    }
    expect(a.core.lane, 3);
    expect(a.takeSounds(), ['hop.wav']);
    a.input(const SwipeInput(Dir.left));
    for (var i = 0; i < 8; i++) {
      a.tick();
    }
    expect(a.core.x, 24);
    a.input(const SwipeInput(Dir.down));
    for (var i = 0; i < 8; i++) {
      a.tick();
    }
    expect(a.core.lane, 2);
    a.input(const ReleaseInput(tap: false)); // a drag that ended: no hop
    a.tick();
    expect(a.core.hopping, isFalse);
  });

  test('every sound the game can request ships as an asset', () {
    for (final f in HopModule.spec.sounds) {
      expect(allSounds.containsKey(f.replaceAll('.wav', '')), isTrue);
    }
    expect(allSounds.keys, containsAll(['click', 'best']));
  });

  testWidgets('a run in the shared flow: tap to start and hop', (tester) async {
    await tester.runAsync(loadLcdFont);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final app = LocalStore.memory();
    final store = app.scoped('hop');
    await tester.pumpWidget(
      MaterialApp(
        home: ArcadeGameView(
          host: GameHost(
            store: store,
            sound: SoundSetting(app),
            leaderboard: LeaderboardService(FakeBackend(), store),
            exitToLauncher: () {},
          ),
          spec: HopModule.spec,
          player: FakePlayer(),
          seedSource: () => 2,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Level'), findsNothing);
    await tester.tap(find.text('New game'));
    await tester.pump();
    expect(find.text('Tap to'), findsOneWidget);
    final s = tester.state<ArcadeGameViewState>(find.byType(ArcadeGameView));
    await tester.tapAt(const Offset(200, 600));
    await tester.pump();
    expect(s.phase, ArcadePhase.playing);
    for (var i = 0; i < 10; i++) {
      s.advance(1 / 60);
    }
    expect((s.game as HopArcade).core.lane, 3);
  });
}
