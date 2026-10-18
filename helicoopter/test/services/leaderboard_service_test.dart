import 'dart:async';

import 'package:cave_copter/services/leaderboard_service.dart';
import 'package:cave_copter/services/local_store.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBackend implements LeaderboardBackend {
  bool failSignIn = false;
  bool failSubmit = false;
  bool failShow = false;
  bool hangSignIn = false;
  int signIns = 0;
  int shows = 0;
  final submitted = <int>[];

  @override
  Future<void> signIn() async {
    signIns++;
    if (hangSignIn) return Completer<void>().future;
    if (failSignIn) throw Exception('declined');
  }

  @override
  Future<void> submit(int score) async {
    if (failSubmit) throw Exception('offline');
    submitted.add(score);
  }

  @override
  Future<void> show() async {
    if (failShow) throw Exception('ui failed');
    shows++;
  }
}

void main() {
  late FakeBackend backend;
  late LocalStore store;
  late LeaderboardService service;

  setUp(() {
    backend = FakeBackend();
    store = LocalStore.memory();
    service = LeaderboardService(backend, store);
  });

  test('init signs in once', () async {
    await service.init();
    expect(service.signedIn, isTrue);
    expect(backend.signIns, 1);
  });

  test(
    'signed in: a new best is submitted and nothing stays pending',
    () async {
      await service.init();
      await service.submitBest(120);
      expect(backend.submitted, [120]);
      expect(store.pendingScore, isNull);
    },
  );

  test('declined sign-in: best is kept pending, never throws', () async {
    backend.failSignIn = true;
    await service.init();
    expect(service.signedIn, isFalse);
    await service.submitBest(50);
    await service.submitBest(30);
    expect(backend.submitted, isEmpty);
    expect(store.pendingScore, 50); // the higher one
  });

  test('submit failure keeps the score pending', () async {
    await service.init();
    backend.failSubmit = true;
    await service.submitBest(40);
    expect(store.pendingScore, 40);
  });

  test('pending score is flushed after the next successful sign-in', () async {
    await store.setPendingScore(99);
    await service.init();
    expect(backend.submitted, [99]);
    expect(store.pendingScore, isNull);
  });

  test(
    'offline then online: pending goes out when Online scores signs in',
    () async {
      backend.failSignIn = true;
      await service.init();
      await service.submitBest(77);
      backend.failSignIn = false;
      expect(await service.show(), LeaderboardResult.shown);
      expect(backend.submitted, [77]);
      expect(store.pendingScore, isNull);
    },
  );

  test('show retries sign-in and reports failures', () async {
    backend.failSignIn = true;
    await service.init();
    expect(await service.show(), LeaderboardResult.signInFailed);
    expect(backend.signIns, 2);
    expect(backend.shows, 0);

    backend.failSignIn = false;
    backend.failShow = true;
    expect(await service.show(), LeaderboardResult.showFailed);
  });

  test('a hanging sign-in times out instead of blocking', () {
    fakeAsync((async) {
      backend.hangSignIn = true;
      final s = LeaderboardService(
        backend,
        store,
        timeout: const Duration(seconds: 5),
      );
      var done = false;
      s.init().then((_) => done = true);
      async.elapse(const Duration(seconds: 6));
      expect(done, isTrue);
      expect(s.signedIn, isFalse);
    });
  });

  test('unsupported platform reports unavailable', () async {
    final s = LeaderboardService(const UnsupportedLeaderboardBackend(), store);
    await s.init();
    expect(s.signedIn, isFalse);
    expect(await s.show(), LeaderboardResult.unavailable);
    await s.submitBest(10);
    expect(store.pendingScore, 10);
  });

  group('platform backend', () {
    test('iOS always uses Game Center', () {
      expect(
        leaderboardBackendFor(isIOS: true, isAndroid: false),
        isA<GamesServicesLeaderboardBackend>(),
      );
    });
    test('Android uses Play Games only once configured', () {
      expect(
        leaderboardBackendFor(
          isIOS: false,
          isAndroid: true,
          androidConfigured: false,
        ),
        isA<UnsupportedLeaderboardBackend>(),
      );
      expect(
        leaderboardBackendFor(
          isIOS: false,
          isAndroid: true,
          androidConfigured: true,
        ),
        isA<GamesServicesLeaderboardBackend>(),
      );
    });
    test('desktop has no leaderboard', () {
      expect(
        leaderboardBackendFor(isIOS: false, isAndroid: false),
        isA<UnsupportedLeaderboardBackend>(),
      );
    });
  });
}
