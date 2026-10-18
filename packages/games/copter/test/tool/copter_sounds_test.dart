import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_kit/synth.dart';

import '../../tool/copter_sounds.dart';

void main() {
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

  test('crash beeps descend', () {
    expect(
      crashNotesHz,
      orderedEquals([...crashNotesHz]..sort((a, b) => b.compareTo(a))),
    );
  });
}
