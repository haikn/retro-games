import 'package:flutter_test/flutter_test.dart';
import 'package:hop/core/lanes.dart';

void main() {
  test('objects move with the tick and wrap around the 144-px loop', () {
    const lane = Lane.road(
      index: 3,
      dir: 1,
      speed: 1,
      objects: [Mover(32, 12)],
    );
    expect(lane.objectsAt(0).single.$1, 0); // loop 32 → screen 0
    expect(lane.objectsAt(10).single.$1, 10);
    expect(lane.objectsAt(144).single.$1, 0); // full loop
    const left = Lane.road(
      index: 3,
      dir: -1,
      speed: 1,
      objects: [Mover(32, 12)],
    );
    expect(left.objectsAt(10).single.$1, -10);
    expect(left.objectsAt(40).single.$1, 104); // wrapped to the right
  });

  test('hits detects overlap with a horizontal range', () {
    const lane = Lane.road(
      index: 3,
      dir: 1,
      speed: 0,
      objects: [Mover(52, 12)],
    );
    // Object occupies screen x 20..32.
    expect(lane.hits(10, 20, 0), isFalse);
    expect(lane.hits(10, 21, 0), isTrue);
    expect(lane.hits(31, 40, 0), isTrue);
    expect(lane.hits(32, 40, 0), isFalse);
  });

  test('grass trees block columns', () {
    const lane = Lane.grass(index: 5, trees: 0x005); // columns 0 and 2
    expect(lane.blocked(0), isTrue);
    expect(lane.blocked(1), isFalse);
    expect(lane.blocked(2), isTrue);
    expect(lane.blocked(-1), isTrue); // off screen
    expect(lane.blocked(10), isTrue);
  });

  test('rail: warning for 60 ticks, then the train crosses in 36 ticks', () {
    const lane = Lane.rail(index: 7, dir: 1, trainPeriod: 300, trainOffset: 0);
    expect(lane.warning(239), isFalse);
    expect(lane.warning(240), isTrue);
    expect(lane.trainX(299), isNull);
    expect(lane.trainX(300), -64); // phase 0: just entering from the left
    expect(lane.trainX(310), -24);
    expect(lane.trainX(335), 76);
    expect(lane.trainX(336), isNull);
    expect(lane.hits(0, 8, 310), isTrue);
    expect(lane.hits(0, 8, 250), isFalse);
  });
}
