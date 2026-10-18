import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_kit/lcd_kit.dart';

void main() {
  test('parse reads # as ink and . as off', () {
    final s = Sprite1.parse(['#..', '.##']);
    expect(s.width, 3);
    expect(s.height, 2);
    expect(s.at(0, 0), isTrue);
    expect(s.at(1, 0), isFalse);
    expect(s.at(2, 1), isTrue);
  });

  test('ragged or unknown characters are rejected', () {
    expect(() => Sprite1.parse(['##', '#']), throwsArgumentError);
    expect(() => Sprite1.parse(['#x']), throwsArgumentError);
    expect(() => Sprite1.parse([]), throwsArgumentError);
  });
}
