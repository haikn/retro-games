import 'package:flutter_test/flutter_test.dart';
import 'package:arcade_core/rng.dart';

void main() {
  test('golden sequence for seed 42 never changes', () {
    final rng = Rng(42);
    expect([for (var i = 0; i < 6; i++) rng.nextUint32()], goldenSeed42);
  });

  test('same seed gives the same 10 000 draws', () {
    final a = Rng(7);
    final b = Rng(7);
    for (var i = 0; i < 10000; i++) {
      expect(a.nextUint32(), b.nextUint32());
    }
  });

  test('different seeds diverge', () {
    final a = Rng(1);
    final b = Rng(2);
    final sa = [for (var i = 0; i < 8; i++) a.nextUint32()];
    final sb = [for (var i = 0; i < 8; i++) b.nextUint32()];
    expect(sa, isNot(equals(sb)));
  });

  test('outputs stay in range', () {
    final rng = Rng(3);
    for (var i = 0; i < 10000; i++) {
      final u = rng.nextUint32();
      expect(u, inInclusiveRange(0, 0xFFFFFFFF));
      final d = rng.nextDouble();
      expect(d, greaterThanOrEqualTo(0));
      expect(d, lessThan(1));
      expect(rng.nextInt(5), inInclusiveRange(0, 4));
      final r = rng.range(-2, 3);
      expect(r, greaterThanOrEqualTo(-2));
      expect(r, lessThan(3));
    }
  });

  test('nextInt covers every value', () {
    final rng = Rng(11);
    final seen = <int>{};
    for (var i = 0; i < 1000; i++) {
      seen.add(rng.nextInt(3));
    }
    expect(seen, {0, 1, 2});
  });
}

// Captured from the first implementation; a change means level sequences
// changed for every seed.
const goldenSeed42 = <int>[
  2837322924,
  544945897,
  479756282,
  3500138142,
  339756180,
  113173290,
];
