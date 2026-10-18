import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/audio_synth.dart';

void main() {
  int u16(ByteData b, int o) => b.getUint16(o, Endian.little);
  int u32(ByteData b, int o) => b.getUint32(o, Endian.little);
  String ascii(Uint8List b, int o) => String.fromCharCodes(b.sublist(o, o + 4));

  test('encodes a valid 16-bit mono PCM WAV', () {
    final wav = encodeWav([0, 0.5, -0.5, 1.5]);
    final b = ByteData.sublistView(wav);
    expect(ascii(wav, 0), 'RIFF');
    expect(u32(b, 4), wav.length - 8);
    expect(ascii(wav, 8), 'WAVE');
    expect(ascii(wav, 12), 'fmt ');
    expect(u16(b, 20), 1); // PCM
    expect(u16(b, 22), 1); // mono
    expect(u32(b, 24), sampleRate);
    expect(u16(b, 34), 16);
    expect(ascii(wav, 36), 'data');
    expect(u32(b, 40), 8);
    expect(b.getInt16(46, Endian.little), 16384);
    expect(b.getInt16(50, Endian.little), 32767); // clipped
  });

  test('every sound is non-silent, in range, and short', () {
    for (final entry in allSounds.entries) {
      final s = entry.value();
      expect(s, isNotEmpty, reason: entry.key);
      expect(s.every((v) => v >= -1 && v <= 1), isTrue, reason: entry.key);
      expect(s.any((v) => v.abs() > 0.05), isTrue, reason: entry.key);
      expect(s.length / sampleRate, lessThan(1.5), reason: entry.key);
    }
  });

  test('rotor loop is exactly 1 s and repeats seamlessly', () {
    final s = rotorLoop();
    expect(s.length, sampleRate);
    // The waveform period divides the loop: sample 0 continues sample n-1
    // exactly as sample k continues sample k-1 one period later.
    final period = sampleRate ~/ rotorChopHz;
    for (var i = 0; i < period; i++) {
      expect(s[i], s[s.length - period + i]);
    }
  });

  test('one-shot sounds start and end silent (no clicks)', () {
    for (final name in ['crash', 'best', 'click']) {
      final s = allSounds[name]!();
      expect(s.first.abs(), lessThan(0.01), reason: name);
      expect(s.last.abs(), lessThan(0.01), reason: name);
    }
  });

  test('crash beeps descend; new-best notes rise', () {
    expect(
      crashNotesHz,
      orderedEquals([...crashNotesHz]..sort((a, b) => b.compareTo(a))),
    );
    expect(bestNotesHz, orderedEquals([...bestNotesHz]..sort()));
    expect(bestNotesHz, hasLength(3));
  });
}
