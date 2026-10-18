import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:lcd_kit/synth.dart';

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

  test('beeps start and end silent (no clicks)', () {
    final s = beep(880, 0.05, 0.5);
    expect(s.first.abs(), lessThan(0.01));
    expect(s.last.abs(), lessThan(0.01));
    expect(s.any((v) => v.abs() > 0.4), isTrue);
  });
}
