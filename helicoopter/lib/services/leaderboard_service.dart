import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import 'leaderboard_ids.dart';
import 'local_store.dart';

/// Platform leaderboard calls. Failures are reported by throwing.
abstract interface class LeaderboardBackend {
  Future<void> signIn();
  Future<void> submit(int score);
  Future<void> show();
}

/// Game Center (iOS) / Google Play Games (Android) via games_services.
class GamesServicesLeaderboardBackend implements LeaderboardBackend {
  const GamesServicesLeaderboardBackend();

  @override
  Future<void> signIn() => GameAuth.signIn();

  @override
  Future<void> submit(int score) => Leaderboards.submitScore(
    score: Score(
      iOSLeaderboardID: LeaderboardIds.ios,
      androidLeaderboardID: LeaderboardIds.android,
      value: score,
    ),
  );

  @override
  Future<void> show() => Leaderboards.showLeaderboards(
    iOSLeaderboardID: LeaderboardIds.ios,
    androidLeaderboardID: LeaderboardIds.android,
  );
}

/// Desktop and tests: no platform leaderboard.
class UnsupportedLeaderboardBackend implements LeaderboardBackend {
  const UnsupportedLeaderboardBackend();

  static Never _unsupported() =>
      throw UnsupportedError('Leaderboards need iOS or Android');

  @override
  Future<void> signIn() async => _unsupported();
  @override
  Future<void> submit(int score) async => _unsupported();
  @override
  Future<void> show() async => _unsupported();
}

LeaderboardBackend platformLeaderboardBackend() => leaderboardBackendFor(
  isIOS: !kIsWeb && Platform.isIOS,
  isAndroid: !kIsWeb && Platform.isAndroid,
);

@visibleForTesting
LeaderboardBackend leaderboardBackendFor({
  required bool isIOS,
  required bool isAndroid,
  bool androidConfigured = LeaderboardIds.androidConfigured,
}) => isIOS || (isAndroid && androidConfigured)
    ? const GamesServicesLeaderboardBackend()
    : const UnsupportedLeaderboardBackend();

enum LeaderboardResult { shown, signInFailed, showFailed, unavailable }

/// Offline-tolerant leaderboard (spec: Platform Integration, Error Handling).
///
/// Signs in once at launch (never mid-run), submits only new bests, keeps the
/// highest unsubmitted best in [LocalStore] and flushes it after the next
/// successful sign-in. Nothing here ever throws into gameplay.
class LeaderboardService {
  LeaderboardService(
    this._backend,
    this._store, {
    this.timeout = const Duration(seconds: 20),
  });

  final LeaderboardBackend _backend;
  final LocalStore _store;
  final Duration timeout;

  bool _signedIn = false;
  bool _unsupported = false;

  bool get signedIn => _signedIn;

  Future<bool> _try(String what, Future<void> Function() call) async {
    try {
      await call().timeout(timeout);
      return true;
    } on UnsupportedError catch (e) {
      _unsupported = true;
      debugPrint('Leaderboard $what: $e');
    } catch (e) {
      debugPrint('Leaderboard $what failed: $e');
    }
    return false;
  }

  Future<void> _signIn() async {
    _signedIn = await _try('sign-in', _backend.signIn);
    if (_signedIn) await _flushPending();
  }

  Future<void> _flushPending() async {
    final pending = _store.pendingScore;
    if (pending == null) return;
    if (await _try('submit', () => _backend.submit(pending))) {
      await _store.setPendingScore(null);
    }
  }

  /// Called once at launch, on the title screen.
  Future<void> init() => _signIn();

  /// Records a new local best for the platform leaderboard.
  Future<void> submitBest(int score) async {
    final toSend = math.max(score, _store.pendingScore ?? 0);
    await _store.setPendingScore(toSend);
    if (_signedIn) await _flushPending();
  }

  /// `Online scores`: retries sign-in if needed, then opens the board.
  Future<LeaderboardResult> show() async {
    if (!_signedIn) await _signIn();
    if (_unsupported) return LeaderboardResult.unavailable;
    if (!_signedIn) return LeaderboardResult.signInFailed;
    return await _try('show', _backend.show)
        ? LeaderboardResult.shown
        : LeaderboardResult.showFailed;
  }
}
