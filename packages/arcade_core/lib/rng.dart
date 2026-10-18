/// Deterministic PRNG (xoshiro128**, seeded via splitmix32).
///
/// Used instead of `dart:math` `Random`, whose sequence is not guaranteed to
/// stay the same across Dart SDK versions. All arithmetic is masked to 32 bits.
class Rng {
  Rng(int seed) {
    _sm = seed & _mask;
    _a = _splitmix32();
    _b = _splitmix32();
    _c = _splitmix32();
    _d = _splitmix32();
    if ((_a | _b | _c | _d) == 0) _a = 1;
  }

  static const _mask = 0xFFFFFFFF;

  int _sm = 0;
  int _a = 0;
  int _b = 0;
  int _c = 0;
  int _d = 0;

  int _splitmix32() {
    _sm = (_sm + 0x9E3779B9) & _mask;
    var z = _sm;
    z = ((z ^ (z >> 16)) * 0x85EBCA6B) & _mask;
    z = ((z ^ (z >> 13)) * 0xC2B2AE35) & _mask;
    return (z ^ (z >> 16)) & _mask;
  }

  static int _rotl(int x, int k) => ((x << k) | (x >> (32 - k))) & _mask;

  /// Uniform integer in [0, 2^32).
  int nextUint32() {
    final result = (_rotl((_b * 5) & _mask, 7) * 9) & _mask;
    final t = (_b << 9) & _mask;
    _c ^= _a;
    _d ^= _b;
    _b ^= _c;
    _a ^= _d;
    _c ^= t;
    _d = _rotl(_d, 11);
    return result;
  }

  /// Uniform double in [0, 1).
  double nextDouble() => nextUint32() / 4294967296.0;

  /// Uniform integer in [0, max).
  int nextInt(int max) => (nextDouble() * max).floor();

  /// Uniform double in [min, max).
  double range(double min, double max) => min + nextDouble() * (max - min);
}
