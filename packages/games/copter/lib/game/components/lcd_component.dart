import 'dart:ui';

import 'package:flame/components.dart';

import '../helicopter_game.dart';
import '../render/scene.dart';

import 'package:lcd_kit/lcd_kit.dart';

/// Composes the frame into the game's LCD buffer and paints it.
class LcdComponent extends Component with HasGameReference<HelicopterGame> {
  late final LcdPainter _painter;

  @override
  Future<void> onLoad() async {
    _painter = LcdPainter(
      palette: game.palette,
      cellSize: game.config.lcdPixel,
      cells: game.buffer.width * game.buffer.height,
    );
  }

  @override
  void update(double dt) {
    final b = game.buffer;
    final c = game.config;
    final fx = game.effects;
    final heli = game.sim.state.heli;
    b.beginFrame(dt);
    drawWorld(b, game.sim.state, c);
    if (game.phase.value != GamePhase.crashed) {
      final y = game.phase.value == GamePhase.playing
          ? interpolatedY(heli.prevY, heli.y, game.stepper.alpha)
          : heli.y;
      drawHeli(b, y, fx.rotorFrame, c);
    }
    fx.draw(b);
    b.inverted = fx.inverted;
    b.endFrame();
  }

  @override
  void render(Canvas canvas) => _painter.paint(canvas, game.buffer);
}
