import 'dart:typed_data';

import '../../core/config.dart';
import '../../core/rng.dart';
import '../lcd/lcd_buffer.dart';
import 'scene.dart';

/// Cosmetic animation state: rotor, smoke trail, crash debris and flashes.
///
/// Advanced in fixed 60 Hz ticks and driven by its own RNG, so it never
/// affects the level sequence. Fixed-size pools; no allocation per tick.
class Effects {
  Effects(this.config, int seed) : _rng = Rng(seed);

  static const rotorFrameTicks = 8;
  static const smokeInterval = 4;
  static const smokeMinLife = 16;
  static const smokeMaxLife = 30;
  static const smokeBlinkTicks = 6;
  static const smokeCapacity = 16;
  static const debrisCount = 12;
  static const debrisTicks = 66;
  static const restartTicks = 36; // 600 ms
  static const gameOverTicks = 40;

  final Config config;
  final Rng _rng;

  int _ticks = 0;

  final _smokeX = Int32List(smokeCapacity);
  final _smokeY = Int32List(smokeCapacity);
  final _smokeLife = Int32List(smokeCapacity);
  final _smokeVisible = Uint8List(smokeCapacity);
  int smokeCount = 0;

  final _debrisX = Float64List(debrisCount);
  final _debrisY = Float64List(debrisCount);
  final _debrisVx = Float64List(debrisCount);
  final _debrisVy = Float64List(debrisCount);

  /// Ticks since the crash, or -1 while not crashed.
  int crashTicks = -1;

  bool get crashed => crashTicks >= 0;
  int get rotorFrame => (_ticks ~/ rotorFrameTicks) % 2;

  /// Whole screen inverted: 3 flashes over the first 25 ticks.
  bool get inverted =>
      crashTicks >= 0 &&
      (crashTicks < 5 ||
          (crashTicks >= 10 && crashTicks < 15) ||
          (crashTicks >= 20 && crashTicks < 25));

  bool get canRestart => crashTicks >= restartTicks;
  bool get showGameOver => crashTicks >= gameOverTicks;

  int smokeX(int i) => _smokeX[i];
  int smokeY(int i) => _smokeY[i];

  void reset() {
    _ticks = 0;
    smokeCount = 0;
    crashTicks = -1;
  }

  /// Ready / paused: only the rotor animates.
  void onIdleTick() => _ticks++;

  /// One simulation tick while playing; the world scrolls 1 LCD px per tick.
  void onPlayTick({required double heliY}) {
    _ticks++;
    _ageSmoke(drift: 1);
    if (_ticks % smokeInterval == 0 && smokeCount < smokeCapacity) {
      final i = smokeCount++;
      _smokeX[i] = heliColumn(config) - 1;
      _smokeY[i] = heliRow(heliY, config) + 3;
      _smokeLife[i] =
          smokeMinLife + _rng.nextInt(smokeMaxLife - smokeMinLife + 1);
      _smokeVisible[i] = 1;
    }
  }

  void startCrash({required double heliY}) {
    crashTicks = 0;
    final cx = heliColumn(config) + 5.0;
    final cy = heliRow(heliY, config) + 3.0;
    for (var i = 0; i < debrisCount; i++) {
      _debrisX[i] = cx;
      _debrisY[i] = cy;
      _debrisVx[i] = _rng.range(-0.7, 0.7);
      _debrisVy[i] = _rng.range(-1.1, 0);
    }
  }

  /// One 60 Hz tick after the crash; the world is frozen.
  void onCrashTick() {
    crashTicks++;
    for (var i = 0; i < debrisCount; i++) {
      _debrisX[i] += _debrisVx[i];
      _debrisY[i] += _debrisVy[i];
      _debrisVy[i] += 0.06;
    }
    _ageSmoke(drift: 0);
  }

  void _ageSmoke({required int drift}) {
    var w = 0;
    for (var r = 0; r < smokeCount; r++) {
      final x = _smokeX[r] - drift;
      final life = _smokeLife[r] - 1;
      if (life <= 0 || x < 0) continue;
      _smokeX[w] = x;
      _smokeY[w] = _smokeY[r];
      _smokeLife[w] = life;
      _smokeVisible[w] = life > smokeBlinkTicks || _rng.nextInt(2) == 0 ? 1 : 0;
      w++;
    }
    smokeCount = w;
  }

  void draw(LcdBuffer b) {
    for (var i = 0; i < smokeCount; i++) {
      if (_smokeVisible[i] == 1) b.set(_smokeX[i], _smokeY[i]);
    }
    if (crashTicks >= 0 && crashTicks < debrisTicks) {
      for (var i = 0; i < debrisCount; i++) {
        b.set(_debrisX[i].floor(), _debrisY[i].floor());
      }
    }
  }
}
