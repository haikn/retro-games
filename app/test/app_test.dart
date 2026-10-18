import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_arcade/main.dart';
import 'package:lcd_kit/lcd_kit.dart';
import 'package:lcd_kit/testing.dart';

void main() {
  late List<List<String>> orientationRequests;

  Future<void> pumpArcade(WidgetTester tester) async {
    orientationRequests = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientationRequests.add(List<String>.from(call.arguments as List));
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    setScreen(tester, portrait: true);
    final services = ArcadeServices.create(
      LocalStore.memory(),
      games,
      backend: (_) => FakeBackend(),
    );
    await tester.pumpWidget(LcdArcadeApp(services: services));
    await tester.pump();
  }

  testWidgets('launcher shows four tiles with selection counter', (
    tester,
  ) async {
    await pumpArcade(tester);
    expect(find.text('Games'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    for (final title in ['Copter', 'Snake', 'Blocks', 'Hop']) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('games still to come say so and stay on the launcher', (
    tester,
  ) async {
    await pumpArcade(tester);
    await tester.tap(find.text('Snake'));
    await tester.pump();
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
    expect(orientationRequests, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Coming soon'), findsNothing);
  });

  testWidgets(
    'Copter rotates to landscape, draws only after rotating, and returns '
    'to the portrait launcher',
    (tester) async {
      await pumpArcade(tester);
      await tester.tap(find.text('Copter'));
      await tester.pump();
      expect(orientationRequests.last, [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);

      // Still portrait: the gate shows only the bezel.
      await tester.pump();
      expect(find.text('New game'), findsNothing);

      setScreen(tester, portrait: false); // the device has rotated
      await tester.pump();
      await tester.pump();
      expect(find.text('New game'), findsOneWidget);
      expect(find.text('All games'), findsOneWidget);

      await tester.tap(find.text('All games'));
      await tester.pump();
      await tester.pump();
      expect(orientationRequests.last, ['DeviceOrientation.portraitUp']);
      setScreen(tester, portrait: true);
      await tester.pump();
      expect(find.text('Games'), findsOneWidget);
    },
  );

  test('each game gets its own storage namespace and leaderboard', () async {
    final store = LocalStore.memory();
    final services = ArcadeServices.create(
      store,
      games,
      backend: (_) => FakeBackend(),
    );
    final host = services.hostFor(games.first, exit: () {});
    await host.store.recordBest(42);
    expect(store.scoped('copter').best, 42);
    expect(store.scoped('snake').best, 0);
    expect(services.leaderboards.keys, ['copter']);
  });
}

void setScreen(WidgetTester tester, {required bool portrait}) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = portrait
      ? const Size(800, 1600)
      : const Size(1600, 800);
  addTearDown(tester.view.reset);
}
