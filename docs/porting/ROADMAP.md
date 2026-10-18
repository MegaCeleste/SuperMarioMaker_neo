# Roadmap

The goal is behavioural parity with SMM:WE OpenWE, not a line-by-line
translation. Milestones are cumulative; each ends with a playable build and a
regression scene.

## M0 — Audit and tooling

- [x] Pin base (GodotWE `4a836e6`) and reference (OpenWE `2f84414`).
- [x] Inventory both projects (objects, folders, scripts, rooms, sprites).
- [x] Gap report by OpenWE resource folder.
- [x] Sprite conversion pipeline + runtime `SpriteLibrary`.
- [x] Generated SWE test fixture (no third-party level data).
- [ ] Sound conversion pipeline.
- [ ] Headless test runner.

## M1 — Vertical slice: SMW overworld basics

See `SLICE-001.md`. Exit criterion: a fixture level is playable end to end
with SMW small/super Mario, Goomba, coin/question blocks, HUD and goal.

## M2 — Editor parity (SMW)

- Port every SMW palette part as a `Part` subclass.
- Variant windows (part types, wings, direction, contents).
- Eraser, multi-place, undo/redo parity.
- Save `.swe` (currently `LevelProcessor` only loads).
- Exit criterion: build a level in GodotWE, save, reopen it in OpenWE.

## M3 — Content breadth: SMW

- All SMW enemies and hazards, theme by theme.
- Platforms, semisolids, doors/warps, note blocks, P-switches, springs.
- Backgrounds and decorations per theme.
- Exit criterion: representative community levels for each theme load and play.

## M4 — Game styles

- SMB, SMB3 and NSMBU player physics, sprites, HUD and palette differences.
- Style-specific objects and bosses.
- Exit criterion: one representative level per style completes with parity.

## M5 — Systems and polish

- Save/profile data, level list (Coursebot), settings, language.
- Audio: music transitions, sound effects, editor music.
- Autoscroll, water/lava levels, clear conditions, pink coins, checkpoints.
- Exit criterion: full play-through of a curated level set without crashes.

## M6 — Parity verification

- Side-by-side comparison harness (same `.swe`, same inputs).
- Physics trace comparison for player movement.
- Release build pipeline and documentation.

## Explicit non-goals

- Online level sharing/account services (OpenWE itself removes online).
- Discord webhook integration.
- Redistribution of Nintendo assets.
