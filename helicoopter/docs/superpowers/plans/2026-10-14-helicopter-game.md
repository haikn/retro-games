# Helicopter Game Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a faithful mobile remake of the classic Flash Helicopter Game for iOS and Android with local best score, online leaderboards, and sound.

**Architecture:** Pure-Dart game logic in `lib/core/` (physics, cave generation, collision, world state) with no Flame imports, fully unit-tested. A Flame `FlameGame` drives the state machine and renders `core` state through render-only components at a fixed 800×400 virtual resolution. Flutter widgets provide input capture and the title/game-over overlays; services wrap storage, leaderboards, and audio behind small classes that never block play.

**Tech Stack:** Flutter (stable), Dart 3, Flame, flame_audio, games_services, shared_preferences, flutter_test, flame_test. GitHub Actions for analyze/test; Codemagic for iOS builds.

**Spec:** `docs/superpowers/specs/2026-10-14-helicopter-game-design.md`

## Global Constraints

- Dev machine is Windows; all commands are PowerShell. iOS is built only in the cloud (Codemagic).
- Package name `helicopter`; org `com.nhk`; bundle/application id `com.nhk.helicopter`.
- Landscape only on both platforms.
- Virtual resolution 800×400; play area height 370; HUD band 30 at the bottom.
- Fixed simulation timestep 1/60 s; frame delta clamped to 0.25 s.
- Colors: black background, cave/obstacles/HUD green `0xFF00DD00`.
- `lib/core/` must not import `package:flame` or `package:flutter`.
- Leaderboard, audio, and storage failures must never throw into gameplay; log with `debugPrint`.
- No ads, IAP, skins, power-ups, or settings other than in-memory mute.
- `flutter analyze` must report no issues and `flutter test` must pass before every commit.

---

## File Map

| File | Responsibility |
|---|---|
| `lib/main.dart` | Bootstrap: orientation, immersive mode, construct services and game, `runApp` |
| `lib/app/helicopter_app.dart` | `MaterialApp` shell |
| `lib/app/game_screen.dart` | `Stack` of input `Listener` + `GameWidget` + phase-driven overlays |
| `lib/app/overlays/title_overlay.dart` | Title text + LEADERBOARD / SOUND buttons |
| `lib/app/overlays/game_over_overlay.dart` | "Tap to play" after a crash |
| `lib/game/helicopter_game.dart` | `GamePhase`, `HelicopterGame` state machine, input, crash handling |
| `lib/game/components/palette.dart` | Shared colors and paints |
| `lib/game/components/cave_component.dart` | Draws ceiling/floor columns |
| `lib/game/components/obstacle_component.dart` | Draws obstacle blocks |
| `lib/game/components/heli_component.dart` | Draws pixel-art helicopter with rotor animation |
| `lib/game/components/smoke_component.dart` | Smoke trail puffs |
| `lib/game/components/explosion_component.dart` | Crash explosion |
| `lib/game/components/hud_component.dart` | `DISTANCE` / `BEST` text |
| `lib/core/config.dart` | All tuning constants |
| `lib/core/physics.dart` | `HeliState`, `stepHeli` |
| `lib/core/cave_generator.dart` | `CaveColumn`, `Obstacle`, `CaveGenerator`, `gapAt`, `obstacleSpacingAt` |
| `lib/core/collision.dart` | `Box`, `collides` |
| `lib/core/world_state.dart` | `GameWorld`: fixed-step simulation of one run |
| `lib/services/score_repository.dart` | Best score + pending leaderboard score in shared_preferences |
| `lib/services/leaderboard_service.dart` | Backend interface, games_services backend, offline-tolerant service |
| `lib/services/audio_service.dart` | Rotor loop, crash SFX, mute |
| `tool/gen_audio.dart` | Synthesizes `assets/audio/rotor.wav` and `crash.wav` |
| `.github/workflows/ci.yml` | Analyze + test on push |
| `codemagic.yaml` | iOS build → TestFlight |

---

### Task 1: Project scaffold, landscape lock, CI

**Files:**
- Create: Flutter project in repo root (via `flutter create`)
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`
- Modify: `.gitignore`
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: nothing
- Produces: Flutter package `helicopter` with dependencies `flame`, `flame_audio`, `games_services`, `shared_preferences`, dev dependency `flame_test`.

- [ ] **Step 1: Verify toolchain**

Run: `flutter doctor`
Expected: Flutter (stable) and Android toolchain show `[√]`. Xcode will show as unavailable on Windows; that is expected.

- [ ] **Step 2: Create the project in the existing folder**

Run from `c:\Users\NHA7CX\Projects\NHK\helicoopter`:
```powershell
flutter create --project-name helicopter --org com.nhk --platforms android,ios,windows .
```
Expected: `All done!` and `lib/main.dart`, `test/widget_test.dart`, `android/`, `ios/`, `windows/` exist. `docs/` is untouched.

- [ ] **Step 3: Add dependencies**

```powershell
flutter pub add flame flame_audio games_services shared_preferences
flutter pub add --dev flame_test
```
Expected: `Changed N dependencies!`

- [ ] **Step 4: Lock Android to landscape**

In `android/app/src/main/AndroidManifest.xml`, add `android:screenOrientation="sensorLandscape"` to the `<activity android:name=".MainActivity"` element, e.g.:
```xml
        <activity
            android:name=".MainActivity"
            android:screenOrientation="sensorLandscape"
            android:exported="true"
```
(keep every other existing attribute unchanged).

- [ ] **Step 5: Lock iOS to landscape and full screen**

In `ios/Runner/Info.plist`, replace both orientation arrays so they contain only landscape, and add full-screen keys before the closing `</dict>`:
```xml
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UIRequiresFullScreen</key>
	<true/>
	<key>UIStatusBarHidden</key>
	<true/>
```

- [ ] **Step 6: Ignore signing secrets**

Append to `.gitignore`:
```gitignore
# Signing secrets
android/key.properties
*.jks
*.keystore
```

- [ ] **Step 7: Add CI workflow**

Create `.github/workflows/ci.yml`:
```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

- [ ] **Step 8: Verify**

Run: `flutter analyze; flutter test`
Expected: `No issues found!` and `All tests passed!` (the generated counter test still passes; it is removed in Task 10).

- [ ] **Step 9: Init git and commit**

```powershell
git init
git add .
git commit -m "chore: scaffold Flutter project with landscape lock and CI"
```

---

### Task 2: Config and helicopter physics

**Files:**
- Create: `lib/core/config.dart`
- Create: `lib/core/physics.dart`
- Test: `test/core/physics_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `abstract final class GameConfig` with static `double` constants listed below.
  - `class HeliState { HeliState({required double y, double vy = 0}); double y; double vy; }`
  - `void stepHeli(HeliState heli, {required bool holding, required double dt})`

- [ ] **Step 1: Create config**

`lib/core/config.dart`:
```dart
abstract final class GameConfig {
  static const double worldWidth = 800;
  static const double worldHeight = 400;
  static const double playHeight = 370;

  static const double fixedDt = 1 / 60;
  static const double maxFrameDt = 0.25;

  static const double gravity = 900;
  static const double thrust = 1800;
  static const double maxRiseSpeed = 300;
  static const double maxFallSpeed = 350;

  static const double heliX = 160;
  static const double heliWidth = 48;
  static const double heliHeight = 20;
  static const double hitboxInset = 4;

  static const double scrollSpeed = 240;
  static const double distanceUnit = 10;

  static const double columnWidth = 20;
  static const double initialGap = 300;
  static const double minGap = 160;
  static const double gapShrinkPerPx = 0.004;
  static const double maxCenterStep = 12;
  static const double edgeMargin = 20;

  static const double obstacleWidth = 30;
  static const double obstacleHeight = 80;
  static const double initialObstacleSpacing = 600;
  static const double minObstacleSpacing = 250;
  static const double obstacleSpacingShrinkPerPx = 0.01;
  static const double minPassable = 60;
}
```

- [ ] **Step 2: Write the failing test**

`test/core/physics_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:helicopter/core/config.dart';
import 'package:helicopter/core/physics.dart';

void main() {
  const dt = GameConfig.fixedDt;

  test('falls when not holding', () {
    final heli = HeliState(y: 100);
    stepHeli(heli, holding: false, dt: dt);
    expect(heli.vy, greaterThan(0));
    expect(heli.y, greaterThan(100));
  });

  test('rises when holding', () {
    final heli = HeliState(y: 100);
    stepHeli(heli, holding: true, dt: dt);
    expect(heli.vy, lessThan(0));
    expect(heli.y, lessThan(100));
  });

  test('accelerates gradually instead of jumping to max speed', () {
    final heli = HeliState(y: 100);
    stepHeli(heli, holding: true, dt: dt);
    expect(heli.vy.abs(), lessThan(GameConfig.maxRiseSpeed));
  });

  test('clamps fall speed', () {
    final heli = HeliState(y: 0);
    for (var i = 0; i < 600; i++) {
      stepHeli(heli, holding: false, dt: dt);
    }
    expect(heli.vy, GameConfig.maxFallSpeed);
  });

  test('clamps rise speed', () {
    final heli = HeliState(y: 0);
    for (var i = 0; i < 600; i++) {
      stepHeli(heli, holding: true, dt: dt);
    }
    expect(heli.vy, -GameConfig.maxRiseSpeed);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/physics_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:helicopter/core/physics.dart'`.

- [ ] **Step 4: Implement physics**

`lib/core/physics.dart`:
```dart
import 'config.dart';

class HeliState {
  HeliState({required this.y, this.vy = 0});

  double y;
  double vy;
}

void stepHeli(HeliState heli, {required bool holding, required double dt}) {
  final accel = GameConfig.gravity - (holding ? GameConfig.thrust : 0);
  heli.vy = (heli.vy + accel * dt)
      .clamp(-GameConfig.maxRiseSpeed, GameConfig.maxFallSpeed);
  heli.y += heli.vy * dt;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/physics_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```powershell
git add lib/core test/core
git commit -m "feat(core): add tuning config and helicopter physics"
```

---

### Task 3: Cave generator

**Files:**
- Create: `lib/core/cave_generator.dart`
- Test: `test/core/cave_generator_test.dart`

**Interfaces:**
- Consumes: `GameConfig` (Task 2)
- Produces:
  - `class CaveColumn { CaveColumn({required double x, required double top, required double bottom}); double x; final double top; final double bottom; }` — `top` is the ceiling's lower edge, `bottom` is the floor's upper edge.
  - `class Obstacle { Obstacle({required double x, required double y}); double x; final double y; }` — size is `GameConfig.obstacleWidth × obstacleHeight`.
  - `double gapAt(double worldX)`
  - `double obstacleSpacingAt(double worldX)`
  - `class CaveGenerator { CaveGenerator(int seed); (CaveColumn, Obstacle?) next({required double x, required double worldX}); }`

- [ ] **Step 1: Write the failing test**

`test/core/cave_generator_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:helicopter/core/cave_generator.dart';
import 'package:helicopter/core/config.dart';

List<(CaveColumn, Obstacle?)> generate(int seed, int count) {
  final generator = CaveGenerator(seed);
  return [
    for (var i = 0; i < count; i++)
      generator.next(
        x: i * GameConfig.columnWidth,
        worldX: i * GameConfig.columnWidth,
      ),
  ];
}

void main() {
  const eps = 1e-9;

  test('same seed produces the same cave', () {
    final a = generate(42, 500);
    final b = generate(42, 500);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].$1.top, b[i].$1.top);
      expect(a[i].$1.bottom, b[i].$1.bottom);
      expect(a[i].$2?.y, b[i].$2?.y);
    }
  });

  test('different seeds produce different caves', () {
    final a = generate(1, 50).map((s) => s.$1.top).toList();
    final b = generate(2, 50).map((s) => s.$1.top).toList();
    expect(a, isNot(equals(b)));
  });

  test('gap shrinks with distance down to the minimum', () {
    expect(gapAt(0), GameConfig.initialGap);
    expect(gapAt(10000), lessThan(GameConfig.initialGap));
    expect(gapAt(1e9), GameConfig.minGap);
  });

  test('gap never below minimum and walls keep their margin', () {
    for (final (column, _) in generate(7, 5000)) {
      expect(column.bottom - column.top,
          greaterThanOrEqualTo(GameConfig.minGap - eps));
      expect(column.top, greaterThanOrEqualTo(GameConfig.edgeMargin - eps));
      expect(column.bottom,
          lessThanOrEqualTo(GameConfig.playHeight - GameConfig.edgeMargin + eps));
    }
  });

  test('no obstacles on the first screen', () {
    final firstScreen =
        (GameConfig.worldWidth / GameConfig.columnWidth).floor();
    for (final (_, obstacle) in generate(5, firstScreen)) {
      expect(obstacle, isNull);
    }
  });

  test('obstacles spawn inside the gap and leave a passable route', () {
    final withObstacles =
        generate(3, 5000).where((s) => s.$2 != null).toList();
    expect(withObstacles, isNotEmpty);
    for (final (column, obstacle) in withObstacles) {
      final o = obstacle!;
      final above = o.y - column.top;
      final below = column.bottom - (o.y + GameConfig.obstacleHeight);
      expect(above, greaterThanOrEqualTo(-eps));
      expect(below, greaterThanOrEqualTo(-eps));
      expect(
        above >= GameConfig.minPassable - eps ||
            below >= GameConfig.minPassable - eps,
        isTrue,
      );
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/cave_generator_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:helicopter/core/cave_generator.dart'`.

- [ ] **Step 3: Implement generator**

`lib/core/cave_generator.dart`:
```dart
import 'dart:math';

import 'config.dart';

class CaveColumn {
  CaveColumn({required this.x, required this.top, required this.bottom});

  double x;
  final double top;
  final double bottom;
}

class Obstacle {
  Obstacle({required this.x, required this.y});

  double x;
  final double y;
}

double gapAt(double worldX) => max(
      GameConfig.minGap,
      GameConfig.initialGap - worldX * GameConfig.gapShrinkPerPx,
    );

double obstacleSpacingAt(double worldX) => max(
      GameConfig.minObstacleSpacing,
      GameConfig.initialObstacleSpacing -
          worldX * GameConfig.obstacleSpacingShrinkPerPx,
    );

class CaveGenerator {
  CaveGenerator(int seed) : _rng = Random(seed);

  final Random _rng;
  double _center = GameConfig.playHeight / 2;
  // Starts negative so the first screen is obstacle-free.
  double _sinceObstacle = -GameConfig.worldWidth;

  (CaveColumn, Obstacle?) next({required double x, required double worldX}) {
    final half = gapAt(worldX) / 2;
    _center += (_rng.nextDouble() * 2 - 1) * GameConfig.maxCenterStep;
    _center = _center.clamp(
      GameConfig.edgeMargin + half,
      GameConfig.playHeight - GameConfig.edgeMargin - half,
    );
    final column = CaveColumn(x: x, top: _center - half, bottom: _center + half);

    _sinceObstacle += GameConfig.columnWidth;
    Obstacle? obstacle;
    if (_sinceObstacle >= obstacleSpacingAt(worldX)) {
      _sinceObstacle = 0;
      obstacle = _placeObstacle(column);
    }
    return (column, obstacle);
  }

  Obstacle? _placeObstacle(CaveColumn column) {
    const minPassable = GameConfig.minPassable;
    final maxY = column.bottom - GameConfig.obstacleHeight;
    if (maxY - column.top < minPassable) return null;

    var y = column.top + _rng.nextDouble() * (maxY - column.top);
    final above = y - column.top;
    final below = maxY - y;
    if (above < minPassable && below < minPassable) {
      y = above >= below ? column.top + minPassable : maxY - minPassable;
    }
    return Obstacle(x: column.x, y: y);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/cave_generator_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```powershell
git add lib/core/cave_generator.dart test/core/cave_generator_test.dart
git commit -m "feat(core): add seeded cave and obstacle generator"
```

---

### Task 4: Collision

**Files:**
- Create: `lib/core/collision.dart`
- Test: `test/core/collision_test.dart`

**Interfaces:**
- Consumes: `GameConfig` (Task 2); `CaveColumn`, `Obstacle` (Task 3)
- Produces:
  - `class Box { const Box(double left, double top, double width, double height); double get right; double get bottom; bool overlaps(Box other); }`
  - `bool collides(Box heli, Iterable<CaveColumn> columns, Iterable<Obstacle> obstacles)`

- [ ] **Step 1: Write the failing test**

`test/core/collision_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:helicopter/core/cave_generator.dart';
import 'package:helicopter/core/collision.dart';
import 'package:helicopter/core/config.dart';

CaveColumn column(double x, {double top = 100, double bottom = 300}) =>
    CaveColumn(x: x, top: top, bottom: bottom);

void main() {
  const heli = Box(100, 150, 40, 12);

  test('inside the gap is safe', () {
    expect(collides(heli, [column(100)], const []), isFalse);
  });

  test('above the ceiling of an overlapping column hits', () {
    expect(collides(const Box(100, 90, 40, 12), [column(100)], const []),
        isTrue);
  });

  test('below the floor of an overlapping column hits', () {
    expect(collides(const Box(100, 295, 40, 12), [column(100)], const []),
        isTrue);
  });

  test('touching the ceiling exactly is safe', () {
    expect(collides(const Box(100, 100, 40, 12), [column(100)], const []),
        isFalse);
  });

  test('columns that do not overlap in x are ignored', () {
    final left = column(100 - GameConfig.columnWidth, top: 200);
    final right = column(140, top: 200);
    expect(collides(heli, [left, right], const []), isFalse);
  });

  test('overlapping obstacle hits', () {
    expect(collides(heli, const [], [Obstacle(x: 120, y: 140)]), isTrue);
  });

  test('adjacent obstacle is safe', () {
    expect(collides(heli, const [], [Obstacle(x: 140, y: 140)]), isFalse);
  });

  test('leaving the play area hits', () {
    expect(collides(const Box(100, -1, 40, 12), const [], const []), isTrue);
    expect(
      collides(Box(100, GameConfig.playHeight - 11, 40, 12), const [],
          const []),
      isTrue,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/collision_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:helicopter/core/collision.dart'`.

- [ ] **Step 3: Implement collision**

`lib/core/collision.dart`:
```dart
import 'cave_generator.dart';
import 'config.dart';

class Box {
  const Box(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  bool overlaps(Box other) =>
      left < other.right &&
      right > other.left &&
      top < other.bottom &&
      bottom > other.top;
}

bool collides(
  Box heli,
  Iterable<CaveColumn> columns,
  Iterable<Obstacle> obstacles,
) {
  if (heli.top < 0 || heli.bottom > GameConfig.playHeight) return true;

  for (final c in columns) {
    final overlapsX =
        c.x < heli.right && c.x + GameConfig.columnWidth > heli.left;
    if (overlapsX && (heli.top < c.top || heli.bottom > c.bottom)) {
      return true;
    }
  }

  for (final o in obstacles) {
    final box = Box(
        o.x, o.y, GameConfig.obstacleWidth, GameConfig.obstacleHeight);
    if (heli.overlaps(box)) return true;
  }
  return false;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/collision_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```powershell
git add lib/core/collision.dart test/core/collision_test.dart
git commit -m "feat(core): add AABB collision against cave and obstacles"
```

---

### Task 5: Game world simulation

**Files:**
- Create: `lib/core/world_state.dart`
- Test: `test/core/world_state_test.dart`

**Interfaces:**
- Consumes: `GameConfig`, `HeliState`, `stepHeli` (Task 2); `CaveGenerator`, `CaveColumn`, `Obstacle` (Task 3); `Box`, `collides` (Task 4)
- Produces:
  - `class GameWorld { GameWorld({required int seed}); final HeliState heli; final List<CaveColumn> columns; final List<Obstacle> obstacles; double distance; bool crashed; int get score; Box get heliHitbox; void update({required bool holding, required double dt}); }`

- [ ] **Step 1: Write the failing test**

`test/core/world_state_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:helicopter/core/config.dart';
import 'package:helicopter/core/world_state.dart';

void main() {
  test('columns cover the whole screen at start', () {
    final world = GameWorld(seed: 1);
    expect(world.columns.first.x, lessThanOrEqualTo(0));
    expect(world.columns.last.x + GameConfig.columnWidth,
        greaterThanOrEqualTo(GameConfig.worldWidth));
  });

  test('starts alive with the helicopter inside the gap', () {
    final world = GameWorld(seed: 1);
    expect(world.crashed, isFalse);
    expect(world.score, 0);
  });

  test('one fixed step advances distance by scroll speed * dt', () {
    final world = GameWorld(seed: 1);
    world.update(holding: false, dt: GameConfig.fixedDt);
    expect(world.distance,
        closeTo(GameConfig.scrollSpeed * GameConfig.fixedDt, 1e-9));
  });

  test('columns keep covering the screen while scrolling', () {
    final world = GameWorld(seed: 1);
    for (var i = 0; i < 30; i++) {
      world.update(holding: i.isEven, dt: GameConfig.fixedDt);
    }
    expect(world.columns.first.x, lessThanOrEqualTo(0));
    expect(world.columns.last.x + GameConfig.columnWidth,
        greaterThanOrEqualTo(GameConfig.worldWidth));
  });

  test('huge frame delta is clamped', () {
    final world = GameWorld(seed: 1);
    world.update(holding: true, dt: 10);
    expect(world.distance,
        lessThanOrEqualTo(GameConfig.scrollSpeed * GameConfig.maxFrameDt + 1e-6));
  });

  test('falling without thrust crashes and then the world freezes', () {
    final world = GameWorld(seed: 1);
    for (var i = 0; i < 600 && !world.crashed; i++) {
      world.update(holding: false, dt: GameConfig.fixedDt);
    }
    expect(world.crashed, isTrue);
    final distanceAtCrash = world.distance;
    world.update(holding: false, dt: GameConfig.fixedDt);
    expect(world.distance, distanceAtCrash);
  });

  test('score is distance in whole units', () {
    final world = GameWorld(seed: 1)..distance = 123;
    expect(world.score, 12);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/world_state_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:helicopter/core/world_state.dart'`.

- [ ] **Step 3: Implement world**

`lib/core/world_state.dart`:
```dart
import 'dart:math';

import 'cave_generator.dart';
import 'collision.dart';
import 'config.dart';
import 'physics.dart';

class GameWorld {
  GameWorld({required int seed}) : _generator = CaveGenerator(seed) {
    _fillAhead();
  }

  final CaveGenerator _generator;
  final HeliState heli =
      HeliState(y: (GameConfig.playHeight - GameConfig.heliHeight) / 2);
  final List<CaveColumn> columns = [];
  final List<Obstacle> obstacles = [];
  double distance = 0;
  bool crashed = false;
  double _accumulator = 0;

  int get score => (distance / GameConfig.distanceUnit).floor();

  Box get heliHitbox => Box(
        GameConfig.heliX + GameConfig.hitboxInset,
        heli.y + GameConfig.hitboxInset,
        GameConfig.heliWidth - 2 * GameConfig.hitboxInset,
        GameConfig.heliHeight - 2 * GameConfig.hitboxInset,
      );

  void update({required bool holding, required double dt}) {
    _accumulator += min(dt, GameConfig.maxFrameDt);
    while (_accumulator >= GameConfig.fixedDt && !crashed) {
      _accumulator -= GameConfig.fixedDt;
      _step(holding);
    }
  }

  void _step(bool holding) {
    stepHeli(heli, holding: holding, dt: GameConfig.fixedDt);

    const dx = GameConfig.scrollSpeed * GameConfig.fixedDt;
    distance += dx;
    for (final c in columns) {
      c.x -= dx;
    }
    for (final o in obstacles) {
      o.x -= dx;
    }
    columns.removeWhere((c) => c.x + GameConfig.columnWidth < 0);
    obstacles.removeWhere((o) => o.x + GameConfig.obstacleWidth < 0);
    _fillAhead();

    crashed = collides(heliHitbox, columns, obstacles);
  }

  void _fillAhead() {
    var x = columns.isEmpty ? 0.0 : columns.last.x + GameConfig.columnWidth;
    while (x < GameConfig.worldWidth + GameConfig.columnWidth) {
      final (column, obstacle) =
          _generator.next(x: x, worldX: distance + x);
      columns.add(column);
      if (obstacle != null) obstacles.add(obstacle);
      x += GameConfig.columnWidth;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```powershell
git add lib/core/world_state.dart test/core/world_state_test.dart
git commit -m "feat(core): add fixed-step game world simulation"
```

---

### Task 6: Score repository

**Files:**
- Create: `lib/services/score_repository.dart`
- Test: `test/services/score_repository_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences`
- Produces:
  - `class ScoreRepository { ScoreRepository(SharedPreferences prefs); int get best; Future<bool> recordScore(int score); int? get pendingSubmission; Future<void> setPendingSubmission(int? score); }`

- [ ] **Step 1: Write the failing test**

`test/services/score_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:helicopter/services/score_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ScoreRepository> repo([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return ScoreRepository(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('best is 0 when nothing stored', () async {
    expect((await repo()).best, 0);
  });

  test('loads a stored best', () async {
    expect((await repo({'best_score': 42})).best, 42);
  });

  test('records only higher scores', () async {
    final scores = await repo();
    expect(await scores.recordScore(10), isTrue);
    expect(scores.best, 10);
    expect(await scores.recordScore(5), isFalse);
    expect(scores.best, 10);
  });

  test('pending submission round-trips and clears', () async {
    final scores = await repo();
    expect(scores.pendingSubmission, isNull);
    await scores.setPendingSubmission(77);
    expect(scores.pendingSubmission, 77);
    await scores.setPendingSubmission(null);
    expect(scores.pendingSubmission, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/score_repository_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:helicopter/services/score_repository.dart'`.

- [ ] **Step 3: Implement repository**

`lib/services/score_repository.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';

class ScoreRepository {
  ScoreRepository(this._prefs);

  static const _bestKey = 'best_score';
  static const _pendingKey = 'pending_leaderboard_score';

  final SharedPreferences _prefs;

  int get best => _prefs.getInt(_bestKey) ?? 0;

  Future<bool> recordScore(int score) async {
    if (score <= best) return false;
    await _prefs.setInt(_bestKey, score);
    return true;
  }

  int? get pendingSubmission => _prefs.getInt(_pendingKey);

  Future<void> setPendingSubmission(int? score) async {
    if (score == null) {
      await _prefs.remove(_pendingKey);
    } else {
      await _prefs.setInt(_pendingKey, score);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/score_repository_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```powershell
git add lib/services/score_repository.dart test/services/score_repository_test.dart
git commit -m "feat(services): add local best score repository"
```

---

### Task 7: Leaderboard service

**Files:**
- Create: `lib/services/leaderboard_service.dart`
- Test: `test/services/leaderboard_service_test.dart`

**Interfaces:**
- Consumes: `ScoreRepository` (Task 6); `games_services` (`GameAuth.signIn`, `Leaderboards.submitScore`, `Leaderboards.showLeaderboards`, `Score`)
- Produces:
  - `abstract interface class LeaderboardBackend { Future<void> signIn(); Future<void> submit(int score); Future<void> show(); }`
  - `class GamesServicesBackend implements LeaderboardBackend`
  - `class UnsupportedBackend implements LeaderboardBackend`
  - `LeaderboardBackend platformLeaderboardBackend()`
  - `class LeaderboardService { LeaderboardService(LeaderboardBackend backend, ScoreRepository scores); bool get isSignedIn; Future<void> init(); Future<void> submit(int score); Future<void> show(); }`
  - Constants `androidLeaderboardId`, `iosLeaderboardId` (real values filled in Tasks 11–12).

- [ ] **Step 1: Write the failing test**

`test/services/leaderboard_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:helicopter/services/leaderboard_service.dart';
import 'package:helicopter/services/score_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBackend implements LeaderboardBackend {
  bool failSignIn = false;
  bool failSubmit = false;
  final submitted = <int>[];
  int shown = 0;

  @override
  Future<void> signIn() async {
    if (failSignIn) throw Exception('sign-in failed');
  }

  @override
  Future<void> submit(int score) async {
    if (failSubmit) throw Exception('submit failed');
    submitted.add(score);
  }

  @override
  Future<void> show() async {
    shown++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ScoreRepository scores;
  late FakeBackend backend;
  late LeaderboardService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    scores = ScoreRepository(await SharedPreferences.getInstance());
    backend = FakeBackend();
    service = LeaderboardService(backend, scores);
  });

  test('signed in: submits and leaves nothing pending', () async {
    await service.init();
    await service.submit(50);
    expect(backend.submitted, [50]);
    expect(scores.pendingSubmission, isNull);
  });

  test('sign-in failure does not throw and stores the score as pending',
      () async {
    backend.failSignIn = true;
    await service.init();
    expect(service.isSignedIn, isFalse);
    await service.submit(50);
    await service.submit(30);
    expect(backend.submitted, isEmpty);
    expect(scores.pendingSubmission, 50);
  });

  test('submit failure does not throw and stores the score as pending',
      () async {
    await service.init();
    backend.failSubmit = true;
    await service.submit(40);
    expect(scores.pendingSubmission, 40);
  });

  test('init flushes a pending score after successful sign-in', () async {
    await scores.setPendingSubmission(99);
    await service.init();
    expect(backend.submitted, [99]);
    expect(scores.pendingSubmission, isNull);
  });

  test('submit sends the higher of the new and pending score', () async {
    await service.init();
    await scores.setPendingSubmission(500);
    await service.submit(100);
    expect(backend.submitted, [500]);
  });

  test('show signs in on demand and opens the leaderboard', () async {
    await service.show();
    expect(service.isSignedIn, isTrue);
    expect(backend.shown, 1);
  });

  test('show does nothing when sign-in fails', () async {
    backend.failSignIn = true;
    await service.show();
    expect(backend.shown, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/leaderboard_service_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:helicopter/services/leaderboard_service.dart'`.

- [ ] **Step 3: Implement service**

`lib/services/leaderboard_service.dart`:
```dart
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import 'score_repository.dart';

// Set from Play Console (Task 11) and App Store Connect (Task 12).
const androidLeaderboardId = 'REPLACE_WITH_PLAY_CONSOLE_LEADERBOARD_ID';
const iosLeaderboardId = 'helicopter_distance';

abstract interface class LeaderboardBackend {
  Future<void> signIn();
  Future<void> submit(int score);
  Future<void> show();
}

class GamesServicesBackend implements LeaderboardBackend {
  @override
  Future<void> signIn() async {
    await GameAuth.signIn();
  }

  @override
  Future<void> submit(int score) async {
    await Leaderboards.submitScore(
      score: Score(
        androidLeaderboardID: androidLeaderboardId,
        iOSLeaderboardID: iosLeaderboardId,
        value: score,
      ),
    );
  }

  @override
  Future<void> show() async {
    await Leaderboards.showLeaderboards(
      androidLeaderboardID: androidLeaderboardId,
      iOSLeaderboardID: iosLeaderboardId,
    );
  }
}

class UnsupportedBackend implements LeaderboardBackend {
  @override
  Future<void> signIn() async =>
      throw UnsupportedError('Leaderboards require iOS or Android');

  @override
  Future<void> submit(int score) async =>
      throw UnsupportedError('Leaderboards require iOS or Android');

  @override
  Future<void> show() async =>
      throw UnsupportedError('Leaderboards require iOS or Android');
}

LeaderboardBackend platformLeaderboardBackend() =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS)
        ? GamesServicesBackend()
        : UnsupportedBackend();

class LeaderboardService {
  LeaderboardService(this._backend, this._scores);

  final LeaderboardBackend _backend;
  final ScoreRepository _scores;
  bool _signedIn = false;

  bool get isSignedIn => _signedIn;

  Future<void> init() async {
    await _trySignIn();
    final pending = _scores.pendingSubmission;
    if (_signedIn && pending != null) await submit(pending);
  }

  Future<void> submit(int score) async {
    final toSend = max(score, _scores.pendingSubmission ?? 0);
    if (_signedIn) {
      try {
        await _backend.submit(toSend);
        await _scores.setPendingSubmission(null);
        return;
      } catch (e) {
        debugPrint('Leaderboard submit failed: $e');
      }
    }
    await _scores.setPendingSubmission(toSend);
  }

  Future<void> show() async {
    if (!_signedIn) await _trySignIn();
    if (!_signedIn) return;
    try {
      await _backend.show();
    } catch (e) {
      debugPrint('Leaderboard show failed: $e');
    }
  }

  Future<void> _trySignIn() async {
    try {
      await _backend.signIn();
      _signedIn = true;
    } catch (e) {
      debugPrint('Leaderboard sign-in failed: $e');
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/leaderboard_service_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```powershell
git add lib/services/leaderboard_service.dart test/services/leaderboard_service_test.dart
git commit -m "feat(services): add offline-tolerant leaderboard service"
```

---

### Task 8: Audio assets and audio service

**Files:**
- Create: `tool/gen_audio.dart`
- Create (generated): `assets/audio/rotor.wav`, `assets/audio/crash.wav`
- Create: `lib/services/audio_service.dart`
- Modify: `pubspec.yaml` (`flutter:` section)
- Test: `test/services/audio_service_test.dart`

**Interfaces:**
- Consumes: `flame_audio`
- Produces:
  - `class AudioService { bool get muted; Future<void> load(); Future<void> startRotor(); Future<void> stopRotor(); Future<void> playCrash(); Future<void> setMuted(bool value); }`

- [ ] **Step 1: Write the audio generator**

`tool/gen_audio.dart`:
```dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sampleRate = 22050;

void main() {
  Directory('assets/audio').createSync(recursive: true);
  final rng = Random(1);

  // 12 chops per second over exactly 1 s so the loop is seamless.
  final rotor = List<double>.generate(sampleRate, (i) {
    final t = i / sampleRate;
    final chop = pow(0.5 + 0.5 * cos(2 * pi * 12 * t), 4).toDouble();
    final noise = rng.nextDouble() * 2 - 1;
    return (noise * 0.4 + sin(2 * pi * 48 * t) * 0.3) * chop;
  });
  _writeWav('assets/audio/rotor.wav', rotor);

  var lowPass = 0.0;
  final crash = List<double>.generate((sampleRate * 0.8).round(), (i) {
    final t = i / sampleRate;
    lowPass += 0.2 * ((rng.nextDouble() * 2 - 1) - lowPass);
    return lowPass * exp(-4 * t) * 2.5;
  });
  _writeWav('assets/audio/crash.wav', crash);

  stdout.writeln('Wrote assets/audio/rotor.wav and assets/audio/crash.wav');
}

void _writeWav(String path, List<double> samples) {
  final dataBytes = samples.length * 2;
  final bytes = ByteData(44 + dataBytes);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    bytes.setInt16(44 + i * 2, v, Endian.little);
  }
  File(path).writeAsBytesSync(bytes.buffer.asUint8List());
}
```

- [ ] **Step 2: Generate assets**

Run: `dart run tool/gen_audio.dart`
Expected: `Wrote assets/audio/rotor.wav and assets/audio/crash.wav`; both files exist (rotor ≈ 44 KB, crash ≈ 35 KB).

- [ ] **Step 3: Register assets**

In `pubspec.yaml`, under the existing `flutter:` key (keep `uses-material-design: true`):
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/audio/
```

- [ ] **Step 4: Write the failing test**

`test/services/audio_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:helicopter/services/audio_service.dart';

void main() {
  test('calls before load are safe no-ops', () async {
    final audio = AudioService();
    await audio.startRotor();
    await audio.playCrash();
    await audio.stopRotor();
    expect(audio.muted, isFalse);
  });

  test('setMuted toggles the flag', () async {
    final audio = AudioService();
    await audio.setMuted(true);
    expect(audio.muted, isTrue);
    await audio.setMuted(false);
    expect(audio.muted, isFalse);
  });
}
```

- [ ] **Step 5: Run test to verify it fails**

Run: `flutter test test/services/audio_service_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:helicopter/services/audio_service.dart'`.

- [ ] **Step 6: Implement audio service**

`lib/services/audio_service.dart`:
```dart
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static const rotorFile = 'rotor.wav';
  static const crashFile = 'crash.wav';

  bool _loaded = false;
  bool _muted = false;
  AudioPlayer? _rotor;

  bool get muted => _muted;

  Future<void> load() async {
    try {
      await FlameAudio.audioCache.loadAll([rotorFile, crashFile]);
      _loaded = true;
    } catch (e) {
      debugPrint('Audio disabled: $e');
    }
  }

  Future<void> startRotor() async {
    if (!_loaded || _muted || _rotor != null) return;
    try {
      _rotor = await FlameAudio.loop(rotorFile, volume: 0.35);
    } catch (e) {
      debugPrint('Rotor sound failed: $e');
    }
  }

  Future<void> stopRotor() async {
    final rotor = _rotor;
    _rotor = null;
    if (rotor == null) return;
    try {
      await rotor.stop();
      await rotor.dispose();
    } catch (e) {
      debugPrint('Rotor stop failed: $e');
    }
  }

  Future<void> playCrash() async {
    if (!_loaded || _muted) return;
    try {
      await FlameAudio.play(crashFile, volume: 0.8);
    } catch (e) {
      debugPrint('Crash sound failed: $e');
    }
  }

  Future<void> setMuted(bool value) async {
    _muted = value;
    if (value) await stopRotor();
  }
}
```

- [ ] **Step 7: Run tests and analyze**

Run: `flutter test test/services; flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 8: Commit**

```powershell
git add tool assets pubspec.yaml lib/services/audio_service.dart test/services/audio_service_test.dart
git commit -m "feat(services): add synthesized SFX and audio service"
```

---

### Task 9: Flame game and render components

**Files:**
- Create: `lib/game/helicopter_game.dart`
- Create: `lib/game/components/palette.dart`
- Create: `lib/game/components/cave_component.dart`
- Create: `lib/game/components/obstacle_component.dart`
- Create: `lib/game/components/heli_component.dart`
- Create: `lib/game/components/smoke_component.dart`
- Create: `lib/game/components/explosion_component.dart`
- Create: `lib/game/components/hud_component.dart`
- Test: `test/game/helicopter_game_test.dart`

**Interfaces:**
- Consumes: `GameConfig` (Task 2), `GameWorld` (Task 5), `ScoreRepository` (Task 6), `LeaderboardService`, `LeaderboardBackend` (Task 7), `AudioService` (Task 8)
- Produces:
  - `enum GamePhase { ready, playing, crashed }`
  - `class HelicopterGame extends FlameGame { HelicopterGame({required ScoreRepository scores, required LeaderboardService leaderboard, required AudioService audio, int Function()? seedSource}); static const double restartDelay; final ScoreRepository scores; final LeaderboardService leaderboard; final AudioService audio; final ValueNotifier<GamePhase> phase; late GameWorld state; double crashElapsed; bool get holding; int get displayedBest; void pointerDown(); void pointerUp(); }`

- [ ] **Step 1: Write the failing test**

`test/game/helicopter_game_test.dart`:
```dart
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helicopter/core/config.dart';
import 'package:helicopter/game/helicopter_game.dart';
import 'package:helicopter/services/audio_service.dart';
import 'package:helicopter/services/leaderboard_service.dart';
import 'package:helicopter/services/score_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBackend implements LeaderboardBackend {
  @override
  Future<void> signIn() async {}
  @override
  Future<void> submit(int score) async {}
  @override
  Future<void> show() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ScoreRepository scores;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    scores = ScoreRepository(await SharedPreferences.getInstance());
  });

  HelicopterGame build() => HelicopterGame(
        scores: scores,
        leaderboard: LeaderboardService(FakeBackend(), scores),
        audio: AudioService(),
        seedSource: () => 1,
      );

  void fallUntilCrash(HelicopterGame game) {
    for (var i = 0; i < 600 && game.phase.value == GamePhase.playing; i++) {
      game.update(GameConfig.fixedDt);
    }
  }

  testWithGame<HelicopterGame>('starts ready and begins on first press', build,
      (game) async {
    expect(game.phase.value, GamePhase.ready);
    game.pointerDown();
    expect(game.phase.value, GamePhase.playing);
    expect(game.holding, isTrue);
    game.pointerUp();
    expect(game.holding, isFalse);
  });

  testWithGame<HelicopterGame>('multi-touch holds until the last finger lifts',
      build, (game) async {
    game.pointerDown();
    game.pointerDown();
    game.pointerUp();
    expect(game.holding, isTrue);
    game.pointerUp();
    expect(game.holding, isFalse);
  });

  testWithGame<HelicopterGame>(
      'crash saves the best score and queues leaderboard submission', build,
      (game) async {
    game.pointerDown();
    game.pointerUp();
    fallUntilCrash(game);
    expect(game.phase.value, GamePhase.crashed);

    await Future<void>.delayed(Duration.zero);
    expect(game.state.score, greaterThan(0));
    expect(scores.best, game.state.score);
    // Not signed in (init not called), so the score is kept as pending.
    expect(scores.pendingSubmission, game.state.score);
  });

  testWithGame<HelicopterGame>('restart is ignored until the delay passes',
      build, (game) async {
    game.pointerDown();
    game.pointerUp();
    fallUntilCrash(game);

    game.pointerDown();
    game.pointerUp();
    expect(game.phase.value, GamePhase.crashed);

    game.update(HelicopterGame.restartDelay + 0.01);
    game.pointerDown();
    expect(game.phase.value, GamePhase.playing);
    expect(game.state.distance, 0);
    expect(game.state.crashed, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/game/helicopter_game_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:helicopter/game/helicopter_game.dart'`.

- [ ] **Step 3: Create palette**

`lib/game/components/palette.dart`:
```dart
import 'dart:ui';

abstract final class Palette {
  static const greenColor = Color(0xFF00DD00);
  static const heliColor = Color(0xFFDDDDDD);
  static const cockpitColor = Color(0xFF66AAFF);
  static const smokeColor = Color(0xFF999999);
  static const fireColor = Color(0xFFFF8800);
  static const sparkColor = Color(0xFFFFEE00);

  static final green = Paint()..color = greenColor;
  static final heli = Paint()..color = heliColor;
  static final cockpit = Paint()..color = cockpitColor;
}
```

- [ ] **Step 4: Create cave and obstacle components**

`lib/game/components/cave_component.dart`:
```dart
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:helicopter/core/config.dart';
import 'package:helicopter/game/components/palette.dart';
import 'package:helicopter/game/helicopter_game.dart';

class CaveComponent extends Component with HasGameReference<HelicopterGame> {
  // Slight overdraw hides seams between adjacent columns.
  static const _width = GameConfig.columnWidth + 0.5;

  @override
  void render(Canvas canvas) {
    for (final c in game.state.columns) {
      canvas.drawRect(Rect.fromLTWH(c.x, 0, _width, c.top), Palette.green);
      canvas.drawRect(
        Rect.fromLTWH(c.x, c.bottom, _width, GameConfig.playHeight - c.bottom),
        Palette.green,
      );
    }
  }
}
```

`lib/game/components/obstacle_component.dart`:
```dart
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:helicopter/core/config.dart';
import 'package:helicopter/game/components/palette.dart';
import 'package:helicopter/game/helicopter_game.dart';

class ObstacleComponent extends Component
    with HasGameReference<HelicopterGame> {
  @override
  void render(Canvas canvas) {
    for (final o in game.state.obstacles) {
      canvas.drawRect(
        Rect.fromLTWH(
            o.x, o.y, GameConfig.obstacleWidth, GameConfig.obstacleHeight),
        Palette.green,
      );
    }
  }
}
```

- [ ] **Step 5: Create helicopter component**

`lib/game/components/heli_component.dart`:
```dart
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:helicopter/core/config.dart';
import 'package:helicopter/game/components/palette.dart';
import 'package:helicopter/game/helicopter_game.dart';

class HeliComponent extends Component with HasGameReference<HelicopterGame> {
  static const _pixel = 2.0;
  static const _rotorFrameSeconds = 0.05;

  // 24x10 grid at 2px = 48x20, matching GameConfig.heliWidth/heliHeight.
  static const _rotorFrames = [
    '..XXXXXXXXXXXXXXXXXXXX..',
    '.......XXXXXXXXXX.......',
  ];
  static const _body = [
    '...........XX...........',
    '.........XXXXXXX........',
    'X.......XXXXXXCCC.......',
    'XXXXXXXXXXXXXXCCCC......',
    'X.......XXXXXXXXXXX.....',
    '.........XXXXXXXXX......',
    '..........X....X........',
    '.......XXXXXXXXXXXX.....',
    '........................',
  ];

  double _time = 0;

  @override
  void update(double dt) {
    if (game.phase.value == GamePhase.playing) _time += dt;
  }

  @override
  void render(Canvas canvas) {
    if (game.phase.value == GamePhase.crashed) return;

    final frame = (_time / _rotorFrameSeconds).floor() % 2;
    final rows = [_rotorFrames[frame], ..._body];
    final top = game.state.heli.y;

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        final ch = row[c];
        if (ch == '.') continue;
        canvas.drawRect(
          Rect.fromLTWH(
            GameConfig.heliX + c * _pixel,
            top + r * _pixel,
            _pixel,
            _pixel,
          ),
          ch == 'C' ? Palette.cockpit : Palette.heli,
        );
      }
    }
  }
}
```

- [ ] **Step 6: Create smoke component**

`lib/game/components/smoke_component.dart`:
```dart
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:helicopter/core/config.dart';
import 'package:helicopter/game/components/palette.dart';
import 'package:helicopter/game/helicopter_game.dart';

class _Puff {
  _Puff(this.x, this.y);

  double x;
  final double y;
  double age = 0;
}

class SmokeComponent extends Component with HasGameReference<HelicopterGame> {
  static const _interval = 0.06;
  static const _life = 0.7;
  static const _size = 6.0;

  final _puffs = <_Puff>[];
  final _paint = Paint();
  double _sinceSpawn = 0;

  void clear() {
    _puffs.clear();
    _sinceSpawn = 0;
  }

  @override
  void update(double dt) {
    if (game.phase.value != GamePhase.playing) return;

    _sinceSpawn += dt;
    while (_sinceSpawn >= _interval) {
      _sinceSpawn -= _interval;
      _puffs.add(_Puff(
        GameConfig.heliX - _size,
        game.state.heli.y + GameConfig.heliHeight * 0.4,
      ));
    }
    for (final p in _puffs) {
      p.x -= GameConfig.scrollSpeed * dt;
      p.age += dt;
    }
    _puffs.removeWhere((p) => p.age >= _life);
  }

  @override
  void render(Canvas canvas) {
    for (final p in _puffs) {
      _paint.color =
          Palette.smokeColor.withValues(alpha: 0.8 * (1 - p.age / _life));
      canvas.drawRect(Rect.fromLTWH(p.x, p.y, _size, _size), _paint);
    }
  }
}
```

- [ ] **Step 7: Create explosion component**

`lib/game/components/explosion_component.dart`:
```dart
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:helicopter/core/config.dart';
import 'package:helicopter/game/components/palette.dart';
import 'package:helicopter/game/helicopter_game.dart';

class ExplosionComponent extends Component
    with HasGameReference<HelicopterGame> {
  static const _duration = 0.6;
  static const _reach = 60.0;
  static const _directions = [
    (1.0, 0.0), (0.7, 0.7), (0.0, 1.0), (-0.7, 0.7),
    (-1.0, 0.0), (-0.7, -0.7), (0.0, -1.0), (0.7, -0.7),
  ];

  final _paint = Paint();

  @override
  void render(Canvas canvas) {
    if (game.phase.value != GamePhase.crashed) return;
    final t = game.crashElapsed;
    if (t >= _duration) return;

    final progress = t / _duration;
    final cx = GameConfig.heliX + GameConfig.heliWidth / 2;
    final cy = game.state.heli.y + GameConfig.heliHeight / 2;
    final size = 10 * (1 - progress) + 2;

    _paint.color = Palette.sparkColor;
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(cx, cy), width: size * 2, height: size * 2),
      _paint,
    );
    for (var i = 0; i < _directions.length; i++) {
      final (dx, dy) = _directions[i];
      _paint.color = i.isEven ? Palette.fireColor : Palette.sparkColor;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(
              cx + dx * progress * _reach, cy + dy * progress * _reach),
          width: size,
          height: size,
        ),
        _paint,
      );
    }
  }
}
```

- [ ] **Step 8: Create HUD component**

`lib/game/components/hud_component.dart`:
```dart
import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';
import 'package:helicopter/core/config.dart';
import 'package:helicopter/game/components/palette.dart';
import 'package:helicopter/game/helicopter_game.dart';

class HudComponent extends Component with HasGameReference<HelicopterGame> {
  static const _margin = 10.0;
  static const _y = GameConfig.playHeight +
      (GameConfig.worldHeight - GameConfig.playHeight) / 2;

  static final _text = TextPaint(
    style: const TextStyle(
      color: Palette.greenColor,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      fontFamily: 'Courier',
      fontFamilyFallback: ['monospace'],
    ),
  );

  @override
  void render(Canvas canvas) {
    _text.render(canvas, 'DISTANCE: ${game.state.score}',
        Vector2(_margin, _y), anchor: Anchor.centerLeft);
    _text.render(canvas, 'BEST: ${game.displayedBest}',
        Vector2(GameConfig.worldWidth - _margin, _y),
        anchor: Anchor.centerRight);
  }
}
```

- [ ] **Step 9: Create the game**

`lib/game/helicopter_game.dart`:
```dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:helicopter/core/config.dart';
import 'package:helicopter/core/world_state.dart';
import 'package:helicopter/game/components/cave_component.dart';
import 'package:helicopter/game/components/explosion_component.dart';
import 'package:helicopter/game/components/heli_component.dart';
import 'package:helicopter/game/components/hud_component.dart';
import 'package:helicopter/game/components/obstacle_component.dart';
import 'package:helicopter/game/components/smoke_component.dart';
import 'package:helicopter/services/audio_service.dart';
import 'package:helicopter/services/leaderboard_service.dart';
import 'package:helicopter/services/score_repository.dart';

enum GamePhase { ready, playing, crashed }

class HelicopterGame extends FlameGame {
  HelicopterGame({
    required this.scores,
    required this.leaderboard,
    required this.audio,
    int Function()? seedSource,
  })  : _seedSource = seedSource ?? _randomSeed,
        super(
          camera: CameraComponent.withFixedResolution(
            width: GameConfig.worldWidth,
            height: GameConfig.worldHeight,
          ),
        );

  // Prevents the tap that caused the crash from instantly restarting.
  static const double restartDelay = 0.6;

  static int _randomSeed() => Random().nextInt(1 << 31);

  final ScoreRepository scores;
  final LeaderboardService leaderboard;
  final AudioService audio;
  final int Function() _seedSource;
  final ValueNotifier<GamePhase> phase = ValueNotifier(GamePhase.ready);

  late GameWorld state;
  late final SmokeComponent _smoke;
  double crashElapsed = 0;
  int _pointers = 0;

  bool get holding => _pointers > 0;

  int get displayedBest => max(scores.best, state.score);

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    state = GameWorld(seed: _seedSource());
    _smoke = SmokeComponent();
    world.addAll([
      CaveComponent(),
      ObstacleComponent(),
      _smoke,
      HeliComponent(),
      ExplosionComponent(),
      HudComponent(),
    ]);
  }

  void pointerDown() {
    _pointers++;
    switch (phase.value) {
      case GamePhase.ready:
        _start();
      case GamePhase.crashed:
        if (crashElapsed >= restartDelay) {
          _reset();
          _start();
        }
      case GamePhase.playing:
        break;
    }
  }

  void pointerUp() {
    if (_pointers > 0) _pointers--;
  }

  @override
  void update(double dt) {
    switch (phase.value) {
      case GamePhase.playing:
        state.update(holding: holding, dt: dt);
        if (state.crashed) _onCrash();
      case GamePhase.crashed:
        crashElapsed += dt;
      case GamePhase.ready:
        break;
    }
    super.update(dt);
  }

  void _start() {
    phase.value = GamePhase.playing;
    unawaited(audio.startRotor());
  }

  void _reset() {
    state = GameWorld(seed: _seedSource());
    _smoke.clear();
    crashElapsed = 0;
    phase.value = GamePhase.ready;
  }

  void _onCrash() {
    crashElapsed = 0;
    phase.value = GamePhase.crashed;
    final score = state.score;
    unawaited(audio.stopRotor());
    unawaited(audio.playCrash());
    unawaited(scores.recordScore(score));
    unawaited(leaderboard.submit(score));
  }
}
```

- [ ] **Step 10: Run tests and analyze**

Run: `flutter test test/game; flutter analyze`
Expected: `All tests passed!` and `No issues found!`. If analyze flags `unnecessary_import` (e.g. `package:flame/camera.dart` or `package:flame/text.dart`, which some Flame versions re-export from `components.dart`), delete that import line and re-run.

- [ ] **Step 11: Commit**

```powershell
git add lib/game test/game
git commit -m "feat(game): add Flame game state machine and classic renderers"
```

---

### Task 10: Overlays, game screen, and app entry point

**Files:**
- Create: `lib/app/overlays/title_overlay.dart`
- Create: `lib/app/overlays/game_over_overlay.dart`
- Create: `lib/app/game_screen.dart`
- Create: `lib/app/helicopter_app.dart`
- Modify: `lib/main.dart` (replace entirely)
- Delete: `test/widget_test.dart`
- Test: `test/app/overlays_test.dart`
- Test: `test/app/game_screen_test.dart`

**Interfaces:**
- Consumes: `HelicopterGame`, `GamePhase` (Task 9); `ScoreRepository` (Task 6); `LeaderboardService`, `LeaderboardBackend`, `platformLeaderboardBackend` (Task 7); `AudioService` (Task 8)
- Produces:
  - `class TitleOverlay extends StatelessWidget { const TitleOverlay({required bool muted, required VoidCallback onToggleSound, required VoidCallback onLeaderboard}); }`
  - `class GameOverOverlay extends StatelessWidget { const GameOverOverlay(); }`
  - `class GameScreen extends StatefulWidget { const GameScreen({required HelicopterGame game}); }`
  - `class HelicopterApp extends StatelessWidget { const HelicopterApp({required HelicopterGame game}); }`

- [ ] **Step 1: Write the failing overlay tests**

`test/app/overlays_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helicopter/app/overlays/game_over_overlay.dart';
import 'package:helicopter/app/overlays/title_overlay.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('title shows name, instructions and buttons', (tester) async {
    await tester.pumpWidget(host(TitleOverlay(
      muted: false,
      onToggleSound: () {},
      onLeaderboard: () {},
    )));
    expect(find.text('HELICOPTER GAME'), findsOneWidget);
    expect(find.text('Press and hold to go up. Release to go down.'),
        findsOneWidget);
    expect(find.text('Tap to play'), findsOneWidget);
    expect(find.text('LEADERBOARD'), findsOneWidget);
    expect(find.text('SOUND: ON'), findsOneWidget);
  });

  testWidgets('title reflects muted state', (tester) async {
    await tester.pumpWidget(host(TitleOverlay(
      muted: true,
      onToggleSound: () {},
      onLeaderboard: () {},
    )));
    expect(find.text('SOUND: OFF'), findsOneWidget);
  });

  testWidgets('title buttons invoke callbacks', (tester) async {
    var sound = 0;
    var board = 0;
    await tester.pumpWidget(host(TitleOverlay(
      muted: false,
      onToggleSound: () => sound++,
      onLeaderboard: () => board++,
    )));
    await tester.tap(find.text('SOUND: ON'));
    await tester.tap(find.text('LEADERBOARD'));
    expect(sound, 1);
    expect(board, 1);
  });

  testWidgets('game over shows tap to play', (tester) async {
    await tester.pumpWidget(host(const GameOverOverlay()));
    expect(find.text('Tap to play'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app/overlays_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:helicopter/app/overlays/game_over_overlay.dart'`.

- [ ] **Step 3: Implement overlays**

`lib/app/overlays/title_overlay.dart`:
```dart
import 'package:flutter/material.dart';

class TitleOverlay extends StatelessWidget {
  const TitleOverlay({
    super.key,
    required this.muted,
    required this.onToggleSound,
    required this.onLeaderboard,
  });

  final bool muted;
  final VoidCallback onToggleSound;
  final VoidCallback onLeaderboard;

  static const _style = TextStyle(
    color: Color(0xFF00DD00),
    fontWeight: FontWeight.bold,
    fontFamily: 'Courier',
    fontFamilyFallback: ['monospace'],
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Taps on the text fall through to the game and start play.
          IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('HELICOPTER GAME', style: _style.copyWith(fontSize: 32)),
                const SizedBox(height: 12),
                Text(
                  'Press and hold to go up. Release to go down.',
                  style: _style.copyWith(fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text('Tap to play', style: _style.copyWith(fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: onLeaderboard,
                child: const Text('LEADERBOARD', style: _style),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: onToggleSound,
                child: Text(muted ? 'SOUND: OFF' : 'SOUND: ON', style: _style),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

`lib/app/overlays/game_over_overlay.dart`:
```dart
import 'package:flutter/material.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Center(
        child: Text(
          'Tap to play',
          style: TextStyle(
            color: Color(0xFF00DD00),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
            fontFamilyFallback: ['monospace'],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run overlay tests to verify they pass**

Run: `flutter test test/app/overlays_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Write the failing game screen test**

`test/app/game_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helicopter/app/game_screen.dart';
import 'package:helicopter/game/helicopter_game.dart';
import 'package:helicopter/services/audio_service.dart';
import 'package:helicopter/services/leaderboard_service.dart';
import 'package:helicopter/services/score_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBackend implements LeaderboardBackend {
  int shown = 0;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> submit(int score) async {}
  @override
  Future<void> show() async {
    shown++;
  }
}

void main() {
  testWidgets('title buttons do not start play; tapping the game does',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final scores = ScoreRepository(await SharedPreferences.getInstance());
    final backend = FakeBackend();
    final game = HelicopterGame(
      scores: scores,
      leaderboard: LeaderboardService(backend, scores),
      audio: AudioService(),
      seedSource: () => 1,
    );

    await tester.pumpWidget(MaterialApp(home: GameScreen(game: game)));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('LEADERBOARD'));
    await tester.pump();
    expect(game.phase.value, GamePhase.ready);
    expect(backend.shown, 1);

    await tester.tap(find.text('SOUND: ON'));
    await tester.pump();
    expect(game.phase.value, GamePhase.ready);
    expect(find.text('SOUND: OFF'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(game.phase.value, GamePhase.playing);
    expect(find.text('HELICOPTER GAME'), findsNothing);
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/app/game_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:helicopter/app/game_screen.dart'`.

- [ ] **Step 7: Implement game screen and app**

`lib/app/game_screen.dart`:
```dart
import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:helicopter/app/overlays/game_over_overlay.dart';
import 'package:helicopter/app/overlays/title_overlay.dart';
import 'package:helicopter/game/helicopter_game.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.game});

  final HelicopterGame game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  HelicopterGame get _game => widget.game;

  Future<void> _toggleSound() async {
    await _game.audio.setMuted(!_game.audio.muted);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _game.pointerDown(),
            onPointerUp: (_) => _game.pointerUp(),
            onPointerCancel: (_) => _game.pointerUp(),
            child: GameWidget(game: _game),
          ),
          ValueListenableBuilder<GamePhase>(
            valueListenable: _game.phase,
            builder: (context, phase, _) => switch (phase) {
              GamePhase.ready => TitleOverlay(
                  muted: _game.audio.muted,
                  onToggleSound: () => unawaited(_toggleSound()),
                  onLeaderboard: () => unawaited(_game.leaderboard.show()),
                ),
              GamePhase.crashed => const GameOverOverlay(),
              GamePhase.playing => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}
```

`lib/app/helicopter_app.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:helicopter/app/game_screen.dart';
import 'package:helicopter/game/helicopter_game.dart';

class HelicopterApp extends StatelessWidget {
  const HelicopterApp({super.key, required this.game});

  final HelicopterGame game;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helicopter',
      debugShowCheckedModeBanner: false,
      home: GameScreen(game: game),
    );
  }
}
```

Replace `lib/main.dart` entirely:
```dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:helicopter/app/helicopter_app.dart';
import 'package:helicopter/game/helicopter_game.dart';
import 'package:helicopter/services/audio_service.dart';
import 'package:helicopter/services/leaderboard_service.dart';
import 'package:helicopter/services/score_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final scores = ScoreRepository(await SharedPreferences.getInstance());
  final leaderboard = LeaderboardService(platformLeaderboardBackend(), scores);
  final audio = AudioService();
  await audio.load();
  unawaited(leaderboard.init());

  runApp(HelicopterApp(
    game: HelicopterGame(scores: scores, leaderboard: leaderboard, audio: audio),
  ));
}
```

Delete the generated counter test:
```powershell
Remove-Item test/widget_test.dart
```

- [ ] **Step 8: Run full suite and analyze**

Run: `flutter analyze; flutter test`
Expected: `No issues found!` and `All tests passed!`

- [ ] **Step 9: Smoke-run on Android emulator**

Run: `flutter emulators --launch <your_emulator_id>; flutter run`
Expected: Landscape black screen with green cave and helicopter; title text visible; press-and-hold climbs, release falls; crash shows explosion and "Tap to play"; `BEST` persists after restarting the app. (Leaderboard button logs a sign-in failure until Task 11 — expected.)

- [ ] **Step 10: Commit**

```powershell
git add lib test
git commit -m "feat(app): add title/game-over overlays, input layer and entry point"
```

---

### Task 11: Android release signing and Google Play Games leaderboard

**Files:**
- Create: `android/app/src/main/res/values/games-ids.xml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/build.gradle.kts`
- Modify: `lib/services/leaderboard_service.dart` (`androidLeaderboardId`)
- Create (local only, git-ignored): `android/key.properties`, `%USERPROFILE%\upload-keystore.jks`

**Interfaces:**
- Consumes: `androidLeaderboardId` constant (Task 7)
- Produces: signed release `.aab`; working Play Games sign-in/leaderboard on Android.

- [ ] **Step 1: Create Play Console app and leaderboard (manual)**

In Google Play Console: create app "Helicopter" with package `com.nhk.helicopter` → Grow → Play Games Services → Setup → create a new Games Services project → add Android credentials (package `com.nhk.helicopter`, SHA-1 of the upload key from Step 3 and of the debug key from `cd android; .\gradlew signingReport`) → Leaderboards → create "Distance" (integer, higher is better). Record the **Project ID** (numeric) and the **Leaderboard ID** (starts with `Cgk`). Add your Google account as a tester.

- [ ] **Step 2: Wire Play Games project ID**

Create `android/app/src/main/res/values/games-ids.xml` (use your numeric Project ID):
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="game_services_project_id" translatable="false">123456789012</string>
</resources>
```

In `android/app/src/main/AndroidManifest.xml`, inside `<application ...>` (sibling of `<activity>`), add:
```xml
        <meta-data
            android:name="com.google.android.gms.games.APP_ID"
            android:value="@string/game_services_project_id" />
```

In `lib/services/leaderboard_service.dart`, set:
```dart
const androidLeaderboardId = 'CgkI...'; // the Leaderboard ID from Step 1
```

- [ ] **Step 3: Create upload key (you type the passwords)**

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Create `android/key.properties` (git-ignored in Task 1):
```properties
storePassword=<the store password you chose>
keyPassword=<the key password you chose>
keyAlias=upload
storeFile=C:/Users/NHA7CX/upload-keystore.jks
```

- [ ] **Step 4: Configure release signing**

In `android/app/build.gradle.kts`, add at the top (below the `plugins { }` block):
```kotlin
import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```
Inside `android { }`, add a `signingConfigs` block before `buildTypes` and point release at it (replace the generated `signingConfig = signingConfigs.getByName("debug")` line):
```kotlin
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
```
(If Gradle complains that `import` must be at the top of the file, move the two `import` lines above `plugins { }`.)

- [ ] **Step 5: Verify on device**

Run: `flutter run --release` on a physical Android device signed into the tester Google account.
Expected: Play Games sign-in banner appears on launch; after a crash, LEADERBOARD on the title screen opens the "Distance" leaderboard containing your score.

- [ ] **Step 6: Build bundle and verify tests**

Run: `flutter analyze; flutter test; flutter build appbundle --release`
Expected: `No issues found!`, `All tests passed!`, `√ Built build\app\outputs\bundle\release\app-release.aab`. Upload it to Play Console → Internal testing.

- [ ] **Step 7: Commit (secrets excluded)**

```powershell
git status   # confirm key.properties and *.jks are NOT listed
git add android/app/src/main/res/values/games-ids.xml android/app/src/main/AndroidManifest.xml android/app/build.gradle.kts lib/services/leaderboard_service.dart
git commit -m "feat(android): release signing and Play Games leaderboard"
```

---

### Task 12: iOS build in the cloud with Game Center

**Files:**
- Create: `ios/Runner/Runner.entitlements`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Create: `codemagic.yaml`
- Modify: `lib/services/leaderboard_service.dart` (`iosLeaderboardId`, only if you chose a different ID)

**Interfaces:**
- Consumes: `iosLeaderboardId` constant (Task 7)
- Produces: TestFlight build with working Game Center leaderboard.

- [ ] **Step 1: Apple setup (manual, in a browser)**

1. Apple Developer → Identifiers → register App ID `com.nhk.helicopter` with **Game Center** capability enabled.
2. App Store Connect → My Apps → New App "Helicopter", bundle ID `com.nhk.helicopter`.
3. In that app → Services → Game Center → Leaderboards → add "Classic Leaderboard", reference name "Distance", **Leaderboard ID `helicopter_distance`**, score format Integer, sort High to Low. Enable Game Center on the app version.
4. Users and Access → Integrations → App Store Connect API → generate a key with **App Manager** role; download the `.p8`, note Issuer ID and Key ID.

- [ ] **Step 2: Add Game Center entitlement**

Create `ios/Runner/Runner.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.game-center</key>
	<true/>
</dict>
</plist>
```

In `ios/Runner.xcodeproj/project.pbxproj`, find the three `buildSettings` blocks that contain `PRODUCT_BUNDLE_IDENTIFIER = com.nhk.helicopter;` (Debug, Release, Profile — not the `RunnerTests` ones) and add this line to each, next to `PRODUCT_BUNDLE_IDENTIFIER`:
```
				CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
```

- [ ] **Step 3: Add Codemagic workflow**

Create `codemagic.yaml`:
```yaml
workflows:
  ios-testflight:
    name: iOS TestFlight
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: helicopter_asc_key
    environment:
      flutter: stable
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.nhk.helicopter
    triggering:
      events:
        - tag
    scripts:
      - name: Get packages
        script: flutter pub get
      - name: Analyze and test
        script: |
          flutter analyze
          flutter test
      - name: Apply signing profiles
        script: xcode-project use-profiles
      - name: Build IPA
        script: |
          flutter build ipa --release \
            --build-number=$PROJECT_BUILD_NUMBER \
            --export-options-plist=/Users/builder/export_options.plist
    artifacts:
      - build/ios/ipa/*.ipa
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
```

- [ ] **Step 4: Connect Codemagic (manual)**

Push the repo to GitHub (or GitLab). In codemagic.io: add the repository → Team settings → Integrations → Developer Portal → add the API key from Step 1.4 named **`helicopter_asc_key`** → Code signing identities → let Codemagic fetch/create the App Store distribution certificate and profile for `com.nhk.helicopter`.

- [ ] **Step 5: Verify locally, commit, tag**

Run: `flutter analyze; flutter test`
Expected: `No issues found!` and `All tests passed!`

```powershell
git add ios/Runner/Runner.entitlements ios/Runner.xcodeproj/project.pbxproj codemagic.yaml lib/services/leaderboard_service.dart
git commit -m "feat(ios): Game Center entitlement and Codemagic TestFlight workflow"
git tag v0.1.0
git push --follow-tags
```
Expected: Codemagic build `ios-testflight` starts on the tag and finishes green; the build appears in TestFlight.

- [ ] **Step 6: Verify on iPhone**

Install from TestFlight on an iPhone signed into Game Center (sandbox).
Expected: Game Center welcome banner on launch; crash → LEADERBOARD shows "Distance" with your score; landscape only; no status bar.

---

### Task 13: Feel tuning and release checklist

**Files:**
- Modify: `lib/core/config.dart` (only constant values)

**Interfaces:**
- Consumes: everything
- Produces: tuned constants; release-ready builds.

- [ ] **Step 1: Playtest on one Android and one iOS device**

Check each item and note values to change:
- Hold for ~0.5 s from rest: helicopter should visibly ease into climbing (not snap). Adjust `thrust` / `gravity`.
- Typical first-time run lasts 10–30 s; a skilled run reaches the minimum gap (~3500 distance). Adjust `gapShrinkPerPx`, `obstacleSpacingShrinkPerPx`.
- Cave walls look jagged but not noisy. Adjust `maxCenterStep`.
- Hitbox feels fair (no "I didn't touch it" crashes). Adjust `hitboxInset`.
- 60 fps with no visible stutter while smoke is active.

- [ ] **Step 2: Apply changes and re-run tests**

Edit only values in `lib/core/config.dart`, then run: `flutter test`
Expected: `All tests passed!` (generator tests assert invariants, not exact numbers, so they survive tuning as long as `minGap >= obstacleHeight + minPassable`).

- [ ] **Step 3: Commit**

```powershell
git add lib/core/config.dart
git commit -m "tune: adjust physics and difficulty after device playtest"
```
