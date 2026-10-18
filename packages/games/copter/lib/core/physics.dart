import 'config.dart';
import 'world_state.dart';

/// Advances [heli] by one fixed tick (semi-implicit Euler, clamped speed).
void stepVertical(
  HeliState heli, {
  required bool holding,
  required Config config,
}) {
  final accel = config.gravity - (holding ? config.thrust : 0);
  heli.vy = (heli.vy + accel * config.fixedDt).clamp(
    -config.maxVerticalSpeed,
    config.maxVerticalSpeed,
  );
  heli.y += heli.vy * config.fixedDt;
}
