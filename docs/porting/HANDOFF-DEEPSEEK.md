# Handoff delta — DeepSeek agent session (2026-10-19)

> Historical report. For the subsequent source audit, corrected behaviour and
> remaining work, read [REVIEW-2026-10-20.md](REVIEW-2026-10-20.md). Several
> source-parity claims and implementation details below have been superseded.

Author of everything in this file: **DeepSeek agent (this session)**. It lists
exactly what this session added or changed, how it was verified, what is still
unfinished, and which parts are approximations. Sections of `HANDOFF.md`
without this marker predate the session (earlier Codex passes); the four
sections marked `— DeepSeek session` there were written by this session.

Read `HANDOFF.md` first for the project-wide state, then this file before
touching the recent content.

## Before changing anything

1. `git status --short` — the delta is uncommitted; do not assume HEAD contains
   it and do not reset the worktree.
2. `python -I tools/porting/run_tests.py` — expect 26/26 before you start.
3. Read the section for the feature you touch here; the approximations listed
   under "Known gaps" are deliberate, not accidental leftovers.
4. For any visual change, re-render the matching capture and measure the drawn
   rect against the feet (see the art-anchor regression below).

## Current status at the end of the session

- Repository: `C:\Working\新建文件夹\GodotWE`, branch `port/openwe`.
- Head: `af6bb46 chore: add agent handoff entry`. **Everything below is
  uncommitted**: 326 changed/untracked entries at the time of writing, no
  commit and no push.
- Engine: `..\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe`.
- Regression suite: **26/26 scenes pass** with
  `python -I tools/porting/run_tests.py` (last run after the GroundPart fix).
- Assets: `python -I tools/porting/prepare_slice.py` prepares **178 sprites /
  615 frames** and the authored fixture (fixture hash unchanged).
- The managed-sandbox `user://`/certificate diagnostics still appear; the
  runner filters them. Verbose shutdown of the new tests only shows the known
  Ogg/WAV playback references, no leaked Nodes.
- The workspace ACL problem from the start of the session was repaired with the
  DSH `diagnose-windows-sandbox-acl` skill; recovery files are under
  `C:\Working\新建文件夹_acl_recovery`. Shell access works now.

## What this session delivered

### 1. Thwomp family (finished an interrupted pass)

The Part/Variant/entity/resources/test existed but `thwomp_test` failed on
three contact behaviours. This session fixed:

- Normal jump must hurt and a spin jump must recoil. The test teleported the
  player and switched to `PlayerSpinJumpingState` while `is_on_floor()` was
  still stale, so the state fell back to Idle; one settle tick was added
  (`tests/scripts/thwomp_test.gd`). `Thwomp` still uses the shared stomp path
  (`hardness 99`, `stomp 2`).
- Buzzy helmet bounce and Spiny 200-point helmet defeat:
  `PlayerHelmet.deflect()` now accepts the actor's swept pre-move bottom edge
  (`Player.helmet_deflects(enemy, previous_bottom)`), and
  `PlayerHelmet.shields()` keeps the helmet effective while a bounced actor is
  still inside Mario's body (Godot reports Area overlaps one physics step after
  the crossing; the source fires on the first step). `Thwomp._body_handling`
  passes its `_before.end.y`.
- Added `--editor-thwomp` / `--thwomp` captures; both were checked visually.

Files: `scripts/level/entities/thwomp.gd`,
`scripts/components/player_helmet.gd`, `scripts/level/entities/player.gd`,
`tests/scripts/thwomp_test.gd`, `tests/scripts/play_slice.gd`,
`tools/porting/capture_slice.py`.

### 2. Monty Mole (new)

Source: `obj_monty_res` (Step_2 only), `obj_monty_chase`
Create/Step_0/Other_10/11/Alarm_10/Draw_0, `scr_edit_to_play` 1329-1340,
`scr_play_to_edit` 203-210, `scr_musicalscale`, `obj_score/Other_10`.

- Native `MontyPart` + `MontyVariant` + `Monty` entity, 2px editor art
  (27x24, origin (5,6), SMW frame 2), off-grid SWE cell, legacy/modern signed
  wrappers, unknown fields, dependent wings/parachute undo.
- Source behaviour: two-tick charge alarm, 116.64px/s^2 toward Mario capped at
  90px/s (36 underwater/night), wall reverse + 90px/s hop, wings 180px/s
  grounded hop via the shared `BOUNCE` profile, parachute 360/24 with +/-16px
  sway, wings strip on first stomp, 200 points on defeat
  (`spr_monty_deads` frame 2).
- Product decision (NOT source parity): Monty may only be placed in a
  ground/block cell. `MontyPart.is_placeable()` requires a `GroundPart`
  overlap, and `build()` spawns the actor on the cell's top surface so it
  emerges. The source (`obj_parent_resource/Alarm_0.gml`) only checks
  overlapping resources and `move_snap(16,16)`; there is no ground rule. If the
  next agent wants exact source placement, revert this rule, the build offset
  and the test assertions together.
- Parts are Areas with `monitoring=false`, so shape queries cannot see them.
  `GroundPart` registers itself in the `ground_parts` group and the placement
  rule scans that group.

Files: `scripts/level/entities/monty_variant.gd`,
`scripts/level/entities/monty.gd`, `scripts/level/parts/monty_part.gd`,
`resources/content/smw_monty.tres`,
`resources/content/smw_flight_monty.tres`, `scenes/entities/monty.tscn`,
`scenes/parts/monty_part.tscn`, `tests/scripts/monty_test.gd`,
`tests/scenes/monty_test.tscn`.

### 3. Rocky Wrench (new)

Source: `obj_rocky_res` (Step_2 only), `obj_rocky`
Create/Step_0/Alarms 0..4/Other_7,10,11,12,14,16,17, `obj_wrench`
Create/Step_0/Collision_obj_mario/Alarms 0,1, `scr_edit_to_play`.

- Native `RockyPart` + `RockyVariant` + `Rocky` + `Wrench`. The Part has no
  popup (source declares none) and keeps the authored off-grid cell; build adds
  the source +8 x offset. Source cycle: pop at 90px/s (48 underwater), settle,
  wait 60 ticks, rise 2px, wait 90, rise to 9px, windup 2, throw art 30, spawn
  one wrench, idle 30, sink at 30px/s, repeat; 10-tick retry when blocked;
  death when the settled support disappears.
- `Wrench`: 60px/s (30 underwater) flight, one of 0/5/13/21/29px arcs at
  180px/s^2 capped to 30px/s, SMW frame 2, 10x10 player area, 6s blink every 7
  ticks, 8s expiry, 128px camera culling (+2px scale tolerance), no terrain
  collision. Stomp kills for 200 points (`spr_rocky_deads` frame 2).

Files: `scripts/level/entities/rocky_variant.gd`,
`scripts/level/entities/rocky.gd`, `scripts/level/entities/wrench.gd`,
`scripts/level/parts/rocky_part.gd`, `resources/content/smw_rocky.tres`,
`scenes/entities/rocky.tscn`, `scenes/parts/rocky_part.tscn`,
`tests/scripts/rocky_test.gd`, `tests/scenes/rocky_test.tscn`.

### 4. Hammer Bro family, five types (new)

Source: `obj_hammerbro_res/firebro_res/icebro_res/boomerangbro_res/
sledgebro_res`, `obj_ventana` number 12 (`Other_22`), `obj_hammerbro`
Create/Step_0/Alarms 1..7,10/Other_7,10,11,13,14,17,25, the
fire/ice/boomerang Alarm_2/3 overrides, `obj_sledgebro`
Create/Step_0/Alarms 1..6,10/Other_7,10,11,13, `obj_brohammer`,
`obj_fireball_bro`, `obj_snowball_bro`, `obj_boomerang`, `scr_edit_to_play`.

- `HammerBroPart` + five `HammerBroVariant` resources + one shared `HammerBro`
  entity + one `BroProjectile` entity. Window: five type buttons + wings. The
  source's separate sledge conversion is folded into the fifth type.
- Patrol +/-16px at 24px/s, face Mario, burst throwing (17-tick entry,
  20/30/30/90-tick throw delays, 80/120/120/120 cooldowns), 6s jumps at
  -371.4/-150px/s for the four Bros; Sledge uses an 18x24 mask, 40x40 throw
  art, fixed 8s -360px/s jumps, 80-tick throws and source landing
  sound/shake/smoke.
- Projectiles: hammer (90px/s, -180 launch, 450 gravity, rotates), fireball
  and snowball (150/144px/s with a floor bounce at -132), boomerang (120px/s
  outbound, reverses after ~0.55s and flies back to the thrower). All damage
  on player overlap, blink at 6s, expire at 8s, cull 32px beyond the camera.
- Icons are the source editor-resource sprites (`spr_*bro_res` frame 2), not
  the 16x32 runtime frames.

Files: `scripts/level/entities/hammer_bro_variant.gd`,
`scripts/level/entities/hammer_bro.gd`,
`scripts/level/entities/bro_projectile.gd`,
`scripts/level/parts/hammer_bro_part.gd`,
`resources/content/smw_hammerbro_{hammer,fire,ice,boomerang,sledge}.tres`,
`scenes/entities/hammer_bro.tscn`, `scenes/parts/hammer_bro_part.tscn`,
`tests/scripts/hammer_bro_test.gd`, `tests/scenes/hammer_bro_test.tscn`.

### 5. Shared framework changes

- `EnemyFlightProfile`: added `manual_walk` (skip the shared slide so a custom
  chase is not overwritten) and `wing_hop_speed` (per-profile grounded wing
  hop), plus `enemy_flight_component.gd` honours both.
- `Part._create_window()` now opens when either variants or modifiers exist
  (Monty has only wings/parachute toggles).
- `GroundPart._ready()` calls `super()` (see regressions below) and adds the
  `ground_parts` group.
- `level_processor.gd`: object table entries and per-Part variant/flag/position
  loading for Monty, Rocky and all five Bros.
- `swe_level_serializer.gd`: `_object_id` for the new Parts; wings flags for
  the Bros, wings/parachute for Monty.
- `resources/palette/category_enemies.tres`: Monty slot 3, Rocky slot 4 and
  Hammer Bro slot 5 enabled (placeholder scripts removed).
- `tools/porting/prepare_slice.py`: new resource globs
  (`smw_monty*`, `smw_rocky*`, `smw_hammerbro*`), digit-safe sprite key regex
  (`idle2_sprite`), explicit `spr_hammer/fireball/snowball/boomerang`.
- `tools/porting/run_tests.py`: `monty_test`, `rocky_test`,
  `hammer_bro_test` registered.
- `tests/scripts/editor_history_test.gd`: supported Part list extended; new
  hover assertion (right-click erase regression).
- UI icon fixes: `editor.tscn` CenterIcon, `card.tscn` Icon and
  `palette_ring.gd` sector icons use `KEEP_ASPECT_CENTERED` (source icons are
  not square).
- `tests/scripts/play_slice.gd` + `capture_slice.py`: captures
  `--editor-thwomp/--thwomp`, `--editor-monty/--monty`,
  `--editor-rocky/--rocky`, `--editor-hammerbro/--hammerbro`.

### 6. Documentation written by this session

- `HANDOFF.md`: four sections marked `— DeepSeek session` (Thwomp, Monty,
  Rocky, Bros), state bullets, 26-scene list, capture list, limits, traps.
- `ROADMAP.md`, `ARCHITECTURE.md`, `AGENTS.md`, `SLICE-001.md`, `TOOLS.md`:
  counts and the new modules.
- `GAP_REPORT.md` and `docs/porting/generated/godotwe.json` regenerated;
  `tools/porting/gap_report.py` description table updated (Airship/Castle,
  Editor Res Objects, UI/Editor, Enemies).

## Verification actually performed

- `python -I tools/porting/run_tests.py` → 26/26 PASS after every fix; final
  run after the GroundPart `_ready` fix.
- `python -I tools/porting/run_tests.py --import` used after adding sprites.
- `monty_test`: both signed wrappers, off-grid cell, unknown field, four-slot
  window, dependent undo, charge/caps, wall hop, wing strip + 200 points,
  wing hop, parachute cap/sway/landing, placement rule, build anchor.
- `rocky_test`: both wrappers, absent popup, exact cell, cycle phases, wrench
  kind/speed/arc/expiry/culling, stomp, support removal.
- `hammer_bro_test`: both wrappers, five-type window, type/wings round-trip,
  projectile kind/speed/direction, boomerang return, jump heights, Sledge
  mask/jump, art bottom == feet, wing strip + 200 points.
- `thwomp_test`: contact, both helmets, cycle, blocks, POW, void, cleanup.
- Art anchor measured by script: drawn bottom == feet (-94.8) for Hammer and
  Sledge; the same regression is now an assertion.
- Captures regenerated and inspected: `slice_thwomp.png`,
  `slice_editor_thwomp.png`, `slice_monty.png`, `slice_editor_monty.png`,
  `slice_rocky.png`, `slice_editor_rocky.png`, `slice_hammerbro.png`,
  `slice_editor_hammerbro.png` (all under `.godot/porting-tests/`, gitignored).

## Known gaps, approximations and risks

1. **Sledge Bro stun is not ported.** Source `obj_sledgebro/Step_0` sets
   `stuntime = 80` and `disablecontrols = 1` on a grounded Mario after a jump
   landing. The player has no native stun state yet; only the thwomp sound,
   camera shake and smoke run. Do not claim parity until a stun state exists.
2. **Bro wings are editor flags only.** They are saved, stripped on the first
   stomp and drawn in the editor decoration, but there is no winged bro flight
   or runtime wing art; source `Other_25`/jump tables and wing drawing are not
   reproduced. Sledge's `volar` hover is absent.
3. **Monty placement is a product rule, not source.** Source allows any
   snapped cell that does not overlap another resource. The current build also
   moves the runtime anchor from the cell bottom to the cell top; loading old
   SWE content authored under the previous anchor shifts the actor by one cell.
4. **Projectile fidelity is approximate.** Fire/ice use 720 gravity and bounce
   at -132; the snowball source has no Step_0 (movement inheritance was not
   fully audited), so its bounce is an assumption. Boomerang phases are
   approximated at ~0.55s rather than the exact 32/15/8 tick alarms and it has
   no rotation art.
5. **Hammer Bro AI is simplified.** No `throughsolid` jump phases, no
   block-pass/landing behaviour, no source wing jump heights, throw cadence is
   from Alarm_2 rather than frame-exact; the five types share one state machine.
6. **Icon choice.** The Bros use `spr_*bro_res` art; other Parts keep their
   existing png icons. The global `KEEP_ASPECT_CENTERED` change also affects
   those icons visually (they were square before, so it should be neutral).
7. **Shared-code risk.** `EnemyFlightProfile`/`EnemyFlightComponent` changes
   affect every winged enemy; all 26 scenes pass, but review if a future change
   depends on `_slide` running.
8. **No commit.** The whole delta is uncommitted; run the suite before and
   after any reset.

## Regressions I introduced during the session (and the guards added)

1. `GroundPart._ready()` overrode `Part._ready()` without `super()` while
   registering the `ground_parts` group. This silently removed
   `mouse_entered/mouse_exited`, so `editor.hovered_part` stayed null and
   **right-click ground erase stopped working**. Fixed by calling `super()`;
   `editor_history_test` now asserts hover set/clear.
2. The Hammer Bro `Graphics` offset was changed from -16 to 0 without measuring;
   the 32px art then ended 16px below the feet (buried). Fixed back to -16 and
   guarded by `check_art_anchor` in `hammer_bro_test`.
3. The first Hammer Bro icons used runtime 16x32 frames instead of the source
   editor-resource sprites, and the UI stretched them into square slots. Fixed
   the icon source and set `KEEP_ASPECT_CENTERED` on the palette centre, ring
   sectors and editor card.
4. The Monty placement rule was inferred from the user's request and presented
   without checking the source first; the source has no such rule. It is now
   documented as a product decision so the next agent can revert it cleanly.

Process lesson: measure shared visuals (drawn rect vs feet) and check the
source event before changing an anchor or a base-class lifecycle hook; every
one of these regressions came from changing shared/base code without a test
that watched the user-visible result.

## Suggested next steps

1. Port **Chain Chomp** (palette page 2 slot 6, `obj_chomp_res`), the current
   next task in `HANDOFF.md`; audit `obj_chain_chomp*` (free/held/bowserjr),
   chain links and stake/block interactions first.
2. Then Spike and the remaining page-2 entries, pipe Piranha Plants
   (`obj_tuberia_res`), water/night variants and block contents.
3. Optional fidelity follow-ups for the work above: Sledge stun, bro wings and
   `volar`, exact boomerang alarms, snowball movement audit, and a decision on
   Monty placement (source parity vs the stricter rule).
4. Real OpenWE interoperability (saved files in a running OpenWE binary) is
   still untested.

## Quick commands

```powershell
# Full suite (26 scenes).
python -I tools/porting/run_tests.py

# One scene while iterating.
python -I tools/porting/run_tests.py hammer_bro_test

# Regenerate assets + fixture (needs ../openwe-ref).
python -I tools/porting/prepare_slice.py

# Captures for the recent content.
python -I tools/porting/capture_slice.py --editor-hammerbro
python -I tools/porting/capture_slice.py --hammerbro
python -I tools/porting/capture_slice.py --monty
python -I tools/porting/capture_slice.py --rocky
python -I tools/porting/capture_slice.py --thwomp
```
