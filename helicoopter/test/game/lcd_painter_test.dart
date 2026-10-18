import 'dart:ui';

import 'package:cave_copter/game/lcd/lcd_buffer.dart';
import 'package:cave_copter/game/lcd/lcd_painter.dart';
import 'package:cave_copter/game/lcd/palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Image> paint(LcdBuffer b, {LcdPalette palette = LcdPalette.green}) {
    final recorder = PictureRecorder();
    LcdPainter(palette: palette, cellSize: 5).paint(Canvas(recorder), b);
    return recorder.endRecording().toImage(b.width * 5, b.height * 5);
  }

  Future<Color> pixel(Image image, int x, int y) async {
    final data = (await image.toByteData(format: ImageByteFormat.rawRgba))!;
    final o = (y * image.width + x) * 4;
    return Color.fromARGB(
      data.getUint8(o + 3),
      data.getUint8(o),
      data.getUint8(o + 1),
      data.getUint8(o + 2),
    );
  }

  const noGrid = LcdPalette(
    lcd: Color(0xFFC7F0D8),
    ink: Color(0xFF43523D),
    bezel: Color(0xFF1E2219),
    gridOpacity: 0,
  );

  test('lit cells are ink, others lcd; a cell is exactly 5×5 px', () async {
    final b = LcdBuffer(width: 4, height: 2)..beginFrame(0);
    b.set(1, 0);
    b.endFrame();
    final img = await paint(b, palette: noGrid);
    expect(await pixel(img, 7, 2), noGrid.ink); // inside cell (1,0)
    expect(await pixel(img, 5, 0), noGrid.ink); // its top-left corner
    expect(await pixel(img, 9, 4), noGrid.ink); // its bottom-right corner
    expect(await pixel(img, 10, 2), noGrid.lcd); // next cell
    expect(await pixel(img, 4, 2), noGrid.lcd); // previous cell
    expect(await pixel(img, 7, 7), noGrid.lcd); // row below
  });

  test('inverted swaps the two tones', () async {
    final b = LcdBuffer(width: 2, height: 1)..beginFrame(0);
    b.set(0, 0);
    b.inverted = true;
    b.endFrame();
    final img = await paint(b, palette: noGrid);
    expect(await pixel(img, 2, 2), noGrid.lcd);
    expect(await pixel(img, 7, 2), noGrid.ink);
  });

  test('ghost pixels are drawn between the two tones', () async {
    final b = LcdBuffer(width: 2, height: 1)..beginFrame(0);
    b.set(0, 0);
    b.endFrame();
    b.beginFrame(1 / 60);
    b.endFrame();
    final img = await paint(b, palette: noGrid);
    final ghost = await pixel(img, 2, 2);
    expect(ghost, isNot(noGrid.ink));
    expect(ghost, isNot(noGrid.lcd));
  });

  test('painting with the grid does not throw and keeps cells ink', () async {
    final b = LcdBuffer(width: 160, height: 80)..beginFrame(0);
    b.fillRect(0, 0, 160, 1);
    b.endFrame();
    final img = await paint(b);
    expect(await pixel(img, 2, 2), LcdPalette.green.ink);
  });
}
