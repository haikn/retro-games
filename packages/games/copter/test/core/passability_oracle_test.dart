import 'package:flutter_test/flutter_test.dart';

import 'reachability_oracle.dart';

void main() {
  test('exhaustive search survives seed 1 past the end of the ramp', () {
    // 4 000 ticks = distance 2 000, where the gap reaches its minimum.
    expect(firstUnsurvivableTick(1, 4000), -1);
  });

  test(
    'exhaustive search survives 20 seeds to distance 5 000',
    () {
      for (var seed = 1; seed <= 20; seed++) {
        expect(firstUnsurvivableTick(seed, 10000), -1, reason: 'seed $seed');
      }
    },
    tags: 'slow',
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
