# LCD Arcade (working name) — Collection Design Spec

Date: 2026-10-18 · Revision: 1.0 · Design canvas: [LCD Arcade collection](https://claude.ai/artifact/VyDKYb9SSQEexE7AsHFWok) · Builds on: [Cave Copter spec rev 1.3](../../helicoopter/docs/superpowers/specs/2026-10-14-helicopter-game-design.md)

## Goal

One mobile app holding four small games in the same retro monochrome-LCD style as Cave Copter: two tones, a visible pixel grid, Silkscreen type, Nokia-style menus and square-wave sounds. A simple launcher with four tiles lets the player pick a game; each game shows in the orientation that suits it.

| Game (working name) | Inspired by | Orientation |
|---|---|---|
| Copter | Classic helicopter cave game (already built) | Landscape |
| Snake | Snake on early-2000s phones | Portrait |
| Blocks | Falling-block puzzle games | Portrait |
| Hop | Endless road-and-river crossing games | Portrait |

Success criteria: as Cave Copter (60 fps on the low-end reference device, identical feel at 60/120 Hz, every generated level passable by construction), plus: switching between launcher and a game of the other orientation completes in < 500 ms with no stretched frame.

## Scope (v1)

- iOS and Android, one Flutter app.
- Launcher, four games, a menu per game, local best score per game, one platform leaderboard per game, sound effects, one app-wide sound setting.
- English only. Out of scope: ads, in-app purchases, accounts, cloud save, achievements, multiplayer, settings beyond sound and start level.

## Open Decisions (resolve before A1 ends)

| # | Decision | Recommendation | Why it matters |
|---|---|---|---|
| C1 | One app or four apps | **One app** with a launcher (as requested) | Shared code, one store listing, one review. Cave Copter is not yet in a store, so its store record can become the collection's. |
| C2 | Collection name and app id | A distinct name (working: "LCD Arcade"); decide before any store record, then keep it | Replaces D1 of the Copter spec; the app id cannot change once store records exist. |
| C3 | Game names | Generic, non-trademarked names (working: Copter, Snake, Blocks, Hop). Never "Tetris", "Crossy Road", "Nokia" or "Snake II" in the app or listing | "Tetris" and "Crossy Road" are registered trademarks; "Snake" alone is a generic genre name. |
| C4 | **Falling-block game: legal review** | **Get a short review by an IP lawyer before building Blocks**; schedule Blocks last | The Tetris Company enforces its rights actively, and in *Tetris Holding v. Xio Interactive* (D.N.J. 2012) a clone was found to infringe on the *look* of Tetris (the 10×20 board, the seven four-cell pieces, how they look and move), not only its name. A monochrome LCD style differs from Tetris' coloured look, but that alone may not be enough. Fallback if advised: change the board and pieces (e.g. 3-cell or 5-cell pieces, a different well shape) or drop Blocks. |
| C5 | Hop: avoid copying Crossy Road's distinctive elements | Generic crossing mechanics (lanes, cars, logs, trains) with our own art and no "eagle"-style chaser; time pressure comes from a slowly advancing screen edge instead | Mechanics are not protected; distinctive characters, names and presentation can be. |

## Platform and Orientation

- The **launcher is portrait** (three of four games are portrait). Opening Copter rotates to landscape; leaving it rotates back.
- Implementation: each game declares its orientation; the app calls `SystemChrome.setPreferredOrientations` before pushing the game route and restores portrait when it pops. The new route builds only after the first frame at the new size, so nothing is drawn stretched.
- iOS: `Info.plist` allows portrait + both landscape directions; `UIRequiresFullScreen` stays. Android: remove the activity's fixed `screenOrientation` (the Copter guard test changes to "orientation is controlled in code").
- Within a game, the orientation is locked; both landscape directions (Copter) and upright portrait are allowed.
- Virtual screens on the same 5-px LCD grid: **landscape 800×400** (160×80 LCD pixels) and **portrait 400×800** (80×160 LCD pixels), each letterboxed in the `bezel` colour inside the safe area.

## Architecture

A Dart pub workspace in the existing `retro-games` repo:

```
app/                      Flutter app: launcher, routing, orientation, services wiring
packages/
  lcd_kit/                LcdBuffer, LcdPainter, palette, Silkscreen styles, 1-bit sprites,
                          LCD widgets (viewport, menu screen, soft key, dialog, blink, scrollbar),
                          AudioService, LocalStore (namespaced per game), LeaderboardService,
                          sound synth tool
  games/copter/           moved from helicoopter/ (core/, game/, screens)
  games/snake/            core/ (pure Dart, TDD) + rendering + screens
  games/blocks/           core/ (pure Dart, TDD) + rendering + screens
  games/hop/              core/ (pure Dart, TDD) + rendering + screens
```

- Each game implements one interface:
  `GameModule { id, title, icon (12×12 1-bit grid), orientation, leaderboardIds, settings (e.g. start level), Widget build(GameHost host) }`.
  `GameHost` gives a game the shared services (sound, its own storage namespace, its leaderboard, "back to launcher").
- Every game keeps the Copter rules: a pure-Dart `core/` with no Flutter/Flame imports (enforced by a test), fixed 60 Hz tick, seeded in-repo RNG, no per-tick allocation, render-only drawing into an `LcdBuffer`.
- Rendering: Copter keeps Flame. Snake, Blocks and Hop are grid games that only need an `LcdBuffer` repainted on a ticker; they use the lighter `LcdSceneView` from `lcd_kit` (Flame is optional per game).

## Shared UX

- **Launcher** (canvas board 1): header `Games` + counter `2/4`; 2×2 tiles (190×325 virtual px at x 5 and 205, 1-LCD-px border; the 180-px inner width fits six letters, so tile names are at most 6 letters), each with its 12×12 icon drawn at 2 LCD px and its name; the selected tile is inverted; soft key `Select`. Tapping a tile selects and opens it. Back on the launcher exits the app (Android).
- **Game menu** (board 2), same parts as Cave Copter's menus: `New game`, `Level: N` (Snake, Blocks; 1–9, tap cycles), `Top score`, `Sound: On/Off`, `Instructions`, `All games`. Back = `All games`.
- **In game**: HUD on top (score left, `HI` best right, 5 digits, 1-px rule), no buttons; pause on back / app background with the pause menu (`Continue`, `New game`, `Sound`, `Main menu`); game over dialog with `New best!` and `Tap to play`; crash = 3 inverted flashes.
- **Sound**: one app-wide setting; each game adds its own square-wave effects to the shared synth script.
- **Scores**: best per game in local storage; one leaderboard per game (four in Game Center, four in Play Games), same offline-tolerant service as Copter.

## Game Specs

### Snake (portrait) — canvas board 3 (playable)

- **Field**: 19×37 cells of 4×4 LCD px inside a 1-px border (LCD x 1–78, y 10–159). Body segments are 3×3 blocks joined into a continuous 3-px line; the head has an eye; food is a 3×3 plus.
- **Rules**: start length 5 moving right; walls wrap around (classic mode); eating grows by 1 and scores `level` points; hitting your own body ends the game. Every 5th food spawns a bonus item for 5 s worth `5 × level`.
- **Speed**: levels 1–9, a step every `250 − 25 × (level − 1)` ms (250 ms → 50 ms).
- **Controls**: swipe anywhere = new direction (absolute, minimum 12 px); up to 2 turns queued; reversing into yourself is ignored. The first swipe starts the game.
- **Fairness**: food never spawns on the snake; the game ends only by the player's own move.
- **Tests**: movement and wrap, growth, collision (including moving into the tail cell that leaves this tick), turn queue, food placement, determinism per seed.

### Blocks (portrait) — canvas board 4 · subject to decision C4

- **Field**: 10×20 well of 5×5 LCD px cells (bricks drawn 4×4 with a 1-px gap) at LCD x 2–51, y 12–111; `NEXT` preview at the right; `LV` and `LN` under the well.
- **Rules** (as specified now, may change after C4): pieces from a shuffled bag; simple rotation with wall kicks; completed rows blink (inverted, 3×) and collapse; level up every 10 rows; gravity speeds up per level; game over when a new piece cannot appear. Score per cleared rows 40/100/300/1200 × level.
- **Controls**: tap = rotate; horizontal drag = move one column per 25 virtual px; drag down = soft drop; quick flick down = hard drop.
- **Tests**: rotation and kicks, collision, row clearing, scoring, gravity table, bag randomness per seed, spawn-blocked game over.

### Hop (portrait) — canvas board 5

- **Field**: lanes 10 LCD px tall, 15 visible; 10 columns of 8 px; the chicken is an 8×8 sprite that moves one lane or one column per hop (8-tick hop animation).
- **Lanes**: grass (trees block columns), road (cars 12 px and trucks 22 px at a constant speed and direction per lane), river (dotted water; logs carry you; water ends the run), railway (warning light blinks for 1 s, then a fast train).
- **Controls**: tap = hop forward; swipe left/right/down = hop sideways/back.
- **Pressure**: the screen edge creeps upward slowly and speeds up with distance; falling off the bottom ends the run. The camera otherwise keeps the chicken in the lower third.
- **Score**: furthest lane reached.
- **Generation** (seeded, passable by construction, like Copter's cave): every grass lane keeps at least 2 free columns and a free path from the previous lane; at most 3 river lanes in a row and log gaps bounded so the next log arrives within a set wait; traffic gaps never smaller than the hop time; density and speed rise with distance. A property test generates thousands of lanes per seed and checks that a path exists.
- **Tests**: hop movement, carrying on logs, drowning, vehicle and train collisions, edge pressure, generator path guarantee.

## Store & Compliance

- One store listing for the collection; screenshots of all four games in both orientations.
- Privacy unchanged (no data collected by the app). Age rating 4+ / Everyone.
- Names and art per C3–C5; nothing resembling Nokia, Tetris or Crossy Road branding.
