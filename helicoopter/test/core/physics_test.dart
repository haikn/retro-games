import 'package:cave_copter/core/config.dart';
import 'package:cave_copter/core/physics.dart';
import 'package:cave_copter/core/world_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = Config();

  test('falls when released, with exact semi-implicit Euler values', () {
    final heli = HeliState(y: 100);
    stepVertical(heli, holding: false, config: config);
    expect(heli.vy, closeTo(15, 1e-9)); // 900 px/s² × 1/60 s
    expect(heli.y, closeTo(100.25, 1e-9)); // + 15 px/s × 1/60 s
  });

  test('rises while held (net 900 px/s² upward)', () {
    final heli = HeliState(y: 100);
    stepVertical(heli, holding: true, config: config);
    expect(heli.vy, closeTo(-15, 1e-9));
    expect(heli.y, closeTo(99.75, 1e-9));
  });

  test('accelerates gradually', () {
    final heli = HeliState(y: 100);
    for (var i = 0; i < 10; i++) {
      stepVertical(heli, holding: true, config: config);
    }
    expect(heli.vy, closeTo(-150, 1e-9));
  });

  test('clamps at ±360 px/s', () {
    final down = HeliState(y: 0);
    final up = HeliState(y: 0);
    for (var i = 0; i < 600; i++) {
      stepVertical(down, holding: false, config: config);
      stepVertical(up, holding: true, config: config);
    }
    expect(down.vy, config.maxVerticalSpeed);
    expect(up.vy, -config.maxVerticalSpeed);
  });
}
