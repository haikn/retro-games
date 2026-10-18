import '../../core/config.dart';
import '../../core/world_state.dart';
import '../lcd/lcd_buffer.dart';
import '../lcd/sprites.dart';

/// Draws the HUD rule, the cave walls and the obstacles of [state].
///
/// All cave geometry is grid aligned and the scroll is a whole number of LCD
/// pixels, so what is drawn is exactly what collides.
void drawWorld(LcdBuffer b, WorldState state, Config c) {
  final px = c.lcdPixel;
  final playTopRow = (c.playTop / px).round();
  b.fillRect(0, playTopRow - 1, b.width, 1);

  final colCells = (c.columnWidth / px).round();
  final ring = state.columns;
  for (var i = ring.firstIndex; i <= ring.lastIndex; i++) {
    final x = ((i * c.columnWidth - state.scrollPx) / px).round();
    final top = (ring.topAt(i) / px).round();
    final bottom = (ring.bottomAt(i) / px).round();
    b.fillRect(x, playTopRow, colCells, top - playTopRow);
    b.fillRect(x, bottom, colCells, b.height - bottom);
    if (ring.hasObstacleAt(i)) {
      final oTop = (ring.obstacleTopAt(i) / px).round();
      final oBottom = (ring.obstacleBottomAt(i) / px).round();
      b.fillRect(x, oTop, colCells, oBottom - oTop);
    }
  }
}

/// LCD row of the sprite's top edge for a (possibly fractional) y in px.
int heliRow(double y, Config c) => (y / c.lcdPixel).floor();

/// LCD column of the sprite's left edge.
int heliColumn(Config c) => (c.heliX / c.lcdPixel).round();

void drawHeli(LcdBuffer b, double y, int rotorFrame, Config c) =>
    b.blit(Sprites.heli[rotorFrame], heliColumn(c), heliRow(y, c));

/// Helicopter y for rendering, between the last two ticks.
double interpolatedY(double prevY, double y, double alpha) =>
    prevY + (y - prevY) * alpha;
