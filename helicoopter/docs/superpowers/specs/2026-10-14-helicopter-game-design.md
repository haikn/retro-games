# Helicopter Game (Mobile) — Design Spec

Date: 2026-10-14 · Revision: 1.3 (retro phone-game UI redesign, see [Change Log](#change-log))

UI reference: [Cave Copter LCD UI design canvas](https://claude.ai/artifact/BZmh5D8PVzgqnXemYQszzm) (title, menus, playable gameplay, game over, UI kit). Where this spec and the canvas differ, this spec wins.

## Goal

A mobile remake of the classic Flash **Helicopter Game**: same one-touch control, same feel, same cave-and-blocks gameplay, presented in the style of a **retro monochrome phone game** (the early-2000s Nokia LCD look of Snake and Space Impact). Flappy Bird is a reference for the one-tap mobile UX only; it is not part of this product.

Success criteria for v1:

- Control feel is indistinguishable between a 60 Hz and a 120 Hz device (no judder, same trajectory).
- Every generated run is passable by construction; difficulty comes from skill, never from an impossible section.
- Stable 60 fps (no frame > 32 ms during play) on a low-end reference Android device (e.g. ~2019 budget phone, 2–3 GB RAM).
- Cold start to title screen < 2 s on the reference device; app download size < 15 MB.
- Shipped to Google Play production and the App Store.

## Scope (v1)

- Platforms: iOS and Android from one codebase.
- Orientation: landscape only (as in the original), both landscape directions.
- Features: core gameplay, local best score, online leaderboard (Game Center / Google Play Games), sound effects, persisted mute setting.
- Language: English only.
- Out of scope: ads, in-app purchases, skins, power-ups, multiple modes, settings beyond mute, analytics/telemetry SDKs, cloud save, achievements.

## Open Decisions (resolve before M0 ends)

| # | Decision | Recommendation | Why it matters |
|---|---|---|---|
| D1 | Store name and branding | A distinct name. **Working name: "Cave Copter"** (used in code and UI until D1 is closed); package `cave_copter`, app id `com.nhk.cave_copter` (iOS `com.nhk.caveCopter`). Not "Helicopter Game"; no "Nokia" name, logo, phone image or Nokia font in the app or store listing | The original name/brand belongs to a third party, and so does Nokia's; a lookalike name risks store rejection (Apple 4.1 copycats) or takedown. Gameplay mechanics and a generic "monochrome LCD" style are not protected; names, logos and assets can be. Describe the style as "retro LCD" or "classic phone style". |
| D2 | Google Play account type | Organization account if available (needs D-U-N-S) | New *personal* Play accounts must run a closed test with ≥ 12 opted-in testers for 14 consecutive days before production access. This is a hard schedule item. |
| D3 | Target age group | 13+ | Declaring under-13 audiences brings Families policy / Kids Category requirements. |
| D4 | iOS build path | Local Xcode for development and TestFlight uploads; Codemagic optional for tag-triggered releases | The primary dev machine is now a Mac with Xcode, so cloud signing is no longer required. GitHub-hosted macOS minutes are billed at 10× on private repos. |

## Tech Stack

| Concern | Choice |
|---|---|
| Language / UI | Flutter (Dart), current stable channel, versions pinned in `pubspec.lock` |
| Game engine | Flame (used for game loop, camera/viewport, components) |
| Audio | flame_audio (audioplayers), audio session configured as *ambient* |
| Leaderboards | games_services (Game Center + Play Games Services v2) behind an interface |
| Local storage | shared_preferences |
| Font | Bundled **Silkscreen** (OFL), regular + bold, rendered on the LCD grid |
| Tests | flutter_test (unit + widget), integration_test (on-device smoke) |
| Lints | flutter_lints (or very_good_analysis), zero warnings in CI |

Rationale: single codebase, small binary, mature 2D loop and fixed-resolution camera via Flame, one plugin covering both store leaderboards, and pure-Dart logic that is easy to unit test. Godot 4 and Unity were considered and rejected (weaker leaderboard plugins / unnecessary weight).

Dependency risk: `games_services` is a community plugin. It is wrapped behind `LeaderboardService` so it can be replaced by thin platform channels if it lags behind a store SDK change.

## Development Environment & Build

- Primary dev machine: macOS (Apple Silicon) with Xcode.
  - Flutter SDK, Android Studio (Android SDK + emulator, bundled JDK 17+), VS Code with Flutter/Dart extensions.
  - Day-to-day iteration on a USB Android device or iPhone (preferred for feel and frame timing) or simulators; macOS desktop target allowed for quick checks (leaderboard is a no-op there).
- Android: built, signed, and published to Google Play from the Mac. Upload key stored outside the repo; Play App Signing enabled. Target SDK must meet Play's current target API level requirement; native libs must support 16 KB page sizes (handled by a current Flutter release).
- iOS: built and signed locally in Xcode (automatic signing), uploaded to TestFlight; optionally Codemagic on tags (see D4). Game Center capability is added via `Runner.entitlements` and the corresponding `project.pbxproj` change.
- Prerequisites: Apple Developer Program account, Google Play Console account, a physical iPhone for TestFlight playtesting, a low-end reference Android device.
- Source control: the `retro-games` monorepo; the Flutter project lives in `helicoopter/`, so CI jobs set `working-directory: helicoopter`. CI runs `flutter analyze`, `flutter test`, and an Android release build on every push; the iOS build and TestFlight upload run on tagged releases.
- Secrets (keystore, App Store Connect API key, Play service account JSON) live only in CI secret storage and a local password manager, never in git.

## Gameplay

### Visuals — Retro Monochrome LCD

Art direction: the whole game looks like it runs on an early-2000s monochrome phone screen. There are exactly **two colours**, "ink" and "LCD"; no grey, gradients or anti-aliasing.

**Palette** (defined once as tokens in `game/lcd/palette.dart`; kept out of `core/` because colours are a Flutter type):

| Token | Default | Use |
|---|---|---|
| `lcd` | `#C7F0D8` (pale green backlight) | Screen background, "off" pixels |
| `ink` | `#43523D` (dark olive, reads as black) | Every "on" pixel: cave, blocks, helicopter, text |
| `bezel` | `#1E2219` | Letterbox bars around the LCD |
| `pixelGap` | `ink` at 6% opacity | Optional faint LCD grid lines |

An alternative palette for a more strictly black-and-white look (`#E0E6D8` / `#1A1A1A`) is kept as a second token set, selectable by a constant. It is not a user setting in v1.

**LCD grid.** The 800×400 virtual screen is drawn as a grid of **160 × 80 LCD pixels**, each 5 × 5 virtual px. Every element is drawn as whole LCD pixels; nothing is drawn between grid cells. The large, visible pixels are the core of the look.

- HUD strip: **top** 8 LCD rows (40 virtual px), then a 1-LCD-pixel `ink` rule (row 8), as in the Snake / Space Impact score bar. Play area: rows 9–79 = 160 × 71 LCD pixels (y 45–400, 355 virtual px).
- Cave ceiling and floor: solid `ink` columns, 2 LCD pixels wide (10 virtual px), giving the blocky, jagged edge.
- Obstacle blocks: solid `ink` rectangles, 4 LCD pixels wide (20 px), 10–18 LCD pixels tall (50–90 px).
- Helicopter: **10 × 6** LCD-pixel sprite (50 × 30 virtual px), 1-bit, facing right, at x = 160 px (20% of screen width); the world scrolls right to left. Rotor row flips between a long and a short bar every 8 ticks (~7.5 fps). Sprite (`#` = ink):

  ```
  frame A  .########.      frame B  ...####...
           ......#...               (body rows identical)
           #...#####.
           #######.##
           #...#####.
           ...######.
  ```
- Smoke: single `ink` LCD pixels emitted every 4 ticks behind the tail (one pixel left of the sprite, row 3 of the sprite), drifting left with the world, living 16–30 ticks and blinking at random during their last 6 ticks instead of fading with alpha.
- Crash: the helicopter disappears, 12 single-pixel debris bits fly out with gravity for ~1.1 s, and the whole screen **inverts** (ink ↔ lcd) 3 times (ticks 0–4, 10–14, 20–24). The game-over box appears at tick 40.
- LCD ghosting (optional, **off**): pixels that switch off could fade out over ~60 ms, mimicking a slow LCD. Supported by the renderer but disabled, because in playtesting the 1-pixel-per-frame scroll made it read as an echo on every moving edge. With it off, exactly two tones are on screen.
- Motion: positions are snapped to the LCD grid when drawn, so the cave moves in visible 1-pixel steps, like the original phones. The simulation itself stays continuous (see Physics).

**Text and HUD.**

- Font: Silkscreen, drawn in `ink`. Two sizes only, chosen so font pixels land exactly on LCD pixels: **body 40 px** (1 font px = 1 LCD px, caps 5 LCD px tall) and **title 80 px bold** (1 font px = 2 LCD px). The large top-score number on the Top score screen uses 120 px bold.
- Copy is sentence case, as on the original phones (`New game`, `Game over!`); Silkscreen renders lower case as small caps. The title logo is upper case (`CAVE COPTER`).
- HUD during play: score left (`00123`), best right (`HI 00456`), both zero-padded to 5 digits, vertically centred in the 40 px strip with 25 px side margins.

**Screens (phone-menu style).** Every screen except gameplay is a Nokia-style screen made of the same parts:

| Part | Spec |
|---|---|
| Header | Screen title at top-left (x 25, 55 px tall); optional right-aligned value (menu item counter `1/4`, or the paused run's distance) |
| Menu list | Rows 60 px (12 LCD px) tall starting at y 55, text inset 15 px, list x 10–755. The selected row is **inverted** (ink bar, lcd text) |
| Scrollbar | Right edge: 1-LCD-px track at x 775, 3 × 12 LCD-px thumb at x 770 whose position follows the selection / scroll position |
| Soft key | One centred label at the bottom (y 345–400, 250 px wide), like the middle soft key on old phones: `Select`, `Back` or `Menu`. Over the cave it is drawn on an `lcd` plate so it stays legible |
| Dialog | 1-LCD-px `ink` border on `lcd`, centred text rows 50 px apart |

Screens:

- **Title splash** (cold start): `CAVE COPTER` in title type, the helicopter bobbing 1 LCD px over a static cave strip with a short smoke trail, `Tap to start` blinking (1 s period). Any tap opens the main menu.
- **Main menu**: header `Cave Copter` + counter; items `New game`, `Top score`, `Sound: On/Off`, `Instructions`; soft key `Select`.
- **Ready** (after `New game`, and after `Continue`): the cave and helicopter are visible, a dialog shows `Hold to fly` blinking, soft key `Menu`. The first press starts (or resumes) the run and already counts as thrust.
- **Gameplay**: HUD + play area only; no buttons. Tapping anywhere flies.
- **Paused** (back button or app backgrounded): header `Paused` + current distance; items `Continue`, `New game`, `Sound: On/Off`, `Main menu`; soft key `Select`.
- **Game over**: the frozen frame stays visible behind a dialog: `Game over!` (bold), `Dist 01234`, then `New best!` blinking if applicable (otherwise `Best 01234`), then `Tap to play`; soft key `Menu`.
- **Top score**: header `Top score:`, the local best in 120 px bold, `On this phone`, an inverted `Online scores` button (opens the platform leaderboard), soft key `Back`.
- **Instructions**: header `Instructions`, body text that scrolls (scrollbar follows), soft key `Back`.

Touch: tapping a menu row selects **and** activates it (the inverted bar shows on press, so the user sees which row fired); the soft key activates the current selection. Every row and soft key has a touch target of at least 48 × 48 dp at the smallest supported scale. Menus, dialogs and soft keys never register as flight input.

**Assets.** All sprites are drawn procedurally as 1-bit pixel grids, and sound effects are synthesized into WAV files by a script, so no third-party art or audio is needed. The only third-party asset is the OFL font (license file shipped in-app via `LicenseRegistry`). Nothing resembling a real phone, logo or brand is drawn.

### Controls

- Press and hold anywhere on screen: thrust up. Release: fall.
- "Holding" means at least one pointer is down (pointer count > 0); extra fingers have no further effect.
- No on-screen buttons during play.
- The first press on the Ready screen starts the run, and that press already counts as holding (thrust begins immediately).
- After a crash, a restart requires a **new** press that begins at least 600 ms after the crash. A finger still held from the crash never restarts the game. A restart goes straight into a new run (classic behaviour), not via Ready.
- System gestures: immersive sticky fullscreen on Android; on iOS the home indicator is auto-hidden and edge gestures are deferred (native `preferredScreenEdgesDeferringSystemGestures` override in the iOS runner) so holding near an edge does not trigger the system.
- Android back button: title splash and main menu exit the app; Ready, game over, Top score and Instructions return to the main menu; gameplay opens Paused; Paused continues the run (via Ready), like the original phones' back key.

### Physics

All values are in virtual pixels (px) and seconds, in the 800×400 virtual resolution. y grows downward. Starting values (tunable in `config.dart`):

| Constant | Start value |
|---|---|
| Gravity | 900 px/s² |
| Thrust (while held) | 1 800 px/s² upward (net 900 px/s² up) |
| Max vertical speed (both directions) | 360 px/s |
| Scroll speed | **300 px/s** (exactly 1 LCD px per 60 Hz tick), constant for the whole run |
| Simulation rate | 60 Hz fixed (dt = 1/60 s) |

- Vertical velocity integrates gravity (always) and thrust (while held) using semi-implicit Euler, giving a smooth curve, not instant movement.
- Vertical speed clamped to the maximum in both directions.
- Fixed 60 Hz timestep with an accumulator so feel is identical regardless of frame rate:
  - Frame delta is clamped to 100 ms (prevents a "spiral of death" after hitches or resume).
  - At most 6 simulation steps per frame.
  - Rendering interpolates helicopter y between the previous and current simulation state (`alpha = accumulator / dt`) before snapping to the LCD grid.
- Rendering interpolates only the helicopter's y. The world scrolls exactly 1 LCD px per tick, so scroll needs no interpolation and moves in perfectly even steps on 60 Hz screens (on 120 Hz each step is held for exactly 2 frames).
- Anti-tunnelling invariant: per-tick displacement (5 px horizontal, ≤ 6 px vertical) is smaller than the thinnest collidable feature (column width 10 px, obstacle min size 20 px). `config.dart` asserts this.

### Level Generation

- Geometry: the play area is 800 × 355 px (y 45–400; the top 45 px are HUD + rule). The cave is a sequence of columns 10 px wide; each column has a ceiling height and a floor height. Columns live in a ring buffer (visible count + 2). The tunnel centre is kept at least 10 px (2 LCD px) inside the play area, so the ceiling and floor are always at least 2 LCD px thick.
- **Grid alignment:** all generated geometry (ceiling/floor heights, obstacle positions and sizes) is a multiple of 5 px, so it maps exactly onto LCD pixels and what you see is exactly what collides.
- Procedural, driven by a seeded RNG (new seed per run, deterministic for a given seed). The RNG is a small in-repo PRNG (e.g. xorshift128+ or PCG32), not `dart:math` `Random`, so sequences stay stable across Dart SDK versions.
- Tunnel center follows a bounded random walk column by column: step of −5, 0 or +5 px (one LCD row) per column, center kept within the play area margins.
- Tunnel gap starts at 300 px and shrinks linearly (rounded to 5 px) to a minimum of 170 px, reached at distance 2 000 (20 000 px scrolled, ≈ 67 s).
- Obstacles: `ink` blocks 20 px wide (2 columns) × 50–90 px tall (multiples of 10). First obstacle after a 2 s grace period (600 px). Spawn interval starts at 600 px of scroll and decreases linearly to a minimum of 300 px. While an obstacle spans its two columns, the tunnel centre does not walk, so the free window is the same in both columns.
- **Passability is guaranteed by construction.** The generator tracks the *reachable band* (the set of y positions the helicopter hitbox can occupy) column by column:
  - From one column to the next, the band can expand by at most `climbMargin = 0.5 × maxVerticalSpeed × columnTime` up and down (a conservative 50% of the theoretical limit to account for acceleration).
  - The band is then intersected with the column's free space (gap minus obstacle, minus hitbox height). Where an obstacle splits the gap, the band becomes up to two intervals.
  - An obstacle placement (or random-walk step) is rejected and re-rolled (bounded retries, then skipped) if it would make the band empty, or leave no free window (wall-to-obstacle space, before subtracting the hitbox) of at least `minPassableHeight` = 80 px (4× hitbox height).
  - With the default constants: column time = 10 / 300 s, so `climbMargin` = 6 px per column > random-walk step 5 px; and min gap 170 px − max obstacle 90 px = 80 px, so a valid placement always exists.
- Smoke and explosion effects use a separate cosmetic RNG so they never affect the level sequence.

### Collision

- Axis-aligned bounding box (AABB). Helicopter sprite 50 × 30 px (10 × 6 LCD pixels); hitbox 40 × 20 px, inset exactly 1 LCD px on every side. The rotor row, the skid row, the tail fin and the nose tip lie outside the hitbox, so grazing a wall with them by 1 LCD px is deliberately forgiven.
- Cave and obstacle geometry is grid-aligned, so what you see is what collides for walls and blocks. The helicopter's y is continuous and drawn floored to the grid, so its drawn position can lag its hitbox by up to 1 LCD px (5 px); the 1-LCD-px hitbox inset absorbs this.
- Tested against the ceiling/floor columns overlapping the helicopter's x-range and against obstacle blocks.
- Leaving the top or bottom of the play area counts as a crash (defensive; the cave normally covers these).
- Touching edges count as a hit (≥ / ≤ comparisons are defined and tested).

### Score

- Distance = scrolled px / 10, shown as an integer (30 per second at the default speed).
- Best score stored locally and updated on crash.
- Score submitted to the platform leaderboard on crash only when it is a new local best. If submission fails, the pending score is persisted and retried on the next successful sign-in.
- Leaderboard tamper limits configured in Play Console and App Store Connect (upper bound e.g. 1 000 000).

## Architecture

Pure game logic (`core/`) has no Flutter or Flame imports and is fully unit-testable, including a headless simulation of whole runs. Flame components only render state; services are behind interfaces so they can be faked in tests and on unsupported platforms.

```
lib/
  main.dart                  # bootstrap, orientation lock, immersive fullscreen, service wiring
  app/
    app_flow.dart            # AppScreen enum + AppFlow (ChangeNotifier): which screen is shown, back-button routing
    game_screen.dart         # Stack: input Listener + GameWidget + LcdViewport(screens); lifecycle observer; PopScope
    lcd/                     # LcdViewport (800×400 FittedBox, bezel letterbox), LcdText, MenuList, SoftKey, LcdDialog, Scrollbar
    screens/                 # Flutter widgets in 800×400 virtual px: title, main_menu, ready, paused, game_over, top_score, instructions
  game/
    helicopter_game.dart     # FlameGame: state machine, fixed-step accumulator, event → effects
    lcd/                     # palette tokens, LcdBuffer (160×80 bit grid + ghosting), LcdComponent painter, 1-bit sprite grids
    components/              # render-only, draw into LcdBuffer: heli, cave, obstacles, smoke, explosion, hud
  core/
    config.dart              # tuning constants + invariant asserts
    rng.dart                 # deterministic PRNG
    physics.dart             # vertical integration, fixed dt
    cave_generator.dart      # seeded tunnel + obstacles + reachable-band guarantee
    collision.dart           # AABB tests
    world_state.dart         # run snapshot (heli y/vy, column ring buffer, obstacles, distance)
    simulation.dart          # GameSimulation.step(isHolding) → SimEvent? (orchestrates one tick)
  services/
    local_store.dart         # best score, pending leaderboard score, mute flag (shared_preferences)
    leaderboard_service.dart # interface + GamesServicesLeaderboard + NoopLeaderboard
    audio_service.dart       # rotor loop, crash SFX, mute flag, ambient audio session
assets/
  audio/                     # rotor loop, crash (generated by tool/gen_audio.dart, committed)
  fonts/                     # OFL pixel font + license
tool/
  gen_audio.dart             # synthesizes the WAV files
test/
  core/                      # physics, rng, generator, collision, simulation, passability
  services/
  widgets/
integration_test/            # on-device smoke: launch, play, crash, restart
```

The HUD is a Flame component so it scales with the fixed-resolution viewport. Menu screens and dialogs are Flutter widgets laid out in the same 800×400 virtual coordinate space (one `FittedBox` with the same letterboxing as the Flame camera), so their text and borders land on the same LCD grid as the game. Input is captured by a Flutter `Listener` around the `GameWidget` (pointer down/up/cancel counting); screens sit above it in a `Stack` and absorb their own taps so their buttons don't trigger flight. `GameSimulation` is the single entry point for a tick, which lets tests and the passability checker run thousands of headless runs.

### State Machine

```
          tap            New game            press              hit           new press ≥600 ms
title ─────────▶ menu ───────────▶ ready ──────────▶ playing ──────────▶ crashed ─────────────────▶ playing
                 ▲ ▲ │  ▲            ▲  │ Menu/back     │  ▲                │ Menu/back
                 │ │ │  │            │  ▼               │  │ Continue       ▼
                 │ │ │  └────────────┼─ menu    back /  ▼  │ (→ ready)     menu
                 │ │ ▼               │          app bg  paused ──Main menu──▶ menu
                 │ topScore / instructions ──Back──▶ menu       └─New game──▶ ready (new run)
```

- `title` (cold start only): splash; any tap → `menu`.
- `menu`: main menu list; `New game` creates a new run and enters `ready`.
- `ready`: world visible and frozen, `Hold to fly` dialog. A press enters `playing` with thrust already on. Entered from `New game` (fresh run) and from `Continue` (same run, stored velocity kept).
- `playing`: fixed-step loop runs, rotor sound loops.
- `paused`: entered when the app goes to background (`AppLifecycleState.inactive/paused`) or back is pressed; simulation and audio stop; pause menu shown.
- `crashed`: explosion, rotor stops, crash SFX, best saved, score submitted if new best, game-over dialog. A valid new press starts a new run directly in `playing` (classic behaviour); `Menu` / back → `menu`.
- `topScore`, `instructions`: info screens; `Back` → `menu`.

### Per-Tick Data Flow (playing)

`GameSimulation.step(isHolding)` performs, in order:

1. Save previous state (for render interpolation).
2. `physics.step(state, isHolding, dt)`.
3. Scroll by `scrollSpeed * dt`; `caveGenerator` recycles columns leaving the left edge and appends new columns / obstacles on the right.
4. `collision.check(state)`; on hit → return `SimEvent.crashed` and stop.
5. `distance += scrollSpeed * dt`.

`HelicopterGame.update` runs the accumulator, calls `step` 0–6 times, and maps events to state changes and effects (explosion, audio, persistence). Components read `world_state` plus `alpha` and render.

No per-tick allocations in `core/` (ring buffers and object pools) to avoid GC hitches.

### Rendering

- Fixed virtual resolution 800×400 using Flame's fixed-resolution camera, letterboxed on other aspect ratios, so gameplay is identical across devices. Letterbox bars use the `bezel` colour, so the game reads as an LCD panel set into a dark phone body.
- The HUD strip and soft keys are inset by the device safe-area padding (notch / rounded corners) so text is never clipped.
- **LCD pipeline:** each frame, components draw into a 160×80 logical pixel buffer (positions computed from the interpolated state, then floored to LCD cells). One `LcdComponent` paints the buffer: `lcd` background, one rect per lit cell (batched with `drawRawAtlas` or a single `Path`), optional grid lines, and ghost pixels fading out. The inverted-flash crash effect swaps the two palette colours at this stage.
- Helicopter y interpolation is applied before snapping; the world scroll is whole LCD pixels per tick and is not interpolated.
- Procedural 1-bit sprites are stored as bit grids (`List<String>` rows of `#`/`.` in code) and blitted into the buffer; no image filtering is involved.

### Audio

- Audio session category *ambient* (iOS) so the game respects the silent switch and does not stop the player's music.
- Sound style matches the visuals: **monophonic square-wave beeps**, like an old phone's buzzer. The rotor is a low, quiet square-wave pulse loop; the crash is a short descending beep run; a new best plays a 3-note rising jingle; menu soft keys play a short key click.
- Rotor loop is a seamlessly looping WAV (no MP3, which gaps on loop); started on `playing`, stopped on `paused`/`crashed`.
- Mute persists across launches.

### Platform Integration

- Game Center / Play Games sign-in is attempted once at launch on the title screen (never mid-run, as iOS presents UI). If the player declined, the `Online scores` button on the Top score screen retries sign-in and, on failure, shows a short non-blocking message.
- Leaderboard IDs are configured per platform in one constants file.

## Error Handling

- Leaderboard sign-in or submit failure: logged, never shown as a blocking error, never interrupts play.
- Offline: the latest unsubmitted best score is persisted and submitted on next successful sign-in.
- Audio load failure: game continues muted.
- Local storage read failure: best score treated as 0, mute treated as off.
- Uncaught errors: caught by `FlutterError.onError` / `PlatformDispatcher.onError`, logged; the store consoles' crash reporting (Play vitals, App Store crash reports) is the v1 monitoring.

## Testing

- Unit (`core/`):
  - RNG: fixed seed yields a known golden sequence.
  - Physics: velocity rises while holding, falls when released, respects clamps.
  - Generator: same seed yields same sequence; gap never below minimum; every obstacle leaves a passable window.
  - **Passability property test**: 1 000 seeds × 10 000 columns each; the reachable band is never empty.
  - Collision: edge cases at exact touch, inside, and just outside.
  - Simulation: frame-rate independence — the same input timeline fed at 30/60/120 Hz frame deltas produces the same crash tick.
  - Config invariants (anti-tunnelling) hold.
- Widget: every screen renders the right values; menu rows and soft keys navigate per the state machine; back-button routing; menu rows, dialogs and soft keys do not register as flight input.
- Services: local store with mocked preferences; leaderboard service failure paths do not throw; pending score retry.
- Integration (`integration_test/`, on device / emulator in CI where possible): launch → play → crash → restart.
- Performance: profile build on the reference Android device; DevTools frame chart shows no frame > 32 ms over a 2-minute run.
- Manual: on-device playtest on at least one iOS (incl. a 120 Hz device if available) and one low-end Android device for control feel, frame pacing, notch handling, interruptions (call, notification shade, background/foreground).

## Store & Compliance

- Store assets: app icon (procedural: the 1-bit helicopter sprite in `ink` on an `lcd` square, enlarged with hard pixel edges), screenshots, short/long description, feature graphic (Play).
- Privacy: no data collected by the app itself; App Privacy label and Play Data safety form completed accordingly (Game Center / Play Games are handled by the platforms). A simple privacy policy page is published (required by Play for listing).
- Content rating questionnaires (IARC / App Store) completed; expected rating: everyone / 4+.
- Open-source licenses shown via Flutter's license page (reachable from title screen long-press or store description).

## Change Log

### 1.3 — 2026-10-18 (retro phone-game UI redesign)

Approved by the product owner from the [design canvas](https://claude.ai/artifact/BZmh5D8PVzgqnXemYQszzm).

Playtest follow-up (2026-10-18): LCD ghosting switched off by default; it showed as an echo on moving walls and the helicopter, unlike the design canvas.

| Area | Change | Reason |
|---|---|---|
| Screens | Nokia-style full-screen menus (inverted selection bar, item counter, pixel scrollbar, centred soft key); new main menu, Ready, Top score and Instructions screens; pause becomes a menu | Closer to the original phone games, and full-width rows are easier to tap than corner soft-key labels. |
| HUD | Moved to the top (8 rows + rule); `00123` / `HI 00456` | Matches Snake / Space Impact. |
| Type | Silkscreen fixed; body 40 px (1 font px = 1 LCD px), title 80 px; sentence case | Pixel-exact text on the LCD grid. |
| Sprite | Helicopter 8×4 → 10×6 LCD px (50×30); hitbox 30×14 → 40×20, inset 1 LCD px | 8×4 was not readable as a helicopter; a grid-aligned inset keeps sprite and hitbox consistent. |
| Speed | Scroll 240 → 300 px/s (1 LCD px per tick); scroll no longer interpolated | 240 px/s gave 48 steps/s on a 60 Hz screen, an uneven 4:1 cadence that contradicted the "no judder" goal. |
| Generation | Min gap 160 → 170 px; obstacles 50–90 px in steps of 10; `minPassableHeight` 70 → 80 px; centre margin 10 px; no walk under an obstacle | Re-derived for the larger hitbox and faster scroll; closes the 65 px window edge case. |
| Back button / state machine | Added `menu`, `ready`, `topScore`, `instructions`; back routing redefined | Follows the new screens. |
| Environment | Dev machine is a Mac with Xcode; monorepo `working-directory`; working name Cave Copter (`cave_copter`); D4 updated | Reflects the actual setup. |

### 1.2 — 2026-10-15 (retro LCD art direction)

| Area | Change | Reason |
|---|---|---|
| Goal / Visuals | Replaced the black + bright-green Flash look with a two-colour monochrome LCD style (pale green `lcd`, dark `ink`), drawn on a 160×80 grid of large pixels | Product owner request: retro early-2000s phone-game look (Snake era). |
| Visuals | Smoke fades by pixels blinking out; crash flashes an inverted screen; optional LCD ghosting | A 1-bit look has no grey or alpha, so effects use classic LCD tricks instead. |
| Screens | Title/pause/game-over are bordered boxes; LEADERBOARD and SOUND become soft-key labels in the HUD strip; HUD is `DIST 0000` / `BEST 0000` | Matches old phone menu conventions. |
| Geometry | All generated geometry is a multiple of 5 px; walk step 5 px; helicopter 40×20 (hitbox 30×14); min gap 150 → 160 px; `minPassableHeight` 60 → 70 px | Sprites and cave must sit exactly on the LCD grid so what you see is what collides; the bigger chunky helicopter needs a bit more room. |
| Rendering | LCD buffer pipeline, `bezel`-coloured letterbox | One place to draw pixels, apply palette, inversion and ghosting. |
| Audio | Square-wave beep sound set, new-best jingle, key click | Matches the visual style. |
| Branding (D1) | No Nokia name, logo, phone image or font | Third-party trademarks; describe as "retro LCD". |

### 1.1 — 2026-10-14 (architecture review)

| Area | Change | Reason |
|---|---|---|
| Goal | Added measurable success criteria | Make "same feel" and performance verifiable. |
| Scope | Mute is persisted; added open decisions D1–D4 | Users expect settings to persist; naming, Play account type and CI choice affect schedule and approval risk. |
| Controls | Restart requires a fresh press after 600 ms; start press counts as thrust; system gestures and back button defined | The original spec allowed an accidental instant restart from the finger still held at crash time, and left Android back / edge gestures undefined. |
| Physics | Concrete starting constants and units; dt clamp, max steps, render interpolation; anti-tunnelling invariant | A fixed step without interpolation judders on 90/120 Hz screens; without clamping, resume after background causes a burst of steps. |
| Generation | Reachable-band algorithm; in-repo PRNG; concrete sizes; separate cosmetic RNG | "Gap ≥ minimum" alone does not guarantee the next window is *reachable* in time; `dart:math` Random is not guaranteed stable across SDK versions. |
| Architecture | Added `simulation.dart`, `rng.dart`, `local_store.dart`, leaderboard interface + no-op | One tick entry point enables headless tests and passability checks; interfaces allow Windows/desktop and tests without plugins. |
| State machine | Fixed to `title → playing → crashed → playing`, added `paused` | The 1.0 machine routed crashes back to `ready` (title), contradicting "a tap after a crash restarts"; mobile interruptions were not handled. |
| Rendering/audio | Safe-area inset for HUD, pixel snapping, ambient audio session, WAV loop | Notches clip HUD text; default iOS audio session stops user music and ignores the silent switch. |
| Font | Bundled OFL pixel font instead of platform monospace | Platform monospace fonts differ between iOS and Android and are not pixel fonts. |
| Leaderboard | Submit only on new best; sign-in only at launch; tamper limits | Avoids redundant calls and mid-run Game Center UI; limits trivially forged scores. |
| Testing | Passability property test, frame-rate independence test, integration test, perf budget | Cover the two highest-risk properties: fairness and feel. |
| Store | Added store & compliance section | Privacy forms, rating, and Play closed-testing rules are release blockers. |
