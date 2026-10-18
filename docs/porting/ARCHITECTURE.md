# Architecture and module mapping

This document is the contract between the OpenWE specification and the Godot
implementation. When a system is ported, add or update its row and link the
implementation files.

## Engine-side model (GodotWE base)

```
Level (Node2D)
├── SubArea (Node2D)               one per playable area
│   ├── background (Parallax2D)
│   ├── parts (Part, Area2D)       editor-placeable elements
│   ├── tiles (GroundTile, ...)    runtime solids spawned from parts
│   └── entities (Entity)          player, enemies, powerups
├── HUD
└── Editor (Control, when editing)
```

- `Part` is the editor-side representation of one GameMaker `*_res` object.
  It builds runtime nodes via `build()`.
- `Entity extends CharacterBodyExt` is the runtime representation of GameMaker
  `obj_enemyparent` descendants.
- `Component` nodes attach reusable behaviour (gravity, pickup, sliding,
  block bumping) to a parent node instead of deep inheritance.
- `StateMachine`/`State` implement player state logic; each OpenWE `scr_*`
  player state becomes one `Player*State`.

## OpenWE resource folder → Godot module

| OpenWE folder | Godot target | Status |
|---|---|---|
| `Objects/Main/Player` | `scripts/level/entities/player.gd`, `scripts/level/entities/states/` | partial |
| `Objects/Main/Parents` | `scripts/level/entities/entity.gd`, `enemies/enemy.gd`, `parts/part.gd`, `scripts/components/` | partial |
| `Objects/Main/Controllers` | `scripts/singletons/`, `scripts/level/level.gd`, `sub_area.gd` | partial |
| `Objects/Enemies/<theme>` | `scripts/level/entities/enemies/`, `scenes/entities/` | minimal |
| `Objects/Blocks/*` | `scripts/level/parts/`, `scripts/level/tiles/` | partial |
| `Objects/Interactive/Collectables` | `scripts/level/powerups/`, `scripts/level/tiles/coin.gd` | partial |
| `Objects/Interactive/Platforms` | `scripts/level/parts/` (to add) | missing |
| `Objects/Interactive/Goals` | `scripts/level/parts/` + `SubArea` goal flow (to add) | missing |
| `Objects/Interactive/Special` | `scripts/level/parts/` (doors, warps, effects) | missing |
| `Objects/Editor Res Objects` | one `Part` subclass per resource + palette resources | partial |
| `Objects/UI/<area>` | `scripts/ui/<area>/`, `scenes/ui/` | partial |
| `Objects/Decorations` | `scripts/level/background.gd`, `scenes/backgrounds/` | minimal |
| `Objects/Collisions` | Godot physics layers + collision parents | partial |
| `Objects/Demo`, `Objects/Discord Webhook` | not ported | n/a |
| `Scripts/Mario` | player states | partial |
| `Scripts/Editor` | `scripts/ui/editor/` | partial |
| `Scripts/Backgrounds` | background controllers | minimal |
| `Scripts/Sounds`, `Scripts/Music` | `scripts/singletons/music_player.gd`, audio bus | partial |
| `Scripts/Misc` | scattered; classify per function during port | partial |
| `Sprites/*` | `assets/openwe/` via `tools/porting/port_sprites.py` | tooling ready |
| `Sounds/*` | `assets/openwe/sounds/` (tool to add) | missing |

## Level data flow

1. `LevelProcessor.decode_swe()` verifies the HMAC and decodes Base64 JSON.
2. `LevelProcessor._from_swe()` reads sections `S1/AJUSTES`, `S2/SUELO`,
   `S4/NIVEL` (new format) or `MAIN`/`AJUSTES`/`SUELO`/`NIVEL` (legacy).
3. Terrain entries become `GroundPart`; object entries are looked up in
   `SWE_OBJECT_TABLE` and instantiated.
4. Unknown object IDs are currently skipped. During the port they must map to
   either an implemented `Part` or an explicit placeholder with a warning.

## Conventions for new systems

- One folder per system under `scripts/`; no new top-level dumping grounds.
- Content tables (enemy stats, per-style physics, palette entries) are
  `Resource` files under `resources/content/`, not constants in scripts.
- Runtime nodes are built from `Part` classes; `Part` classes own editor
  behaviour only.
- Public API gets doc comments; behaviour that mirrors an OpenWE script links
  the source path in a short comment (e.g. `# Ported from scr_mariojump.gml`).
- Every ported system gets a minimal test scene under `tests/scenes/` once the
  test harness is added.
