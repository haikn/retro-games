# Retro Games

A collection of small retro-style mobile games in a monochrome phone-LCD style, in one app, **Retro LCD Games** (`com.nhk.retrolcdgames`), with a launcher.

| Game | Orientation | Status | Docs |
|---|---|---|---|
| [Copter](packages/games/copter/) (Cave Copter) | Landscape | Built (M1–M5); playable from the launcher | [Spec](packages/games/copter/docs/superpowers/specs/2026-10-14-helicopter-game-design.md) · [Plan](packages/games/copter/docs/superpowers/plans/2026-10-14-helicopter-game-plan.md) · [UI design](https://claude.ai/artifact/BZmh5D8PVzgqnXemYQszzm) |
| Snake | Portrait | Built (A2) | Collection spec below |
| Blocks | Portrait | Built (A4); held back from release builds until the IP review (C4) | Collection spec below |
| Hop | Portrait | Built (A3) | Collection spec below |

Collection: [Spec](docs/specs/2026-10-18-lcd-arcade-design.md) · [Plan](docs/plans/2026-10-18-lcd-arcade-plan.md) · [UI design](https://claude.ai/artifact/VyDKYb9SSQEexE7AsHFWok) · [Leaderboard setup](docs/leaderboards-setup.md)

## Layout

Dart pub workspace — run `flutter pub get` at the repo root.

- `app/` – the Flutter app: launcher, orientation switching, iOS/Android projects
- `packages/arcade_core/` – pure-Dart pieces shared by game cores (seeded RNG)
- `packages/lcd_kit/` – LCD pixel buffer, painter, palette, Silkscreen, LCD widgets, sound, storage, leaderboards
- `packages/games/copter/` – Copter (logic, Flame game, screens, its docs)
- `packages/games/{snake,blocks,hop}/` – the grid games: pure-Dart `core/`, drawing and input on lcd_kit's shared arcade flow

Run a package's checks from its folder: `flutter analyze && flutter test --exclude-tags slow`. Run the app: `cd app && flutter run`. On-device smoke test: `cd app && flutter test integration_test -d <device>`.
