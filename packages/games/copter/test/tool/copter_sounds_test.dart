import 'dart:math';

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

  test('every rotor variant is audible on a phone yet softer than before', () {
    // The first rotor: a hard 70 Hz square, gated 40 % of each pulse.
    final chop = sampleRate ~/ rotorChopHz;
    final old = [
      for (var i = 0; i < sampleRate; i++)
        i % chop < (chop * 0.4).round() ? square(70, i) * 0.18 : 0.0,
    ];
    for (final name in rotorVariants.keys) {
      final s = rotorVariant(name);
      // Phone speakers play roughly 300 Hz–3 kHz: keep at least the old
      // rotor's energy there, or the rotor is silent on a phone (F1 bug).
      expect(
        _bandRms(s, 300, 3000),
        greaterThanOrEqualTo(_bandRms(old, 300, 3000)),
        reason: name,
      );
      // Softer: far less harsh buzz above 3 kHz, and rounded edges.
      expect(
        _bandRms(s, 3000, sampleRate / 2),
        lessThan(_bandRms(old, 3000, sampleRate / 2) / 2),
        reason: name,
      );
      var maxStep = 0.0;
      for (var i = 1; i < s.length; i++) {
        final d = (s[i] - s[i - 1]).abs();
        if (d > maxStep) maxStep = d;
      }
      expect(maxStep, lessThan(0.36 / 2), reason: name); // old jumped 0.36
    }
  });

  test('every rotor variant loops seamlessly', () {
    for (final name in rotorVariants.keys) {
      final s = rotorVariant(name);
      expect(s.length, sampleRate, reason: name);
      final period = sampleRate ~/ rotorChopHz;
      for (var i = 0; i < period; i++) {
        expect(s[i], closeTo(s[s.length - period + i], 1e-6), reason: name);
      }
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

/// RMS of [s] between [loHz] and [hiHz] (one-pole filters; a periodic loop).
double _bandRms(List<double> s, double loHz, double hiHz) {
  final lo = lowPass(s, 1000 / (2 * pi * loHz), periodic: true);
  final high = [for (var i = 0; i < s.length; i++) s[i] - lo[i]];
  final band = hiHz >= sampleRate / 2
      ? high
      : lowPass(high, 1000 / (2 * pi * hiHz), periodic: true);
  return sqrt(band.fold(0.0, (a, x) => a + x * x) / s.length);
}
