import 'package:cave_copter/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
