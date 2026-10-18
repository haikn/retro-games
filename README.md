# Retro Games

A collection of small retro-style mobile games in a monochrome phone-LCD style, planned as one app ("LCD Arcade", working name) with a launcher.

| Game | Orientation | Status | Docs |
|---|---|---|---|
| [Copter](packages/games/copter/) (Cave Copter) | Landscape | Built (M1–M5); playable from the launcher | [Spec](packages/games/copter/docs/superpowers/specs/2026-10-14-helicopter-game-design.md) · [Plan](packages/games/copter/docs/superpowers/plans/2026-10-14-helicopter-game-plan.md) · [UI design](https://claude.ai/artifact/BZmh5D8PVzgqnXemYQszzm) |
| Snake | Portrait | Planned | Collection spec below |
| Blocks | Portrait | Planned (pending legal review) | Collection spec below |
| Hop | Portrait | Planned | Collection spec below |

Collection: [Spec](docs/specs/2026-10-18-lcd-arcade-design.md) · [Plan](docs/plans/2026-10-18-lcd-arcade-plan.md) · [UI design](https://claude.ai/artifact/VyDKYb9SSQEexE7AsHFWok)

## Layout

Dart pub workspace — run `flutter pub get` at the repo root.

- `app/` – the Flutter app: launcher, orientation switching, iOS/Android projects
- `packages/arcade_core/` – pure-Dart pieces shared by game cores (seeded RNG)
- `packages/lcd_kit/` – LCD pixel buffer, painter, palette, Silkscreen, LCD widgets, sound, storage, leaderboards
- `packages/games/copter/` – Copter (logic, game, screens, its docs)

Run a package's checks from its folder: `flutter analyze && flutter test --exclude-tags slow`. Run the app: `cd app && flutter run`.
