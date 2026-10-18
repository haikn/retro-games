import 'package:cave_copter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('skeleton shows a 2:1 LCD panel on the bezel', (tester) async {
    await tester.pumpWidget(const CaveCopterApp());
    final panel = tester.widget<ColoredBox>(
      find.byWidgetPredicate((w) => w is ColoredBox && w.color == lcdColor),
    );
    expect(panel, isNotNull);
    expect(find.byType(AspectRatio), findsOneWidget);
  });
}
