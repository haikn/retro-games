import 'package:lcd_kit/lcd_kit.dart';

/// Copter's procedural sprites (spec rev 1.3).
abstract final class Sprites {
  static const _heliBody = [
    '......#...',
    '#...#####.',
    '#######.##',
    '#...#####.',
    '...######.',
  ];

  /// Helicopter, facing right; rotor frames A (long) and B (short).
  static final List<Sprite1> heli = [
    Sprite1.parse(['.########.', ..._heliBody]),
    Sprite1.parse(['...####...', ..._heliBody]),
  ];
}
