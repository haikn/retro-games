import 'package:cave_copter/core/world_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('push and read back by world index', () {
    final ring = ColumnRing(4);
    ring.push(top: 50, bottom: 300);
    ring.push(top: 55, bottom: 305, obstacleTop: 100, obstacleBottom: 160);
    expect(ring.length, 2);
    expect(ring.firstIndex, 0);
    expect(ring.lastIndex, 1);
    expect(ring.topAt(0), 50);
    expect(ring.bottomAt(1), 305);
    expect(ring.hasObstacleAt(0), isFalse);
    expect(ring.hasObstacleAt(1), isTrue);
    expect(ring.obstacleTopAt(1), 100);
    expect(ring.obstacleBottomAt(1), 160);
  });

  test('wraps around while keeping world indices', () {
    final ring = ColumnRing(3);
    for (var i = 0; i < 3; i++) {
      ring.push(top: i * 5.0, bottom: 300);
    }
    ring.dropFirst();
    ring.push(top: 15, bottom: 300);
    ring.dropFirst();
    ring.push(top: 20, bottom: 300, obstacleTop: 1, obstacleBottom: 2);
    expect(ring.firstIndex, 2);
    expect(ring.lastIndex, 4);
    expect([for (var i = 2; i <= 4; i++) ring.topAt(i)], [10, 15, 20]);
    expect(ring.hasObstacleAt(3), isFalse);
    expect(ring.hasObstacleAt(4), isTrue);
  });

  test('pushing into a full ring throws', () {
    final ring = ColumnRing(1)..push(top: 0, bottom: 1);
    expect(() => ring.push(top: 0, bottom: 1), throwsStateError);
  });

  test('reading outside the stored range throws', () {
    final ring = ColumnRing(2)..push(top: 0, bottom: 1);
    expect(() => ring.topAt(1), throwsRangeError);
  });
}
