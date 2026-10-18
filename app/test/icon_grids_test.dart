import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_arcade/main.dart';

import '../tool/icon_grids.dart';

void main() {
  test('the app icon uses the games\' current launcher icons, in order', () {
    expect(iconGrids, [for (final g in games) g.icon]);
  });
}
