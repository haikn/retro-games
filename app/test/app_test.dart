import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_arcade/main.dart';
import 'package:lcd_arcade/remote/remote_settings.dart';
import 'package:lcd_kit/lcd_kit.dart';
import 'package:lcd_kit/testing.dart';

void main() {
  late List<List<String>> orientationRequests;

  late List<RemoteSettings> storeOpens;

  Future<void> pumpArcade(
    WidgetTester tester, {
    ValueNotifier<RemoteSettings>? remote,
    LocalStore? store,
  }) async {
    storeOpens = [];
    await tester.runAsync(loadLcdFont);
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
      store ?? LocalStore.memory(),
      games,
      backend: (_) => FakeBackend(),
    );
    await tester.pumpWidget(
      LcdArcadeApp(
        services: services,
        remote: remote,
        version: '1.0.0',
        openStore: (s) async => storeOpens.add(s),
      ),
    );
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

  testWidgets('a newer version is offered once; Later dismisses it', (
    tester,
  ) async {
    final remote = ValueNotifier(const RemoteSettings(latestVersion: '1.1.0'));
    final store = LocalStore.memory();
    await pumpArcade(tester, remote: remote, store: store);
    expect(find.text('New version'), findsOneWidget);
    expect(find.text('Copter'), findsNothing);
    await tester.tap(find.text('Update'));
    expect(storeOpens, hasLength(1));
    await tester.tap(find.text('Later'));
    await tester.pump();
    expect(find.text('Copter'), findsOneWidget);
    // Remembered after a restart; a later release asks again.
    await pumpArcade(tester, remote: remote, store: store);
    expect(find.text('New version'), findsNothing);
    remote.value = const RemoteSettings(latestVersion: '1.2.0');
    await tester.pump();
    expect(find.text('New version'), findsOneWidget);
  });

  testWidgets('below the minimum version the games stay locked', (
    tester,
  ) async {
    final remote = ValueNotifier(const RemoteSettings(minVersion: '1.1.0'));
    await pumpArcade(tester, remote: remote);
    expect(find.text('Must update'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    expect(find.text('Copter'), findsNothing);
    // Lifted remotely: the launcher comes back without a restart.
    remote.value = RemoteSettings.defaults;
    await tester.pump();
    expect(find.text('Copter'), findsOneWidget);
  });

  test('release builds hold back games not cleared for release', () {
    final release = launcherEntriesFor(games, release: true);
    final debug = launcherEntriesFor(games, release: false);
    expect(release.map((e) => e.title), ['Copter', 'Snake', 'Blocks', 'Hop']);
    expect(release[2].module, isNull); // Blocks: pending decision C4
    expect(release.where((e) => e.module != null), hasLength(3));
    expect(debug.every((e) => e.module != null), isTrue);
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

  test('sign-in happens once for all games', () async {
    final backends = <String, FakeBackend>{};
    final store = LocalStore.memory();
    await store.scoped('hop').setPendingScore(30);
    final services = ArcadeServices.create(
      store,
      games,
      backend: (g) => backends[g.id] = FakeBackend(),
    );
    await services.signIn();
    final signIns = backends.values.fold(0, (n, b) => n + b.signIns);
    expect(signIns, 1);
    expect(services.leaderboards.values.every((l) => l.signedIn), isTrue);
    expect(backends['hop']!.submitted, [30]);
  });

  test('a declined sign-in is not repeated for the other games', () async {
    final backends = <String, FakeBackend>{};
    final services = ArcadeServices.create(
      LocalStore.memory(),
      games,
      backend: (g) => backends[g.id] = FakeBackend()..failSignIn = true,
    );
    await services.signIn();
    expect(backends.values.fold(0, (n, b) => n + b.signIns), 1);
  });

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
    expect(services.leaderboards.keys, ['copter', 'snake', 'blocks', 'hop']);
  });

  testWidgets('Snake opens in portrait at its menu and returns', (
    tester,
  ) async {
    await pumpArcade(tester);
    await tester.tap(find.text('Snake'));
    await tester.pump();
    expect(orientationRequests.last, ['DeviceOrientation.portraitUp']);
    await tester.pump();
    expect(find.text('Level: 5'), findsOneWidget);
    await tester.tap(find.text('All games'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Games'), findsOneWidget);
  });
}

void setScreen(WidgetTester tester, {required bool portrait}) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = portrait
      ? const Size(800, 1600)
      : const Size(1600, 800);
  addTearDown(tester.view.reset);
}
