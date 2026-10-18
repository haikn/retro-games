import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_kit/lcd_kit.dart';
import 'package:lcd_kit/testing.dart';

class FakeGame extends ArcadeGame {
  int ticks = 0;
  int startedLevel = 0;
  final inputs = <GameInput>[];
  final _sounds = <String>[];
  @override
  int score = 0;
  @override
  bool over = false;

  @override
  void start({required int level, required int seed}) {
    startedLevel = level;
    ticks = 0;
    score = 0;
    over = false;
  }

  @override
  void tick() {
    ticks++;
    if (ticks == 1) _sounds.add('blip.wav');
  }

  @override
  void input(GameInput input) => inputs.add(input);

  @override
  void draw(LcdBuffer buffer) => buffer.fillRect(0, 8, buffer.width, 1);

  @override
  List<HudText> get texts => const [HudText('NEXT', Offset(300, 60))];

  @override
  List<String> takeSounds() {
    final s = List.of(_sounds);
    _sounds.clear();
    return s;
  }
}

void main() {
  late FakeGame game;
  late FakePlayer player;
  late FakeBackend backend;
  late LocalStore store;
  late SoundSetting sound;
  late int exits;

  Future<ArcadeGameViewState> pump(
    WidgetTester tester, {
    int? levels = 9,
  }) async {
    await tester.runAsync(loadLcdFont);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    game = FakeGame();
    player = FakePlayer();
    backend = FakeBackend();
    final app = LocalStore.memory();
    store = app.scoped('fake');
    sound = SoundSetting(app);
    exits = 0;
    final leaderboard = LeaderboardService(backend, store);
    await leaderboard.init();
    await tester.pumpWidget(
      MaterialApp(
        home: ArcadeGameView(
          host: GameHost(
            store: store,
            sound: sound,
            leaderboard: leaderboard,
            exitToLauncher: () => exits++,
          ),
          spec: ArcadeSpec(
            title: 'Fake',
            package: 'fake',
            orientation: GameOrientation.portrait,
            create: () => game,
            sounds: const ['blip.wav'],
            instructions: const ['Do the thing.'],
            startHint: const ['Swipe to', 'start'],
            levels: levels,
            defaultLevel: 5,
          ),
          player: player,
          seedSource: () => 7,
        ),
      ),
    );
    await tester.pump();
    return tester.state<ArcadeGameViewState>(find.byType(ArcadeGameView));
  }

  void ticks(ArcadeGameViewState s, int n) {
    for (var i = 0; i < n; i++) {
      s.advance(1 / 60);
    }
  }

  testWidgets('menu lists the items, with Level when the game has levels', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Fake'), findsOneWidget);
    for (final item in [
      'New game',
      'Level: 5',
      'Top score',
      'Sound: On',
      'How to play',
      'All games',
    ]) {
      expect(find.text(item), findsOneWidget);
    }
  });

  testWidgets('no Level row without levels', (tester) async {
    await pump(tester, levels: null);
    expect(find.textContaining('Level'), findsNothing);
  });

  testWidgets('Level cycles 1–9 and is remembered', (tester) async {
    final s = await pump(tester);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.textContaining('Level:'));
      await tester.pump();
    }
    expect(find.text('Level: 1'), findsOneWidget); // 5 → 6,7,8,9,1
    expect(store.intSetting('level', 0), 1);
    s.newGame();
    expect(game.startedLevel, 1);
  });

  testWidgets('New game shows the hint; the first press starts and reaches '
      'the game', (tester) async {
    final s = await pump(tester);
    await tester.tap(find.text('New game'));
    await tester.pump();
    expect(s.phase, ArcadePhase.ready);
    expect(find.text('Swipe to'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
    ticks(s, 10);
    expect(game.ticks, 0); // ready: frozen

    await tester.tapAt(const Offset(200, 600));
    await tester.pump();
    expect(s.phase, ArcadePhase.playing);
    expect(game.inputs.whereType<PressInput>(), isNotEmpty);
    expect(game.inputs.whereType<ReleaseInput>().single.tap, isTrue);
    ticks(s, 3);
    expect(game.ticks, 3);
  });

  testWidgets('swipes are reported once, as soon as they cross the threshold', (
    tester,
  ) async {
    final s = await pump(tester);
    s.newGame();
    await tester.pump();
    final g = await tester.startGesture(const Offset(200, 400));
    await g.moveBy(const Offset(10, 0));
    await g.moveBy(const Offset(25, 0));
    await g.moveBy(const Offset(25, 0));
    await g.up();
    await tester.pump();
    expect(game.inputs.whereType<SwipeInput>().map((e) => e.dir), [Dir.right]);
    expect(game.inputs.whereType<DragInput>().length, 3);
  });

  testWidgets('sounds requested by the game are played', (tester) async {
    final s = await pump(tester);
    s.newGame();
    await tester.pump();
    await tester.tapAt(const Offset(200, 600));
    ticks(s, 2);
    await tester.pump();
    expect(player.played, contains('blip.wav'));
  });

  testWidgets('game over: flash, dialog at 40 ticks, best saved and '
      'submitted, restart only after 600 ms', (tester) async {
    final s = await pump(tester);
    s.newGame();
    await tester.pump();
    await tester.tapAt(const Offset(200, 600));
    ticks(s, 5);
    game.score = 120;
    game.over = true;
    ticks(s, 1);
    await tester.pump();
    expect(s.phase, ArcadePhase.over);
    expect(s.inverted, isTrue);
    expect(store.best, 120);
    expect(backend.submitted, [120]);
    expect(find.text('Game over!'), findsNothing);

    ticks(s, 30);
    await tester.tapAt(const Offset(200, 600));
    await tester.pump();
    expect(s.phase, ArcadePhase.over); // too early

    ticks(s, 10);
    await tester.pump();
    expect(find.text('Game over!'), findsOneWidget);
    expect(find.text('Score 00120'), findsOneWidget);
    expect(find.text('New best!'), findsOneWidget);
    expect(player.played, contains(AudioService.bestFile));

    await tester.tapAt(const Offset(200, 300));
    await tester.pump();
    expect(s.phase, ArcadePhase.playing);
    expect(game.score, 0);
  });

  testWidgets('a worse run shows the best instead of New best!', (
    tester,
  ) async {
    final s = await pump(tester);
    await store.recordBest(500);
    s.newGame();
    await tester.pump();
    await tester.tapAt(const Offset(200, 600));
    game.score = 40;
    game.over = true;
    ticks(s, 45);
    await tester.pump();
    expect(find.text('Best 00500'), findsOneWidget);
    expect(backend.submitted, isEmpty);
  });

  testWidgets('back: playing → paused → ready → menu → launcher', (
    tester,
  ) async {
    final s = await pump(tester);
    s.newGame();
    await tester.pump();
    await tester.tapAt(const Offset(200, 600));
    await tester.pump();
    s.back();
    await tester.pump();
    expect(s.phase, ArcadePhase.paused);
    expect(find.text('Paused'), findsOneWidget);
    s.back();
    await tester.pump();
    expect(s.phase, ArcadePhase.ready);
    s.back();
    await tester.pump();
    expect(s.phase, ArcadePhase.menu);
    s.back();
    expect(exits, 1);
  });

  testWidgets('going to the background pauses a run', (tester) async {
    final s = await pump(tester);
    s.newGame();
    await tester.pump();
    await tester.tapAt(const Offset(200, 600));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(s.phase, ArcadePhase.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('sound toggle is app-wide and persisted', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Sound: On'));
    await tester.pump();
    expect(find.text('Sound: Off'), findsOneWidget);
    expect(sound.on, isFalse);
  });

  testWidgets('top score and online scores notice', (tester) async {
    final s = await pump(tester);
    await store.recordBest(77);
    backend.failSignIn = true;
    await LeaderboardService(backend, store).init();
    await tester.tap(find.text('Top score'));
    await tester.pump();
    expect(find.text('00077'), findsOneWidget);
    expect(find.text('On this phone'), findsOneWidget);
    expect(s.phase, ArcadePhase.topScore);
    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(s.phase, ArcadePhase.menu);
  });

  testWidgets('instructions show the game text', (tester) async {
    await pump(tester);
    await tester.tap(find.text('How to play'));
    await tester.pump();
    expect(find.text('Do the thing.'), findsOneWidget);
  });

  testWidgets('All games returns to the launcher', (tester) async {
    await pump(tester);
    await tester.tap(find.text('All games'));
    expect(exits, 1);
  });
}
