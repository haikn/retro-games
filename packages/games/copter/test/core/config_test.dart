import 'package:copter/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = Config();

  test('default config satisfies every invariant', () {
    expect(config.invariantViolations(), isEmpty);
    expect(config.assertInvariants, returnsNormally);
  });

  test('derived values match the spec', () {
    expect(config.scrollPxPerTick, 5);
    expect(config.maxVerticalPerTick, closeTo(6, 1e-9));
    expect(config.climbMargin, closeTo(6, 1e-9));
    expect(config.hitboxWidth, 40);
    expect(config.hitboxHeight, 20);
    expect(config.playHeight, 355);
    expect(config.ringCapacity, 82);
  });

  test('anti-tunnelling violation is reported', () {
    const fast = Config(scrollSpeed: 900);
    expect(fast.invariantViolations(), isNotEmpty);
    expect(fast.assertInvariants, throwsStateError);
  });

  test('impassable obstacle configuration is reported', () {
    const tight = Config(minGap: 150);
    expect(
      tight.invariantViolations(),
      contains(contains('minPassableHeight')),
    );
  });

  test('walk step larger than climb margin is reported', () {
    const steep = Config(walkStep: 10);
    expect(steep.invariantViolations(), contains(contains('walkStep')));
  });
}
