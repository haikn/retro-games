import 'package:blocks/blocks.dart';
import 'package:blocks/core/blocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_kit/lcd_kit.dart';
import 'package:lcd_kit/testing.dart';

import '../tool/blocks_sounds.dart';

void main() {
  BlocksArcade arcade() => BlocksArcade()..start(level: 1, seed: 1);

  LcdBuffer frame(BlocksArcade a) {
    final b = LcdBuffer(width: 80, height: 160)..beginFrame(0);
    a.draw(b);
    return b;
  }

  test('draws the well frame and 4x4 bricks with a 1-px gap', () {
    final a = arcade();
    a.core.debugSet(0, 19);
    final b = frame(a);
    expect(b.isLit(1, 50), isTrue);
    expect(b.isLit(52, 50), isTrue);
    expect(b.isLit(30, 112), isTrue);
    final (x, y) = BlocksArcade.origin(0, 19);
    expect((x, y), (2, 107));
    expect(b.isLit(x, y), isTrue);
    expect(b.isLit(x + 3, y + 3), isTrue);
    expect(b.isLit(x + 4, y), isFalse); // gap
  });

  test('shows the next piece and the level / lines texts', () {
    final a = arcade();
    final b = frame(a);
    final first = shapeCells(a.core.next, 0).first;
    expect(b.isLit(57 + 5 * first.$1, 22 + 5 * first.$2), isTrue);
    expect(a.texts.map((t) => t.text), ['NEXT', 'LV 01', 'LN 000']);
  });

  test('tap rotates, horizontal drags move by 25 px, downward drag soft '
      'drops, flick hard drops', () {
    final a = arcade()..core.debugSetPiece(PieceKind.t);
    final x0 = a.core.piece.x;
    a.input(const PressInput(Offset.zero));
    a.input(const ReleaseInput(tap: true));
    expect(a.core.piece.rot, 1);
    expect(a.takeSounds(), ['rotate.wav']);

    a.input(const PressInput(Offset.zero));
    a.input(const DragInput(30, 0));
    a.input(const DragInput(24, 0));
    expect(a.core.piece.x, x0 + 2);
    a.input(const DragInput(0, 26));
    expect(a.core.score, 1);
    a.input(const ReleaseInput(tap: false, vy: 200));
    expect(a.core.score, 1); // slow release: no hard drop

    a.input(const PressInput(Offset.zero));
    a.input(const ReleaseInput(tap: false, vy: 3000));
    expect(a.core.score, greaterThan(20));
    expect(a.takeSounds(), contains('lock.wav'));
  });

  test('every sound the game can request ships as an asset', () {
    for (final f in BlocksModule.spec.sounds) {
      expect(allSounds.containsKey(f.replaceAll('.wav', '')), isTrue);
    }
    expect(allSounds.keys, containsAll(['click', 'best']));
  });

  test('Blocks is not cleared for release (decision C4)', () {
    expect(const BlocksModule().releaseCleared, isFalse);
  });

  testWidgets('a run in the shared flow', (tester) async {
    await tester.runAsync(loadLcdFont);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final app = LocalStore.memory();
    final store = app.scoped('blocks');
    await tester.pumpWidget(
      MaterialApp(
        home: ArcadeGameView(
          host: GameHost(
            store: store,
            sound: SoundSetting(app),
            leaderboard: LeaderboardService(FakeBackend(), store),
            exitToLauncher: () {},
          ),
          spec: BlocksModule.spec,
          player: FakePlayer(),
          seedSource: () => 2,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Level: 1'), findsOneWidget);
    await tester.tap(find.text('New game'));
    await tester.pump();
    final s = tester.state<ArcadeGameViewState>(find.byType(ArcadeGameView));
    await tester.tapAt(const Offset(200, 300));
    await tester.pump();
    expect(s.phase, ArcadePhase.playing);
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.text('LV 01'), findsOneWidget);
    for (var i = 0; i < 40000 && s.phase == ArcadePhase.playing; i++) {
      s.advance(1 / 60);
    }
    expect(s.phase, ArcadePhase.over); // nobody played: the stack tops out
  });
}
