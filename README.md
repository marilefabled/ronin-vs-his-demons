# Ronin Vs His Demons

A sumi-e samurai puzzle. Plan a path, then watch it play.

> *The weight of every blade.*

A wandering ronin in purgatory must draw an ink path through the demons of his past to reach the gate of release. Each kill builds his "number" — numbered demons gate the path until that number is high enough, turning each level into a small theorem.

## Modes

- **Story** — 20 hand-authored levels with a difficulty curve, story interludes, three-star times
- **Endless** — procedurally generated levels with a BFS reachability + numbered-gating validator
- **Speedrun** — three locked-in level sets (Short / Mid / Marathon) with persisted personal bests
- **Forms** — five unlockable samurai variants with distinct stats and signature slash styles

## Stack

- **Flutter** + **Flame** (game engine)
- **GLSL fragment shaders** for paper grain, bloom, and chromatic aberration
- **Dart-only** — no native plugins
- Built-in **desktop level editor** sharing the schema with the runtime

## Build

```bash
flutter pub get

# play
flutter run -d macos
flutter run -d chrome

# build for web
flutter build web

# author levels
flutter run -d macos --target lib/main_editor.dart
```

## Origins

Rescued from a 2022 Construct 3 prototype called *DragonKut*. The voice lines are by Akira, recorded during covid (2020).

---

Built solo by Omar with Claude.
