import 'package:flutter/widgets.dart';

enum Dir { up, down, left, right }

/// Touch input for arcade games, in virtual px of the LCD screen.
sealed class GameInput {
  const GameInput();
}

/// A finger touched the screen.
class PressInput extends GameInput {
  const PressInput(this.position);
  final Offset position;
}

/// The finger moved; deltas since the previous move.
class DragInput extends GameInput {
  const DragInput(this.dx, this.dy);
  final double dx;
  final double dy;
}

/// The gesture moved far enough to count as a swipe, sent as soon as the
/// threshold is crossed so turns react immediately. Once per gesture, or
/// once per change of direction with [ArcadeGestureLayer.continuousSwipes].
class SwipeInput extends GameInput {
  const SwipeInput(this.dir);
  final Dir dir;
}

/// The finger lifted. [tap] is a short touch that never became a swipe;
/// [vy] is the downward speed at release in px/s (flicks).
class ReleaseInput extends GameInput {
  const ReleaseInput({required this.tap, this.vx = 0, this.vy = 0});
  final bool tap;
  final double vx;
  final double vy;
}

/// Turns raw pointer events of the first finger into [GameInput]s.
class ArcadeGestureLayer extends StatefulWidget {
  const ArcadeGestureLayer({
    super.key,
    required this.onInput,
    required this.child,
    this.swipeThreshold = 30,
    this.continuousSwipes = false,
  });

  final void Function(GameInput input) onInput;
  final Widget child;

  /// Movement (virtual px) after which a gesture is a swipe.
  final double swipeThreshold;

  /// Keep reading swipes until the finger lifts: after each one the
  /// gesture is measured again from the finger's current position, and a
  /// new [SwipeInput] is sent whenever it heads in a new direction (one
  /// stroke can turn right, then up, then left).
  final bool continuousSwipes;

  @override
  State<ArcadeGestureLayer> createState() => _ArcadeGestureLayerState();
}

class _ArcadeGestureLayerState extends State<ArcadeGestureLayer> {
  int? _pointer;
  Offset _start = Offset.zero;
  Offset _last = Offset.zero;
  Duration _startTime = Duration.zero;
  Duration _lastTime = Duration.zero;
  Offset _velocity = Offset.zero;
  bool _swiped = false;
  Dir? _lastDir;

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _start = _last = e.localPosition;
    _startTime = _lastTime = e.timeStamp;
    _velocity = Offset.zero;
    _swiped = false;
    _lastDir = null;
    widget.onInput(PressInput(e.localPosition));
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final delta = e.localPosition - _last;
    final dt = (e.timeStamp - _lastTime).inMicroseconds / 1e6;
    if (dt > 0) _velocity = delta / dt;
    _last = e.localPosition;
    _lastTime = e.timeStamp;
    widget.onInput(DragInput(delta.dx, delta.dy));
    final total = e.localPosition - _start;
    final crossed =
        total.dx.abs() >= widget.swipeThreshold ||
        total.dy.abs() >= widget.swipeThreshold;
    if (!crossed || (_swiped && !widget.continuousSwipes)) return;
    final dir = total.dx.abs() > total.dy.abs()
        ? (total.dx > 0 ? Dir.right : Dir.left)
        : (total.dy > 0 ? Dir.down : Dir.up);
    _swiped = true;
    if (widget.continuousSwipes) _start = e.localPosition;
    if (dir == _lastDir) return; // still the same stroke
    _lastDir = dir;
    widget.onInput(SwipeInput(dir));
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final moved = (e.localPosition - _start).distance;
    final held = e.timeStamp - _startTime;
    final tap =
        !_swiped && moved < 15 && held < const Duration(milliseconds: 300);
    widget.onInput(ReleaseInput(tap: tap, vx: _velocity.dx, vy: _velocity.dy));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: widget.child,
    );
  }
}
