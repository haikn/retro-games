import 'package:lcd_kit/synth.dart';

List<double> eatBlip() => beep(880, 0.04, 0.3);

List<double> bonusChirp() => [
  ...beep(1200, 0.05, 0.28),
  ...silence(0.015),
  ...beep(1600, 0.07, 0.28),
];

List<double> crashSound() => [
  for (final hz in [660.0, 440.0, 220.0]) ...[
    ...beep(hz, 0.09, 0.32),
    ...silence(0.03),
  ],
  ...beep(110, 0.2, 0.32),
];

/// File name (without extension) → generator.
const allSounds = <String, List<double> Function()>{
  'eat': eatBlip,
  'bonus': bonusChirp,
  'crash': crashSound,
  'best': bestJingle,
  'click': keyClick,
};
