/// Monophonic square-wave "phone buzzer" synthesis for the games' sound
/// scripts (pure Dart; used by `tool/gen_audio.dart` in each game).
library;

import 'dart:typed_data';

const sampleRate = 22050;

/// Square wave at [hz], sample [i]: +1 or -1.
double square(double hz, int i) =>
    ((i * hz * 2 / sampleRate).floor()).isEven ? 1.0 : -1.0;

/// One beep of [seconds], with 2 ms fades so it starts and ends at 0.
List<double> beep(double hz, double seconds, double volume) {
  final n = (seconds * sampleRate).round();
  final fade = (0.002 * sampleRate).round();
  return [
    for (var i = 0; i < n; i++)
      square(hz, i) *
          volume *
          (i < fade
              ? i / fade
              : i >= n - fade
              ? (n - 1 - i) / fade
              : 1.0),
  ];
}

List<double> silence(double seconds) =>
    List.filled((seconds * sampleRate).round(), 0.0);

/// 16-bit mono PCM WAV; samples are clipped to [-1, 1].
Uint8List encodeWav(List<double> samples) {
  final dataBytes = samples.length * 2;
  final b = ByteData(44 + dataBytes);
  void tag(int o, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + dataBytes, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = samples[i].clamp(-1.0, 1.0);
    b.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}
