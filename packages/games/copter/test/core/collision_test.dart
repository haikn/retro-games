import 'package:copter/core/collision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Hitbox 40×20 at (165, 150).
  const heli = Box(165, 150, 205, 170);

  group('Box.touches', () {
    test('overlap hits', () {
      expect(heli.touches(const Box(200, 160, 220, 180)), isTrue);
    });
    test('exact edge contact counts as a hit', () {
      expect(heli.touches(const Box(205, 150, 225, 170)), isTrue);
      expect(heli.touches(const Box(165, 170, 205, 190)), isTrue);
    });
    test('1 px gap is safe', () {
      expect(heli.touches(const Box(206, 150, 226, 170)), isFalse);
      expect(heli.touches(const Box(165, 171, 205, 191)), isFalse);
    });
  });

  group('hitsColumn', () {
    bool hits(Box b, {double x = 170, double top = 100, double bottom = 300}) =>
        hitsColumn(b, x: x, width: 10, top: top, bottom: bottom);

    test('fully inside the gap is safe', () {
      expect(hits(heli), isFalse);
    });
    test('crossing the ceiling hits', () {
      expect(hits(heli, top: 151), isTrue);
    });
    test('touching the ceiling exactly hits', () {
      expect(hits(heli, top: 150), isTrue);
    });
    test('1 px below the ceiling is safe', () {
      expect(hits(heli, top: 149), isFalse);
    });
    test('touching the floor exactly hits', () {
      expect(hits(heli, bottom: 170), isTrue);
    });
    test('column not overlapping in x is ignored', () {
      expect(hits(heli, x: 150, top: 200), isFalse); // right edge 160 < 165
      expect(hits(heli, x: 206, top: 200), isFalse);
    });
    test('column touching the hitbox side counts', () {
      expect(hits(heli, x: 155, top: 200), isTrue); // right edge 165
    });
    test('obstacle inside the column hits', () {
      expect(
        hitsColumn(
          heli,
          x: 170,
          width: 10,
          top: 50,
          bottom: 350,
          obstacleTop: 160,
          obstacleBottom: 220,
        ),
        isTrue,
      );
    });
    test('obstacle 1 px clear is safe', () {
      expect(
        hitsColumn(
          heli,
          x: 170,
          width: 10,
          top: 50,
          bottom: 350,
          obstacleTop: 171,
          obstacleBottom: 220,
        ),
        isFalse,
      );
    });
  });

  group('outsidePlayArea', () {
    test('touching the HUD rule or the bottom edge hits', () {
      expect(
        outsidePlayArea(const Box(0, 45, 1, 65), playTop: 45, bottom: 400),
        isTrue,
      );
      expect(
        outsidePlayArea(const Box(0, 380, 1, 400), playTop: 45, bottom: 400),
        isTrue,
      );
      expect(outsidePlayArea(heli, playTop: 45, bottom: 400), isFalse);
    });
  });
}
