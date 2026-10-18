# LCD Arcade — Development Plan

Date: 2026-10-18 · Spec: [2026-10-18-lcd-arcade-design.md](../specs/2026-10-18-lcd-arcade-design.md) · Design: [LCD Arcade canvas](https://claude.ai/artifact/VyDKYb9SSQEexE7AsHFWok)

## Status (2026-10-18)

| Milestone | State |
|---|---|
| A0 Decisions | **Open**: C2 (collection name, app id), C4 (Blocks IP review) |
| A1 Collection shell | Done (workspace, lcd_kit, launcher, orientation switching) |
| A2 Snake | Done |
| A3 Hop | Done |
| A4 Blocks | Done, held back from release builds until C4 |
| A5 Polish & QA | Code done (shared sign-in, collection icon, smoke test, Hop drawing cost); **device QA, performance and playtest tuning need real phones** |
| A6 Release | Not started (store accounts and records) |

## Approach

- **Collection shell first.** Turn Cave Copter into the first module of the collection before writing new games, so every game is built on the shared `lcd_kit` from day one.
- **Same discipline as Copter.** Pure-Dart `core/` per game written test-first; render-only drawing into an `LcdBuffer`; generated content passable by construction and checked by property tests; check every screen as a rendered image before calling it done.
- **Easiest new game first, riskiest last.** Snake proves the portrait pipeline; Hop has the hardest generator; Blocks waits for the legal review (C4).
- Copter's remaining milestones (M6 tuning/QA, M7 release) merge into A5/A6: the collection ships as one app.

Assumptions: one developer, ideal days; store review and legal review time are extra.

## Timeline

| Milestone | Content | Est. (days) |
|---|---|---|
| A0 | Decisions C1–C5; start the legal review for Blocks | 1 (+ legal wait) |
| A1 | Workspace, `lcd_kit` extraction, Copter as a module, launcher, orientation switching | 5 |
| A2 | Snake | 5 |
| A3 | Hop | 9 |
| A4 | Blocks (if C4 allows; else a changed design or dropped) | 7 |
| A5 | Collection polish, per-game sounds, four leaderboards, device QA in both orientations | 5 |
| A6 | Release (store listing, ratings, closed test, submission) | 2 + wait |
| | **Total** | **~34 days** |

## A0 — Decisions (1 day)

| # | Task | Done when |
|---|---|---|
| 0.1 | Decide C2 collection name + app id, C3 game names | Written into the spec; Copter's working id replaced everywhere |
| 0.2 | Send Blocks (C4) for IP review with the canvas board and the rules section | Review requested; answer expected before A4 |
| 0.3 | Confirm Hop presentation rules (C5) | Spec updated |

## A1 — Collection Shell (5 days)

| # | Task | Acceptance |
|---|---|---|
| 1.1 | Dart pub workspace: `app/`, `packages/lcd_kit`, `packages/games/copter`; move code with history (`git mv`) | `flutter analyze` and all 164 Copter tests pass from the new layout |
| 1.2 | Extract to `lcd_kit`: LcdBuffer, LcdPainter, palette, text styles, sprites, LCD widgets, AudioService, LocalStore, LeaderboardService, synth tool | No game imports another game; kit has its own tests |
| 1.3 | Make `LcdViewport` orientation-aware (800×400 or 400×800); menu widgets lay out in both | Widget tests render the menu in both sizes |
| 1.4 | `GameModule` / `GameHost` interfaces; Copter implements them | Copter runs unchanged inside the shell |
| 1.5 | `LocalStore` namespaces per game (`copter.best`, …) with a one-time migration of the existing Copter keys | Existing best score survives the update |
| 1.6 | Launcher screen per canvas board 1 (tiles, inverted selection, counter, `Select`) | Matches the canvas in a rendered image; tile taps open games |
| 1.7 | Orientation switching on route push/pop; iOS `Info.plist` and Android manifest opened up; platform guard test updated | Launcher portrait → Copter landscape → back, no stretched frame, on iPhone and Android |
| 1.8 | Per-game menu with `All games`; app-wide sound setting | Back from any game menu returns to the launcher |

Exit: Copter fully playable from the launcher on both platforms.

## A2 — Snake (5 days)

| # | Task | Acceptance |
|---|---|---|
| 2.1 | `core/`: grid, wrap, growth, self-collision, turn queue, food and bonus placement, level speeds, seeded RNG | Unit tests per spec; determinism per seed |
| 2.2 | Rendering into `LcdBuffer` (joined body, head eye, food, bonus), HUD, 3-flash game over | Rendered image matches canvas board 3 |
| 2.3 | Swipe input (absolute direction, 12-px threshold, 2-turn queue) | Widget tests for swipes, reverse ignored |
| 2.4 | Menu with `Level`, pause, game over, top score, instructions | Widget tests per screen |
| 2.5 | Sounds (eat, bonus, crash), best score, leaderboard | Service tests with fakes |

## A3 — Hop (9 days)

| # | Task | Acceptance |
|---|---|---|
| 3.1 | `core/`: lanes, columns, hop movement and timing, vehicles, logs carrying, trains with warning | Unit tests per rule |
| 3.2 | Seeded lane generator with the path guarantee and difficulty ramp | **Property test**: thousands of lanes × many seeds, a path always exists; traffic and log gaps within bounds |
| 3.3 | Edge pressure and camera | Tests for speed ramp and falling off the edge |
| 3.4 | Sprites (chicken, car, truck, log, tree, train) and lane rendering | Rendered image matches canvas board 5 |
| 3.5 | Input (tap forward, swipes), menu, pause, game over, sounds, leaderboard | Widget and service tests |
| 3.6 | Optional: look-ahead bot sanity test (as for Copter) | Bot survives a target distance on most seeds |

## A4 — Blocks (7 days, gated by C4)

| # | Task | Acceptance |
|---|---|---|
| 4.1 | Apply the legal outcome to the rules (board, pieces, name) | Spec updated |
| 4.2 | `core/`: pieces, rotation + kicks, collision, row clearing, scoring, gravity table, shuffled bag | Unit tests per rule |
| 4.3 | Rendering (bricks, next preview, row blink), HUD | Rendered image matches canvas board 4 |
| 4.4 | Gesture input (tap rotate, drag columns, soft/hard drop) | Widget tests with recorded gestures |
| 4.5 | Menu with start `Level`, pause, game over, sounds, leaderboard | Widget and service tests |

## A5 — Collection Polish and QA (5 days)

| # | Task | Acceptance |
|---|---|---|
| 5.1 | App icon and splash for the collection (launcher-style tile art) | Legible at 48 px |
| 5.2 | Four leaderboards in App Store Connect and Play Console; IDs in one constants file | Scores visible on all eight boards |
| 5.3 | Performance in both orientations on the low-end Android device; 120 Hz check on iPhone | No frame > 32 ms in 2-minute sessions per game |
| 5.4 | Device and interruption matrix (rotation while backgrounded, calls, notification shade) | Always pauses, correct orientation on resume |
| 5.5 | Playtest tuning per game (speeds, densities) | Median first run 20–60 s per game |
| 5.6 | On-device smoke test: launcher → each game → crash → back | Green on emulator in CI |

## A6 — Release

As Copter M7: listings with all four games, privacy label, age ratings, Play closed test if the account requires it, staged rollout, App Store review.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Blocks found to infringe Tetris rights | Medium | High | Legal review first (C4); build it last; changed design or drop |
| Name or look too close to Crossy Road / Nokia | Low–Medium | High | Generic names and own art (C3, C5); no chaser character |
| Orientation switch glitches (stretched frame, wrong orientation after resume) | Medium | Medium | Build only after resize; device matrix in A5; guard tests for platform settings |
| Hop generator creates impossible rows | Medium | High | Path guarantee + property test, as Copter's cave |
| Shared-kit refactor breaks Copter | Low | Medium | Move with tests green at every step; Copter tests run in CI |
| Scope growth (modes, power-ups) | Medium | Medium | v1 scope fixed in the spec |
