# Cave Copter (helicoopter)

Retro monochrome-LCD remake of the classic one-touch helicopter cave game, for iOS and Android. Working name until store decision D1 is closed.

- Spec: [docs/superpowers/specs/2026-10-14-helicopter-game-design.md](docs/superpowers/specs/2026-10-14-helicopter-game-design.md) (rev 1.3)
- Plan: [docs/superpowers/plans/2026-10-14-helicopter-game-plan.md](docs/superpowers/plans/2026-10-14-helicopter-game-plan.md)
- UI design: [Cave Copter LCD UI canvas](https://claude.ai/artifact/BZmh5D8PVzgqnXemYQszzm)

## Layout

- `lib/core/` – pure-Dart simulation (no Flutter/Flame imports; enforced by `test/core/core_purity_test.dart`)
- `test/core/` – unit tests, including the passability property test and an exhaustive reachability check

## Commands

```sh
flutter pub get
flutter analyze
flutter test --exclude-tags slow   # fast suite (~15 s)
flutter test                       # everything, incl. slow property checks (~5 min)
flutter run                        # device or simulator, landscape only
```
