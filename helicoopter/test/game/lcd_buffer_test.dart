import 'package:cave_copter/game/lcd/lcd_buffer.dart';
import 'package:cave_copter/game/lcd/sprites.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LcdBuffer b;
  setUp(() => b = LcdBuffer(width: 8, height: 4, ghostDuration: 0.06));

  test('set and read cells; out-of-range writes are clipped', () {
    b.beginFrame(0);
    b.set(1, 2);
    b.set(-1, 0);
    b.set(8, 0);
    b.set(0, 4);
    expect(b.isLit(1, 2), isTrue);
    expect(b.isLit(2, 1), isFalse);
    expect(b.isLit(-1, 0), isFalse);
    expect(b.litCount, 1);
  });

  test('fillRect clips to the screen', () {
    b.beginFrame(0);
    b.fillRect(6, 2, 5, 5);
    expect(b.litCount, 4); // x 6..7, y 2..3
    expect(b.isLit(7, 3), isTrue);
  });

  test('fillRect with empty size draws nothing', () {
    b.beginFrame(0);
    b.fillRect(2, 2, 0, 3);
    b.fillRect(2, 2, 3, -1);
    expect(b.litCount, 0);
  });

  test('beginFrame clears the previous frame', () {
    b.beginFrame(0);
    b.set(0, 0);
    b.endFrame();
    b.beginFrame(1 / 60);
    expect(b.litCount, 0);
  });

  test('blit draws only the sprite\'s ink pixels, clipped', () {
    final s = Sprite1.parse(['#.', '.#']);
    b.beginFrame(0);
    b.blit(s, 7, 3);
    expect(b.isLit(7, 3), isTrue);
    expect(b.litCount, 1);
    b.blit(s, 0, 0);
    expect(b.isLit(0, 0), isTrue);
    expect(b.isLit(1, 0), isFalse);
    expect(b.isLit(1, 1), isTrue);
  });

  test('a pixel that switches off leaves a fading ghost', () {
    b.beginFrame(0);
    b.set(3, 1);
    b.endFrame();
    expect(b.ghostLevel(3, 1), 0);

    b.beginFrame(1 / 60);
    b.endFrame();
    expect(b.ghostLevel(3, 1), closeTo(1, 1e-6));

    b.beginFrame(0.03);
    b.endFrame();
    expect(b.ghostLevel(3, 1), closeTo(0.5, 1e-6));

    b.beginFrame(0.05);
    b.endFrame();
    expect(b.ghostLevel(3, 1), 0);
  });

  test('a lit pixel has no ghost', () {
    b.beginFrame(0);
    b.set(3, 1);
    b.endFrame();
    b.beginFrame(1 / 60);
    b.endFrame();
    b.beginFrame(1 / 60);
    b.set(3, 1);
    b.endFrame();
    expect(b.ghostLevel(3, 1), 0);
  });

  test('ghosting can be turned off', () {
    final plain = LcdBuffer(width: 2, height: 2, ghostDuration: 0);
    plain.beginFrame(0);
    plain.set(0, 0);
    plain.endFrame();
    plain.beginFrame(1 / 60);
    plain.endFrame();
    expect(plain.ghostLevel(0, 0), 0);
  });
}
