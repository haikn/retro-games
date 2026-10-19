/// Hop: endless road-and-river crossing, as a Retro LCD Games module.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:lcd_kit/lcd_kit.dart';

import 'core/hop_game.dart';
import 'core/lanes.dart';

class HopModule extends GameModule {
  const HopModule();

  @override
  String get id => 'hop';

  @override
  String get title => 'Hop';

  @override
  List<String> get icon => const [
    '....##......',
    '...####.....',
    '..#####.#...',
    '...####.....',
    '...####.....',
    '....#.#.....',
    '............',
    '#.#.#.#.#.#.',
    '............',
    '..######....',
    '.########...',
    '..#....#....',
  ];

  @override
  GameOrientation get orientation => GameOrientation.portrait;

  @override
  LeaderboardIds get leaderboard => const LeaderboardIds(
    ios: 'lcd_arcade_hop',
    android: 'REPLACE_WITH_PLAY_CONSOLE_LEADERBOARD_ID',
  );

  static final spec = ArcadeSpec(
    title: 'Hop',
    package: 'hop',
    orientation: GameOrientation.portrait,
    create: HopArcade.new,
    sounds: const ['hop.wav', 'splash.wav', 'crash.wav', 'bell.wav'],
    instructions: const [
      'Tap to hop forward. Swipe left, right or down to hop sideways or '
          'back.',
      'Cross roads between the cars, ride logs over rivers and listen for '
          'the train bell.',
      'Keep moving: the screen edge creeps up behind you.',
      'Your score is the furthest lane you reach.',
      'Tap the score bar to pause.',
    ],
    startHint: const ['Tap to', 'start'],
  );

  @override
  Widget build(BuildContext context, GameHost host) =>
      ArcadeGameView(host: host, spec: spec);
}

/// 1-bit sprites from the design canvas (board 5), facing right.
abstract final class HopSprites {
  static final tree = Sprite1.parse(const [
    '..###..',
    '.#####.',
    '#######',
    '#######',
    '.#####.',
    '...#...',
    '...#...',
    '.#####.',
  ]);
  static const _car = [
    '..#####.....',
    '.#..#..#....',
    '############',
    '############',
    '.##......##.',
    '.##......##.',
  ];
  static const _truck = [
    '##############.#####..',
    '##############.#..##..',
    '##############.#...##.',
    '######################',
    '######################',
    '.##....##........##...',
    '.##....##........##...',
  ];
  static final car = Sprite1.parse(_car);
  static final carLeft = Sprite1.parse(_mirror(_car));
  static final truck = Sprite1.parse(_truck);
  static final truckLeft = Sprite1.parse(_mirror(_truck));
  static final chicken = Sprite1.parse(const [
    '...##...',
    '..####..',
    '..#.###.',
    '..#####.',
    '.#####..',
    '.#####..',
    '..####..',
    '..#..#..',
  ]);

  static List<String> _mirror(List<String> rows) => [
    for (final r in rows) r.split('').reversed.join(),
  ];
}

/// Draws a [HopGame] on the portrait LCD and maps taps and swipes to hops.
class HopArcade extends ArcadeGame {
  HopArcade({this.factory});

  /// Overrides run creation (tests).
  final HopGame Function(int seed)? factory;

  HopGame? _game;
  final _sounds = <String>[];
  final _water = List<bool>.filled(HopRules.screenWidth, true);

  HopGame get core => _game!;

  @override
  void start({required int level, required int seed}) {
    _game = factory?.call(seed) ?? HopGame(seed: seed);
    _sounds.clear();
  }

  @override
  void tick() {
    core.tick();
    for (final e in core.takeEvents()) {
      _sounds.add('$e.wav');
    }
  }

  @override
  void input(GameInput input) {
    switch (input) {
      case ReleaseInput(tap: true):
        core.move(HopMove.forward);
      case SwipeInput(:final dir):
        core.move(switch (dir) {
          Dir.up => HopMove.forward,
          Dir.down => HopMove.back,
          Dir.left => HopMove.left,
          Dir.right => HopMove.right,
        });
      default:
        break;
    }
  }

  @override
  int get score => _game?.score ?? 0;

  @override
  bool get over => _game?.over ?? false;

  @override
  List<String> takeSounds() {
    final s = List.of(_sounds);
    _sounds.clear();
    return s;
  }

  /// Top LCD row of a lane (or of a fractional lane position).
  static int laneTop(double lane, double camera) =>
      (160 - (lane + 1 - camera) * HopRules.laneHeight).round();

  @override
  void draw(LcdBuffer b) {
    final g = _game;
    if (g != null) {
      final first = g.camera.floor() - 1;
      for (var i = first; i <= first + HopRules.visibleLanes + 2; i++) {
        final y = laneTop(i.toDouble(), g.camera);
        if (y >= b.height || y + HopRules.laneHeight <= 9) continue;
        _drawLane(b, g, g.laneAt(i), y);
      }
      final arc = g.hopping
          ? (math.sin(g.hopProgress * math.pi) * 3).round()
          : 0;
      b.blit(
        HopSprites.chicken,
        g.drawX.round(),
        laneTop(g.drawLane, g.camera) + 1 - arc,
      );
    }
    b.clearRect(0, 0, b.width, 9); // keep the world out of the HUD strip
    b.fillRect(0, 8, b.width, 1); // HUD rule
  }

  void _drawLane(LcdBuffer b, HopGame g, Lane lane, int y) {
    final t = g.ticks;
    switch (lane.kind) {
      case LaneKind.grass:
        for (var c = 0; c < HopRules.columns; c++) {
          if (lane.blocked(c)) {
            b.blit(HopSprites.tree, c * HopRules.columnWidth, y + 1);
          }
        }
      case LaneKind.road:
        if (g.laneAt(lane.index - 1).kind == LaneKind.road) {
          // Dashed line between two road lanes (at this lane's bottom).
          for (var x = 0; x < b.width; x += 8) {
            b.fillRect(x, y + HopRules.laneHeight - 1, 4, 1);
          }
        }
        for (final (x, len) in lane.objectsAt(t)) {
          final truck = len > 12;
          final sprite = lane.dir > 0
              ? (truck ? HopSprites.truck : HopSprites.car)
              : (truck ? HopSprites.truckLeft : HopSprites.carLeft);
          b.blit(sprite, x.round(), y + (truck ? 1 : 2));
        }
      case LaneKind.river:
        // Log spans once per lane per frame, then mark which columns are
        // water (no per-pixel log search).
        final logs = lane.objectsAt(t).toList(growable: false);
        _water.fillRange(0, _water.length, true);
        for (final (xd, len) in logs) {
          final x0 = xd.round().clamp(0, b.width);
          final x1 = (xd.round() + len).clamp(0, b.width);
          _water.fillRange(x0, x1, false);
        }
        for (var yy = 1; yy < HopRules.laneHeight; yy += 2) {
          final offset = yy % 4 == 1 ? 0 : 3;
          for (var x = offset; x < b.width; x += 6) {
            if (_water[x]) b.set(x, y + yy);
          }
        }
        for (final (xd, len) in logs) {
          final x = xd.round();
          b.fillRect(x, y + 2, len, 1);
          b.fillRect(x, y + 7, len, 1);
          b.fillRect(x, y + 2, 1, 6);
          b.fillRect(x + len - 1, y + 2, 1, 6);
          for (var bx = x + 3; bx < x + len - 3; bx += 5) {
            b.fillRect(bx, y + 4 + (bx & 1), 2, 1); // bark
          }
        }
      case LaneKind.rail:
        b.fillRect(0, y + 2, b.width, 1);
        b.fillRect(0, y + 7, b.width, 1);
        for (var x = 0; x < b.width; x += 5) {
          b.fillRect(x, y + 3, 1, 4); // sleepers
        }
        if (lane.warning(t) && (t ~/ 15).isEven) b.fillRect(1, y - 1, 3, 3);
        final tx = lane.trainX(t);
        if (tx != null) {
          final x = tx.round();
          const len = HopRules.trainLength;
          b.clearRect(x, y + 1, len, 8);
          b.fillRect(x, y + 1, len, 1);
          b.fillRect(x, y + 8, len, 1);
          b.fillRect(x, y + 1, 1, 8);
          b.fillRect(x + len - 1, y + 1, 1, 8);
          for (var wx = x + 3; wx < x + len - 4; wx += 8) {
            b.fillRect(wx, y + 3, 4, 3); // windows
          }
        }
    }
  }
}
