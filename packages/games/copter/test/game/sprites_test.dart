import 'package:copter/game/sprites.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('helicopter frames are 10×6 and differ only in the rotor row', () {
    expect(Sprites.heli, hasLength(2));
    final a = Sprites.heli[0];
    final b = Sprites.heli[1];
    expect((a.width, a.height), (10, 6));
    expect((b.width, b.height), (10, 6));
    var rotorDiff = false;
    for (var x = 0; x < 10; x++) {
      if (a.at(x, 0) != b.at(x, 0)) rotorDiff = true;
      for (var y = 1; y < 6; y++) {
        expect(a.at(x, y), b.at(x, y), reason: 'body pixel $x,$y');
      }
    }
    expect(rotorDiff, isTrue);
  });

  test('outside the 8×4 hitbox: only rotor, skid, tail fin and nose tip', () {
    // Spec 1.3: the 1-LCD-px inset deliberately forgives grazing contact by
    // the rotor, the skid, the tail fin (column 0) and the nose tip (column 9).
    for (final s in Sprites.heli) {
      for (var y = 1; y <= 4; y++) {
        for (final x in [0, 9]) {
          if (!s.at(x, y)) continue;
          final tailFin = x == 0;
          final noseTip = x == 9 && y == 3;
          expect(tailFin || noseTip, isTrue, reason: 'pixel $x,$y');
        }
      }
    }
  });
}
