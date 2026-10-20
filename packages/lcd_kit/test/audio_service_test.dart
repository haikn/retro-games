import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_kit/lcd_kit.dart';
import 'package:lcd_kit/testing.dart';

void main() {
  late FakePlayer player;
  late AudioService audio;

  setUp(() {
    player = FakePlayer();
    audio = AudioService(player, files: ['boom.wav', 'hum.wav']);
  });

  test('load configures the ambient session and enables sound', () async {
    await audio.load();
    expect(player.ambientCalls, 1);
    expect(audio.available, isTrue);
  });

  test('preloads its files plus the shared click and jingle', () {
    expect(audio.files, ['click.wav', 'best.wav', 'boom.wav', 'hum.wav']);
  });

  test('plays effects and one loop once loaded', () async {
    await audio.load();
    await audio.startLoop('hum.wav');
    expect(player.looping, 'hum.wav');
    await audio.startLoop('boom.wav'); // one loop at a time
    expect(player.looping, 'hum.wav');
    await audio.stopLoop();
    expect(player.looping, isNull);
    await audio.play('boom.wav');
    await audio.newBest();
    await audio.click();
    expect(player.played, [
      'boom.wav',
      AudioService.bestFile,
      AudioService.clickFile,
    ]);
  });

  test('dispose frees the players and silences the service', () async {
    await audio.load();
    await audio.startLoop('hum.wav');
    await audio.dispose();
    expect(player.disposed, isTrue);
    expect(player.looping, isNull);
    await audio.play('boom.wav');
    expect(player.played, isEmpty);
  });

  test('nothing plays before load', () async {
    await audio.startLoop('hum.wav');
    await audio.play('boom.wav');
    expect(player.looping, isNull);
    expect(player.played, isEmpty);
  });

  test('load failure leaves the game silent without throwing', () async {
    player.failLoad = true;
    await audio.load();
    expect(audio.available, isFalse);
    await audio.startLoop('hum.wav');
    await audio.play('boom.wav');
    expect(player.played, isEmpty);
  });

  test('playback failures never throw', () async {
    await audio.load();
    player.failPlay = true;
    await audio.startLoop('hum.wav');
    await audio.play('boom.wav');
  });

  test('muting stops the loop and silences effects', () async {
    await audio.load();
    await audio.startLoop('hum.wav');
    await audio.setMuted(true);
    expect(player.looping, isNull);
    await audio.play('boom.wav');
    await audio.startLoop('hum.wav');
    expect(player.played, isEmpty);
    expect(player.looping, isNull);
  });

  test('can start muted', () async {
    final muted = AudioService(player, files: const [], muted: true);
    await muted.load();
    await muted.click();
    expect(player.played, isEmpty);
  });
}
