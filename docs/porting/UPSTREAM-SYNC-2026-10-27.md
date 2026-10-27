# Upstream GodotWE sync — 2026-10-27

The user asked to unify SMMneo with the current GodotWE. Branch
`sync/godotwe-upstream` merges `upstream/main` at `b029b73` into `SMMneo`
(previous base `4a836e6`, 44 upstream commits). This is a real merge, so later
syncs only need to resolve changes made after `b029b73`.

## Rule used for conflicts

SMMneo's verified gameplay wins; upstream's layout and editor work are adopted.

| Area | Result |
|---|---|
| Directory layout (`scenes/level/...`, `textures/styles/<style>/...`, `audio/styles/<style>/...`, `states/player/`) | Upstream. SMMneo-only scenes and the extra player states moved to match; every `res://` path in scenes, scripts, resources, tests and current docs was rewritten. |
| Editor UI (game style popout, music toggle, clapperboard `pause` hotkey, part window on middle click) | Upstream. `Level.music` is honoured by SMMneo's `_play()` music selection. |
| Course theme popout | SMMneo's `level_theme_panel.gd` cards. Upstream's thirteen `LevelThemePopoutBtn` nodes and `NightModeBtn` were removed from `editor.tscn`: they drew over SMMneo's cards and set `level_theme` / `night_mode` directly, bypassing editor history and `SMWTheme.CHOICES`. Their scripts remain unused. |
| Player, `Enemy` base class, components, `DeadEntity`, Galoomba/Koopa/BeachKoopa/KoopaShell scenes and scripts | SMMneo. Upstream's StompComponent / ShellPickupComponent / KinematicCollisionExt / `items/` (Grabbable, Shell, StunnedEnemy, KoopaShell) / BeachKoopa states were not taken, as they replace the `Enemy` architecture all SMMneo enemies use and duplicate the `BeachKoopa`/`KoopaShell` class names. |
| Display smoothing | SMMneo's WorldPresentation. `physics/common/physics_interpolation` stays off, the template has no `Camera2D`, and `Utility` keeps the canvas-transform camera with `camera_render_offset`. Upstream's `reset_physics_interpolation()` calls that merged cleanly are no-ops while interpolation is off. |
| `Utility.query_rect()` / `Utility.shake()` | Upstream helpers added. |
| `klock.ogg` | Upstream deleted it in favour of `kick1`–`kick8`; SMMneo still uses it, so it is kept at `audio/styles/smw/player/klock.ogg` with its original UID. |
| `textures/tiles/slopes/` | Unchanged; it is SMMneo-only and stays at its documented path. |

## Fixed during the sync

Placing terrain could immediately grab the new part, stopping a paint stroke.
`Part` ignored the placing press only within its spawn process frame, but
physics picking delivers that press on the next physics tick, which at 120 Hz
can be a later frame. `Editor.presses` now counts left presses; a part ignores
the press count it was created under. `editor_flow_test` covers the late press.

## Deferred

Migrating SMMneo enemies onto upstream's component architecture, and comparing
WorldPresentation with native physics interpolation, are separate tasks.
