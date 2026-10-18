import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lcd_kit/lcd_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LocalStore> open([Map<String, Object> values = const {}]) {
    SharedPreferences.setMockInitialValues(values);
    return LocalStore.open();
  }

  test('defaults when nothing is stored', () async {
    final store = await open();
    expect(store.best, 0);
    expect(store.pendingScore, isNull);
    expect(store.muted, isFalse);
  });

  test('records only higher best scores and persists them', () async {
    final store = await open();
    expect(await store.recordBest(120), isTrue);
    expect(await store.recordBest(80), isFalse);
    expect(store.best, 120);
    final reopened = await LocalStore.open();
    expect(reopened.best, 120);
  });

  test('pending leaderboard score round-trips and clears', () async {
    final store = await open();
    await store.setPendingScore(77);
    expect((await LocalStore.open()).pendingScore, 77);
    await store.setPendingScore(null);
    expect((await LocalStore.open()).pendingScore, isNull);
  });

  test('mute persists', () async {
    final store = await open();
    await store.setMuted(true);
    expect((await LocalStore.open()).muted, isTrue);
  });

  test('corrupt values fall back to defaults', () async {
    final store = await open({
      LocalStore.bestKey: 'not a number',
      LocalStore.mutedKey: 3,
    });
    expect(store.best, 0);
    expect(store.muted, isFalse);
  });

  test('without storage everything still works in memory', () async {
    final store = LocalStore.memory();
    expect(store.best, 0);
    expect(await store.recordBest(5), isTrue);
    expect(store.best, 5);
    await store.setMuted(true);
    expect(store.muted, isTrue);
  });

  test('scores are kept per game; sound is app-wide', () async {
    final app = await open();
    final copter = app.scoped('copter');
    final snake = app.scoped('snake');
    await copter.recordBest(300);
    await snake.recordBest(40);
    await snake.setPendingScore(40);
    await copter.setMuted(true);
    expect(copter.best, 300);
    expect(snake.best, 40);
    expect(copter.pendingScore, isNull);
    expect(app.muted, isTrue);
    expect(snake.muted, isTrue);
    final reopened = (await LocalStore.open()).scoped('copter');
    expect(reopened.best, 300);
  });

  test(
    'legacy Cave Copter scores move into the copter namespace once',
    () async {
      final app = await open({
        LocalStore.bestKey: 512,
        LocalStore.pendingKey: 512,
      });
      await app.migrateLegacyScores('copter');
      expect(app.scoped('copter').best, 512);
      expect(app.scoped('copter').pendingScore, 512);
      expect(app.best, 0); // legacy key removed
      await app.migrateLegacyScores('copter'); // idempotent
      expect(app.scoped('copter').best, 512);
    },
  );

  test('migration never lowers an existing namespaced best', () async {
    final app = await open({
      LocalStore.bestKey: 10,
      'copter.${LocalStore.bestKey}': 900,
    });
    await app.migrateLegacyScores('copter');
    expect(app.scoped('copter').best, 900);
  });

  test('memory stores share data between scopes', () async {
    final app = LocalStore.memory();
    await app.scoped('hop').recordBest(7);
    expect(app.scoped('hop').best, 7);
    expect(app.scoped('snake').best, 0);
  });
}
