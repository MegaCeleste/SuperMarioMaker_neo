# OpenWE porting workspace

For the current running/review entry, read [CURRENT.md](CURRENT.md).
For feature-by-feature explanations, read
[the Chinese implementation guide](IMPLEMENTATION-GUIDE.zh-CN.md).
Historical source/acceptance notes remain in HANDOFF.md.

This branch ports the systems of **SMM:WE (OpenWE edition)** into the
GodotWE codebase. OpenWE's GML project is used as the behavioural
specification; GodotWE supplies the engine-side architecture (level format,
editor, entities, UI).

## Base and reference

| | Repository | Revision | License |
|---|---|---|---|
| Base | [NCubss/GodotWE](https://github.com/NCubss/GodotWE) | `4a836e6`, merged with `b029b73` | GPL-3.0 |
| Spec | [Sicraftails/SMM-WE-OpenWE](https://github.com/Sicraftails/SMM-WE-OpenWE) | see `reference.lock` | AGPL-3.0 |

The OpenWE checkout is a local reference only and is not committed to this
repository. `docs/porting/reference.lock` records the exact revision used for
each porting pass.

## Principles

1. **Port behaviour, not syntax.** GML event code is translated into
   Godot-native nodes, resources and signals. Line-by-line transliteration of
   5,000 event files is explicitly out of scope.
2. **One system, one module.** Each OpenWE resource folder maps to a documented
   module under `scripts/`. The mapping is recorded in `ARCHITECTURE.md`.
3. **Data over code.** Content that OpenWE duplicates per style/theme (sprites,
   sounds, physics constants, enemy tables) lives in resource files
   (`resources/content/`), not in copied scripts.
4. **Level compatibility first.** The SWE level format is the main test oracle:
   a ported system is considered working when it can load and play a real
   community level that exercises it.
5. **Fail loudly in development.** Unknown level objects, sprites or sounds are
   reported with actionable errors instead of silently skipped.

## Layout additions

```
assets/openwe/
  sprites/<name>/frame_000.png   converted sprite frames
  manifests/sprites.json         sprite metadata (origin, fps, folder)
docs/porting/
  README.md                      this file
  ARCHITECTURE.md                OpenWE resource -> Godot module mapping
  GAP_REPORT.md                  generated coverage report
  HANDOFF.md                     project-wide handoff
  HANDOFF-DEEPSEEK.md            2026-10-19 DeepSeek session delta and caveats
  SLOPES-2026-10-22.md           thin ribbons and connected irregular terrain
  SPRING-2026-10-22.md           ordinary portable SMW spring source contracts
  THEMES-2026-10-22.md           six SMW course themes, native history and saves
  reference.lock                 pinned OpenWE revision
scripts/singletons/
  sprite_library.gd              runtime SpriteFrames builder
tools/porting/                   conversion/inventory scripts (added later)
```

## Workflow

1. Run the inventory tools against both projects (see `docs/porting/TOOLS.md`).
2. Pick one vertical slice from `GAP_REPORT.md`.
3. For each OpenWE object in the slice:
   - read its GML events and note the state it owns;
   - design the Godot node/resource shape (no 1:1 translation);
   - implement, then validate with a real SWE level.
4. Update `ARCHITECTURE.md` and the gap report status.
5. Add regression scenes for behaviours that are easy to break (collisions,
   block interactions, enemy stomps).

## Licensing

Combining GPL-3.0 GodotWE code with AGPL-3.0 OpenWE-derived behaviour makes the
combined work subject to AGPL-3.0. All new porting code in this repository is
therefore licensed under **AGPL-3.0-or-later**, while the unmodified GodotWE
base remains GPL-3.0. See `LICENSING.md`.

Mario characters, sprites, music and level data are Nintendo IP and are **not**
covered by either code license. Do not distribute builds or asset bundles
publicly without permission.
