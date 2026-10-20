// Renders the Retro LCD Games app icon: a pixel handheld on the LCD (design
// canvas idea A). Run from app/, then regenerate the platform icons (and
// re-run `flutter test`: the platform guard tests catch settings the icon
// tool has reverted before):
//   dart run tool/gen_icon.dart
//   dart run flutter_launcher_icons
import 'dart:io';

import 'package:image/image.dart' as img;

import 'icon_art.dart';

final lcd = img.ColorRgba8(0xC7, 0xF0, 0xD8, 0xFF);
final ink = img.ColorRgba8(0x3E, 0x4B, 0x37, 0xFF);
// Unlit LCD pixels: just visible, like the screen in the games.
final unlit = img.ColorRgba8(0xB9, 0xE3, 0xC9, 0xFF);
final clear = img.ColorRgba8(0, 0, 0, 0);

const size = 1024;

/// Draws [art] centred, [cell] px per LCD pixel with a [gap] between them.
void _art(img.Image image, List<String> art, {required int cell, int gap = 0}) {
  final n = art.length;
  final origin = (size - n * cell) ~/ 2;
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < art[r].length; c++) {
      final x = origin + c * cell;
      final y = origin + r * cell;
      img.fillRect(
        image,
        x1: x,
        y1: y,
        x2: x + cell - gap - 1,
        y2: y + cell - gap - 1,
        color: art[r][c] == '#' ? ink : unlit,
      );
    }
  }
}

void main() {
  Directory('assets/icon').createSync(recursive: true);

  // iOS and legacy Android: art across ~70% of the square.
  final icon = img.Image(width: size, height: size, numChannels: 4)..clear(lcd);
  _art(icon, handheldIcon, cell: 45, gap: 4);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(icon));

  // Android adaptive foreground (on the LCD-green background): the whole
  // 16×16 grid stays inside the round mask some launchers use.
  final fg = img.Image(width: size, height: size, numChannels: 4)..clear(clear);
  _art(fg, handheldIcon, cell: 30, gap: 3);
  File('assets/icon/icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Wrote assets/icon/icon.png and icon_foreground.png');
}
