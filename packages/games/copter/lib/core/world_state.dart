import 'dart:typed_data';

import 'config.dart';

/// Vertical state of the helicopter. [y] is the sprite's top edge in px.
class HeliState {
  HeliState({required this.y, this.vy = 0}) : prevY = y;

  double y;
  double vy;

  /// [y] before the latest tick, for render interpolation.
  double prevY;
}

/// Fixed-capacity ring of cave columns addressed by world column index.
///
/// Column `i` spans world x `[i * columnWidth, (i + 1) * columnWidth)`. An
/// obstacle is stored per column as the segment it covers, so a 2-column
/// block is two entries with the same segment. No allocation after creation.
class ColumnRing {
  ColumnRing(this.capacity)
    : _top = Float64List(capacity),
      _bottom = Float64List(capacity),
      _obstacleTop = Float64List(capacity),
      _obstacleBottom = Float64List(capacity),
      _hasObstacle = Uint8List(capacity);

  final int capacity;
  final Float64List _top;
  final Float64List _bottom;
  final Float64List _obstacleTop;
  final Float64List _obstacleBottom;
  final Uint8List _hasObstacle;

  int _head = 0;
  int _length = 0;
  int _firstIndex = 0;

  int get length => _length;

  /// World index of the oldest stored column.
  int get firstIndex => _firstIndex;

  /// World index of the newest stored column.
  int get lastIndex => _firstIndex + _length - 1;

  /// World index the next [push] will get.
  int get nextIndex => _firstIndex + _length;

  void push({
    required double top,
    required double bottom,
    double? obstacleTop,
    double? obstacleBottom,
  }) {
    if (_length == capacity) throw StateError('ColumnRing is full');
    final slot = (_head + _length) % capacity;
    _top[slot] = top;
    _bottom[slot] = bottom;
    final has = obstacleTop != null && obstacleBottom != null;
    _hasObstacle[slot] = has ? 1 : 0;
    _obstacleTop[slot] = has ? obstacleTop : 0;
    _obstacleBottom[slot] = has ? obstacleBottom : 0;
    _length++;
  }

  void dropFirst() {
    if (_length == 0) throw StateError('ColumnRing is empty');
    _head = (_head + 1) % capacity;
    _length--;
    _firstIndex++;
  }

  void clear() {
    _head = 0;
    _length = 0;
    _firstIndex = 0;
  }

  int _slot(int index) {
    if (index < _firstIndex || index > lastIndex) {
      throw RangeError.range(index, _firstIndex, lastIndex, 'index');
    }
    return (_head + index - _firstIndex) % capacity;
  }

  /// Lower edge of the ceiling.
  double topAt(int index) => _top[_slot(index)];

  /// Upper edge of the floor.
  double bottomAt(int index) => _bottom[_slot(index)];

  bool hasObstacleAt(int index) => _hasObstacle[_slot(index)] == 1;
  double obstacleTopAt(int index) => _obstacleTop[_slot(index)];
  double obstacleBottomAt(int index) => _obstacleBottom[_slot(index)];
}

/// Snapshot of one run.
class WorldState {
  WorldState(Config config, {required double heliY})
    : heli = HeliState(y: heliY),
      columns = ColumnRing(config.ringCapacity),
      _distanceUnit = config.distanceUnit;

  final HeliState heli;
  final ColumnRing columns;
  final int _distanceUnit;

  int ticks = 0;

  /// Total scrolled px (whole px; scroll per tick is an integer).
  int scrollPx = 0;
  bool crashed = false;

  int get distance => scrollPx ~/ _distanceUnit;
}
