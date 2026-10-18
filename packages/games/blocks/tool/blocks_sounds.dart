import 'package:lcd_kit/synth.dart';

List<double> rotateClick() => beep(980, 0.018, 0.2);

List<double> lockThud() => beep(180, 0.045, 0.3);

List<double> clearRun() => [
  for (final hz in [660.0, 880.0, 1100.0]) ...[
    ...beep(hz, 0.05, 0.28),
    ...silence(0.01),
  ],
];

List<double> fourRun() => [
  for (final hz in [523.0, 659.0, 784.0, 1046.0, 1318.0]) ...[
    ...beep(hz, 0.06, 0.28),
    ...silence(0.01),
  ],
];

List<double> crashSound() => [
  for (final hz in [500.0, 380.0, 260.0, 140.0]) ...[
    ...beep(hz, 0.1, 0.3),
    ...silence(0.03),
  ],
];

/// File name (without extension) → generator.
const allSounds = <String, List<double> Function()>{
  'rotate': rotateClick,
  'lock': lockThud,
  'clear': clearRun,
  'four': fourRun,
  'crash': crashSound,
  'best': bestJingle,
  'click': keyClick,
};
