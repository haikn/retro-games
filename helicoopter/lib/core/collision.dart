import 'config.dart';
import 'world_state.dart';

/// Axis-aligned box given by its edges. Edge contact counts as touching.
class Box {
  const Box(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  bool touches(Box o) =>
      left <= o.right && o.left <= right && top <= o.bottom && o.top <= bottom;
}

/// Whether [hitbox] touches the ceiling, floor or obstacle of one column.
bool hitsColumn(
  Box hitbox, {
  required double x,
  required double width,
  required double top,
  required double bottom,
  double? obstacleTop,
  double? obstacleBottom,
}) {
  if (x > hitbox.right || x + width < hitbox.left) return false;
  if (hitbox.top <= top || hitbox.bottom >= bottom) return true;
  return obstacleTop != null &&
      obstacleBottom != null &&
      hitbox.top <= obstacleBottom &&
      hitbox.bottom >= obstacleTop;
}

/// Whether [hitbox] touches or leaves the play area (defensive bound).
bool outsidePlayArea(
  Box hitbox, {
  required double playTop,
  required double bottom,
}) => hitbox.top <= playTop || hitbox.bottom >= bottom;

/// The helicopter's hitbox for its current y.
Box heliHitbox(HeliState heli, Config config) {
  final left = config.heliX + config.hitboxInset;
  final top = heli.y + config.hitboxInset;
  return Box(left, top, left + config.hitboxWidth, top + config.hitboxHeight);
}

/// Whether the helicopter in [state] has crashed.
bool collides(WorldState state, Config config) {
  final box = heliHitbox(state.heli, config);
  if (outsidePlayArea(
    box,
    playTop: config.playTop,
    bottom: config.worldHeight,
  )) {
    return true;
  }
  final ring = state.columns;
  final w = config.columnWidth;
  final first = ((box.left + state.scrollPx - w) / w).floor();
  final last = ((box.right + state.scrollPx) / w).floor();
  for (var i = first; i <= last; i++) {
    if (i < ring.firstIndex || i > ring.lastIndex) continue;
    final has = ring.hasObstacleAt(i);
    if (hitsColumn(
      box,
      x: i * w - state.scrollPx,
      width: w,
      top: ring.topAt(i),
      bottom: ring.bottomAt(i),
      obstacleTop: has ? ring.obstacleTopAt(i) : null,
      obstacleBottom: has ? ring.obstacleBottomAt(i) : null,
    )) {
      return true;
    }
  }
  return false;
}
