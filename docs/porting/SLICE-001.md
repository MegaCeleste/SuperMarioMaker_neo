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
| Player movement (SMW) | `obj_mario/Other_12.gml` physics, `Step_0.gml` collision, `scr_mario*` sprite selection | `player.gd`, `states/player_*.gd`, `resources/content/smw_player_physics.tres` |
| Power state (small/super) | `obj_mario` Other events, `obj_powerupparent` | `powerups/`, player damage logic |
| Ground / terrain | `obj_ground`, `obj_ground2`, `obj_ground3`, `scr_tiles_ground` | `parts/ground_part.gd`, `tiles/ground.gd` |
| Coins | `obj_coin`, `obj_coin_res` | `parts/coin_part.gd`, `tiles/coin.gd` |
| Question / turn blocks | `obj_block`, `obj_block_coinchain`, `obj_qblock_res` | `parts/question_block_part.gd`, `tiles/question_block.gd` |
| Goomba | `obj_goomba_res`, `obj_galoomba` (SMW Galoomba) | `parts/goomba_part.gd`, `enemies/galoomba.gd`, `stomped_galoomba.gd` |
| Goal | `obj_goalgate`, `obj_goalgate_tape`, `obj_player_goal_smw` | `parts/goal_pole_part.gd`, `tiles/goal_gate.gd`, `smw_goal_sequence.gd`, `states/player_goal_state.gd` |
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

## Implemented and verified — 2026-10-18

The generated 60-tile course includes two loose coins, a coin question block,
a mushroom question block, a turn block, a Goomba resource and a derived SMW
gate. A fixed-input run traverses the course and completes it; graphical
OpenGL playback captures the initial screen and SMW victory pose.

`python -I tools/porting/run_tests.py --import` runs five metadata-origin tests and all forty-two regression
scenes. Interaction tests exercise real body overlaps and head bumps, including
mushroom sprouting, small/super changes, damage immunity, stomp/carry/kick,
spin stomp, turn-block recovery, death/retry and timer expiry.
Player visual tests cover physical mushroom growth in motion/air/tight spaces,
standing up after a low ceiling, one-way platform undersides, synchronous sprite
origins and actual walking-frame changes. Walking/coasting use abs(vx)/5 fps,
capped at 18, and also pass at 30/120 rendering rates.
Actual small/super shoe bounds overlap a physics floor by one pixel, retaining
the y+1 draw offset shared by source gameplay and SMW goal poses.
Outgoing power-change poses use static snapshots so adding them cannot reset
walking art to idle. Atomic visibility switches prevent one-frame double
drawings. Regressions check poses and per-frame visibility in both directions,
growth/shrink, interrupted changes and externally owned pauses. OpenGL captures
record 120 consecutive frames per direction through a real mushroom pickup,
with normal camera following and one stable screen anchor during the pause.
The separate player_render_test uses 120fps against 60Hz physics, frozen and
animated poses, both directions and small/super walk/full-run states. Fixed
screen crops expose camera/body-clock jitter hidden by actor-relative crops.
The camera now follows after each body physics step; OpenGL 60/120fps captures
measure stable full-run pixels and anchors, and the regression also passes at
30/144/240fps. Source animation geometry and floor overlap are retained.
The Spiny integration scene adds palette/undo/SWE, spiked contacts, block-flipped
shell recovery, ceiling drops, timed needles and the distinct shell helmet.
It tests actual collisions and pending-body cleanup, not just resource flags.
The Blooper scene checks native palette/save/history, locked 40-tick jets,
40-tick sinking cooldowns, elliptical contacts, passage through terrain,
air/water stomp differences, head bumps, shell/helmet hits and floating defeat
cleanup. Cheep Cheep adds native red/yellow selection, dependent attachment
undo, signed save/reopen, precise alpha-derived native contacts, swimming and
240-tick turns, two small/one large air jumps, aimed jumps, timed wing glide,
parachutes and lava/poison auras. Tests exercise actual normal/spin/helmet/shell/
block contacts and rotating death in air/water. A separate liquid regression
checks three speeds, source 12px offsets, two-second holds, retry/reset and
metadata validation. Underwater player physics, liquid damage, theme backgrounds
and water-height editing remain separate unfinished systems.
Standalone Piranha regression adds jump/fire window/card/SWE, dependent
floor/ceiling/side history, jump and shot trajectories, precise/elliptical
contacts, support removal, shell/helmet/block hits, lava sinking and cleanup.
Pipe-contained plants remain unported.
Muncher adds small/giant size undo/SWE/origin conversion, native solid ellipses,
fall/cap/drag traces, stacks, moving semisolids, crushing, block launches,
source helmet distinctions, POW defeat and render-only landing shake/audio.
Its editor wings/parachute flags intentionally do not reach the source runtime.

The recent-enemy review adds source-derived platform/attachment/editor cases
and bro_projectile_test: boomerang alarm boundaries, distinct fire/ice contacts,
ice freezing/retry and control-lock recovery. Native Sledge landing stun and
wing hover are covered in hammer_bro_test. See REVIEW-2026-10-20.md for the
corrected DeepSeek claims, real-render captures and remaining fidelity gaps.

chomp_test adds both free Chain Chomp sizes: actual palette/window clicks,
dependent size/flag/position undo, fractional signed SWE round-trips, elliptical
head contacts, historical links, free hops/reversals, source water/liquid rules,
five-part defeat and death/activation/culling/retry ownership. Its two real-render
capture modes show native editor previews/window and the live/free/defeated
actors. The source editor flags are saved but not passed to the runtime; no
stake, tether or escape behavior exists in this pinned version.

grrrol_test adds three distinct source forms, legacy/new editor routes, signed
SWE/history, fixed masks with rotating art, source motion/water/night/contact,
block-owned break alarms, defeat/death/activation/culling and retry cases.
The separate capture_slice.py --rotation-render real-GL probe checks the requested
rotation sampling refinement, including cardinal equality, edge alpha/tint and
unchanged actual Mario/terrain. It does not claim shader verification headlessly
or remove the sprite's baked pixel-art silhouette.

enemy_grounding_test adds41 actual settled floor/ceiling/inverted-art cases,
checking visible pixels against physics rays for the user's one-source-pixel
overlap policy. A stable rest-animation reference retains natural pose changes;
no collision/motion or per-frame pivot snapping is introduced. --enemy-grounding
captures the actual corrected art against native terrain.

Physics snapshots cover walk/run/skid/stop. Jump-height oracles at 60Hz are
26.65px (released), 73.05px (held), and 49.5px (spin), with 0.3px tolerance for
Godot floor separation. These check the local port; they are not a recorded
trace from a running OpenWE binary. The one-frame state-entry and collision
solver differences are documented in `tests/fixtures/smw_player_trace.json`.

Terrain uses GodotWE's existing native atlas and connection rules on load and
after painting/erasing. The fixture spawn derives from the starting-ground
height; no synthetic `obj_mariostart` resource is serialized.

The gate retains OpenWE's 137px geometry and moving tape. Completion plays the
SMW clear music and automatically walks to end-ground +106. Time conversion
starts at frame 240 (250 points per eight seconds, then 50 per final second),
the victory pose appears at 440, and exit occurs at 560. Editor test-play
returns to editing; Coursebot play returns to its level list. Goal-height
bonuses and castle endings remain unported. Other styles/themes retain their
metadata but are not content-complete.
