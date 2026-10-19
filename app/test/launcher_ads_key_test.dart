import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_arcade/launcher/launcher_screen.dart';
import 'package:lcd_arcade/main.dart';
import 'package:lcd_kit/lcd_kit.dart';

void main() {
  Future<void> pump(WidgetTester tester, {VoidCallback? onAdPrivacy}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LauncherScreen(
          entries: launcherEntriesFor(games),
          palette: LcdPalette.active,
          onOpen: (_) {},
          onAdPrivacy: onAdPrivacy,
          banner: const SizedBox(key: ValueKey('banner'), height: 50),
        ),
      ),
    );
  }

  testWidgets('no Ads key unless the law needs it', (tester) async {
    await pump(tester);
    expect(find.text('Ads'), findsNothing);
    expect(find.text('Select'), findsOneWidget);
  });

  testWidgets('Ads key opens the privacy options; Select still works', (
    tester,
  ) async {
    var opened = 0;
    await pump(tester, onAdPrivacy: () => opened++);
    await tester.tap(find.text('Ads'));
    expect(opened, 1);
    expect(find.text('Select'), findsOneWidget);
  });

  testWidgets('the banner sits below the LCD, never over it', (tester) async {
    await pump(tester);
    final banner = tester.getRect(find.byKey(const ValueKey('banner')));
    final lcd = tester.getRect(find.byType(LcdViewport));
    expect(banner.top, greaterThanOrEqualTo(lcd.bottom));
  });

  testWidgets('tiles have the same gap across and down', (tester) async {
    await pump(tester);
    Rect tile(String title) => tester.getRect(
      find
          .ancestor(of: find.text(title), matching: find.byType(DecoratedBox))
          .first,
    );
    final copter = tile('Copter');
    final snake = tile('Snake');
    final blocks = tile('Blocks');
    final across = snake.left - copter.right;
    final down = blocks.top - copter.bottom;
    expect(across, greaterThan(0));
    expect(down, closeTo(across, 0.01));
    final select = tester.getRect(find.text('Select'));
    expect(blocks.bottom, lessThanOrEqualTo(select.top));
  });
}
