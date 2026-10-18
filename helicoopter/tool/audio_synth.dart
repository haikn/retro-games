import 'dart:typed_data';

/// Monophonic square-wave "phone buzzer" sounds (spec: Audio).
const sampleRate = 22050;

/// Rotor: a low square tone gated on and off; both rates divide 1 s exactly,
/// so the 1 s loop repeats seamlessly.
const rotorToneHz = 70;
const rotorChopHz = 14;

const crashNotesHz = [880.0, 660.0, 440.0, 220.0];
const bestNotesHz = [1046.5, 1318.5, 1568.0]; // C6 E6 G6

double _square(double hz, int i) =>
    ((i * hz * 2 / sampleRate).floor()).isEven ? 1.0 : -1.0;

/// One beep of [seconds], with 2 ms fades so it starts and ends at 0.
List<double> _beep(double hz, double seconds, double volume) {
  final n = (seconds * sampleRate).round();
  final fade = (0.002 * sampleRate).round();
  return [
    for (var i = 0; i < n; i++)
      _square(hz, i) *
          volume *
          (i < fade
              ? i / fade
              : i >= n - fade
              ? (n - 1 - i) / fade
              : 1.0),
  ];
}

List<double> _silence(double seconds) =>
    List.filled((seconds * sampleRate).round(), 0.0);

List<double> rotorLoop() {
  final chop = sampleRate ~/ rotorChopHz;
  final on = (chop * 0.4).round();
  return [
    for (var i = 0; i < sampleRate; i++)
      i % chop < on ? _square(rotorToneHz.toDouble(), i) * 0.18 : 0.0,
  ];
}

List<double> crashSound() => [
  for (final hz in crashNotesHz) ...[
    ..._beep(hz, 0.09, 0.32),
    ..._silence(0.03),
  ],
  ..._beep(110, 0.18, 0.32),
];

List<double> bestJingle() => [
  ..._beep(bestNotesHz[0], 0.1, 0.28),
  ..._silence(0.02),
  ..._beep(bestNotesHz[1], 0.1, 0.28),
  ..._silence(0.02),
  ..._beep(bestNotesHz[2], 0.22, 0.28),
];

List<double> keyClick() => _beep(1500, 0.025, 0.22);

/// File name (without extension) → generator.
const allSounds = <String, List<double> Function()>{
  'rotor': rotorLoop,
  'crash': crashSound,
  'best': bestJingle,
  'click': keyClick,
};

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
