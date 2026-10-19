// Renders the Retro LCD Games app icon: the launcher's 2×2 game tiles. Run from
// app/, then regenerate the platform icons (and re-run `flutter test`: the
// platform guard tests catch settings the icon tool has reverted before):
//   dart run tool/gen_icon.dart
//   dart run flutter_launcher_icons
import 'dart:io';

import 'package:image/image.dart' as img;

import 'icon_grids.dart';

final lcd = img.ColorRgba8(0xC7, 0xF0, 0xD8, 0xFF);
final ink = img.ColorRgba8(0x43, 0x52, 0x3D, 0xFF);
final clear = img.ColorRgba8(0, 0, 0, 0);

const size = 1024;

void _rect(img.Image image, int x, int y, int w, int h, img.Color c) =>
    img.fillRect(image, x1: x, y1: y, x2: x + w - 1, y2: y + h - 1, color: c);

/// Four tiles in a 2×2 grid; the first is inverted like the launcher's
/// selected tile.
void _tiles(
  img.Image image, {
  required int tile,
  required int gap,
  required int border,
}) {
  final grid = 2 * tile + gap;
  final origin = (size - grid) ~/ 2;
  final cell = (tile - 2 * border) * 2 ~/ 3 ~/ 12; // icon ≈ 2/3 of the tile
  for (var i = 0; i < 4; i++) {
    final x = origin + (i % 2) * (tile + gap);
    final y = origin + (i ~/ 2) * (tile + gap);
    final selected = i == 0;
    _rect(image, x, y, tile, tile, ink);
    if (!selected) {
      _rect(
        image,
        x + border,
        y + border,
        tile - 2 * border,
        tile - 2 * border,
        lcd,
      );
    }
    final rows = iconGrids[i];
    final ix = x + (tile - 12 * cell) ~/ 2;
    final iy = y + (tile - 12 * cell) ~/ 2;
    for (var r = 0; r < 12; r++) {
      for (var c = 0; c < 12; c++) {
        if (rows[r][c] == '#') {
          _rect(
            image,
            ix + c * cell,
            iy + r * cell,
            cell,
            cell,
            selected ? lcd : ink,
          );
        }
      }
    }
  }
}

void main() {
  Directory('assets/icon').createSync(recursive: true);

  final icon = img.Image(width: size, height: size, numChannels: 4)..clear(lcd);
  _tiles(icon, tile: 408, gap: 48, border: 24);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(icon));

  // Android adaptive foreground: inside the 66% safe zone.
  final fg = img.Image(width: size, height: size, numChannels: 4)..clear(clear);
  _tiles(fg, tile: 300, gap: 36, border: 18);
  File('assets/icon/icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Wrote assets/icon/icon.png and icon_foreground.png');
}
