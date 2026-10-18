import 'package:lcd_kit/synth.dart';

/// Rotor: a low square tone gated on and off; both rates divide 1 s exactly,
/// so the 1 s loop repeats seamlessly.
const rotorToneHz = 70;
const rotorChopHz = 14;

const crashNotesHz = [880.0, 660.0, 440.0, 220.0];

List<double> rotorLoop() {
  final chop = sampleRate ~/ rotorChopHz;
  final on = (chop * 0.4).round();
  return [
    for (var i = 0; i < sampleRate; i++)
      i % chop < on ? square(rotorToneHz.toDouble(), i) * 0.18 : 0.0,
  ];
}

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
