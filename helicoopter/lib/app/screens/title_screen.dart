import 'package:flutter/material.dart';

import '../../core/rng.dart';
import '../../game/lcd/lcd_buffer.dart';
import '../../game/lcd/lcd_text.dart';
import '../../game/lcd/palette.dart';
import '../../game/lcd/sprites.dart';
import '../lcd/lcd_widgets.dart';

/// Cold-start splash: logo, a helicopter bobbing over a static cave strip,
/// blinking `Tap to start`. The tap itself is handled by the screen host.
class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key, required this.palette});

  final LcdPalette palette;

  // Static cave strip: 2-LCD-px columns, thin ceiling, floor rows 62–70.
  static final List<(int, int)> _strip = () {
    final rng = Rng(7);
    var ceil = 3;
    var floor = 66;
    return [
      for (var x = 0; x < 80; x++)
        (
          ceil = (ceil + rng.nextInt(3) - 1).clamp(1, 5),
          floor = (floor + rng.nextInt(3) - 1).clamp(62, 70),
        ),
    ];
  }();

  static const _smoke = [
    (-2, 3),
    (-4, 2),
    (-5, 4),
    (-8, 3),
    (-11, 2),
    (-15, 4),
  ];

  static void compose(LcdBuffer b, int tick) {
    for (var i = 0; i < _strip.length; i++) {
      final (ceil, floor) = _strip[i];
      b.fillRect(i * 2, 0, 2, ceil);
      b.fillRect(i * 2, floor, 2, b.height - floor);
    }
    const hx = 32;
    final hy = 37 + (tick ~/ 36) % 2;
    b.blit(Sprites.heli[(tick ~/ 8) % 2], hx, hy);
    for (final (dx, dy) in _smoke) {
      b.set(hx + dx, 37 + dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: LcdSceneView(palette: palette, compose: compose),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 40,
          height: 80,
          child: Center(
            child: Text('CAVE COPTER', style: LcdText.title(palette.ink)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 245,
          height: 50,
          child: Blink(
            child: Center(
              child: Text('Tap to start', style: LcdText.body(palette.ink)),
            ),
          ),
        ),
      ],
    );
  }
}
