import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_kit/lcd_kit.dart';

void main() {
  Future<List<Dir>> stroke(
    WidgetTester tester,
    List<Offset> moves, {
    bool continuous = false,
    double threshold = 30,
  }) async {
    final swipes = <Dir>[];
    await tester.pumpWidget(
      ArcadeGestureLayer(
        swipeThreshold: threshold,
        continuousSwipes: continuous,
        onInput: (i) => i is SwipeInput ? swipes.add(i.dir) : null,
        child: const SizedBox(width: 400, height: 800),
      ),
    );
    final g = await tester.startGesture(const Offset(200, 400));
    for (final m in moves) {
      await g.moveBy(m);
    }
    await g.up();
    return swipes;
  }

  const right = Offset(10, 0);
  const up = Offset(0, -10);
  const left = Offset(-10, 0);

  testWidgets('by default one stroke is one swipe', (tester) async {
    final swipes = await stroke(tester, [right, right, right, up, up, up, up]);
    expect(swipes, [Dir.right]);
  });

  testWidgets('continuous: one stroke turns right, up, then left', (
    tester,
  ) async {
    final swipes = await stroke(
      tester,
      [
        right, right, // 20 px: past the 18-px threshold
        right, right, right, right, // further right: no repeat
        up, up,
        left, left,
      ],
      continuous: true,
      threshold: 18,
    );
    expect(swipes, [Dir.right, Dir.up, Dir.left]);
  });

  testWidgets('continuous: a small wobble does not turn', (tester) async {
    final swipes = await stroke(
      tester,
      [right, right, const Offset(10, -5), const Offset(10, 5), right, right],
      continuous: true,
      threshold: 18,
    );
    expect(swipes, [Dir.right]);
  });

  testWidgets('a tap is still a tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      ArcadeGestureLayer(
        continuousSwipes: true,
        onInput: (i) => i is ReleaseInput && i.tap ? taps++ : null,
        child: const SizedBox(width: 400, height: 800),
      ),
    );
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 1);
  });
}
