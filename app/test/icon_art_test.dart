import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../tool/icon_art.dart';

void main() {
  test('the icon art is a 16×16 grid of lit and unlit pixels', () {
    expect(handheldIcon, hasLength(16));
    for (final row in handheldIcon) {
      expect(row, hasLength(16));
      expect(row, matches(RegExp(r'^[.#]+$')));
    }
  });

  test('the adaptive foreground grid fits the round launcher mask', () {
    // 30 px cells: 480 px grid; its diagonal must fit the 72/108 visible
    // circle of a 1024 px adaptive icon.
    const grid = 16 * 30;
    expect(sqrt(2) * grid, lessThanOrEqualTo(1024 * 72 / 108));
  });
}
