import 'package:blocks/blocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hop/hop.dart';
import 'package:lcd_arcade/main.dart';
import 'package:lcd_kit/testing.dart';
import 'package:snake/snake.dart';

/// Game-specific text must fit its portrait slots, measured with the real
/// font (decision C6: every translation must pass this too).
void main() {
  testWidgets('game names, titles and start hints fit', (tester) async {
    await tester.runAsync(loadLcdFont);
    for (final g in games) {
      final w = lcdTextWidth(g.title);
      expect(w, lessThanOrEqualTo(180), reason: 'launcher tile "${g.title}"');
    }
    for (final spec in [SnakeModule.spec, BlocksModule.spec, HopModule.spec]) {
      final header =
          lcdTextWidth(spec.title, bold: true) + lcdTextWidth('6/6') + 15;
      expect(
        header,
        lessThanOrEqualTo(380),
        reason: 'menu header ${spec.title}',
      );
      for (final line in spec.startHint) {
        expect(
          lcdTextWidth(line),
          lessThanOrEqualTo(340),
          reason: 'start hint "$line"',
        );
      }
    }
  });
}
