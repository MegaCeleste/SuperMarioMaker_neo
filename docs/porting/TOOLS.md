# Porting tools

All tools are plain Python 3 (stdlib only) and read the GameMaker project as
untrusted input. Run them with `-I` (isolated mode) and pass the reference
checkout as an argument; never `cd` into the reference checkout to run them.

From the repository root, with the OpenWE reference at `../openwe-ref`:

```bash
python -I tools/porting/inventory_gms.py ../openwe-ref docs/porting/generated/openwe.json
python -I tools/porting/inventory_godot.py "$PWD" docs/porting/generated/godotwe.json
python -I tools/porting/gap_report.py docs/porting/generated/openwe.json docs/porting/generated/godotwe.json docs/porting/GAP_REPORT.md
```

## Sprite conversion

```bash
# Selected sprites
python -I tools/porting/port_sprites.py ../openwe-ref . --sprite spr_1up --sprite spr_SMB_mario_small_idle

# Everything (large; thousands of PNGs)
python -I tools/porting/port_sprites.py ../openwe-ref . --all
```

Outputs:

- `assets/openwe/sprites/<name>/frame_NNN.png`
- `assets/openwe/manifests/sprites.json`

`SpriteLibrary` (autoload) builds `SpriteFrames` lazily from the manifest. The
manifest is additive: converting one sprite does not drop previous entries.

## Prepare, test and play slice 001

From the repository root in PowerShell:

```powershell
python -I tools/porting/prepare_slice.py
python -I tools/porting/run_tests.py --import
& '..\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . res://tests/scenes/play_slice.tscn
```

Preparation reads the small/super/fire animation catalog and enemy/liquid/stun Resources
in resources/content/, converts the selected220 sprites (770 frames), copies31
audio assets (including clear, helmet, plant, impact and ice-contact sounds), and regenerates the
authored 60-tile SWE fixture. Missing required sprites fail preparation. Run it after a
clean checkout, as converted assets are not committed.
It requires the existing local reference checkout and does not download assets.
The additive local manifest currently contains233 sprites /816 frames, including
previously converted resources outside that preparation selection.

The selected SMW Fire Flower regression/captures can be run separately:

```powershell
python -I tools/porting/run_tests.py fire_flower_test
python -I tools/porting/capture_slice.py --fire-flower --fps 60
python -I tools/porting/capture_slice.py --fire-flower --fps 120
```

The item palette's Fire Flower slot is enabled. Its hold window chooses ordinary
or progressive flowers. Drag the flower into a supported block to store it;
long press inspects/extracts that stored item. Run/throw (Shift on the existing keyboard mapping) fires while Fire
Mario is free-handed and standing/jumping; holding the key does not auto-fire.

Super Star and the cold Bro palette/card path have dedicated regressions:

```powershell
python -I tools/porting/run_tests.py star_test palette_icon_test
python -I tools/porting/capture_slice.py --star --fps 60
python -I tools/porting/capture_slice.py --star --fps 120
python -I tools/porting/capture_slice.py --palette-icon
```

The star item slot and star question-block content are enabled. Native saves
use obj_star_res / sprout=-21. The Bro probe checks default cold selection and
actual clipped UI pixels, independent of the older variant-only metadata check.

The donut/note continuation and corrected spike clock share grouped probes:

```powershell
python -I tools/porting/run_tests.py platform_blocks_test terrain_basics_test
python -I tools/porting/capture_slice.py --platform-blocks --fps 60
python -I tools/porting/capture_slice.py --platform-blocks --fps 120
```

The terrain basics continuation has one combined scene and actual GL probes:

```powershell
python -I tools/porting/run_tests.py terrain_basics_test
python -I tools/porting/capture_slice.py --terrain-basics --fps 60
python -I tools/porting/capture_slice.py --terrain-basics --fps 120
```

The combined SMM1 basics/contacts round has one native scene:

```powershell
python -I tools/porting/run_tests.py basic_items_blocks_test
python -I tools/porting/capture_slice.py --basic-items-blocks --fps 60
python -I tools/porting/capture_slice.py --basic-items-blocks --fps 120
```

It covers1UP, hard/hidden blocks, drag-based contents/history/signed SWE,
multi-coins and the existing actor contact matrix. GL mode captures the enlarged
stored-content window, a before/after enemy contact reel and runtime art.
See BASIC-BATCH-2026-10-21.md for the source policies and remaining scope.

The runner defaults to the sibling portable engine; pass --godot for another
executable. It first runs five Python metadata-origin regressions, then forty-nine
independent native scenes; player_render_test uses
120fps with 60Hz physics to expose camera/body mismatch, the others use 60fps, and a
45-second wall timeout per test. It checks PASS markers, exit codes and logs,
so a Godot exit code of zero with a script error still fails. A scene name
can be passed to run only that regression. --import must finish before tests.

Known restricted-environment certificate/user-directory diagnostics and Godot
shutdown RID/resource diagnostics are identified separately from gameplay
errors. Complete logs stay in .godot/porting-tests/; unexpected errors fail.

The actual startup route is covered separately from direct fixture loading:

```powershell
python -I tools/porting/run_tests.py startup_flow_test
python -I tools/porting/capture_slice.py --startup-flow --fps 60
```

startup_flow_test reads the configured main scene from project.godot and drives
its native disclaimer/intro/title/editor/play/return callbacks. It also checks
unbound-cursor processing/pointer input and a freed runtime player while editor
interaction is disabled. The GL mode writes slice_startup_flow.png.

Real-time smoothness diagnostics (visible window, bounded35s run):

```powershell
python -I tools/porting/profile_runtime.py --fps 120 --label=runtime
python -I tools/porting/profile_runtime.py --fps 120 --label=control --no-interpolation
python -I tools/porting/profile_runtime.py --fps 60 --label=runtime
python -I tools/porting/profile_runtime.py --fps 144 --label=runtime
python -I tools/porting/capture_slice.py --world-presentation --fps 120
```

profile_runtime uses wall time, an ordinary GL window, a temporary per-process
VSync override and Engine.max_fps. It performs no image readback or fixed-FPS
simulation during timing. JSON records frame intervals, physical/displayed
positions and directly timed shadow synchronization with/without512 distant
static sprites. It does not measure hardware input latency or compositor
presentation. world-presentation is a separate actual-pixel correctness probe.
See SMOOTHNESS-2026-10-21.md; never infer frame pacing from fixed-FPS captures.

```powershell
python -I tools/porting/capture_slice.py
python -I tools/porting/capture_slice.py --completion
python -I tools/porting/capture_slice.py --editor
python -I tools/porting/capture_slice.py --editor-enemy
python -I tools/porting/capture_slice.py --editor-koopa
python -I tools/porting/capture_slice.py --koopa
python -I tools/porting/capture_slice.py --editor-flight
python -I tools/porting/capture_slice.py --flight
python -I tools/porting/capture_slice.py --editor-buzzy
python -I tools/porting/capture_slice.py --buzzy
python -I tools/porting/capture_slice.py --helmet-completion
python -I tools/porting/capture_slice.py --player-motion
python -I tools/porting/capture_slice.py --player-render
python -I tools/porting/capture_slice.py --player-render --fps 60
python -I tools/porting/capture_slice.py --editor-spiny
python -I tools/porting/capture_slice.py --spiny
python -I tools/porting/capture_slice.py --spiny-completion
python -I tools/porting/capture_slice.py --editor-blooper
python -I tools/porting/capture_slice.py --blooper
python -I tools/porting/capture_slice.py --editor-cheep-cheep
python -I tools/porting/capture_slice.py --cheep-cheep
python -I tools/porting/capture_slice.py --cheep-water
python -I tools/porting/capture_slice.py --cheep-lava
python -I tools/porting/capture_slice.py --editor-piranha
python -I tools/porting/capture_slice.py --piranha
python -I tools/porting/capture_slice.py --piranha-fire
python -I tools/porting/capture_slice.py --piranha-water
python -I tools/porting/capture_slice.py --editor-muncher
python -I tools/porting/capture_slice.py --muncher
python -I tools/porting/capture_slice.py --editor-hammerbro
python -I tools/porting/capture_slice.py --hammerbro
python -I tools/porting/capture_slice.py --bro-status
python -I tools/porting/capture_slice.py --bro-environment
python -I tools/porting/capture_slice.py --rocky-environment
python -I tools/porting/capture_slice.py --thwomp-environment
python -I tools/porting/capture_slice.py --held-stun
python -I tools/porting/capture_slice.py --enemy-defeat
python -I tools/porting/capture_slice.py --world-death
python -I tools/porting/capture_slice.py --chomp
python -I tools/porting/capture_slice.py --editor-chomp
python -I tools/porting/capture_slice.py --grrrol
python -I tools/porting/capture_slice.py --editor-grrrol
python -I tools/porting/capture_slice.py --rotation-render
python -I tools/porting/capture_slice.py --enemy-grounding
python -I tools/porting/capture_slice.py --editor-grounding
python -I tools/porting/capture_slice.py --pixel-shadows --fps 120
python -I tools/porting/capture_slice.py --player-controls --fps 120
python -I tools/porting/capture_slice.py --spin-effects --fps 120
python -I tools/porting/capture_slice.py --player-growth --fps 120
python -I tools/porting/capture_slice.py --braking-dust --fps 120
python -I tools/porting/capture_slice.py --starting-ground
```

The capture tool briefly uses an off-screen OpenGL window, writes
slice_*.png under
.godot/porting-tests/, then exits. Completion mode runs the course using
scripted input; editor mode renders the native block-content window and edit
history controls. Inspect these screenshots after changing gameplay or UI.
Capture logs are retained per mode as `capture_<mode>.stdout.log` and
`capture_<mode>.engine.log`. Bro-status uses the real ice/player overlap and
winged Sledge jump/hover. Bro-environment captures a real ice/Spiny-helmet
rebound and a poison-sinking Bro. Rocky-environment shows the fixed-pose lava
sink, vertical defeat and animated wrench. Thwomp-environment shows precise
silhouettes and paired moving-liquid effects. Held-stun shows a real Sledge
landing, released shell and the source shake animation. Enemy-defeat shows
Monty and all five Bro corpse sprites with their original anchors, frames and
independent facing/impulse. World-death captures the real death pose, stopped
enemies/hammer and an independently moving boomerang. Chomp shows both free
sizes, actual historical links and the five-part defeat; editor-chomp shows
the native size/wings/parachute window and both previews. Grrrol shows all three
source forms; editor-grrrol shows the separate new-size card/window and legacy
preview. These use the 41-scene
suite's setup.
Rotation-render is an additional real-OpenGL readback probe. It verifies crisp
cardinal poses at multiple scales, oblique edge coverage, alpha/tint and unchanged
Mario/terrain controls. slice_rotation_render.png contains three old/new row pairs
(legacy/small/giant), with columns0/3.5/14/31.5/45/-45/90/180 degrees.
rotation_render.json records results. It is intentionally outside the headless
suite: a dummy renderer cannot test the fragment shader. The opt-in material
uses full independent PNG frames, never native atlases or the screen/history.
The same probe also checks actual old Galoomba corpses and shell shake at0/31.5
degrees; those use the material on converted frames, keeping fallback atlases intact.
Enemy-grounding settles41 existing floor/ceiling/inverted variants against real
solids and compares their actual opaque rest pixels to physics rays. It captures
the corrected one-source-pixel overlap in slice_enemy_grounding.png; case order,
surface coordinates, overlap and natural pose lift are in enemy_grounding.json.
It does not flatten per-frame animation motion or change physical masks.
Editor-grounding checks36 existing static Part variants/attachments against
their placement footprints, including ceiling/side plants, wings, repeated
refresh, native hold/drop and undo/redo with unchanged SWE snapshots. It saves
slice_editor_grounding.png and ordered editor_grounding.json contact data.
Pixel-shadows is another real-GL probe outside the headless suite. It compares
current copied silhouettes against an actual translated-source alpha oracle at
scales1/2/2.25/4, including source frames, flips, oblique rotation, inherited
sampling/opacity, atlas/sheet regions, overlap union and removal. It verifies
unchanged solid pixels and actual editor/play actor count and HUD/toolbar.
slice_pixel_shadows.png shows before/after by row (editor, gameplay); separate
slice_pixel_shadows_editor.png and slice_pixel_shadows_play.png are also saved.
pixel_shadows.json records alpha errors and source-pixel controls. Use120fps
to expose stale render frames. The silhouettes have a(2,2) world-pixel offset
and33% black opacity; no animation/physics state is duplicated.
Enemy editor mode renders the Galoomba/Goombud type window and selected tool card.
Koopa modes render the green/red type window or a scene containing both types,
an empty shell and an ejected beach Koopa. The fixture's floor is y=-16, so
captured Parts go at y=-32 and runtime feet at -16; y=0 embeds them in terrain.
Flight modes show independent editor toggles/overlays or descending, hopping
and vertically patrolling actors using the actual OpenGL renderer.
Buzzy modes show type/attachment selection or crawling, ceiling and winged
actors plus a helmet. Helmet completion mode autoplays the course and captures
the original helmet victory frame. Unexpected engine errors fail captures.
Player-motion mode uses player_visual_test with the actual renderer, checking
growth/cadence and capturing small/big walking plus low-ceiling before/after
frames, plus the original one-pixel floor overlap. Those PNGs are slice_small_idle,
slice_super_idle, slice_small_walk, slice_player_motion, slice_growth_before
and slice_growth_after under the same log folder.
It also records consecutive left/right motion through physical mushroom
pickup and continued running with normal camera following. The two contact
sheets slice_player_motion_left/right.png contain 120 frames each, in row
order, with matching JSON traces of feet, screen anchors, cameras and visible
textures. They verify that each rendered frame contains one Mario drawing;
the old AnimatedSprite2D autoplay reset and overlapping bool tweens reproduced
an 8px outgoing-pose shift and single-frame double drawings before the fix.
Those actor-relative contact sheets cannot exclude screen-space pixel jitter.
Player-render mode instead uses a fixed screen crop at full speed, a frozen
pose control and the animated run, both directions, with 120fps rendering by
default (--fps accepts 30/60/120). slice_player_run_<fps>_fixed/animated.png and
matching JSON record actual red-pixel edges, render anchors, physics tick IDs,
camera/body positions and animation frames. This caught the 4–5-screen-pixel
backward step between body updates; camera following now shares their clock.
Spiny modes capture native type/attachment selection, walking/empty/ceiling/
winged actors with a real needle volley, or the original Spiny helmet victory
frame. Blooper modes show its native card and preserved legacy attachment
decorations, or rising/sinking actors and an inverted floating defeat. Blooper
has no type/attachment window in the pinned source. The untouched base fixture
is supplemented only for each capture.
Cheep Cheep modes show the native red/yellow type window, independent flags
and card; actual air jumps, wings and parachute; swimming beneath a moving
forest surface; or lava jumps with the fire aura. Water/lava graphics use the
source SMW sprites. Their theme backgrounds are still unported, so those two
captures show the empty background honestly. Player swimming/liquid damage
and a water-height editor are separate remaining systems.

Manual controls: A/D move, Shift run/hold, Space jump, Tab spin jump. Releasing
Shift kicks a held Galoomba. Clearing a test-play returns to the editor after
the original SMW sequence; Coursebot play returns to the level list. The direct
play scene remains at the victory pose for inspection.
The base Up/Left/Down arrow action bindings and controller bindings are also
retained; Space/Shift/Tab are additional keyboard bindings for this slice.

Editor Save Changes uses the current file path. Save New and Ctrl+Shift+S open
Save As; Ctrl+S saves the current course. The round-trip tests cover unknown
data preservation, repeated overwrites, concurrent saves and write failures.

Hold a question block for half a second to select coin or mushroom contents.
Undo/Redo buttons and Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z handle paint/erase strokes,
dragging, contents and starting-ground height changes. The editor-history test
also checks undo after saving a deletion, retained source data, node cleanup,
40-tile brush grouping, palette selection and a placed mushroom's pickup.

Hold a Goomba-family part to select Galoomba or Goombud. The selected type also
updates its card and subsequent placements. The enemy-variant test covers
save/reopen, an actual platform ledge, stomp/carry, nine-second warning and
ten-second recovery, spin destruction, and pending-spawn cleanup on retry/exit.

Hold a Koopa part to select green/red with the same history and persistent card.
Koopa stomp ejects a beach Koopa and empty shell; Spin destroys it. Hold Shift
to carry a shell, release to kick, W+release to throw up, S+release to drop.
The Koopa regression includes actual contact/reentry and block activation,
separate idle/moving gravity, signed launch speeds, eight-hit chains, held
shields, colour-specific squash effects and retry/exit cleanup. Its 1UP counter
is session-only; it does not implement profile lives.

Enemy windows also have independent wings/parachute toggles; both may be on.
Their flags retain separate history and persist as wings/paracaidas in SWE,
while subsequent new placements start without attachments. The flight test
uses Viewport.push_input(..., true) for actual GUI pointer events; headless
physical-window scaling makes Input.parse_input_event inappropriate for those
viewport coordinates. Runtime tests cover the three wing motion patterns,
parachute sway/landing, first-stomp wing loss, spin destruction and cleanup.

Buzzy palette slot 2 is enabled. Hold it to select beetle or empty shell;
this source swap keeps parachute metadata and drops wings, with full undo.
Place a beetle directly under solid terrain without a floor immediately below
to get its inverted ceiling behavior. Wings make a rideable platform rather
than a stomp target. Occupied shells recover after 640 ticks (600 after being
stopped); empty shells have no occupant. Wear an empty shell by holding Shift
and pressing S on the floor, or let it fall onto Mario from above. The helmet
absorbs one hit without changing small/super power and deflects supported head
contacts. The Buzzy and helmet regressions cover these actual physics paths.

Cheep Cheep palette slot 6 opens red/yellow type selection. Swapping types
keeps wings and removes parachute, with dependent undo; subsequent placements
remember the chosen type. The fish tests check signed SWE and actual physics,
while liquid_surface_test verifies the separate environmental surface. Full
player swimming/liquid damage and water-height editing remain unported.

Piranha palette page 2 slot 0 selects standalone jump/fire plants. The native
window retains independent flags on type swaps. Jump plants attach to ceilings
or side walls when there is no floor immediately below; attaching removes both
flags. Paint/erase/move/type history restores these dependent changes together.
Runtime captures show jumps/wings and the three attachment orientations, aimed
fire poses/projectiles in air or water. Fire-plant overlays are absent in the
pinned SMW source even with saved flags. Pipe-contained plants remain unported.

Muncher page 2 slot 1 enables small/giant sizes. A size swap clears both source
editor flags, and Undo restores them. The giant expands upward/right from its
lower-left cell; dragging checks all four cells. Neither flag reaches the source
runtime. Captures show the size/flag window, grounded small/giant columns and a
falling giant. Tests physically verify contacts, crushing, moving semisolids,
both helmets, block impulses, lava immunity and giant landing effects. Camera
shake affects rendering while camera tracking and collision coordinates stay fixed.

Chomp page2 slot6 enables the free small/giant head with four historical links.
Its modifier-only window offers size/wings/parachute. Size changes shift the
source y by16px, reset both flags and retain full undo. The editor flags survive
SWE but neither affects runtime, matching scr_edit_to_play. The pinned source
has no stake/tether/release system. chomp_test checks both SWE alias formats,
fractional origins, actual window clicks, masks, motion, water/liquid boundaries,
shell/block/helmet contacts, compound corpses, death history and retry cleanup.

Player-controls covers slow/fast walking and full-run reversals in both
directions and power sizes, separate pose/dust thresholds, stopped skid loops,
small/super crouching, physical low ceilings and duck jumps, held-item/helmet
poses and actual Bro palette/card routing. It saves slice_player_controls.png,
slice_player_controls_palette.png and ordered player_controls.json. Run its
headless scene through run_tests.py; use --player-controls for actual GL art.
After the user-supplied SMM2 video, this mode also renders isolated puff alpha
at eight ages to player_controls_dust_profile.png, and captures continuous
real-input braking frames to player_controls_reel_60/120. These check rapid
expansion, filled opaque white interiors, separate fragments and contraction,
not just a shader compiling or a synthetic scale value changing.
The distinct dense running brake is captured to player_controls_run_reel_60/120.
At actual frame_post_draw it checks that every puff remains at its emission
anchor (the latest user request removed following). player_controls.json records
puff counts and stationary-cloud counts. The optional encoded
player_controls_run_walk_braking.gif compares the two real-input sequences.

Spin-effects checks real falling-spin collisions with Spiny, an empty Spiny
shell, Galoomba and Koopa. It verifies the one-frame contact flash and the four
defeat stars growing/shrinking, unchanged recoil/defeat results and finite
audio/effect ownership across editor return. Its GL mode renders eight isolated
ages to slice_spin_effects.png (flash above, stars below), traces pixel coverage
in spin_effects.json, and saves real contact reels to spin_effects_spiny_60/120
and spin_effects_galoomba_60/120. Headless runs wait for wall-clock audio cleanup
separately from their faster fixed-fps simulation; a second natural shell bounce
is outside the single-contact observation window.

Player-growth is the focused60/120fps real-render path for normal mushroom
growth. It records120 input-driven frames per direction in player_growth_left/right_<fps>,
plus slice_player_motion_left/right.png and JSON traces. Those record the one
visible drawing, source texture path, original height and scaled height, and
unchanged paused screen anchor. Growth immediately uses one original big
texture and varies only its vertical scale; only_big_texture must stay true
throughout the pause. Full --player-motion
still runs the wider matrix and may exceed its30s GL bound; use the focused
mode for continuous growth captures and headless tests for that full matrix.
Braking-dust similarly isolates the actual cloud pixel profile and input-driven
walk/run reversal reels from the larger controls/crouch/palette matrix. It uses
the same stationary-anchor assertions and writes player_controls.json plus
player_controls_dust_profile.png. The complete120fps controls GL matrix can
exceed30s; its60fps full matrix and the focused120fps dust mode were verified.

Starting-ground runs the expanded editor_flow_test through the actual editor,
including native paint, erase/resize/history, repeated saves, reopen and play.
slice_starting_ground.png contains isolated, joined-editor and joined-gameplay
views. Native random dirt(16,16) is forced once to verify its supported SWE
equivalent without altering the displayed texture or the native53 atlas choices.

## Notes

`capture_slice.py --theme-switch --fps 60/120` opens the native six-theme
popout, saves theme_menu.png and theme_editor/play_{overworld,underground,
underwater,ghost,airship,castle}.png plus slice_theme_switch.png. Its GPU oracle
samples texture/frame/camera in frame_pre_draw after WorldPresentation, then
checks actual terrain pixels on a thick6x5 block, both narrow strips and an
isolated tile against independent raw source roles, not atlas identity. A30-point
background pool permits foreground occlusion but requires at least10 clear matches.
Preserve final PNG/log files with
_60/_120 suffixes. Native theme_switch_test also checks complete environment
undo/redo, no runtime changes, both signed SWE wrappers/unknown fields, native
terrain topology and default castle lava height after a non-liquid course.

`capture_slice.py --slopes --fps 60/120` runs the native slope editor/contact
matrix with real OpenGL, then saves slopes_editor.png and slice_slopes.png.
The GPU edge probe uses frame_pre_draw canvas coordinates. Keep final files
and matching stdout logs with_60/_120 suffixes; stale intermediate images are
not acceptance for the later fringe or actor-foot correction.
The120 mode adds --slopes-visual-only, retaining editor/jump/slide/junction and
GPU/foot checks while skipping the long native walk/actor matrix already
covered headlessly and by GL60. Endpoint gold-hue checks tolerate editor fade/
dim overlays. slopes_connections.png is a nearest-scaled crop sheet of actual
GPU foot/top joins; it never changes gameplay textures.
The five-issue ribbon correction also saves slopes_ribbons.png (steep5x5/6x6),
slopes_ribbons_gentle.png and slopes_stair_fusion.png. The latter samples956
grass pixels from real GPU output, catching dirt drawn over the slope when
placed later. All44 extent/angle/direction cases, stable distant ground and
actual monster gap/contact edits run in slopes_test. The GL fixture writes
four editable32x32 temporary PNGs to textures/tiles/slopes/templates/; only
files in the parent slopes/ folder are loaded as custom overrides.

`capture_slice.py --slope-fusion --fps 60/120` checks single-cell stair chains
AND the user's later high-end/central-pillar concave profiles in both directions.
It saves slope_fusion_editor/runtime_steep/gentle_up/down, slope_fusion_high_end_
up/down, slope_fusion_central_up/down PNGs plus slice_slope_fusion.png. Keep
matching logs/images with_60/_120 suffixes. It samples30 basic wedges and152
deep-profile points for actual soil/edge RGB and matching runtime collisions,
independent-island preservation, erase/undo/move and unchanged source-Part
count. The old sub-cell-only/no-full-cell-gap acceptance is superseded.

`capture_slice.py --spring --fps 60/120` checks ordinary portable spring
placement/history/signed save, carry/drop/upward release, compression and
normal/high/spin launches, actor bounce and held cleanup on editor return.
The native spring_test also checks both signed SWE wrappers and unknown fields.
Actual GPU shoe pixels plus displayed surface contact are sampled every frame
through compression; a four-pixel interpolation gap failed before the display
anchor correction. Captures: spring_editor/carry/compressed_1/compressed_2/
launch/launch_high/launch_spin/idle.png, slice_spring.png and matching logs.

- `.yy` files are not strict JSON; the parsers tolerate trailing commas.
- `capture_slice.py --semisolid --fps 60/120` verifies native resize/appearance
  history, separate signed platform collections and unknown-data retention,
  full source RGBA tile parity across18 theme/style combinations, actual
  upward passage/downward landing and ordinary actor support. GPU samples
  six editor scenes, runtime art and moved overlapping panels; the original
  resize-handle pixels and UI are excluded. Keep matching semisolid PNGs/logs
  with rate suffixes.
- `capture_slice.py --player-swim --fps 60/120` exercises native SMW swimming,
  three size/power appearances, held buoyancy/diving/release, real solids/block
  bumps/enemy rebound, source water entry/exit and interruption/retry cleanup.
  It checks actual unobscured Mario pixels against independent source art,
  excluding actual carried/effect sprites and their shadows. Keep swim_*.png,
  slice_player_swim.png and capture_player-swim logs with matching rate suffixes.
- Inventory grouping uses the project's own resource folders (`folders/...`),
  not filename heuristics.
- Use absolute --path and --log-file paths for manual Windows Godot diagnostics;
  the bounded runner already does this. Relative log paths can incorrectly
  attempt directory creation under the restricted user:// location.
- When redirecting a full runner in PowerShell, save its `$LASTEXITCODE`
  before displaying the log, then exit with that saved value. A successful
  Get-Content can otherwise hide a failed Python suite. Inspect all scene
  results, not just the log's passing tail; `python -u -I` streams redirected
  progress without buffering it until the end.
- Generated inventories are committed so gap-report changes are reviewable in
  diffs.
