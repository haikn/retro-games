/// Monophonic square-wave "phone buzzer" synthesis for the games' sound
/// scripts (pure Dart; used by `tool/gen_audio.dart` in each game).
library;

import 'dart:typed_data';

const sampleRate = 22050;

/// Square wave at [hz], sample [i]: +1 or -1.
double square(double hz, int i) =>
    ((i * hz * 2 / sampleRate).floor()).isEven ? 1.0 : -1.0;

/// [samples] through a one-pole low-pass with time constant [ms]; rounds
/// square-wave edges into a softer buzz. Pre-rolled over one cycle of a
/// periodic signal so a loop stays seamless.
List<double> lowPass(List<double> samples, double ms, {bool periodic = false}) {
  final a = 1 - _exp(-1 / (ms / 1000 * sampleRate));
  var y = 0.0;
  if (periodic) {
    for (final x in samples) {
      y += a * (x - y);
    }
  }
  return [for (final x in samples) y += a * (x - y)];
}

double _exp(double x) {
  // e^x for small negative x, without dart:math (keeps this file pure).
  var sum = 1.0;
  var term = 1.0;
  for (var n = 1; n < 20; n++) {
    term *= x / n;
    sum += term;
  }
  return sum;
}

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

/// Menu key click shared by every game (`click.wav`).
List<double> keyClick() => beep(1500, 0.025, 0.22);

/// Three-note rising new-best jingle shared by every game (`best.wav`).
List<double> bestJingle() => [
  ...beep(1046.5, 0.1, 0.28),
  ...silence(0.02),
  ...beep(1318.5, 0.1, 0.28),
  ...silence(0.02),
  ...beep(1568.0, 0.22, 0.28),
];

/// Writes each sound as `<dir>/<name>.wav`; returns the written paths.
List<String> writeSounds(
  String dir,
  Map<String, List<double> Function()> sounds,
  void Function(String path, List<int> bytes) write,
) => [
  for (final MapEntry(key: name, value: make) in sounds.entries)
    () {
      final path = '$dir/$name.wav';
      write(path, encodeWav(make()));
      return path;
    }(),
];
