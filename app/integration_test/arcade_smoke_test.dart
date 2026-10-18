import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lcd_arcade/main.dart';
import 'package:lcd_kit/lcd_kit.dart';

/// On-device smoke test (plan A5.6): launcher → each game → start → play →
/// pause → back to the launcher, with real rendering, audio and rotation.
/// Run on a simulator/emulator: `flutter test integration_test -d <device>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $finder');
  }

  Future<void> play(WidgetTester tester, Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('every game opens, runs and returns to the launcher', (
    tester,
  ) async {
    final services = ArcadeServices.create(
      LocalStore.memory(),
      games,
      backend: (_) => const UnsupportedLeaderboardBackend(),
    );
    await tester.pumpWidget(LcdArcadeApp(services: services));
    await waitFor(tester, find.text('Games'));

    for (final title in ['Snake', 'Blocks', 'Hop', 'Copter']) {
      await tester.tap(find.text(title));
      await waitFor(tester, find.text('New game'));
      await tester.tap(find.text('New game'));
      await tester.pump(const Duration(milliseconds: 300));

      // Start the run; Copter also needs a held press to fly.
      final center = tester.getCenter(find.byType(LcdViewport).last);
      final gesture = await tester.startGesture(center);
      await play(tester, const Duration(milliseconds: 600));
      await gesture.up();
      await play(tester, const Duration(seconds: 2));

      // Back: pause (or menu after a crash), then out to the launcher.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      if (find.text('Main menu').evaluate().isNotEmpty) {
        await tester.tap(find.text('Main menu'));
      } else if (find.text('Menu').evaluate().isNotEmpty) {
        await tester.tap(find.text('Menu'));
      }
      await waitFor(tester, find.text('All games'));
      await tester.tap(find.text('All games'));
      await waitFor(tester, find.text('Games'));
    }
  });
}
