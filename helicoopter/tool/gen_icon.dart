// Renders the app icon from the game's 1-bit helicopter sprite. Run from the
// package root, then regenerate the platform icons:
//   dart run tool/gen_icon.dart
//   dart run flutter_launcher_icons
import 'dart:io';

import 'package:cave_copter/game/lcd/sprites.dart';
import 'package:image/image.dart' as img;

final lcd = img.ColorRgba8(0xC7, 0xF0, 0xD8, 0xFF);
final ink = img.ColorRgba8(0x43, 0x52, 0x3D, 0xFF);
final clear = img.ColorRgba8(0, 0, 0, 0);

const size = 1024;

void _cell(img.Image image, int x, int y, int cell) => img.fillRect(
  image,
  x1: x,
  y1: y,
  x2: x + cell - 1,
  y2: y + cell - 1,
  color: ink,
);

/// Helicopter (rotor frame A) with a short smoke trail, centred.
void _heli(img.Image image, int cell, {int dy = 0}) {
  final sprite = Sprites.heli[0];
  const smoke = [(-2, 3), (-4, 2), (-6, 4)];
  final w = (sprite.width + 6) * cell; // include the smoke trail
  final x0 = (size - w) ~/ 2 + 6 * cell;
  final y0 = (size - sprite.height * cell) ~/ 2 + dy;
  for (var y = 0; y < sprite.height; y++) {
    for (var x = 0; x < sprite.width; x++) {
      if (sprite.at(x, y)) _cell(image, x0 + x * cell, y0 + y * cell, cell);
    }
  }
  for (final (dx, sy) in smoke) {
    _cell(image, x0 + dx * cell, y0 + sy * cell, cell);
  }
}

void main() {
  Directory('assets/icon').createSync(recursive: true);

  // Full icon (iOS, legacy Android): LCD square, jagged cave floor.
  const cell = 64; // floor pixels
  final icon = img.Image(width: size, height: size, numChannels: 4)..clear(lcd);
  _heli(icon, 52, dy: -80);
  const floor = [3, 3, 2, 2, 3, 4, 4, 3, 2, 2, 3, 3, 4, 3, 3, 2];
  for (var i = 0; i < floor.length; i++) {
    for (var r = 0; r < floor[i]; r++) {
      _cell(icon, i * cell, size - (r + 1) * cell, cell);
    }
  }
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(icon));

  // Android adaptive foreground: helicopter only, inside the 66% safe zone.
  final fg = img.Image(width: size, height: size, numChannels: 4)..clear(clear);
  _heli(fg, 40);
  File('assets/icon/icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Wrote assets/icon/icon.png and icon_foreground.png');
}
