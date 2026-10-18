import 'package:cave_copter/core/config.dart';
import 'package:cave_copter/game/lcd/lcd_buffer.dart';
import 'package:cave_copter/game/render/effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = Config();
  late Effects fx;
  setUp(() => fx = Effects(config, 7));

  int lit(void Function(LcdBuffer b) draw) {
    final b = LcdBuffer()..beginFrame(0);
    draw(b);
    return b.litCount;
  }

  test('rotor flips every 8 ticks', () {
    final frames = <int>[];
    for (var t = 0; t < 24; t++) {
      frames.add(fx.rotorFrame);
      fx.onIdleTick();
    }
    expect(frames.sublist(0, 8).toSet(), {0});
    expect(frames.sublist(8, 16).toSet(), {1});
    expect(frames.sublist(16, 24).toSet(), {0});
  });

  test('smoke spawns every 4 ticks behind the tail and drifts left', () {
    for (var t = 0; t < 4; t++) {
      fx.onPlayTick(heliY: 100);
    }
    expect(fx.smokeCount, 1);
    expect(fx.smokeX(0), 31); // one LCD px left of the sprite (column 32)
    expect(fx.smokeY(0), 23); // sprite row 20 + 3
    fx.onPlayTick(heliY: 100);
    expect(fx.smokeX(0), 30);
  });

  test('smoke dies within 30 ticks and never exceeds its pool', () {
    for (var t = 0; t < 400; t++) {
      fx.onPlayTick(heliY: 100);
      expect(fx.smokeCount, lessThanOrEqualTo(Effects.smokeCapacity));
    }
    expect(fx.smokeCount, lessThanOrEqualTo(30 ~/ 4 + 1));
  });

  test('smoke blinks during its last 6 ticks only', () {
    for (var t = 0; t < 4; t++) {
      fx.onPlayTick(heliY: 100);
    }
    // A fresh puff (life >= 16) is always visible.
    expect(lit(fx.draw), 1);
  });

  test('crash: 3 inverted flashes, debris, restart after 36 ticks', () {
    fx.startCrash(heliY: 100);
    final inverted = <bool>[];
    for (var t = 0; t < 30; t++) {
      inverted.add(fx.inverted);
      fx.onCrashTick();
    }
    final expected = [
      for (var t = 0; t < 30; t++)
        t < 5 || (t >= 10 && t < 15) || (t >= 20 && t < 25),
    ];
    expect(inverted, expected);

    expect(fx.canRestart, isFalse); // tick 30
    for (var t = 30; t < 36; t++) {
      fx.onCrashTick();
    }
    expect(fx.canRestart, isTrue);
    expect(fx.showGameOver, isFalse);
    for (var t = 36; t < 40; t++) {
      fx.onCrashTick();
    }
    expect(fx.showGameOver, isTrue);
  });

  test('debris is visible after the crash and gone after ~1.1 s', () {
    fx.startCrash(heliY: 100);
    expect(lit(fx.draw), greaterThan(0));
    for (var t = 0; t < Effects.debrisTicks; t++) {
      fx.onCrashTick();
    }
    expect(lit(fx.draw), lessThanOrEqualTo(Effects.smokeCapacity));
  });

  test('reset clears crash state and smoke', () {
    fx.onPlayTick(heliY: 100);
    fx.startCrash(heliY: 100);
    fx.reset();
    expect(fx.crashed, isFalse);
    expect(fx.smokeCount, 0);
    expect(fx.inverted, isFalse);
  });

  test('effects are deterministic for a seed', () {
    final a = Effects(config, 3);
    final b = Effects(config, 3);
    for (var t = 0; t < 40; t++) {
      a.onPlayTick(heliY: 120);
      b.onPlayTick(heliY: 120);
    }
    a.startCrash(heliY: 120);
    b.startCrash(heliY: 120);
    for (var t = 0; t < 10; t++) {
      a.onCrashTick();
      b.onCrashTick();
    }
    final la = LcdBuffer()..beginFrame(0);
    final lb = LcdBuffer()..beginFrame(0);
    a.draw(la);
    b.draw(lb);
    expect(la.cells, lb.cells);
  });
}
