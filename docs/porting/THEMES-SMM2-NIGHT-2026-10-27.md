# SMW SMM2 themes and day/night toggle — 2026-10-27

The user selected a day/night switch and SMM2's four additional themes (desert,
snow, sky, forest), deferring SMM:WE's own themes (fall, beach, mountain and
others). They then chose to limit this round to appearance and music; night
gameplay rules are a later round.

## Native behavior

The course theme popout lists ten cards in SMM2 order, two columns of five:
ground, underground, underwater, desert, snow, sky, forest, ghost house,
airship, castle. Each card is one undoable `EditorHistory.set_theme()` action,
as before.

A lamp on the right of the popout toggles day/night. It reuses upstream
GodotWE's `NightModeBtn` art, position and `change_night_day.wav`, but goes
through `EditorHistory.set_night_mode()` so it can be undone, honours the same
editing/held-part/saving/SMW guards as the cards, and closes the popout.
Upstream's own button set `night_mode` directly and was removed in the sync.

`SubArea.set_environment(theme, night)` replaces `set_theme()`'s body; both the
theme and night setters call it. `theme_state()` now records `night`, so undo
restores theme, night and liquid settings together. Toggling night over an
existing liquid keeps its authored height; a new liquid still starts at the
source default. `Editor.refresh_theme()` only restarts edit music when the
stream changes, since edit music has no night variant.

## Source rules (read-only ../openwe-ref)

| Rule | Source | Port |
|---|---|---|
| Ground sprite | `scr_tiles_ground`, `apariencia == 2` | forest `spr_ground7`, sky `spr_ground8`, desert `spr_ground9`, snow `spr_ground10`; night swaps underwater to `spr_ground4_night` and snow to `spr_ground10_night` only (`night_ground` in `smw_themes.json`, `SMWTheme.ground_sprite()`). |
| Day background | `scr_bg_<theme>` | `bg_desert`, `bg_snow`, `bg_forest`; sky reuses `bg_airship`. |
| Night background | `scr_create_bg_anim`, night branch (overrides `scr_bg_<theme>`) | `bg_night_1..4` loop for every theme except airship (`bg_sky_night_1,2,3,2`), underwater (`bg_underwater_night_1..4`) and ghost house (still `bg_ghost_house_night`). |
| Semisolid art | `scr_semisolid_platform{1,2,3}_sprites` | `spr_ssp<n>_<key>`; sky appearance 1 reuses overworld, snow at night uses `snow_night`. |
| Music | `scr_snd_<theme>`, `scr_snd_editor_<theme>` | play music at night is `snd_music_<theme>_night` (ground for overworld); editor music has no night branch. |
| Liquid | existing `LiquidSurface` | forest is water by day, poison at night. |

`tools/porting/prepare_slice.py` converts the extra sprites and copies the
extra music into gitignored `assets/openwe/`. Wide theme cards for the four new
themes were drawn in the existing flat style from the upstream short cards.

## Not done

Night gameplay: sky low gravity, snow slippery ground, castle underwater
swimming, desert wind, darkness and the other per-object night branches
(OpenWE touches about 400 files). Enemy scripts that already read `night_mode`
keep their existing behaviour. The left-panel theme icon does not show night.

## Verification

`theme_switch_test` walks all ten themes by day (panel, source ground frames,
music, liquid, undo/redo, signed save/reopen, play/edit) and then by night
(toggle, unchanged edit music, night ground and background loop, semisolid art,
forest poison at the same height, undo/redo, save/reopen with night, night play
music, toggle back). `capture_slice.py --theme-switch` compares actual GL
background and terrain pixels for every theme by day, in play, and by night.
