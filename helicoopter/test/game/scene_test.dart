import 'package:cave_copter/core/config.dart';
import 'package:cave_copter/core/simulation.dart';
import 'package:cave_copter/game/lcd/lcd_buffer.dart';
import 'package:cave_copter/game/lcd/sprites.dart';
import 'package:cave_copter/game/render/scene.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = Config();

  LcdBuffer frame(void Function(LcdBuffer b) draw) {
    final b = LcdBuffer();
    b.beginFrame(0);
    draw(b);
    b.endFrame();
    return b;
  }

  test('HUD rule is LCD row 8, full width; HUD rows above stay empty', () {
    final sim = GameSimulation(seed: 1);
    final b = frame((b) => drawWorld(b, sim.state, config));
    for (var x = 0; x < 160; x++) {
      expect(b.isLit(x, 8), isTrue);
      for (var y = 0; y < 8; y++) {
        expect(b.isLit(x, y), isFalse);
      }
    }
  });

  test('cave pixels match the collision geometry exactly', () {
    final sim = GameSimulation(seed: 3);
    for (var t = 0; t < 7; t++) {
      sim.step(t.isEven); // odd scroll offset within a column
    }
    final s = sim.state;
    final b = frame((b) => drawWorld(b, s, config));
    final ring = s.columns;
    for (var x = 0; x < 160; x++) {
      final worldX = x * 5 + s.scrollPx;
      final i = worldX ~/ 10;
      final top = ring.topAt(i) ~/ 5;
      final bottom = ring.bottomAt(i) ~/ 5;
      for (var y = 9; y < 80; y++) {
        var ink = y < top || y >= bottom;
        if (ring.hasObstacleAt(i)) {
          ink |=
              y >= ring.obstacleTopAt(i) ~/ 5 &&
              y < ring.obstacleBottomAt(i) ~/ 5;
        }
        expect(b.isLit(x, y), ink, reason: 'cell $x,$y');
      }
    }
  });

  test('obstacles are drawn once they scroll into view', () {
    final sim = GameSimulation(seed: 3);
    while (!sim.state.crashed && sim.state.scrollPx < 1200) {
      sim.step(sim.state.heli.y > 180);
    }
    final ring = sim.state.columns;
    final withObstacle = [
      for (var i = ring.firstIndex; i <= ring.lastIndex; i++)
        if (ring.hasObstacleAt(i)) i,
    ];
    expect(withObstacle, isNotEmpty);
    final b = frame((b) => drawWorld(b, sim.state, config));
    final i = withObstacle.first;
    final x = (i * 10 - sim.state.scrollPx) ~/ 5;
    final y = ring.obstacleTopAt(i) ~/ 5;
    if (x >= 0) expect(b.isLit(x, y), isTrue);
  });

  test('helicopter is drawn at column 32 and its y floored to the grid', () {
    final b = frame((b) => drawHeli(b, 102.4, 0, config));
    final sprite = Sprites.heli[0];
    for (var sy = 0; sy < sprite.height; sy++) {
      for (var sx = 0; sx < sprite.width; sx++) {
        expect(b.isLit(32 + sx, 20 + sy), sprite.at(sx, sy));
      }
    }
  });

  test('render y interpolates between ticks', () {
    expect(interpolatedY(100, 110, 0.5), 105);
    expect(interpolatedY(100, 110, 0), 100);
  });
}
