import 'dart:typed_data';

/// 1-bit sprite parsed from rows of `#` (ink) and `.` (off).
class Sprite1 {
  Sprite1._(this.width, this.height, this._bits);

  factory Sprite1.parse(List<String> rows) {
    if (rows.isEmpty || rows.first.isEmpty) {
      throw ArgumentError('Sprite needs at least one pixel');
    }
    final width = rows.first.length;
    final bits = Uint8List(width * rows.length);
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      if (row.length != width) {
        throw ArgumentError('Row $y has ${row.length} pixels, expected $width');
      }
      for (var x = 0; x < width; x++) {
        switch (row[x]) {
          case '#':
            bits[y * width + x] = 1;
          case '.':
            break;
          default:
            throw ArgumentError('Unknown pixel "${row[x]}" at $x,$y');
        }
      }
    }
    return Sprite1._(width, rows.length, bits);
  }

  final int width;
  final int height;
  final Uint8List _bits;

  bool at(int x, int y) => _bits[y * width + x] == 1;
}

/// Procedural sprites from the spec (rev 1.3).
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
