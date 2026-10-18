import 'package:cave_copter/app/game_services.dart';
import 'package:cave_copter/game/helicopter_game.dart';
import 'package:cave_copter/services/audio_service.dart';
import 'package:cave_copter/services/leaderboard_service.dart';
import 'package:cave_copter/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../services/audio_service_test.dart' show FakePlayer;
import '../services/leaderboard_service_test.dart' show FakeBackend;

void main() {
  late FakePlayer player;
  late AudioService audio;
  late LocalStore store;
  late HelicopterGame game;
  late GameServices services;
  late FakeBackend backend;

  setUp(() async {
    player = FakePlayer();
    audio = AudioService(player);
    await audio.load();
    store = LocalStore.memory();
    game = HelicopterGame(seedSource: () => 1)..newRun();
    backend = FakeBackend();
    final leaderboard = LeaderboardService(backend, store);
    await leaderboard.init();
    services = GameServices(
      game: game,
      audio: audio,
      store: store,
      leaderboard: leaderboard,
    )..attach();
  });

  tearDown(() => services.detach());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('rotor loops only while playing', () async {
    game.pointerDown();
    await settle();
    expect(player.looping, AudioService.rotor);
    game.pause();
    await settle();
    expect(player.looping, isNull);
    game.resume();
    game.pointerDown();
    await settle();
    expect(player.looping, AudioService.rotor);
  });

  test('crash: rotor stops, crash sound, new best saved', () async {
    game.pointerDown();
    game.pointerUp();
    for (var i = 0; i < 3000 && game.phase.value == GamePhase.playing; i++) {
      game.update(1 / 60);
    }
    await settle();
    expect(player.looping, isNull);
    expect(player.played, [AudioService.crashFile]);
    expect(store.best, game.best);
    expect(store.best, greaterThan(0));
    expect(backend.submitted, [game.best]); // new best goes to the board
  });

  test('a run that is not a new best is not submitted', () async {
    game.best = 1 << 30;
    game.pointerDown();
    game.pointerUp();
    for (var i = 0; i < 3000 && game.phase.value == GamePhase.playing; i++) {
      game.update(1 / 60);
    }
    await settle();
    expect(backend.submitted, isEmpty);
  });

  test('jingle plays with the game-over dialog only for a new best', () async {
    game.pointerDown();
    game.pointerUp();
    for (var i = 0; i < 3000; i++) {
      game.update(1 / 60);
      if (game.gameOverVisible.value) break;
    }
    await settle();
    expect(player.played, [AudioService.crashFile, AudioService.bestFile]);

    // Second run, worse than the best: no jingle.
    player.played.clear();
    game.best = 1 << 30;
    for (var i = 0; i < 40; i++) {
      game.update(1 / 60);
    }
    game.pointerDown();
    game.pointerUp();
    for (var i = 0; i < 3000; i++) {
      game.update(1 / 60);
      if (game.gameOverVisible.value) break;
    }
    await settle();
    expect(player.played, [AudioService.crashFile]);
  });

  test('sound setting updates audio and is persisted', () async {
    await services.setSound(false);
    expect(audio.muted, isTrue);
    expect(store.muted, isTrue);
    await services.setSound(true);
    expect(store.muted, isFalse);
  });

  test('key click plays the click sound', () async {
    await services.click();
    expect(player.played, [AudioService.clickFile]);
  });
}
