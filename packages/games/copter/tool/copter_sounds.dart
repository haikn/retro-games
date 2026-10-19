import 'package:lcd_kit/synth.dart';

/// Rotor (F1, softer): a square tone with rounded edges, gated into pulses
/// that fade in and out over 4 ms. The tone sits at 98–140 Hz and keeps its
/// harmonics up to about 1 kHz: phone speakers play almost nothing below
/// 300 Hz, so a lower or smoother tone is silent on a phone. Tone and pulse
/// rates divide 1 s exactly, so the 1 s loop repeats seamlessly.
const rotorChopHz = 14;

/// The rotor variants to compare by ear; [defaultRotor] ships as rotor.wav.
const rotorVariants =
    <String, ({int toneHz, double duty, double volume, double edgeMs})>{
      'rotor_a': (toneHz: 98, duty: 0.35, volume: 0.25, edgeMs: 0.5),
      'rotor_b': (toneHz: 112, duty: 0.35, volume: 0.24, edgeMs: 0.5),
      'rotor_c': (toneHz: 140, duty: 0.35, volume: 0.22, edgeMs: 0.5),
    };
const defaultRotor = 'rotor_b';

List<double> rotorVariant(String name) {
  final v = rotorVariants[name]!;
  final chop = sampleRate ~/ rotorChopHz;
  final on = (chop * v.duty).round();
  final fade = (0.004 * sampleRate).round();
  final raw = [
    for (var i = 0; i < sampleRate; i++)
      () {
        final k = i % chop;
        if (k >= on) return 0.0;
        final env = k < fade
            ? k / fade
            : (k >= on - fade ? (on - 1 - k) / fade : 1.0);
        return square(v.toneHz.toDouble(), i) * env;
      }(),
  ];
  return [for (final x in lowPass(raw, v.edgeMs, periodic: true)) x * v.volume];
}

List<double> rotorLoop() => rotorVariant(defaultRotor);

const crashNotesHz = [880.0, 660.0, 440.0, 220.0];

List<double> crashSound() => [
  for (final hz in crashNotesHz) ...[...beep(hz, 0.09, 0.32), ...silence(0.03)],
  ...beep(110, 0.18, 0.32),
];

/// File name (without extension) → generator.
const allSounds = <String, List<double> Function()>{
  'rotor': rotorLoop,
  'crash': crashSound,
  'best': bestJingle,
  'click': keyClick,
};
