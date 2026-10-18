# Vertical slice 001 — SMW overworld basics

## Goal

Play and complete a generated `.swe` fixture level using only systems that the
base already partially implements. This slice proves the porting loop end to
end (asset conversion → part/entity implementation → level load → play →
regression test) before broadening content.

## In scope

| System | OpenWE source | Godot target |
|---|---|---|
| Level loading | `obj_load_level/Other_10.gml`, `SMM_WE.yyp` resource names | `scripts/singletons/level_processor.gd` |
| Player movement (SMW) | `obj_mario/Step_0.gml`, `scr_mariowalk`, `scr_mariorun`, `scr_marioidle`, `scr_marijump*`, `scr_marioskid` | `player.gd`, `states/player_*.gd` |
| Power state (small/super) | `obj_mario` Other events, `obj_powerupparent` | `powerups/`, player damage logic |
| Ground / terrain | `obj_ground`, `obj_ground2`, `obj_ground3`, `scr_tiles_ground` | `parts/ground_part.gd`, `tiles/ground.gd` |
| Coins | `obj_coin`, `obj_coin_res` | `parts/coin_part.gd`, `tiles/coin.gd` |
| Question / turn blocks | `obj_block`, `obj_block_coinchain`, `obj_qblock_res` | `parts/question_block_part.gd`, `tiles/question_block.gd` |
| Goomba | `obj_goomba_res` runtime parent objects | `enemies/galoomba.gd` pattern → `goomba.gd` |
| Goal | `obj_flagpole`, `obj_goalcard`, `obj_goalcard_get` | new `parts/goal_pole_part.gd` + level completion flow |
| HUD | SMW HUD objects under `Objects/UI` | `scenes/ui/hud/smw.tscn`, `scripts/ui/hud.gd` |

Out of scope for this slice: other game styles, other themes, enemies beyond
Goomba, editor palette additions, online features, suits/mounts.

## Deliverables

1. Sprite conversion for every sprite used by the slice (manifest-driven).
2. Level loader maps the fixture's object names to real scenes; unknown names
   produce a warning with the object name.
3. Player can walk, run, jump, skid, spin-jump, take damage, die, finish the
   level.
4. HUD shows coins, score and timer.
5. Test scene `tests/scenes/slice_001.tscn` that loads
   `tests/fixtures/port_slice.swe` headlessly and asserts:
   - level loads with expected part counts;
   - player spawns on ground;
   - a scripted jump reaches a known height;
   - touching the goal completes the level.

## Acceptance criteria

- `godot --headless --path . --scene tests/scenes/slice_001.tscn` exits 0.
- Manual playthrough of the fixture has no script errors in the log.
- No hardcoded style/theme overrides remain in `level_processor.gd` for the
  fields used by the slice (`apariencia`, `entorno`, `cronometro`).

## Open questions

- Exact SMW horizontal/vertical speed and acceleration constants need to be
  read from `obj_mario` and confirmed by comparison.
- Ground tile atlas index mapping (`SWE_GROUND_FRAME_TABLE`) currently ignores
  the stored `index`; the slice must restore it.
- Goal-pole placement coordinates and level-complete transition timing.
