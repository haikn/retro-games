import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_kit/lcd_kit.dart';
import 'package:lcd_kit/testing.dart';

void main() {
  Future<void> pumpMenu(WidgetTester tester, int count, Size size) async {
    await tester.runAsync(loadLcdFont);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LcdViewport(
          size: size,
          child: LcdMenuScreen(
            palette: LcdPalette.green,
            title: 'Menu',
            items: [
              for (var i = 0; i < count; i++) LcdMenuItem('Item $i', () {}),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a portrait menu that fits has no scrollbar', (tester) async {
    await pumpMenu(tester, 6, lcdPortrait);
    expect(find.byType(LcdScrollbar), findsNothing);
  });

  testWidgets('a landscape menu of 5 rows fits above the soft key', (
    tester,
  ) async {
    await pumpMenu(tester, 5, lcdLandscape);
    expect(find.byType(LcdScrollbar), findsNothing);
    final last = tester.getRect(find.text('Item 4'));
    final soft = tester.getRect(find.text('Select'));
    expect(last.bottom, lessThanOrEqualTo(soft.top));
  });

  testWidgets('a longer menu scrolls and shows the scrollbar', (tester) async {
    await pumpMenu(tester, 9, lcdLandscape);
    expect(find.byType(LcdScrollbar), findsOneWidget);
    expect(find.text('Item 8'), findsNothing);
    await tester.drag(find.text('Item 2'), const Offset(0, -300));
    await tester.pump();
    expect(find.text('Item 8'), findsOneWidget);
  });
}
