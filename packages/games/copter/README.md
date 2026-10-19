# Copter (formerly Cave Copter)

Retro monochrome-LCD remake of the classic one-touch helicopter cave game; one of the four games in the Retro LCD Games collection (see the [collection spec](../../../docs/specs/2026-10-18-lcd-arcade-design.md)). The app itself lives in [`app/`](../../../app/).

- Spec: [docs/superpowers/specs/2026-10-14-helicopter-game-design.md](docs/superpowers/specs/2026-10-14-helicopter-game-design.md) (rev 1.3)
- Plan: [docs/superpowers/plans/2026-10-14-helicopter-game-plan.md](docs/superpowers/plans/2026-10-14-helicopter-game-plan.md)
- UI design: [Cave Copter LCD UI canvas](https://claude.ai/artifact/BZmh5D8PVzgqnXemYQszzm)
- Leaderboards: [docs/leaderboards-setup.md](../../../docs/leaderboards-setup.md) (store-console steps for all games)

## Layout

- `lib/core/` – pure-Dart simulation (no Flutter/Flame imports; enforced by `test/core/core_purity_test.dart`)
- `test/core/` – unit tests, including the passability property test and an exhaustive reachability check

## Commands

```sh
flutter pub get
flutter analyze
flutter test --exclude-tags slow   # fast suite (~15 s)
flutter test                       # everything, incl. slow property checks (~5 min)
```
