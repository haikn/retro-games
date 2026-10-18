import 'dart:ui';

import 'package:flame/components.dart';

import '../helicopter_game.dart';
import '../lcd/lcd_text.dart';

/// Top HUD strip: distance on the left, best on the right (`HI 00456`).
/// Follows the crash inversion so it flashes with the rest of the screen.
class HudComponent extends Component with HasGameReference<HelicopterGame> {
  static const margin = 25.0;

  TextPaint? _paint;
  Color? _color;

  /// Vertical centre of the HUD strip (above the rule at LCD row 8).
  double get _centerY => (game.config.playTop - game.config.lcdPixel) / 2;

  @override
  void render(Canvas canvas) {
    final palette = game.palette;
    final color = game.buffer.inverted ? palette.lcd : palette.ink;
    if (color != _color) {
      _color = color;
      _paint = TextPaint(style: LcdText.body(color));
    }
    final paint = _paint!;
    paint.render(
      canvas,
      pad5(game.distance),
      Vector2(margin, _centerY),
      anchor: Anchor.centerLeft,
    );
    paint.render(
      canvas,
      'HI ${pad5(game.best)}',
      Vector2(game.config.worldWidth - margin, _centerY),
      anchor: Anchor.centerRight,
    );
  }
}
