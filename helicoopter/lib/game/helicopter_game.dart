import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../core/simulation.dart';
import 'components/debug_overlay.dart';
import 'components/lcd_component.dart';
import 'lcd/lcd_buffer.dart';
import 'lcd/palette.dart';
import 'render/effects.dart';

/// Debug overlay (FPS, ticks per frame, hitbox). Enable with
/// `--dart-define=CAVE_DEBUG=true`; never on in release builds.
const bool kDebugOverlay = bool.fromEnvironment('CAVE_DEBUG') && !kReleaseMode;

enum GamePhase { ready, playing, crashed }

/// Runs the fixed-step simulation and the cosmetic effects, and owns the LCD
/// buffer that render components draw into.
class HelicopterGame extends FlameGame {
  HelicopterGame({
    this.config = const Config(),
    this.palette = LcdPalette.active,
    int Function()? seedSource,
    this.debugOverlay = kDebugOverlay,
  }) : _seedSource = seedSource ?? _randomSeed,
       buffer = LcdBuffer(
         width: (config.worldWidth / config.lcdPixel).round(),
         height: (config.worldHeight / config.lcdPixel).round(),
       ),
       super(
         camera: CameraComponent.withFixedResolution(
           width: config.worldWidth,
           height: config.worldHeight,
         ),
       );

  static int _randomSeed() => math.Random().nextInt(1 << 32);

  final Config config;
  final LcdPalette palette;
  final bool debugOverlay;
  final int Function() _seedSource;
  final LcdBuffer buffer;
  final ValueNotifier<GamePhase> phase = ValueNotifier(GamePhase.ready);

  late GameSimulation sim;
  late FixedStepper stepper;
  late Effects effects;

  int _pointers = 0;
  double _fxAccumulator = 0;

  /// At least one finger is down.
  bool get holding => _pointers > 0;

  @override
  Color backgroundColor() => palette.bezel;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    newRun();
    world.add(LcdComponent());
    if (debugOverlay) world.add(DebugOverlay());
  }

  /// Starts a fresh run in [GamePhase.ready].
  void newRun() {
    final seed = _seedSource();
    sim = GameSimulation(seed: seed, config: config);
    stepper = FixedStepper(sim);
    effects = Effects(config, seed ^ 0x5BD1E995);
    _fxAccumulator = 0;
    phase.value = GamePhase.ready;
  }

  void pointerDown() {
    _pointers++;
    switch (phase.value) {
      case GamePhase.ready:
        phase.value = GamePhase.playing;
      case GamePhase.crashed:
        // Only a new press at least 600 ms after the crash restarts; a finger
        // held since the crash never does (it produces no new pointer-down).
        if (effects.canRestart) {
          newRun();
          phase.value = GamePhase.playing;
        }
      case GamePhase.playing:
        break;
    }
  }

  void pointerUp() {
    if (_pointers > 0) _pointers--;
  }

  /// Forget all pointers (e.g. when the app loses focus).
  void releaseAll() => _pointers = 0;

  @override
  void update(double dt) {
    switch (phase.value) {
      case GamePhase.playing:
        final before = sim.state.ticks;
        final event = stepper.advance(dt, holding);
        for (var t = before; t < sim.state.ticks; t++) {
          effects.onPlayTick(heliY: sim.state.heli.y);
        }
        if (event == SimEvent.crashed) {
          effects.startCrash(heliY: sim.state.heli.y);
          _fxAccumulator = 0;
          phase.value = GamePhase.crashed;
        }
      case GamePhase.crashed:
      case GamePhase.ready:
        _fxAccumulator += dt.clamp(0, config.maxFrameDt);
        while (_fxAccumulator >= config.fixedDt) {
          _fxAccumulator -= config.fixedDt;
          if (phase.value == GamePhase.crashed) {
            effects.onCrashTick();
          } else {
            effects.onIdleTick();
          }
        }
    }
    super.update(dt);
  }
}
