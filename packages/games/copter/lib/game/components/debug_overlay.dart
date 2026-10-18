import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';

import '../../core/collision.dart';
import '../helicopter_game.dart';

/// Debug builds only: FPS, ticks run per frame, hitbox outline.
class DebugOverlay extends Component with HasGameReference<HelicopterGame> {
  final _hitboxPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0xFFFF00FF);
  final _text = TextPaint(
    style: const TextStyle(color: Color(0xFFFF00FF), fontSize: 12),
  );
  double _fps = 0;

  @override
  void update(double dt) {
    if (dt > 0) _fps = _fps * 0.9 + (1 / dt) * 0.1;
  }

  @override
  void render(Canvas canvas) {
    final box = heliHitbox(game.sim.state.heli, game.config);
    canvas.drawRect(
      Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
      _hitboxPaint,
    );
    _text.render(
      canvas,
      'fps ${_fps.toStringAsFixed(0)}  steps ${game.stepper.lastSteps}  '
      'dist ${game.sim.state.distance}',
      Vector2(4, 2),
    );
  }
}
