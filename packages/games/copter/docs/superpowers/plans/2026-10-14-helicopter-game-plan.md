# Helicopter Game (Mobile) — Development Plan

Date: 2026-10-14 · Spec: [2026-10-14-helicopter-game-design.md](../specs/2026-10-14-helicopter-game-design.md) (rev 1.3 — retro phone-game UI redesign) · UI: [design canvas](https://claude.ai/artifact/BZmh5D8PVzgqnXemYQszzm)

## Approach

- **Walking skeleton first.** The riskiest parts are not the game; they are iOS signing and Game Center entitlements, and Play's release gates. A blank app is shipped to TestFlight and a Play internal track in week 1, before gameplay work.
- **Core before pixels.** `lib/core/` is built test-first as pure Dart. Rendering is added only when the headless simulation passes its tests, including the passability and frame-rate-independence tests.
- **Playable on device early.** From M2 onward, every milestone ends with a build on the reference Android device.
- **Tune with data, not guesses.** All tuning constants live in `config.dart`; a debug overlay shows FPS, sim steps per frame, and the reachable band.

Assumptions: one developer, ~6 productive hours/day. Estimates are in ideal days; the calendar adds store review and the Play closed-testing wait.

## Timeline Overview

| Milestone | Content | Est. (days) | Week |
|---|---|---|---|
| M0 | Accounts, repo, CI, walking skeleton on both stores | 3 | 1 |
| M1 | Core simulation (TDD) | 4 | 1–2 |
| M2 | LCD rendering, input, fixed-step loop — playable on Android | 5 | 2–3 |
| M3 | Game flow: states, overlays, HUD, lifecycle | 3 | 3 |
| M4 | Audio, persistence, assets (font, icon) | 2 | 4 |
| M5 | Leaderboards (Android, then iOS) | 3 | 4 |
| M6 | Tuning, performance, polish, device QA | 4 | 5 |
| M7 | Release prep, closed testing, store submission | 2 + wait | 5–7 |
| | **Total** | **~26 days dev** | **~5 weeks dev + 14-day Play closed test (overlaps)** |

Critical path: Apple/Google account approval (M0) → Play closed test start (start it as early as M3 with any playable build so the 14-day clock runs in parallel) → production review.

```
Week:        1        2        3        4        5        6        7
M0 skeleton  ███
M1 core        ██████
M2 render            ██████
M3 flow                   ████
M4 audio/assets                ███
M5 leaderbd                      ████
M6 tuning/QA                         ██████
M7 release                                 ███ ............ (store review)
Play closed test (≥12 testers, 14 days)  ░░░░░░░░░░░░░░░░░░░░
```

---

## M0 — Foundations and Walking Skeleton (3 days)

Goal: an empty Flutter app, landscape-locked, builds and installs from CI on both stores' test tracks.

| # | Task | Output / Acceptance |
|---|---|---|
| 0.1 | Resolve open decisions D1–D4 from the spec (name, Play account type, age group, CI provider) | Decisions written into the spec |
| 0.2 | Enroll Apple Developer Program and Google Play Console (start day 1: approval can take days) | Accounts active |
| 0.3 | `flutter create --org <reverse-domain> --platforms android,ios,windows helicoopter`; `git init`; `.gitignore` incl. keystores, `key.properties`, API keys | Repo with first commit |
| 0.4 | Add dependencies (flame, flame_audio, games_services, shared_preferences), dev deps (flutter_lints or very_good_analysis, integration_test); pin versions | `flutter pub get` clean; `flutter analyze` 0 issues |
| 0.5 | `main.dart`: landscape lock (both directions), immersive sticky fullscreen, placeholder screen in the `lcd` colour | Runs on Android device, iOS simulator and macOS |
| 0.6 | Android release signing: generate upload keystore, `key.properties` (git-ignored), enable Play App Signing; set `applicationId`, `minSdk`, target SDK per Play requirement | `flutter build appbundle --release` succeeds locally |
| 0.7 | iOS: set bundle id, display name, `UISupportedInterfaceOrientations` = landscape only, `UIRequiresFullScreen`; add `Runner.entitlements` with `com.apple.developer.game-center` and wire it in `project.pbxproj` | Diff committed |
| 0.8 | App Store Connect: create app record, App Store Connect API key, enable Game Center | API key stored in CI secrets |
| 0.9 | CI (GitHub Actions): on push → `flutter analyze`, `flutter test`, `flutter build appbundle` | Green pipeline |
| 0.10 | Codemagic: on tag `v*` → iOS build, automatic signing via API key, upload to TestFlight | Skeleton build appears in TestFlight and installs on the iPhone |
| 0.11 | Play Console: create app, upload skeleton AAB to internal testing; create the closed testing track and recruit ≥ 12 testers (if personal account) | Internal build installs from Play |

Exit criteria: skeleton installed from TestFlight and from Play internal testing. **If 0.10 fails, stop and fix before M1**: this is the largest technical risk.

---

## M1 — Core Simulation, Test-First (4 days)

Goal: a headless, deterministic, fully tested game that can run thousands of runs in a unit test. No Flutter/Flame imports in `lib/core/`.

### Key interfaces

```dart
// core/rng.dart
class Rng {                       // xorshift128+ or PCG32
  Rng(int seed);
  double nextDouble();            // [0, 1)
  int nextInt(int max);
  double range(double min, double max);
}

// core/world_state.dart
class WorldState {
  double heliY, heliVy;           // virtual px, px/s
  double prevHeliY;               // for render interpolation
  double scrollX, prevScrollX;    // total scrolled px
  final ColumnRing columns;       // fixed-size ring: ceiling/floor per column
  final ObstaclePool obstacles;   // fixed-size pool, no per-tick allocation
  int get distance => scrollX ~/ 10;
}

// core/simulation.dart
enum SimEvent { none, crashed }
class GameSimulation {
  GameSimulation({required int seed, Config config = const Config()});
  WorldState get state;
  SimEvent step(bool isHolding);  // advances exactly one fixed tick (1/60 s)
}

// Used by HelicopterGame and by tests to prove frame-rate independence.
class FixedStepper {
  FixedStepper(this.sim);
  double alpha = 0;               // render interpolation factor
  SimEvent advance(double frameDt, bool isHolding); // clamps dt, ≤ 6 steps
}
```

### Tasks

| # | Task (write the test first, then the code) | Tests |
|---|---|---|
| 1.1 | `config.dart`: all constants from the spec's Physics / Level Generation tables, `assertInvariants()` | Anti-tunnelling and `walkStep < climbMargin` invariants hold |
| 1.2 | `rng.dart` | Golden sequence for seed 42; two instances with same seed match for 10 000 draws |
| 1.3 | `physics.dart` (semi-implicit Euler, clamp) | Rises while held, falls when released, clamps at ±360 px/s, exact values after N ticks |
| 1.4 | `collision.dart` (AABB vs columns overlapping heli x-range, vs obstacles, play-area bounds) | Exact touch = hit, 1 px gap = no hit, fully inside, out-of-bounds top/bottom |
| 1.5 | `world_state.dart` with `ColumnRing` and `ObstaclePool` | Ring wraps correctly; pool reuse without allocation |
| 1.6 | `cave_generator.dart`: random walk, linear gap shrink, obstacle spawning with grace period and interval curve | Same seed ⇒ same columns/obstacles; gap ≥ 170 everywhere; first obstacle after 2 s; interval never < 300 px |
| 1.7 | Reachable-band tracking in the generator (interval set, expand by `climbMargin`, intersect with free space, reject/re-roll) | **Passability property test**: 1 000 seeds × 10 000 columns, band never empty, every obstacle leaves a ≥ 80 px window; all geometry is a multiple of 5 px (LCD-grid aligned) |
| 1.8 | `simulation.dart`: tick orchestration per spec data flow, returns `SimEvent` | Holding forever ⇒ crash into ceiling; releasing forever ⇒ crash into floor; distance increases 5 px/tick |
| 1.9 | `FixedStepper` | Same input timeline at 30 / 60 / 120 / jittery frame deltas ⇒ identical crash tick and distance; 1 s frame delta ⇒ capped steps |
| 1.10 | Optional: `test/core/bot_test.dart` — a simple look-ahead bot (aim for band center) survives ≥ 5 000 distance on 100 seeds | Sanity check that the band model matches real physics |

Exit criteria: `flutter test test/core` green, `lib/core` has no Flutter/Flame imports (checked by a test that scans imports), coverage of `lib/core` ≥ 90%.

---

## M2 — LCD Rendering, Input, Loop (5 days)

Goal: play the game on the Android device with correct visuals and smooth motion. No menus yet: the app launches straight into a run and restarts on crash.

| # | Task | Acceptance |
|---|---|---|
| 2.1 | `HelicopterGame extends FlameGame` with `CameraComponent.withFixedResolution(800, 400)`, `bezel`-coloured letterbox | Letterboxing correct on 16:9, 19.5:9, and 4:3 (tablet emulator) |
| 2.2 | `game_screen.dart`: `Stack[Listener(GameWidget), overlays]`; pointer down/up/cancel counter → `isHolding` | Multi-finger press/release never leaves "stuck holding"; cancel (e.g. system gesture) releases |
| 2.3 | `update(dt)`: `FixedStepper.advance(dt, isHolding)`; on `crashed` freeze world | |
| 2.4 | `Palette` tokens (`lcd`, `ink`, `bezel`, `pixelGap`, plus the black-and-white alternative) and `LcdBuffer` (160×80 bit grid + per-cell ghost timers, reused every frame) | Unit tests: set/clear/blit sprite, clipping at edges, ghost decay |
| 2.5 | `LcdComponent`: paints the buffer (background, lit cells batched in one draw call, optional grid lines, ghost pixels, inverted mode) | One draw call for lit cells; looks crisp on a 3× density phone |
| 2.6 | `CaveComponent` / `ObstacleComponent` write into the buffer from interpolated scroll, floored to LCD cells | Cave moves in even 1-pixel steps; visible edges match collision exactly (debug hitbox overlay) |
| 2.7 | 1-bit sprites as `#`/`.` string grids: helicopter 8×4 with 2 rotor frames (~8 fps); `HeliComponent` blits at interpolated, floored y | Sprite reviewed at 1:1 and on device |
| 2.8 | `SmokeComponent` (single pixels drifting left, blinking out over ~0.5 s, cosmetic RNG) and `ExplosionComponent` (pixel debris + 3 inverted-screen flashes over ~0.4 s) | No allocations per frame in steady state |
| 2.9 | Debug overlay (debug builds only): FPS, steps/frame, heli hitbox, reachable band | Toggle via a constant |
| 2.10 | iOS edge-gesture deferral: override `preferredScreenEdgesDeferringSystemGestures` and `prefersHomeIndicatorAutoHidden` in the iOS runner's `FlutterViewController` subclass | Verified in TestFlight build: holding at screen edge does not trigger home gesture on first swipe |

Exit criteria: 2-minute play session on the reference Android device without visible judder; DevTools shows no frame > 32 ms.

---

## M3 — Game Flow and HUD (3 days)

| # | Task | Acceptance |
|---|---|---|
| 3.1 | `AppFlow` + game phases: `title / menu / ready / playing / paused / crashed / topScore / instructions` with transitions exactly as in the spec diagram | Unit test drives transitions with fake inputs |
| 3.2 | Start press counts as thrust; restart requires a new press ≥ 600 ms after crash | Widget test: held finger at crash does not restart; new press at 599 ms ignored, at 600 ms accepted |
| 3.3 | `HudComponent`: top strip `00123` / `HI 00456` with 1-pixel rule below; inset by safe-area padding (passed from Flutter `MediaQuery` into the game) | Not clipped on a notched device in either landscape direction |
| 3.4 | LCD widget kit in 800×400 virtual px (`LcdViewport`, `LcdText`, `MenuList` with inverted selection + counter, `Scrollbar`, `SoftKey`, `LcdDialog`) and the screens from spec 1.3: title splash, main menu, ready, paused menu, game over, top score, instructions | Matches the design canvas; rows/soft keys ≥ 48 dp; menus do not trigger flight (widget test); all text sits on the LCD grid |
| 3.5 | Lifecycle: `WidgetsBindingObserver` → `paused` on inactive/paused during play | Notification shade, incoming call, app switch all pause cleanly; resume has no step burst |
| 3.6 | Android back button via `PopScope`, routed by `AppFlow` per spec 1.3 (title/menu → exit; playing → paused; paused → ready; others → menu) | Widget test per screen |
| 3.7 | Title screen background: static cave strip with hovering helicopter (bobbing 1 LCD pixel) | |

Exit criteria: full loop title → menu → ready → play → crash → restart → background → pause menu → continue works on Android device. **Upload this build to the Play closed testing track and start the 14-day clock** (if D2 = personal account).

---

## M4 — Audio, Persistence, Assets (2 days)

| # | Task | Acceptance |
|---|---|---|
| 4.1 | `tool/gen_audio.dart`: synthesize square-wave "phone buzzer" sounds into 16-bit mono WAV: low rotor pulse loop (seamless), descending crash beeps, 3-note new-best jingle, soft-key click; commit outputs | Loop has no audible click; sounds read as one monophonic set |
| 4.2 | `AudioService`: preload, rotor loop start/stop, crash SFX, mute, ambient audio session (iOS), failure ⇒ muted | Background music from another app keeps playing; silent switch respected |
| 4.3 | `LocalStore`: best score, pending leaderboard score, mute; read failure ⇒ defaults | Unit tests with mocked `SharedPreferences` |
| 4.4 | Wire best-score update on crash, `Sound: On/Off` rows in main and pause menus | Values survive app restart |
| 4.5 | Bundle OFL pixel font (Silkscreen or Pixelify Sans) + register license via `LicenseRegistry`; size it so cap height = 5 LCD pixels | Same look on Android and iOS; glyph edges land on the grid |
| 4.6 | App icon and splash: tool script renders the 1-bit helicopter in `ink` on an `lcd` square with hard pixel edges; generate launcher icons (flutter_launcher_icons) and a native splash in the `lcd` colour | No white flash on launch; icon legible at 48 px |

---

## M5 — Leaderboards (3 days)

| # | Task | Acceptance |
|---|---|---|
| 5.1 | `LeaderboardService` interface (`signIn`, `submit(score)`, `show()`), `GamesServicesLeaderboard`, `NoopLeaderboard` (desktop/tests) | All methods return results, never throw |
| 5.2 | Play Console: Play Games Services project, leaderboard, OAuth credentials for **both** the upload key SHA-1 and the Play App Signing SHA-1; tamper limit | Sign-in works on internal-track build (not only debug) |
| 5.3 | App Store Connect: Game Center leaderboard, tamper limits | |
| 5.4 | Sign-in once at launch on title; `Online scores` on the Top score screen retries sign-in then shows board; non-blocking message on failure | |
| 5.5 | Submit on new best; on failure persist pending score; retry after next successful sign-in | Unit tests for success, failure, offline-then-online |
| 5.6 | Verify on TestFlight (Game Center sandbox) and Play internal track | Scores visible on both boards |

---

## M6 — Tuning, Performance, Polish, QA (4 days)

| # | Task | Acceptance |
|---|---|---|
| 6.1 | Playtest tuning sessions (≥ 5 players): adjust gravity/thrust/speed/gap/obstacle curve in `config.dart`; rerun passability test after each change | Median first-time run ~ 15–30 s; skilled runs reach the minimum gap regime |
| 6.2 | Performance pass on reference Android (profile mode): no per-frame allocations, check raster thread, sprite caching | No frame > 32 ms over 2 min; steady memory |
| 6.3 | 120 Hz verification (iPhone Pro or 120 Hz Android) | Motion smooth; feel matches 60 Hz device |
| 6.4 | Device matrix: small phone, large phone, notched iPhone (both landscape directions), Android tablet, low-end Android | Checklist all green |
| 6.5 | Interruption matrix: call, alarm, notification, lock screen, split screen / multi-window (Android) | Always pauses, never crashes |
| 6.6 | `integration_test`: launch → play → crash → restart; run on emulator in CI | Green |
| 6.7 | Bug bash and fix | No open P1/P2 bugs |

---

## M7 — Release (2 days + store wait)

| # | Task | Acceptance |
|---|---|---|
| 7.1 | Store listings: name, descriptions, screenshots (phone + tablet sizes), Play feature graphic | |
| 7.2 | Privacy policy page (static hosting, e.g. GitHub Pages); App Privacy label "Data not collected"; Play Data safety form | |
| 7.3 | Content rating questionnaires (IARC, App Store age rating); target audience 13+ (D3) | |
| 7.4 | Versioning: `pubspec.yaml` `version: 1.0.0+N`, tag `v1.0.0` triggers iOS pipeline | |
| 7.5 | Play: confirm closed test met 12 testers × 14 days (if required), apply for production, staged rollout 20% → 100% | |
| 7.6 | App Store: submit for review from TestFlight build | Approved |
| 7.7 | Post-launch: monitor Play vitals (ANR/crash rate) and App Store crash reports for 2 weeks | Crash-free sessions ≥ 99.5% |

---

## Definition of Done (every task)

- Tests written first for `core/` and services; `flutter analyze` 0 issues; `flutter test` green in CI.
- No Flutter/Flame imports in `lib/core/`.
- Tuning constants only in `config.dart`.
- Verified on a physical Android device for anything that affects feel or rendering.
- Spec updated when behaviour deliberately deviates from it.

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| iOS signing / Game Center entitlement problems | Low–Medium | High | Walking skeleton in M0; local Xcode automatic signing on the dev Mac |
| Play 12-tester / 14-day closed test delays launch | High (personal account) | High | Organization account (D2), or start closed test at end of M3 with any playable build |
| `games_services` breaks with a store SDK update | Low–Medium | Medium | Interface + `NoopLeaderboard`; pin version; fallback to own platform channels |
| Generator produces unfair sections the band model misses | Medium | High | Conservative 50% `climbMargin`; bot test (1.10); debug band overlay during playtests |
| Judder on high-refresh or low-end devices | Medium | High | Render interpolation, no per-tick allocation, profile early in M2 |
| Store rejection as a copycat / name conflict | Medium | High | Distinct name and original procedural art (D1); no use of the original title, or the Nokia name, logo or phone images, in the app or metadata |
| Large LCD pixels make collisions feel unfair (sprite edge vs. hitbox) | Medium | Medium | Grid-aligned geometry, hitbox reviewed with the debug overlay, tuned in M6 playtests |
| Feel differs from the original | Medium | Medium | Constants in one file, side-by-side comparison with a recording of the original during M6 |
| Rotor loop clicks / audio latency on Android | Low | Low | Generated WAV with zero-crossing loop points; preload on start |

## Deliverables Checklist

- [ ] Repo with CI (Android on push, iOS on tag)
- [ ] `lib/core` with ≥ 90% coverage and passability property test
- [ ] Playable build on Android and TestFlight
- [ ] Leaderboards working on both platforms
- [ ] Store listings, privacy policy, ratings
- [ ] v1.0.0 live on Google Play and the App Store
