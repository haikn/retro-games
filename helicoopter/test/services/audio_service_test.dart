import 'package:cave_copter/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePlayer implements SoundPlayer {
  bool failLoad = false;
  bool failPlay = false;
  final played = <String>[];
  String? looping;
  int ambientCalls = 0;

  @override
  Future<void> configureAmbient() async => ambientCalls++;

  @override
  Future<void> preload(List<String> files) async {
    if (failLoad) throw Exception('no audio');
  }

  @override
  Future<void> play(String file, double volume) async {
    if (failPlay) throw Exception('play failed');
    played.add(file);
  }

  @override
  Future<void> startLoop(String file, double volume) async {
    if (failPlay) throw Exception('loop failed');
    looping = file;
  }

  @override
  Future<void> stopLoop() async => looping = null;
}

void main() {
  late FakePlayer player;
  late AudioService audio;

  setUp(() {
    player = FakePlayer();
    audio = AudioService(player);
  });

  test('load configures the ambient session and enables sound', () async {
    await audio.load();
    expect(player.ambientCalls, 1);
    expect(audio.available, isTrue);
  });

  test('plays effects and loops the rotor once loaded', () async {
    await audio.load();
    await audio.startRotor();
    expect(player.looping, AudioService.rotor);
    await audio.startRotor(); // idempotent
    await audio.stopRotor();
    expect(player.looping, isNull);
    await audio.crash();
    await audio.newBest();
    await audio.click();
    expect(player.played, [
      AudioService.crashFile,
      AudioService.bestFile,
      AudioService.clickFile,
    ]);
  });

  test('nothing plays before load', () async {
    await audio.startRotor();
    await audio.crash();
    expect(player.looping, isNull);
    expect(player.played, isEmpty);
  });

  test('load failure leaves the game silent without throwing', () async {
    player.failLoad = true;
    await audio.load();
    expect(audio.available, isFalse);
    await audio.startRotor();
    await audio.crash();
    expect(player.played, isEmpty);
  });

  test('playback failures never throw', () async {
    await audio.load();
    player.failPlay = true;
    await audio.startRotor();
    await audio.crash();
  });

  test('muting stops the rotor and silences effects', () async {
    await audio.load();
    await audio.startRotor();
    await audio.setMuted(true);
    expect(player.looping, isNull);
    await audio.crash();
    await audio.startRotor();
    expect(player.played, isEmpty);
    expect(player.looping, isNull);
  });

  test('can start muted', () async {
    final muted = AudioService(player, muted: true);
    await muted.load();
    await muted.click();
    expect(player.played, isEmpty);
  });
}
