import 'package:lcd_kit/synth.dart';

List<double> hopTick() => beep(620, 0.02, 0.18);

List<double> splash() => [
  for (final hz in [520.0, 390.0, 260.0, 130.0]) ...beep(hz, 0.05, 0.3),
];

List<double> crashSound() => [
  for (final hz in [700.0, 470.0, 235.0]) ...[
    ...beep(hz, 0.08, 0.32),
    ...silence(0.025),
  ],
  ...beep(100, 0.2, 0.32),
];

/// Two-tone crossing bell.
List<double> bell() => [
  ...beep(1320, 0.07, 0.25),
  ...silence(0.05),
  ...beep(1320, 0.07, 0.25),
];

/// File name (without extension) → generator.
const allSounds = <String, List<double> Function()>{
  'hop': hopTick,
  'splash': splash,
  'crash': crashSound,
  'bell': bell,
  'best': bestJingle,
  'click': keyClick,
};
