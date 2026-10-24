# Handoff — M2 in progress; recent enemies reviewed against source

> **Project identity and separation (2026-10-25):** this large project is now
> SMMneo at `C:/Working/SMMneo/GodotWE`, on branch `SMMneo`. Existing local
> integration is preserved in the source checkpoint. The independent repository
> `C:/Working/GodotWE` continues focused upstream PR work. Both projects may
> exchange individually reviewed fixes; do not merge this entire integration
> into the upstream contribution repository. See CURRENT.md and AGENTS.md
> for the active boundaries. The publication target is the `SMMneo` branch of
> MegaCeleste/SuperMarioMaker_neo; existing remote branches remain intact.
> No new gameplay feature is selected by this step.


Updated 2026-10-23 for the next agent continuing this local port. Read this
file, then ARCHITECTURE.md, ROADMAP.md and SLICE-001.md in this folder.

> **Current correction record:** read
> [REVIEW-2026-10-20.md](REVIEW-2026-10-20.md) before continuing. It supersedes
> the four historical DeepSeek feature sections below, including the invented
> Monty placement rule, Rocky settlement, Bro simplifications and helmet guard.
> It also records the later source-reviewed Chain Chomp/Grrrol ports and the
> user-requested rotation sampling improvement. Their remaining
> unported interaction systems are still open.

> **Session attribution.** The four historical DeepSeek sections below
> (Thwomp, Monty Mole, Rocky Wrench, five Hammer Bros) and
> the shared/UI/doc changes they list were written by the **DeepSeek agent** in
> the session that ended 2026-10-19. Everything else in this file comes from
> earlier Codex passes. Read
> [`HANDOFF-DEEPSEEK.md`](HANDOFF-DEEPSEEK.md) for the exact delta, the known
> approximations, the regressions this session introduced and their guards,
> and the verification evidence. Do not trust the later sections without it.

## State

**Latest selected continuation: ordinary SMW semisolid platforms(2026-10-23).**
The user selected this now after swimming. Read SEMISOLIDS-2026-10-23.md.
Native palette slot/page0-sector6, three appearances with remembered card,
bottom-left anchored width/height resizing, native history and separate signed
platform collections are implemented. Source12-frame tiling retains odd/even
width parity and all six selected themes. Background decorations permit
overlapping ordinary Parts; only the top5px is a runtime one-way surface.
Actual player jump/landing/edge, item/enemy standing and edit/replay paths pass.
The original source handle is reused, with its3.6fps active animation.

Real GL exposed high platforms drawing below their own shadow group. Final
art is z0, between shadows/background and terrain/actors, with exact top-y
ordering inside that layer through deferred/coalesced sibling ordering. Source
pixels and GodotWE terrain rules are untouched. Ordinary foreground Part
picking and existing slope precedence are preserved. Platform rows stay in
MAIN.PLATAFORMAS or project-modern S0.S7, keeping unknown records/fields and
source revision/index ownership. Original executable parity is not claimed.

Final GL60/120 passes1038/1038 source pixels per rate in six editor, runtime
and moved-overlap views; native source checks cover full RGBA tiles across18
theme/style cases.
Matching semisolid_*_60/_120 PNGs, slice_semisolid_60/_120.png and
capture_semisolid_60/_120.stdout.log are retained under .godot/porting-tests/.
Final fresh import, five metadata guards and all57 native scenes pass. The
complete report is .godot/porting-tests/final_semisolid_native_suite_2026-10-23.txt;
all57 named scene results were checked, not only the report tail. Current
generated audit:310 scripts /163 scenes /40,681 lines. Preparation selects269
sprites /1308 frames /42 sounds; additive manifest282 sprites /1354 frames.
No production changes followed acceptance. The active SMM1 goal is incomplete.
No Antigravity, subagents, reference/art edits, commit, push or publication.

**Latest selected continuation: ordinary SMW swimming (2026-10-23).** The
active goal remains SMM1 completeness; it is NOT complete. The user selected
swimming now after six-theme switching. Read SWIMMING-2026-10-23.md.
PlayerSwimmingState shares the existing collider/powerups and implements
source empty-hand strokes, floating art, water-floor movement/crouching,
held-item buoyancy/forward drift/Down diving, water rebound and source bubbles.
Small/Super/Fire use original unedited swimming/float art. Water interrupts
ordinary movement but cannot replace freeze/stun/goal/death or spring/note
compression. Surface exit goes through the native variable-height jump when
Jump is held. Source entry/exit hysteresis uses native feet+14/+12 bands.

Continuous-state pickup exposed a real hand-alignment omission: giving an
item now sets its native hand position after deferred reparenting, rather
than relying on a new state's start(). Existing throw/drop ownership remains.
The six-theme UI and original53 terrain chooser are unchanged. No additional
styles, SMM2 themes, mounts or night systems are selected by this round.
The initial aggregate passed52/56 native scenes; its four failures exposed
old test-fixture assumptions. Blooper/fish/plant contact distances now allow
actual1px/tick water descent, and underwater Spin cannot preserve a forced
air spin-recoil pose. Bro's shot-only splash counter now suspends Mario so his
real water entry cannot add an unrelated splash. All four affected scenes and
the new swim scene pass focused reruns. The initial report is retained as
swimming_initial_native_suite_2026-10-23.txt; do not call that report green.

Final real-GL60/120 passes5752/5752 and11595/11595 unobscured source pixels,
including mirrored poses, original three-frame strokes and held art. The
oracle waits for the native entry fade and masks actual foreground objects,
bubbles and thaw effects plus shadows; it accepts zero mismatched remaining
pixels. Matching capture_player-swim_60/_120 logs, swim_*_60/_120.png and
slice_player_swim_60/_120.png are retained in ignored .godot/porting-tests/.
Super float, grounded Fire crouch and held dive screenshots were inspected.
Final fresh `python -I tools/porting/run_tests.py --import` passes import,
the five metadata guards and ALL56 native scenes. The complete report is
final_swimming_native_suite_2026-10-23.txt; every registered scene was checked,
with56 accepted, zero missing and zero FAIL lines. Known shutdown resource/
ObjectDB diagnostics remain subject to the existing runner filters; this is
not a zero-engine-diagnostic claim. No production changes followed final GL
and native acceptance. Earlier terrain/menu acceptance remains scoped to its
previous correction. Current generated
audit:308 scripts /161 scenes /40,054 lines; selected250 sprites/1088 frames/
42 sounds, additive manifest263 sprites/1134 frames. No Antigravity, subagents,
reference/art edits, commit, push or publication.

**Latest correction: theme terrain and menu (2026-10-23).** The user reported
bad terrain after switching themes. This was a real adapter bug, not missing
ordinary ground assets. SWE_GROUND_FRAME_TABLE is a serialization contract;
raw sprite order diverges at43. SMWTheme now reads a separate rendering-only
smw_ground_frames.json: raw43=filled,44=isolated,45=vertical,46=horizontal.
All five added themes share the basic mapping, including underground whose
extra50+ frames contain diagonal art. Previously those triangles reached native
decorative square slots. The original overworld texture and native53 chooser
remain unchanged. The new independent source-role assertions first fail the
old adapter and pass the fix. Thick6x5 ground, narrow strips and isolated ground
are now included in editor/runtime source-pixel verification.

The user requested SMM2's theme-menu layout. Actual original-game screenshot:
https://www.shacknews.com/article/112708/every-course-theme-in-super-mario-maker-2-course-maker
The six authorized themes now use two columns of landscape cards. The user then
explicitly requested the existing red-corner effect and NO name labels. The
final implementation uses ButtonHoverEffect; no handwritten corner renderer,
name badge or tooltip remains. This UI request does not select four further
SMM2 themes or day/night gameplay.

The user is drawing slope art. textures/tiles/slopes/README.md now lists full
per-theme filenames:16x32 steep,32x32 gentle, up/down and standalone/filled.
The loader supports all six theme subdirectories and retains the old overworld
gentle aliases. Ground gentle needs four final PNGs; overworld steep already
exists. Other five themes lack a verified complete paired slope set (underground
has some diagonal pieces), so their current fallback is explicitly temporary.
Normal square ground/background art does not need redrawing. Palette previews
follow the selected non-overworld atlas. Read updated THEMES-2026-10-22.md.

Final production acceptance: import, five metadata checks and all55 native
scenes pass (.godot/porting-tests/final_theme_terrain_native_suite_2026-10-23.txt).
The final sheet review also caught missing batch connection refresh in the TEST
fixture's initial overworld rectangle; the fixture now refreshes once after
construction. Production code did not change. The focused native theme rerun
and final GL60/120 reruns pass after that fixture correction. Both rates check
actual editor/play terrain against raw source pixels across all six themes
(4174/4174 pixels at each rate);
matching capture_theme-switch_60/_120 logs and theme_*.png captures are retained.
themes_terrain_verified_2026-10-23.png is a3x2 sheet of actual120fps editor views,
and theme_menu_120.png shows reused animated corners without name labels. The
2026-10-22 background-only acceptance is historical; it missed source-frame roles.
Current regenerated audit:304 scripts /160 scenes /39,411 GDScript lines.
No Antigravity/subagents, reference/art edits, commit, push or publication.

**Prior selected continuation: SMW course-theme switching (2026-10-22).**
After completing the slope/spring round below, the user selected “scene switching”
and clarified that this means ground/underground/castle course themes. The native
left-panel Course Theme popout now offers SMM1's six themes: ground, underground,
underwater, ghost house, airship and castle. Backgrounds, ground/start-ground/slope
art, relevant editor previews/cards and edit/play music refresh together, with
atomic history, play/edit lifecycle and both signed SWE wrappers. No door/pipe
subarea work or other styles/SMM2-only themes were selected.

Read THEMES-2026-10-22.md. Source ground frames are repacked into the existing
native atlas layout; the53-choice connection tree is unchanged. Nongrass50-frame
sheets use their ordinary edges in place of decorative variants. Theme-specific
slope surfaces are derived from theme edges/body because these SMM1 source
sheets have no diagonal assets; overworld/custom gentle assets keep their route.
Backgrounds animate at6fps in play and freeze frame0 in editing. Child backdrops
now receive the same display camera correction as the foreground.

The GPU probe caught a real castle-entry issue: dormant water_level0 in old
non-liquid SWE files flooded the new castle from the top. Theme entry now creates
a bottom surface (source room_height-4), and history captures/restores the entire
theme/liquid state. Loading an already authored castle retains its saved water
settings. Repeated changes skip reloading editor-player signals and goal sprites.

Final native acceptance: import, five metadata checks and all55 native scenes
pass after theme integration. The explicit report is
.godot/porting-tests/final_themes_native_suite_2026-10-22.txt. Native theme tests
include both signed wrappers, whole environment/liquid history and runtime
rejection. Final --theme-switch GL60/120 pass and were inspected: all six
editor/play views match9/9 actual background source pixels each (108/108 per
render rate). The final menu uses20px labels, including the longer choices.
Matching theme_menu/editor_*/play_* PNGs and capture_theme-switch_60/_120 logs
are retained under .godot/porting-tests/; themes_six_verified.png is a3x2 sheet
of the actual120fps editor captures. It does not modify any gameplay assets.
Affected final --spring GL120 also passes432/432 shoes at0.08px anchor error,
and --slopes GL60 retains1099/1099 grass,476/476 gentle and8/8 shoes at1px
contact. Native55-scene acceptance and those captures follow the final production
changes. No further production changes followed; git diff --check is clean.
Current regenerated audit:304 scripts /160 scenes /39,292 GDScript lines.
Preparation selects242 sprites/1066 frames and41 audio files; additive manifest
contains255 sprites/1112 frames. The earlier54-scene acceptance below belongs
to the slope/spring round. Theme switching does not add Mario swimming, other
style/theme content, room transitions or theme-specific ending sequences.
No Antigravity/agents, reference edits, commit, push or publication.

**Prior selected continuation (2026-10-22): irregular slope fusion and ordinary
portable spring.** The user rejected remaining holes beneath slopes meeting a
central/high-end pillar. Previous acceptance covered only single-cell stair
wedges and invented a sub-cell-only fusion limit. Eight-neighbour native terrain
components now identify actual ribbon contact; each contacted component projects
its column tops to the slope across the footprint, including deep concave gaps.
Independent islands cannot activate fusion. Every derived bridge cell uses the
existing53-choice atlas; editor selection, resize clearance and runtime collision
share the complete outline. Authored terrain remains reversible and independently
saved. Read SLOPES-2026-10-22.md. The expanded slope_fusion_test checks30 basic
wedges plus152 deep-profile points in both directions, actual soil/edge pixels
and runtime collision, source-Part count, history and disconnected islands.

The user explicitly chose ordinary spring next. Gizmos page0 slot0 now places
SpringPart; obj_spring_res supports both signed SWE wrappers and unknown fields.
Run/side pickup, drop/ordinary/upward release, source4-frame18fps compression,
nine-tick rider hold, ordinary/held-Jump/spin launches and ordinary actor bounce
are implemented with existing native components/states. Holding disables the
one-way child surface and editor return clears held runtime bodies. A120fps
GPU probe first exposed4.08px of transient shoe separation at compression frame
changes. WorldPresentation now anchors the rider to the displayed spring pose;
source texture pixels and physics positions are not changed. Read
SPRING-2026-10-22.md. Horizontal/winged springs and other styles remain future.

Final acceptance: import, five metadata checks and all54 native regression
scenes pass (final_native_suite_2026-10-22.txt). --slope-fusion AND --slopes
GL60/120 pass and were inspected:182 wedge/deep-profile soil/collision samples,
1099/1099 fused-grass pixels,476/476 gentle pixels and8/8 Mario shoe pixels with
1px overlap. --spring GL60/120 pass:216/216 and432/432 actual shoe pixels,
maximum0.08px surface-anchor error,38px ordinary and125.925px held-jump ascent
measured after the initial launch tick. Final capture-only waits let editor
fades finish and show airborne poses; native paths/production are unchanged.

Final artifacts/logs retain_60/_120 suffixes under .godot/porting-tests/.
slopes_irregular_fixed.png crops the two actual120fps irregular-profile views;
spring_editor/carry/compressed_1/compressed_2/launch/launch_high/launch_spin/idle
show the selected spring slice. spring_verbose.stdout.log confirms exit
references are audio streams, packets and playback objects only; no leaked
player, spring or terrain nodes. This is not a claim of zero engine/audio
exit diagnostics. Earlier52/53-scene slope acceptance is historical.

Current regenerated inventory:301 scripts /159 scenes /38,905 GDScript lines.
Preparation selects224 sprites/777 frames and31 audio files; additive manifest
contains237 sprites/823 frames. No production changes followed final checks;
git diff --check is clean. No Antigravity or subagents were used.

**Latest five-issue slope correction (2026-10-22):** the user's screenshot and
official Direct recheck rejected the filled right-triangle interpretation.
Slopes are now one-tile diagonal ribbons; empty space beneath them stays empty.
Existing staircase GroundParts are reversibly clipped to the ramp surface in
derived editor art and runtime collision. Only caps use square atlas sprites,
fixing detached tiles at5x5/6x6. Placement/resize uses the convex decomposition
of the ribbon rather than a convex hull, allowing a16px monster gap and rejecting
actual overlap. Coordinate-seeded decorative variants preserve the original53
ground rules without map-wide rerolls, and unchanged art is cached. Actual GL
inspection additionally caught later-placed dirt hiding slope grass; an explicit
terrain overlay order fixes both editor and runtime. User-authored gentle PNGs
belong in textures/tiles/slopes/, with filenames/dimensions in its README and
four32x32 editable temporary templates in templates/. Missing art retains the
temporary sampler. Native focused checks and GL60/120 pass:44 shape cases,
stable distant terrain, stair restoration,956/956 fused grass pixels,476/476
gentle edge pixels and8/8 shoe pixels with1.0px overlap. Actual endpoint
gap/contact cases were added before the aggregate: import, five metadata checks
and all52 native scenes pass. Current regenerated inventory:296 scripts /
155 scenes /38,123 GDScript lines; preparation/manifest selection is unchanged.
Read SLOPES-2026-10-22.md; the earlier triangle acceptance below is historical
and does not establish correct Nintendo editor semantics.
Final confirmation after the shared-refresh/complete-icon refinements: slice,
sprite-library, editor-flow, editor-history, slopes and palette-icon focused
checks all pass. Final actual GL60 (full walk/actor matrix) and GL120 (bounded
visual matrix) pass with956/956 fused grass pixels,476/476 gentle edge pixels,
8/8 shoe pixels and1.0px overlap. Ribbons, gentle ribbons, stair fusion,
editor/runtime, gentle foot/join images and matching logs retain_60/_120 suffixes
under .godot/porting-tests/ and were inspected. The comparison image crops
actual GL60 views without altering gameplay/source textures. No production
changes followed these final successful checks; git diff --check is clean.

**Earlier slope implementation (superseded by the correction above):** SMW floor slopes, overriding the
SMM1-only backlog filter for this selected feature. Read
[SLOPES-2026-10-22.md](SLOPES-2026-10-22.md). The Nintendo Direct's2:29–2:38
editor sequence was frame-stepped after the user signed in; steep/gentle are
two adjacent palette entries. Shared endpoint editing fixes the opposite cap,
preserves1:1/2:1 inclines, flips across it and records whole-gesture history.
The native occupancy/53-choice atlas integrates ground/starting-ground and
diagonal joins. The user's seam screenshots exposed a missing lower grass
fringe; paired fringe overlays now retain the native side/bottom boundaries.
Slope courses configure native floor tolerance/snap; ordinary player/enemy/
item traversal and player sliding use existing physics/state/contact APIs.
WorldPresentation adds a display-only center-foot slope sample, including
shadows, to avoid rectangular-collider corner support making art float.
Signed save/reopen uses explicit godotwe_slope/godotwe_gentle_slope extensions;
do not claim original OpenWE executable support. The initial slice incorrectly
filled the triangle and deferred strips. Import/five metadata checks and all52 native scenes passed in
the aggregate before the final art/UI/ledge refinements. Affected slope/
editor-history, Koopa, Bro-platform and presentation focused reruns pass;
final slice/sprite/slopes/editor-history checks also pass. Actual GL60 runs
the full matrix; the bounded120 mode skips redundant long walk/actor tests
while retaining editor, jump/slide/junction and GPU checks. Both modes pass,
including visible gold handles above terrain,462/462 paired edge/fringe GPU
pixels,8/8 shoe pixels and1.0px contact. Final editor/runtime/gentle/connection
images and logs retain_60/_120 suffixes and were visually inspected. Current
inventory296 scripts /155 scenes /37,843 lines; preparation223 sprites/773
frames/31 sounds; additive manifest236 sprites/819 frames. The initial120
full-matrix timeout and an absolute-brightness handle assertion were probe
limits, not accepted results; final120 uses the focused matrix and gold-hue
visibility oracle. No production changes followed the final successful GL.

**Latest user correction/continuation (2026-10-21):** spike animation was
incorrectly autoplaying the converted60fps metadata. It now samples the source
shared6fps banim3 clock; late-created spikes synchronize and transformation
pause freezes them. The subsequent ordinary SMW donut/note batch is implemented:
enabled palette/history/signed SWE, source donut warning/fall/carry/return and
growth, native note compression/normal-held-spin bounces, existing actor rebound
and drag-based directional powerup release. Read
[PLATFORM-BLOCKS-2026-10-21.md](PLATFORM-BLOCKS-2026-10-21.md). Focused native
platform/terrain/editor-history probes pass. Import, five metadata checks and
all51 native regression scenes pass. Final actual GL60/120 editor/runtime
captures pass and were inspected. Thirty GPU-readback spike frames per mode
match the current source pixels and the shared6fps cadence. The120Hz probe
must capture canvas coordinates in frame_pre_draw after WorldPresentation;
post-draw canvas values can belong to a different render frame. This sampler
repair changes no production rendering. Retain platform_blocks editor/runtime
images and matching stdout logs with_60/_120 suffixes in .godot/porting-tests/.
Current audit:291 scripts /152 scenes /
36,892 lines; preparation220 sprites/770 frames and31 sounds; additive manifest
233 sprites/816 frames. Wings, musical variants/instruments and other styles
remain future work.

**Latest continuation (2026-10-21):** ordinary SMW spikes, ice blocks and cloud
platforms now have enabled native palette Parts, painting/history, signed SWE
and runtime surface/contact policies. Read
[TERRAIN-BASICS-2026-10-21.md](TERRAIN-BASICS-2026-10-21.md). The grouped native
probe passes, including ice coasting/air transitions, cloud jump-through and
enemy/item support, downward Thwomp cloud crushing, spike damage/helmet/star
contacts and retry/editor cleanup. Import and five metadata checks pass. The
aggregate50-scene run passed49; editor_history_test still classified the three
newly implemented Parts as placeholders. Its supported-Part list is updated
and the focused rerun passes. No production regression remained. Final actual
GL60/120 captures pass and were visually inspected, including native palette
icons, cloud support, ice/spike art and shadows. Retain the clean overview and
editor images plus stdout logs with_60/_120 suffixes in .godot/porting-tests/;
the overview reloads first to clear prior helmet/star probe effects.
Current audit:284 scripts /149 scenes /36,097 lines;
preparation216 sprites/762 frames, additive manifest229 sprites/808 frames.

**Latest authorized batch (2026-10-21):** the user requested several basics
before combined validation, then corrected container editing and requested
existing enemy/item contacts.1UP, hard/hidden blocks, drag into question/hidden/
turn containers, enlarged inspect/extract icons, atomic history, timed
multi-coins and missing actor contact rules are implemented. Read
[BASIC-BATCH-2026-10-21.md](BASIC-BATCH-2026-10-21.md) for source contracts,
bounded scope and regression matrix. Focused native checks and actual GL batch
captures at60/120fps pass and were visually inspected. Current generated
audit:277 scripts /145 scenes /35,566 lines; preparation211 sprites/752 frames,
additive manifest224 sprites/798 frames and30 gameplay sounds. Import and five
metadata checks passed. The aggregate49-scene run passed47 and exposed Monty's
post-contact facing and FireFlower's preloaded mushroom cycle. Both fixes pass
clean targeted world_death/fire_flower/monty/recent_enemy_defeat/basic batch
reruns; the other47 results were retained instead of repeating the full suite.
Final cold import, required slice/sprite guards and actual-GL startup flow
pass after the fixes. Final batch GL60/120 captures pass; editor/runtime/contact
reels and stdout logs are retained with_60/_120 suffixes in the ignored test
folder. The enlarged widget crop is basic_stored_content.png.
Enemy contents/attachments, other styles and
profile/challenge lives UI remain future work. Long press inspects current
contents; do not restore the old contents-selection menu.

**Latest selected round (2026-10-21):** the user approved basic SMW Super Star
and clarified the missing Hammer Bro art as its palette/top-card icons. Both
are implemented. Read [STAR-2026-10-21.md](STAR-2026-10-21.md) for the cold-load
empty-cache/default-icon fix, native rendered-pixel regression, star placement/
block/history/SWE and additive player status,10s refresh, speed bonus, source
flash/sparkles/music, enemy chains and lifecycle cleanup. The dedicated icon
GL probe, star captures at60/120fps and actual-GL startup flow pass and were
visually inspected. Import, five metadata checks and all48 native scenes pass.
Current generated audit:266 scripts /140 scenes /34,307 lines. The verbose
star exit audit reports retained audio streams/packet/playback references only,
without leaked player, enemy or editor nodes. Other item variants/styles remain
future work; no further feature is selected by this round. Restart an already
running game to clear its pre-fix icon cache.

**Latest selected content (2026-10-21):** the user chose **now** for ordinary/
progressive SMW Fire Flower, native placement and block contents, save/history,
Fire Mario, ordinary/spin fireballs and existing enemy hit responses. This is
implemented; see [FIRE-FLOWER-2026-10-21.md](FIRE-FLOWER-2026-10-21.md) for source
contracts, integration and verification. Winged flowers and other powers/styles
remain future work. The prior investigation-only notes below are historical.
Import, five metadata checks and all46 native scenes pass, including the new
fire_flower_test and startup flow. Actual GL Fire Flower checks at60/120fps
pass; inspected sheets are retained under .godot/porting-tests/ with_60/_120
suffixes. Current generated audit:260 scripts /136 scenes /33,573 lines.
The actual-GL --startup-flow probe also passes after this content addition.

**Latest startup correction (2026-10-21):** the user's runtime log reports
EditorPlayer._process reading status on a Nil level. A cursor must wait until
its Level context is valid; movement also checks editor/player lifetimes.
Part input ignores unbound context. startup_flow_test reproduces the reported
empty-context failure and follows the configured startup scene through intro,
title, editor creation, play and return. The real-GL --startup-flow capture
passes and shows the actual editor after that round trip.
Import, five metadata checks and all45 native regressions pass, including
cursor movement after binding and safe input before binding.

**Latest growth clarification (2026-10-21):** the user explicitly retracted the
small/big alternation. Mushroom growth now switches immediately to the original
big texture and only changes scale.y throughout its pause: standing heights
24/20/26/20/28, with6/5/5/6/6-tick phases. The last full-size phase also keeps
that same texture. Big duck/held-duck uses the same ratios within its original
height. The texture-bottom pivot preserves feet+1px. Shrink flashing retains
its separate behavior. Seven focused native regressions and actual60/120fps
growth in both directions pass, including one drawing, stable paused display
anchor and only_big_texture=true. No new content was added.

**Previous completed round:** the user approved runtime smoothness optimization.
See [SMOOTHNESS-2026-10-21.md](SMOOTHNESS-2026-10-21.md) for the display-only
actor/camera/background interpolation, cached/camera-culled shadows, measured
120Hz pose coverage and CPU gains,44 native regressions and GL evidence.
The physical tick stays60Hz; standard interpolation has a visual-latency
tradeoff. Earlier60/120fps captures were correctness checks, not real-time
frame-pacing measurements. No new course content was added.

**Latest user direction (supersedes older scope notes below):** SMM1
course-making content first; additions absent from SMM1 wait. Wii U's updated
course-making feature set is the working scope, rather than all OpenWE content.
The user then said to pause new features and fix six specific existing issues
first. Fire Flower was only investigated in that earlier bug-fix round; it is
now implemented in the newly selected content round above.

- Repository: C:\Working\新建文件夹\GodotWE
- Branch: port/openwe, based on GodotWE 4a836e6 (GPL-3.0).
- Reference: sibling openwe-ref, OpenWE
  2f84414054c576bf7ca03dfa33b244ee730d57da (AGPL-3.0).
- Engine: ../.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe.
- M0 audit/tooling is retained. M1 (SLICE-001) is implemented. M2 SWE
  save/reopen and editor/Coursebot entry points are implemented and tested;
  M2 now includes core edit history, standalone mushroom placement and a
  question-block content window, Galoomba/Goombud and green/red Koopa selection,
  SMW Koopa stomp/eject/shell/reentry behavior, and native independent wings/
  parachute flags for the four original ported enemy types. Buzzy Beetle and
  empty Buzzy shells now have native Parts, occupied-shell recovery, ceiling
  crawling/drops, rideable wings and the SMW Buzzy helmet. Remaining
  palette parts/variants and real OpenWE interoperability are still open.
- SMW Spiny/empty shells now have native palette Parts, signed SWE/history,
  ceiling drops, winged needle volleys and their distinct helmet/goal frame.
- SMW Blooper now has a native palette Part, signed SWE/history, timed jets,
  sinking cooldowns, air/water contacts and its animated floating defeat.
- Red/yellow Cheep Cheeps now have native type/card/history/SWE, swim/jump/glide,
  precise native contacts, parachutes and liquid auras. Liquid surface metadata,
  movement and SMW graphics are implemented as their environmental foundation.
- Standalone jump/fire Piranha Plants now have native type/card/history/SWE,
  topology-derived ceiling/side attachment, jumps, aimed shots and typed defeat.
  Pipe-contained Piranha Plants remain a separate, unported system.
- Small/giant Munchers now have native size/attachment windows, dependent undo,
  signed SWE, falling solid masks, stacks, hazardous/crushing contacts, distinct
  helmet behavior and the source giant landing sound/camera impulse.
- Small/giant Thwomps now have native Parts, the source direction cycle (down/
  left/right), size/type window with the enabled legacy Grrrol entry, dependent undo,
  signed SWE, four source phases, block breaking/activation, enemy crushing,
  POW/helmet defeat and native OpenGL captures.
- Monty Mole now has a native palette Part, the source two-tick charge and wall
  hop, independent wings/parachute through the shared flight rules, typed
  defeat and signed SWE.
- Rocky Wrench now has a native palette Part, the source pop/rise/throw/sink
  cycle, an obj_wrench projectile with its arc/blink/expiry, support-removal
  defeat and signed SWE.
- Hammer/Fire/Ice/Boomerang/Sledge Bro share a native palette Part and window,
  source patrol, native platform passing, independent throw/recovery clocks
  and distinct projectiles. Regular Bros have four types and size/wings;
  Sledge has its own size/wings/parachute window, jump warning, wing hover and
  grounded Mario stun. Ice contact now freezes Mario instead of damaging him.
- Both free Chain Chomp sizes now have native palette/window/history/SWE,
  source motion and elliptical masks, four historical links, compound defeat,
  water/liquid policies and death/activation/retry integration. The pinned
  source has no stake, tether or release system.
- Legacy, new small and new giant Grrrol now have separate source identities,
  native editor routes, dependent position/flag history and fractional SWE.
  Rolling masks stay fixed while the art rotates; source water/night, delayed
  block breaks, contact, defeat, death and activation policies are tested.
- Rotating Grrrol, hammer/boomerang shots, Spiny needles and spinning source
  corpses opt into screen-footprint edge sampling. Cardinal poses retain exact
  nearest pixels. This is a requested visual refinement, not a source physics
  change; Mario/terrain remain on their existing sampling path.
- Latest user-reported bugs: continuous rendering exposed an outgoing sprite
  autoplay reset/8px shift and a one-frame double drawing at growth boundaries.
  Static pose snapshots and atomic visibility changes now fix both. A further
  report exposed camera/body clock mismatch: at 120fps, a frozen running pose
  moved backwards 4–5 screen pixels between 60Hz body steps. Camera following
  now runs after body motion on the same physics clock. See the player-fix
  section below. Physical feet/headroom, cadence and y+1 overlap are preserved.
- This continuation has local changes; no push or publication was performed.
- User direction for this continuation: **do not use Antigravity**. Work and
  verification were performed directly by Codex.
- Latest scope correction: focus on basic gameplay and reported bugs. Do not
  automatically implement the rest of OpenWE. Before each next work item,
  explain its concrete scope and ask **now / do not do / leave for later**.
  No answer is not approval. New content in the roadmap is future reference.
- The user selected **now** for the existing-basic-flow review and explicitly
  added enemy floating/surface overlap. This bounded work is authorized;
  broader new content still needs a separate choice.
- The subsequent approved editor-preview contact and lower-right pixel-shadow
  follow-up is delivered and verified below. No additional content is selected.

## What M1 delivered

1. SWE loading restores valid style, theme (including ground/ghost aliases),
   timer, starting-ground height and basic block contents. Spawn derives from
   ground2, as in obj_load_guardabot/Other_11.gml. obj_mariostart is an intro
   overlay, not a saved player marker; the generated fixture no longer uses it.
   Unsupported object names warn with instance count and source file. Empty
   settings and invalid scalar values are handled safely. Async requests use
   their own captured IDs; the worker now joins cleanly on shutdown.
2. GoombaPart maps OpenWE's obj_goomba_res to the SMW Galoomba runtime and
   obj_goombrat_res to Goombud. Normal
   stomp -> flipped carryable body; holding Run picks it up, release kicks
   it; spin stomp destroys it. Other style-specific Goomba behavior is not
   being claimed as implemented.
3. Coin, question/turn block, mushroom, player small/super, Galoomba and goal
   sprites use SpriteLibrary's converted manifest. Preparation now converts 198
   selected sprites / 711 frames and copies nineteen source audio assets into
   gitignored assets. Ground reuses GodotWE's native atlas and connection rules.
   Loading supplies all neighbours before building runtime tiles; painting,
   erasing and filling gaps update surrounding tiles through existing logic.
4. Player physics constants are data in resources/content/. Acceleration and
   gravity use seconds consistently. Walk/run/skid/stop, variable jump, spin,
   buffered jumps/coyote handling, shrink + two-second immunity, death/retry
   and timer expiry work. Power changes retain one stable Sprite node.
5. Coin and mushroom question blocks, recoverable turn blocks, coin/score/time
   HUD and the SMW gate + moving tape. The gate derives from ground3 settings
   unless explicitly stored. The temporary gray result panel has been removed.
   Completion uses automatic walk, SMW clear music, time tally at reference
   frame 240, victory pose at 440 and exit at 560. Editor test-play returns
   to editing; Coursebot play returns to its list. Direct play stays at the pose.
6. The generated 60-tile fixture includes two coins, two question blocks (coin
   and mushroom), one turn block, one Goomba and one derived gate. It can be
   played directly through tests/scenes/play_slice.tscn.
7. Thirty-eight regression scenes, a bounded test runner, and a real OpenGL screenshot
   tool. The graphical autoplay reaches the goal and captures the victory pose
   without script errors or a placeholder panel.
8. GameSettings now falls back to defaults if user:// cannot be written;
   the old recursive retry could overflow the stack in this sandbox.
9. Additional Space/Shift/Tab bindings provide jump/run/spin on the keyboard;
   the base arrow-key and controller action bindings are retained.

## Run and verify (PowerShell, repository root)

```powershell
# Regenerate local assets and the authored fixture; no downloads needed.
python -I tools/porting/prepare_slice.py

# Run five metadata regressions, import and run all forty-nine native scenes.
python -I tools/porting/run_tests.py --import

# Play directly (A/D move, Shift run/hold, Space jump, Tab spin jump).
& '..\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . res://tests/scenes/play_slice.tscn

# Optional real-renderer captures, using a temporary off-screen window.
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
python -I tools/porting/capture_slice.py --editor-thwomp
python -I tools/porting/capture_slice.py --thwomp
python -I tools/porting/capture_slice.py --editor-monty
python -I tools/porting/capture_slice.py --monty
python -I tools/porting/capture_slice.py --editor-rocky
python -I tools/porting/capture_slice.py --rocky
python -I tools/porting/capture_slice.py --editor-hammerbro
python -I tools/porting/capture_slice.py --hammerbro
python -I tools/porting/capture_slice.py --bro-status
python -I tools/porting/capture_slice.py --held-stun
python -I tools/porting/capture_slice.py --enemy-defeat
python -I tools/porting/capture_slice.py --world-death
python -I tools/porting/capture_slice.py --chomp
python -I tools/porting/capture_slice.py --editor-chomp

# Regenerate current inventory and coverage after changes.
python -I tools/porting/inventory_godot.py (Get-Location).Path docs/porting/generated/godotwe.json
python -I tools/porting/gap_report.py docs/porting/generated/openwe.json docs/porting/generated/godotwe.json docs/porting/GAP_REPORT.md
```

The forty-three test scenes are slice_001, sprite_library_test, interactions_test,
loader_compatibility_test, player_physics_test, swe_roundtrip_test,
editor_flow_test, smw_goal_test, editor_history_test, goomba_variants_test, koopa_test,
enemy_flight_test, buzzy_test, helmet_test, player_visual_test, spiny_test,
blooper_test, cheep_cheep_test, liquid_surface_test, piranha_test, muncher_test,
player_render_test, thwomp_test, monty_test, rocky_test, hammer_bro_test,
bro_projectile_test, bro_platform_test, bro_environment_test, rocky_environment_test,
source_mask_test, helmet_mask_test, thwomp_environment_test, held_stun_test,
actor_activity_test, recent_enemy_defeat_test, world_death_test, chomp_test and
grrrol_test, enemy_grounding_test, editor_grounding_test, player_controls_test
and spin_effects_test. Run capture_slice.py
--rotation-render and --pixel-shadows separately for actual shader
pixels, not the headless dummy renderer. The player-render regression uses
120fps to expose frames
between the unchanged 60Hz physics steps; the other scenes use 60fps.
The runner fails on nonzero
exit, a missing PASS marker, timeout, script errors or unexpected engine errors.
Logs and screenshots are in .godot/porting-tests/ (gitignored).

In this managed Windows sandbox, the certificate store and user:// can be
unavailable, and Godot emits known dummy-renderer/resource shutdown diagnostics.
The runner recognizes these specific environment diagnostics; gameplay errors
still fail. The portable engine's _sc_ marker keeps its editor settings beside
that engine. It does not make user:// writable; GameSettings handles that.
The verbose edit-history shutdown diagnostic contains audio stream/playback
objects left by the fast fixed-fps run, with no Part, EditorHistory or UndoRedo
instances in that leaked-object list. Keep the explicit detached-Part disposal
assertions; do not treat future node leaks as an expected audio diagnostic.

## M2 save/reopen foundation

- SWELevelSerializer snapshots supported Parts and metadata on the main
  thread. The worker receives plain data, encodes the signed SWE and stages
  it beside the target, keeping a recovery backup during replacement.
- Original root/settings/sections, unknown objects and their ordering, and
  unknown fields on supported objects survive repeated saves. Source-index
  bindings and file_path change only after a successful write.
- Metadata-only/incomplete loads, multiple playable areas, held Parts and
  unsupported Parts refuse saving. Failed writes preserve the active path
  and existing file. Tests cover legacy/modern aliases and concurrent requests.
- Editor Save Changes/Ctrl+S and Save New/Ctrl+Shift+S are wired. Coursebot
  Edit/Play asynchronously load the selected course and surface errors.
- New editor courses get one default goal. The actual editor -> save ->
  Coursebot preparation -> playable level path is exercised headlessly.
- The editor test cursor is session state and is not serialized as an OpenWE
  resource. Reopened courses derive their spawn from starting ground.

## M2 editor operations delivered

- The existing enemy palette and top card now select GoombaPart. The item
  palette's mushroom entry uses MushroomPart and the existing Mushroom
  runtime; obj_mushroom_res loads and saves. Unimplemented anonymous palette
  entries remain visible but are disabled until they have a working Part.
- Hold a question block for 0.5 seconds to open the existing EditorWindow
  with coin/mushroom icons. Selection changes sprout contents and a small
  editor preview; both undo and SWE round-trip preserve the selection.
- Native UndoRedo records placement, dragging, contents, paint and erase
  strokes. Starting-ground resize and all Parts it covers form one action.
  Undo restores height, collision dimensions, retained fields and terrain.
  Undo/Redo buttons and Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z use the same history.
- Use Editor.erase_part() for interactive erasure; do not queue_free a Part
  while history owns it. Do/undo references release detached nodes when a redo
  branch is replaced or history is cleared. The native UndoRedo object is
  explicitly freed with its history node. Undo order is reversed per action.
- Saves advance swe_revision for active Parts. A detached Part restored after
  a save cannot reuse its stale source index; it retains its unknown fields
  and is safely appended at the next save. This is covered by regression.
- Terrain refreshes after grouped history operations run once per batch via
  the existing GroundPart connection rules. Mouse release ends a gesture even
  over UI controls. Popup placement handles different canvas transforms and
  camera scrolling.
- editor_history_test verifies the actual palette/card/window, input shortcuts,
  move/erase/resize grouping, undo across saves, detached-node cleanup,
  a 40-tile brush stroke and physical pickup of a placed mushroom. The editor
  capture renders the content window and history controls with the real GPU.
- GoombaVariant Resources in resources/content/smw_goomba_*.tres carry the
  source object IDs, icons, walking/held sprites, ledge behavior and recovery
  timings. The native type window supports Galoomba and Goombud. The card
  retains the chosen type for subsequent placements, as in obj_goomba_res's
  object-swap event; existing-object undo does not reset the tool default.
- Goombud uses the existing SlideComponent with a support probe for ledge
  reversal. Both types use source-mask width 10px. Stomped actors retain type,
  begin shaking at nine seconds, and recover at ten. Being held at the warning
  check resets both clocks. Spin stomps destroy both types; void bodies clean up.
- SubArea.add_deferred() owns pending stomp/recovery nodes and checks a play
  revision before insertion. Restart cancels old pending actors, and area
  teardown frees unparented pending nodes. A regression reproduced the stale
  recovery-on-retry bug before the fix and now asserts correct cleanup.
- goomba_variants_test exercises type selection/undo/card defaults, legacy SWE
  IDs and retained unknown fields, real ledges, physical stomp/pickup, held
  warning reset, typed recovery, spin destruction, retry and exit. The new
  --editor-enemy capture shows the native type window and selected card.
- KoopaVariant Resources carry green/red object IDs, icons, walking/shell/
  beach/death sprites, ledge behavior, FPS and shell reentry delay. The existing
  Koopa palette entry, type window, persistent tool card, undo and SWE loading/
  saving now use these resources. Reopened Parts build the selected runtimes
  above the source course's ground, not embedded inside it.
- A normal SMW Koopa stomp creates an empty KoopaShell plus BeachKoopa of
  the same colour; spin stomps destroy the Koopa without ejection. Red Koopas
  avoid ledges through the existing SlideComponent. Koopa/beach source masks
  are 16x16; shells are 10x16. Source object FPS overrides sprite metadata.
- Shells can be kicked, stopped with a normal stomp, destroyed with spin,
  carried, thrown upward or gently dropped with Down. They ricochet, activate
  the existing question/turn blocks, defeat enemies, chain 200..8000 points,
  and consume each other in moving-shell collisions. A carried shell is a
  shield that is consumed with its victim and clears Player's held reference.
  The eighth chain hit increments Player.extra_lives, a session reward count;
  profile persistence and a life UI are still M5 work.
- ShellPhysics holds source speeds, gravity and timing. Koopa/beach and moving
  shells use .2 px/frame² (720 px/s²); idle/up-thrown shells use .15 (540).
  Falling caps at 240 px/s. Retain the source's signed-spd quirk: left launches
  do not accelerate toward their signed target. Launch speed can exceed the
  capped target when released by a running player; do not clamp it prematurely.
- Ejected beach Koopas slide at 180px/s, slow on the floor, wait 1.5s, then
  hop and walk. Their first .5s of contact immunity expires even if Mario is
  still overlapping. Crawling beach Koopas survive moving shells; walking
  ones are enemies. Normal stomps leave a colour-specific flattened sprite
  for .5s. Matching empty shells accept a physical hop back inside and restore
  a green Koopa after 60 ticks or red after 70. Empty SMW shells never wake
  on their own. Retry/exit cancels pending occupants and death/effect nodes.
- BlockComponent.activate() shares player and shell bumps. Its ending tween
  resolves the activator by instance ID, since the actor can disappear during
  that tween. Binding a typed, freed shell to the callback caused a reproduced
  error. PickupComponent now respects use_default_behavior=false so shell
  release velocities are not overwritten by the base guessed behavior.
- koopa_test verifies editor selection/history/save/reopen/runtime, physical
  ledges and stomps, ten-second empty-shell persistence, free fall, kick/release
  speeds, real block ricochets, pickups, eight-enemy scoring, shield consumption,
  shell pairs/top/spin/side contacts, beach immunity/squash/reentry, and lifecycle
  cancellation. Both --editor-koopa and --koopa captures were visually checked.
- Koopa source evidence: obj_koopa/Other_11.gml; obj_shell/Other_12.gml,
  Alarm_7.gml; obj_shell_held/Step_0.gml; obj_beachkoopa/Step_0.gml,
  Alarm_10.gml, Collision_obj_shell.gml and red overrides; obj_stomped alarms;
  obj_physicsparent/Other_14.gml and obj_holdparent/Other_14.gml;
  scr_musicalscale for chain scores. The reference checkout remains read-only.
- GoombaPart/KoopaPart now expose independent `wings` and `parachute` modifiers.
  The source allows both at once. The native EditorWindow uses Content/Attachments
  for these two toggles and Content/Options for the existing type buttons. Toggling
  an attachment keeps the window open; type selection closes it. Pointer hit
  testing converts event positions through the window's full canvas transform.
  History records each flag independently. Type changes preserve attachments;
  attachment changes do not affect the next placement's defaults, matching the
  source resource/card distinction. All prior window tests use the new paths.
- SWE uses integer `wings` and `paracaidas` fields in both legacy and modern
  wrappers. Load restores them; save writes active flags without dropping unknown
  fields. Per-Part EnemyPartDecoration displays original editor overlays under
  the existing graphics/drag transform. The runtime receives copies of flags,
  so wing loss/landing does not change the editor course or its retry state.
- EnemyFlightProfile Resources describe each family's motion and original sprite
  anchors. EnemyFlightPhysics holds common converted constants. A native
  EnemyFlightComponent drives the existing gravity and SlideComponent once
  before Enemy.move_and_slide, then handles landing/ceiling responses afterward.
  Galoomba's normal gravity is now the source 720px/s² with a 240px/s fall cap,
  rather than inheriting Mario's 1080px/s²; all earlier regressions still pass.
- Winged green Koopa repeatedly hops at 247.5px/s. Winged red Koopa stays at
  its x position, faces Mario and patrols above/below its initial y; boundary
  acceleration is 54px/s² beyond +/-32px, with 30px/s cruise speed. Floor/ceiling
  contacts reverse it at 24px/s. Galoomba/Goombud wait two seconds, then make
  three 150px/s hops and one 240px/s hop; Goombud reverses after the large hop.
  Winged Goombud does not use the unwinged ledge avoidance during this pattern.
- Parachutes cap descent at 24px/s using 360px/s² gravity, sway around their
  initial x using +/-16px acceleration boundaries and 30px/s cruise speed, and
  swing the graphics by up to 12 degrees. They reflect from real walls, including
  walls inside the sway boundary (otherwise velocity can remain stuck at zero).
  Galoomba uses the source floating art while descending. Landing removes only
  the parachute, plays the short shrinking canopy effect, restores walking art
  and resumes the retained wings. Red Koopa gets its source post-landing origin.
- Normal stomps first strip wings, retaining the typed enemy and any parachute;
  a later stomp enters its existing unwinged behavior. Spin stomps destroy the
  actor immediately. Detached wings rock/fall and clean up below the level;
  SubArea's revision-checked pending spawns cancel effects on retry/exit.
- enemy_flight_test drives both actual GUI toggles with viewport-local mouse
  input, verifies independent undo/redo, type preservation, new-placement defaults,
  legacy/modern signed SWE round-trips, runtime builds and retry restoration.
  It checks all four motion/landing/stomp patterns, real walls/floor/ceiling,
  canopy/wing cleanup and pending-effect cancellation. Headless Input.parse_input_event
  applies physical-window scaling to pointer positions; use Viewport.push_input
  with in_local_coords=true for these GUI tests, not synthetic pressed signals.
  --editor-flight and --flight screenshots were rendered and visually checked.
- Flight source evidence: obj_goomba_res and obj_koopa_res Other_10/11; their
  red/Goombud overrides; obj_parent_resource Draw_0; obj_button_wings Mouse_4;
  obj_galoomba Step_0/Alarm_0/Other_11/Draw_0; obj_galoomba2 Step_0;
  obj_koopa and obj_koopa_red Step_0/Alarm_10/Draw_0; obj_physicsparent Other_14;
  obj_wings_dead and obj_paracaidas_go. Editor-toggle removal sounds/effects
  remain audio/polish work; runtime wing-loss and parachute-landing effects exist.
- BuzzyPart replaces enemy palette slot 2's anonymous disabled placeholder.
  Its native type window maps obj_buzzybeetle_res and obj_buzzy_shell_res.
  Switching to an empty shell preserves parachute metadata and drops wings,
  matching the source swap; empty shells show only the parachute toggle.
  Unlike Goomba/Koopa, this source swap does not update the card's next-placement
  default. EditorHistory now snapshots the variant ID plus dependent modifiers
  as one action, so undo restores the removed wings too. Both SWE wrappers,
  modern object aliases and unknown fields are covered by round-trip tests.
- Buzzy derives ceiling attachment from the complete live Parts list: supported
  solid tile above, none directly below, no wings/parachute. Preview inversion
  updates on terrain changes and undo; saving writes the derived inup flag.
  Buzzy uses the source 16x16 enemy mask. Ceiling actors crawl under support,
  reverse at its edge and watch for Mario within 32px below. They drop an inverted
  shell which launches at 150px/s toward Mario when it lands. Tests allow the
  native body's 0.08px safe margin at a ceiling instead of exact float equality.
- ShellVariant now carries common art, width, occupant scene, recovery and armor
  policy. KoopaVariant and BuzzyVariant extend it. The historical KoopaShell
  runtime handles both families; each instance has its own collision shape.
  Buzzy shells use width 12, empty helmet shells width 10. Normal Buzzy stomp
  makes a single occupied shell (no beach actor); spin destroys an unwinged Buzzy.
  An occupied shell warns at 540 ticks and restores the Buzzy at 640. Moving
  shells do not wake; stopping one restarts the 600-tick recovery/540-tick warning.
  Carried shells retain their countdown and can wake in Mario's hands, unlike
  flipped Galoombas. Restoration clears the held reference without throwing.
  Empty helmet shells never recover into a beetle or accept a beach Koopa.
- Winged Buzzy is a different flight profile, not a hopping Koopa. It has a
  native one-way AnimatableBody2D platform, moves at 30px/s, sinks initially at
  72px/s under a rider, accelerates upward at 180px/s² and caps rise at 24px/s.
  Unloaded wings hold altitude. Normal/spin top contact does not stomp it;
  Mario can stand on it and native platform velocity carries him. The controller
  owns and frees the external platform, including pending spawns on retry/exit.
  During tree exit a sibling may be outside the tree but still parented; test
  get_parent(), queue_free parented platforms and free only unparented pending
  nodes. The earlier is_inside_tree/free branch caused a reproduced teardown crash.
- Reference quirks are retained: Buzzy wings bypass gravity and detach a combined
  parachute immediately, even in midair. Unwinged parachutes cap descent at 24px/s,
  retain 9 FPS and do not rotate Buzzy's body. The empty-shell editor resource
  preserves its parachute flag, but scr_edit_to_play creates obj_shell_empty
  without copying it; its runtime therefore does not deploy a parachute.
- Empty shells can be carried/kicked/thrown, worn by pressing Down while carrying
  on the floor, or worn when a falling empty shell reaches Mario from above.
  PlayerHelmet is independent of small/super power. It deflects supported enemies
  and shells from above, activates existing question blocks from the head, absorbs
  one ordinary damage hit and grants the normal two-second immunity. Losing the
  helmet keeps Mario's underlying power. Small/super offsets, spin frames, original
  sprites and equip/deflect/remove sounds are implemented. Goal walk keeps the
  overlay; the victory pose selects original SMW goal frame 1 and hides the overlay.
- Create PlayerHelmet's physics Area during Player._ready, with monitoring off.
  Equip/unequip changes monitoring deferred and skips overlap queries until it is
  on. Creating that Area from a shell/player collision callback caused a reproduced
  flushing-queries error. Sprite/effect creation and sounds are safe on that path.
- Enemy.hit_by_projectile(kind, direction) returns whether defeat was accepted.
  Buzzy bodies and shells reject fire; actual moving-shell collisions still defeat
  them. Fireball/player-power simulation is not ported by this API alone and remains
  later content work. kill() continues to be an explicit forced defeat.
- buzzy_test covers palette/type/dependent undo, card defaults, signed SWE aliases,
  topology-derived ceiling attachment, occupied recovery while idle/moving/carried,
  actual ceiling drops/landing, native riding and jumping off, parachutes, projectile
  policy and real shell hits, pending shell/platform cleanup. helmet_test physically
  equips falling/carried shells, tests small/super armor and immunity, head deflection,
  question blocks, retry and helmet-specific goal art. All twenty-two regressions pass.
  The verbose Buzzy run also exited without ObjectDB/resource leak diagnostics.
- Buzzy/helmet captures --editor-buzzy, --buzzy and --helmet-completion were rendered
  and visually checked. Capture modes share one CLI mode table; unexpected engine
  errors now fail a capture even if a PASS marker was printed. Preparation fails
  if a required sprite is absent instead of silently accepting a skipped conversion.
- Buzzy source evidence: obj_buzzybeetle_res Step_2/Draw_0/Other_10/11;
  obj_buzzybeetle Create_0/Step_0/Other_11/18; obj_buzzy_ceiling Step_0;
  obj_buzzy_shell_res, obj_shell_empty, scr_edit_to_play; obj_shell Alarm_3/4,
  obj_shell_held Other_11; obj_enemyparent_held Step_2; obj_helmet Other_16/18,
  collision handlers; obj_mario Other_10 and obj_player_goal_smw Step_2.

## Latest user fixes — mushroom growth and walking cadence

- Reproduced a real low-ceiling growth displacement: Mario at x=480 was pushed
  to x=477.1423 when the collider expanded into the ceiling. Player now queries
  native physics before growing, keeps its feet and short mask in tight spaces,
  uses original SMW duck/held-duck art and stands up when clear. One-way platform
  undersides allow upward growth. No physics speed or jump constants changed.
- AnimatedSprite.animation_changed now updates the manifest origin immediately.
  Small walk/run canvases are 16px wide but idle and big canvases are 32px;
  waiting until _process caused a transient horizontal sprite displacement.
  Transform snapshots retain the displayed texture and the new size retains
  frame progress. Extra mushrooms score/play audio without restarting Super's growth.
- The latest floating-appearance report exposed a missing Draw_0 offset:
  obj_mario and obj_player_goal_smw draw at y+1. Player now translates the
  top-origin source canvas by -31px rather than -32px, giving the original
  one-pixel floor overlap without moving its collider. Keep the source walking
  poses' natural vertical motion; do not crop/realign each opaque frame.
  player_visual_test compares small/super opaque shoe bounds against a real
  physics floor ray in both directions, and checks every animation's origin.
- PlayerAnimationRules stores 5px/frame and 18fps, derived from obj_mario/Step_2:
  min(abs(hspeed / 5), .3) at 60Hz. The source sprites use one frame per step.
  Moving and coasting use the same native helper, including the state-entry
  tick (Moving.end must not reset that tick's cadence). Before: walk 11.7fps,
  key-release coasting 135fps. After: walk 15.6fps, coasting slows with velocity,
  run caps at 18fps. Held walking uses the same source rule.
- player_visual_test physically collects mushrooms moving in both directions,
  in the air, under a solid ceiling and beneath a one-way platform; walks out
  of the tight space; verifies actual texture changes and synchronous origins.
  The Level is explicitly PAUSABLE under the ALWAYS test harness so the growth
  pause is tested with the real game's processing semantics. It passes with
  30/60/120 rendering rates. CharacterBodyExt also filters freed previous
  colliders, exposed by removing a ceiling that had contacted Mario.
- --player-motion runs this test with OpenGL, capturing slice_growth_before.png,
  slice_growth_after.png, slice_small_idle.png, slice_super_idle.png,
  slice_small_walk.png and slice_player_motion.png.
  Before/after feet remained (480,-16); screenshots were visually checked.
- PowerupAnimation owns the old sprite ID, bound tween and prior tree/music
  pause state. Finishing, replacing or leaving the sprite cancels cleanly.
  This fixes a reproduced freed-lambda error when exiting during transformation;
  player_visual_test exits a PAUSABLE level mid-growth and verifies unpause.
  The current implementation also passes the 30/120fps visual regressions.
- A repeated user report exposed two drawing bugs that position-only tests
  had missed. AnimatedSprite2D.duplicate(0) retained autoplay="idle"; adding
  the copy re-ran idle autoplay after pause(), while its outgoing walk offset
  stayed -8. The 32px idle canvas therefore shifted the small image by 8px.
  Separate bool-property tweens also made both poses visible for one rendered
  frame at each boundary. A 120-frame OpenGL recording reproduced both.
- Player now snapshots the current texture/frame, origin, flip and transform
  into a static Sprite2D. PowerupAnimation switches both visibility flags in
  one callback, using source transform alarms (6,7,7,7,7 ticks), rather than
  interpolating booleans. Cancellation hides/frees the outgoing image before
  a replacement snapshot and restores the preceding tree/music pause owner.
  Instant changes also cancel an in-progress animation.
- New regressions first failed on both original drawing faults, then passed
  after the fix. They check walk/run/spin/held poses, both directions, growth
  and shrink, per-frame exclusivity, screen anchor/camera stability, interrupted
  and instant replacement, external pause and exit cleanup at 30/60/120fps.
  --player-motion additionally records two 120-frame contact sheets and JSON
  traces, slice_player_motion_left/right, using normal camera following.
  Both were visually inspected: exactly one drawing in all 240 frames, one
  stable paused screen anchor per direction, and no leftover image after growth.
  The source one-pixel floor overlap and walking-pose bobbing are retained.
  Final import and all twenty-two scenes pass. Verbose player-visual shutdown
  contains only the existing WAV/Ogg playback references, with no leaked Sprite,
  PowerupAnimation or other Node. See player_visual_final_verbose.stdout.log.
- The user's next report correctly identified that one drawing per frame does
  not prove stable pixels. The earlier motion sheets recropped around Mario
  on each frame, hiding screen-space jitter, and did not reach full P-Meter
  running. A new fixed-screen, fixed-pose control reproduced a 4–5-screen-pixel
  backward step on every second 120fps render despite a single unchanged pose.
  Player._process was following the camera on every render while the body
  moved at 60Hz. The phase mismatch also affected ordinary walking.
- Player now updates its existing camera follower immediately after its own
  fixed physics movement. The follower/dead zone, movement constants, sprites,
  original frame geometry and one-pixel floor overlap are unchanged. This
  removes camera motion between two render frames sharing a physics tick.
  It also commits Level's existing camera bounds in that physics tick, before
  projectile culling and other physics queries. Deferring bounds to rendering
  exposed a transient negative camera x at the course edge; the fireball and
  camera-impulse regressions caught it during the first full-suite run.
- player_render_test first failed on the old code, then passed at 30/60/120/
  144/240fps for small/super, walk/full run, both directions and frozen/animated
  poses. It checks render anchors between physics steps and actual animation
  selection. Native floor seams can recover ~0.02 world pixels of safe margin;
  the steady-walk tolerance is below 0.15 screen pixels, not a source pixel.
  At full running speed all screen-anchor ranges are exactly zero.
- --player-render uses the real OpenGL renderer (120fps by default, --fps 60
  for comparison), fixed screen crops, pixel measurements and JSON traces.
  slice_player_run_60/120_fixed.png and _animated.png were inspected: the
  fixed-pose pixels and running anchors stay at the same x, and all three
  animated source poses retain the same red-pixel left edge. Matching JSON
  records 512 sample frames across the small/super/walk/run cases per rate. Do not substitute
  actor-relative crops or visible-node counts for this regression.
  Final import plus all twenty-two scenes pass, including projectile culling,
  the ten source camera-impulse phases, growth/cleanup and goal completion.

## M2 Spiny and typed shell helmets delivered

- SpinyPart enables slot 4 and maps obj_spiny_res / obj_spiny_shell_res. Its
  SMW preview uses source style frame 2. Normal/empty swaps retain parachute
  metadata and remove wings; dependent undo restores both. Like the source,
  the swap does not update the card default. Both SWE wrappers preserve object
  aliases, derived inup and unknown fields. CeilingAttachment shares the native
  Part-topology check with Buzzy; terrain rules and atlas are unchanged.
- Spiny walks at 30px/s with a 16x16 mask, 7.5fps, 720px/s² gravity and 240px/s cap.
  Normal jumps hurt; spin jumps recoil without defeat, score or wing loss.
  Ceiling crawl reverses at support edges, converts source instance origins
  correctly for Mario's proximity check, and drops an inverted occupied shell.
  A real question-block bump flips Spiny; the shared shell restores it after 640
  source ticks. Fire defeats its body; the wearable empty shell is fireproof.
  This is projectile-hit policy, not a completed player/fireball power system.
- A CRUISE EnemyFlightProfile supplies winged horizontal travel and correction
  outside start±10px (source .085/frame² and .4/frame). Its branch bypasses
  terrain/gravity. A 126-frame wait, 60-frame ball windup and 30-frame recovery
  alternate cardinal/diagonal four-needle volleys; component speeds are 42px/s.
  SpinyNeedle is an Entity, not an Enemy/solid target. It passes terrain, damages
  even spin jumping Mario, rechecks continuous overlap after immunity, blinks
  after 6s, expires at 8s and culls to the source camera margins. Pending needles
  and detached defeat wings use SubArea revision/lifetime ownership.
- Source quirk: scr_edit_to_play passes Spiny wings/inup only. Both normal and
  empty resources save/display parachute metadata but do not deploy a runtime
  parachute. Keep that behavior; do not copy Goomba's parachute flight here.
- ShellVariant now has per-instance width/height, spiked-top and helmet rules.
  Empty Spiny shells use 11x14; normal top contact hurts and spin rebounds
  without destroying/stopping the shell. The shell remembers the rebounding
  player's ID until ascent ends, preventing stale overlaps from side-kicking it.
  Existing Koopa/Buzzy carry, shell recovery and chain behavior remain tested.
- HelmetRules selects Buzzy vs Spiny art, collision, audio and goal animation.
  The precreated PlayerHelmet area resizes deferred at equip. Spiny kills enemy
  objects and stationary/moving shell objects from above (200 points each);
  Run suppresses stationary-shell handling but not moving-shell defeat. Other
  hold-parent entities (flipped Galoomba) deflect. Armor keeps Mario's underlying
  power. A short jump can activate a block with the extended head area. Goal
  pose uses original Mario frame 2 and hides the overlay; Buzzy keeps frame 1.
- spiny_test physically verifies normal/spin contacts, stationary/moving spiked
  shells, block flips/restoration, ceiling origins/drop/landing, actual flight
  through solids, both volleys, needle passage/blink/lifetime/retry/exit, falling
  and carried equip, head defeat/deflection, Run behavior, spin/continuous needle
  damage, head blocks, armor and the goal. Native palette/window/undo and signed
  save/reopen are also exercised. All twenty-two regressions pass. OpenGL captures
  --editor-spiny, --spiny and --spiny-completion were visually checked.
- Evidence: obj_spiny[_res] Step_0/Step_2/Draw_0, alarms0..3/10 and Other_15/19;
  obj_spiny_shell_res, obj_spiny_empty Other_11, obj_espina and scr_edit_to_play;
  obj_helmet_spiny collisions/Other_16 and obj_player_goal_smw Step_2. Old local
  .godot/porting-wip/spiny snapshots are superseded; do not restore them.

## M2 native Blooper delivered

- BlooperPart enables palette slot 5 and maps obj_blooper_res to a native
  Blooper scene. SMW preview frame 2 uses the source origin/height offset.
  Source inheritance has no type/attachment window. Existing raw wings and
  paracaidas fields still draw inherited editor decorations; direct_t and
  unknown nested data survive both signed SWE wrappers. New placements have
  no attachments. The runtime receives no flags, matching scr_edit_to_play.
- BlooperRules holds the source movement/art/mask data. Native phases lock a
  diagonal jet toward Mario at 90px/s for 40 source ticks, then zero horizontal
  speed and sink during a 40-tick cooldown. Sink gravity is 180px/s², capped
  at 30px/s. Afterward height eligibility controls the next jet. The initial
  zero-gravity case, equal-height delay and equal-x left direction are tested.
  Convert source origins (Blooper feet-16, Mario feet-32) before height checks.
- The source ellipse is represented by a native 32-vertex convex shape within
  its 10x18 mask, centered 9px above the feet. This avoids rectangular corner
  contacts. Source collisionKind 2 is ellipse; the public mask-kind constants
  are in [GameMaker's official runtime](https://github.com/YoYoGames/GameMaker-HTML5/blob/develop/scripts/functions/Function_Sprite.js).
  This actor passes solid terrain and uses rising/sinking SMW frames. Ordinary
  air stomps defeat it; spin stomps use native spin smoke. Both damage Mario
  underwater. Full underwater player/controller parity remains open.
- FloatingEnemyDefeat supplies the original inverted, non-spinning 3fps art.
  Its launch is -6px/s in air and -2.4px/s underwater; source rise/fall gravity
  differs in air and water, and falling caps at 60px/s. It uses the asymmetric
  source-origin offset, culls below the camera and shares SubArea's deferred
  revision ownership for retry/exit safety.
- Descending Blooper dies when a block is bumped beneath it. BlockComponent
  now retains the source bottom-edge +5px guard, so overlapping an embedded
  actor cannot bump it incorrectly. The same source collision awards 200
  points for flipping Spiny; this previously missing award is now covered.
- blooper_test exercises native palette placement/undo, absence of a popup,
  legacy decorations, signed save/reopen and retained fields; locked jet/cycle
  trajectories, height boundaries, elliptical contacts and terrain passage;
  actual air/water normal/spin contacts, moving shells, Buzzy deflection and
  Spiny helmet defeat, real head bumps, and defeat timing/cleanup. Both OpenGL
  captures (--editor-blooper and --blooper) were visually checked. Preparation
  reports 136 sprites / 502 frames / twelve audio clips. Import and all twenty-two
  regression scenes pass with no unexpected script or engine errors.
- Evidence: obj_blooper_res Step_2, obj_parent_resource/Draw_0 and its parent
  event chain; obj_blooper Create/Step_0/Step_2, Alarm_0/1, Other_10/11 and
  Collision_obj_mario; obj_enemy_dead Create/Step_0/Draw_0; spr_blooper and
  spr_blooper_res metadata; obj_enemyparent/Collision_obj_blockparent and
  scr_edit_to_play. Exact OpenWE binary collision/tick parity remains M6 work.

## M2 red/yellow Cheep Cheep and liquid foundation delivered

- CheepCheepPart enables slot 6 and maps obj_cheepcheep_res / obj_cheepcheep2_res
  to typed Resources and a native Enemy. Source 19px editor canvases use style
  frame 2 and origin (2,2). Independent wings/parachute flags have real GUI toggles.
  Source type swaps keep wings and remove parachute; dependent undo restores
  both. The card remembers the chosen type, but new placements have no flags.
  Both signed SWE wrappers retain direct_t and unknown nested fields. Editor
  modo_water derives from the actual forest/beach surface and saved depth.
- Both types pass solid terrain. Native masks use the source frame alpha,
  BitMap contours and convex decomposition, keeping transparent corners out
  of contacts. Underwater starts at four source ticks, moving left at 30px/s.
  Yellow reverses every 240 ticks; red keeps its direction. Winged water motion
  sways around start±16px using source 0.015/frame² correction. Neither type
  delegates its own swimming/jump logic to the land-enemy flight component.
- Air motion uses source 0.12/frame² gravity and repeats two -3/frame impulses
  followed by -5/frame at the room bottom or actual liquid surface. Red launches
  at 0.8/frame; yellow at 0.5, and its third jump aims toward Mario. Wings use
  1/frame launches and a 120-tick glide on the large jump's descent. The glide's
  source threshold produces 0.2/frame horizontal and -0.3/frame vertical travel.
  The free-below check uses native solid queries while ordinary travel passes
  terrain. Caps occur before built-in gravity, preserving that source order.
- Parachutes use their own 0.1/frame² gravity, 0.4/frame pre-gravity fall cap and
  horizontal sway. They detach at the source bottom/underwater boundaries and
  schedule the ten-tick restart. A normal air stomp strips one wing first;
  spin stomps destroy the body with native smoke. Full underwater contact hurts
  even spin jumpers. Source quirk: forest contact below its water surface hurts,
  while beach's modo_water alone does not forbid stomping. Castle/poison jumps
  add source auras, and castle fish emit finite timed embers.
- SwimmingEnemyDefeat uses typed SMW dead art, signed rotation and distinct
  air/water motion. Normal stomps still choose horizontal launch from Mario's
  speed, or relative bbox-lefts when stopped. dead_h is a POW-specific flag;
  do not incorrectly use its stationary death for ordinary stomps. Tests cover
  left/right physical stomps. Death, detached wings/parachutes, jump bubbles
  and embers all use SubArea's deferred revision/lifetime ownership.
- LiquidSurface is a SubArea-owned native surface outside the disposable
  foreground. SWE water_level/water_level_limit convert with the 432px offset;
  source speeds 0.2/0.5/0.8 map to 12/30/48px/s. It retains the source 12px origin
  and asymmetric return endpoint, two-second endpoint holds, editor/retry reset,
  death freeze and goal settling branch. SMW source sprites draw animated
  tiled surfaces and fill for forest/beach water, castle lava and night poison/
  mountain lava. This is a surface foundation, not complete liquid gameplay.
- cheep_cheep_test covers actual GUI/card/dependent undo, signed save/reopen,
  metadata/depth, swim/jump trajectory oracles, water turns, precise corners,
  passage through ground, water wings, parachutes, glide timing, normal/spin
  contacts, shell/helmet/head-block interactions, typed death and pending cleanup.
  liquid_surface_test physically checks all three speeds, both 120-tick holds,
  both endpoints, retry/edit reset, teardown and invalid/float metadata.
  All twenty-two regressions pass. Four OpenGL captures (--editor-cheep-cheep,
  --cheep-cheep, --cheep-water and --cheep-lava) were visually checked. Preparation
  reports 136 sprites / 502 frames / twelve audio clips. Forest/castle captures
  deliberately show their unported background; no replacement art was invented.
- Evidence: obj_cheepcheep[2]_res Create/Other_10/Other_11/Step_2;
  obj_cheepcheep[2] Create/Step_0, alarms0/1/2/10, Other_10/11/24, Destroy/Draw
  and Collision_obj_mario; obj_enemyparent/Collision_obj_mario; obj_enemy_dead
  Create/Alarm_0/Step_0; obj_lava_water Create/Alarm_0/Step_2/Draw;
  obj_load_level/Other_10/11 and scr_edit_to_play. Exact binary parity remains M6.

## M2 standalone jump/fire Piranha Plants delivered

- PiranhaPart enables pages[1].items[0], with obj_pplant_res / obj_plant_fire_res
  mapped to typed PiranhaVariant Resources. The native window and persistent
  card select jump/fire; independent wings/parachute flags survive type swaps.
  Both signed SWE wrappers retain aliases, direct_t and unknown data. Pipe
  obj_piranhaplant through obj_tuberia_res is a distinct unported actor.
- CeilingAttachment now supplies floor/ceiling/left/right topology using the
  existing Part adjacency. Floor support wins. Jump plants on ceilings or walls
  lose both attachments and disable those options. EditorHistory records these
  environment changes in the same paint/erase/move/type action, so undo restores
  lost flags. Transient held drags do not clear them before the move commits.
  Source rotations/flips affect the sprite around its origin, not the mask.
- Jump plants use native 10x16 ellipses, 180 grounded ticks between jumps,
  150px/s air or 120px/s water impulses and source gravity/caps. SMW wings flap
  without generic land-enemy flight; parachutes use source sway and detach on
  landing. Attached plants remain still and die when native support is removed.
  Fire plants use 11x24 ellipses and ordinary ground physics. Normal stomps hurt;
  spin stomps recoil without defeat, wing loss or score, including underwater.
- Fire plants track horizontal facing but lock vertical aim during the attack:
  first shot at tick 150, then every 170 ticks, with original mouth poses.
  PlantFireball has native alpha-derived collision, source 60/30px/s components
  (halved underwater), terrain/semisolid bursts, player damage and camera culling.
  Source quirk: fire plants save flags and drop wings on death, but their SMW
  Draw_0 has no wing/parachute overlay or horizontal parachute sway. Parachute
  gravity still applies. Head helmets do not intercept this projectile.
- SpriteCollision shares BitMap/convex alpha masks with Cheep Cheep and native
  ellipses with plants. EnemyDefeatStyle now supplies family-specific art,
  frame and offsets to SwimmingEnemyDefeat without a Cheep-specific dependency.
  SinkingEnemy handles the source slow lava/poison sink and spin recoil;
  EnemyEffect supplies finite splash/burst/audio. Shots, defeat effects and
  detached attachments retain SubArea's revision/lifetime ownership.
- piranha_test exercises actual window/card input, signed save/reopen, topology
  painting/erasure/dragging/type changes and dependent undo, air/water trajectories
  and attacks, contacts, support removal, projectiles, shells/helmets/head bumps,
  liquids and pending cleanup. All twenty-two regressions pass. OpenGL captures
  --editor-piranha, --piranha, --piranha-fire and --piranha-water were visually
  checked. Preparation reports 136 sprites / 502 frames / twelve audio clips.
- Evidence: obj_pplant_res, obj_plant_fire_res, scr_edit_to_play;
  obj_jumppiranha Create/Step_0/Draw_0 and alarms; obj_plant_fire Step_2/Draw_0
  and alarms; obj_plantfire collisions/Step_0; obj_enemyparent_lava;
  obj_enemyparent Other_10/11/15 and obj_panel_circle/Other_14. SMW is the
  implemented style; other-style wing hover and full binary parity remain open.

## M2 small/giant Munchers delivered

- MuncherPart enables pages[1].items[1] and maps obj_muncher_res /
  obj_muncher_b_res to typed Resources and a native Muncher Entity. Its native
  window changes size and independently toggles the source editor flags. A size
  change creates fresh source flags (both off); dependent undo restores them.
  The card remains small for subsequent placements, as in the source.
- The native Part position denotes its lower-left cell. Giant graphics and
  collision cover (0,-16,32,32); growing retains the lower-left cell and expands
  upward/right. SWE giant x is native x+16; y is unchanged. Load/save converts
  that origin exactly and retains aliases, inup, direct_t and unknown data.
  Drag validation covers all four cells. Source editor style frames/origins,
  dark-theme previews and attachment offsets are retained.
- Muncher extends Entity, not Enemy. Its native layer 1 blocks players, enemies,
  shells and plant fireballs, while layer 2 exposes head/block queries. Native
  32-vertex ellipses represent the source 14x15 / 28x32 masks. Feet derive from
  these masks, independently of their 16px / 32px art. The 6fps body animation
  shares Level.animation_time, including actors created after the level starts.
- Grounded/air horizontal drag is 360/54px/s². Falling uses source 720px/s²
  gravity and a 240px/s pre-gravity cap, or 72/60 underwater, night sky/airship
  and below the actual forest/beach surface. Muncher's override keeps lava
  immunity. Native one-way movement handles upward passage, landing and moving
  platform carrying. A supported column follows lower actors at source sprite
  spacing; removing its base drops the remaining column rather than killing it.
- Normal/spin and side contacts hurt without defeating/scoring. Falling physical
  solids crush grounded Mario even when super, and crush native enemies/powerups;
  airborne contacts can push them down. Shells ricochet; ordinary projectile
  defeat is rejected. Actual block head bumps launch it only with free headroom,
  using -180px/s in air or -108 in fully underwater themes. POW accepts a
  stationary actor and uses the original size-specific frame-4 rotating defeat.
  This is a hit capability; the POW palette/controller itself remains unported.
- Buzzy deflects falling Munchers even while Run is held. Spiny's dedicated
  Collision_obj_muncher defeats descending actors and awards 200; ascending
  ones are excluded. The helmet controller now recognizes that capability on
  non-Enemy solids. Muncher's typed margins retain Buzzy's +8 and Spiny's strict
  +5 height checks, including explicit boundary tests. A queued defeated actor
  stops physics immediately so it
  cannot crush Mario later in the same frame. Existing helmet regressions remain.
- Physical crush now includes flipped Galoomba/Goombud bodies. Their native
  kill capability retains typed frame-2 death art, clears Mario's held reference
  and prevents later recovery. Environmental enemy/held-body crush emits the
  source snd_klock without awarding Mario points; mushrooms use finite smoke.
- Source quirk: scr_edit_to_play passes neither wings nor paracaidas into
  either Muncher runtime. Keep both in editor/save, clear them on size changes,
  and do not add runtime flight/overlays. Stacked offset alarms are not drawn
  by source Draw_0. Link shield pushing belongs to the still-unported Link suit.
- Giant landing emits snd_thwomp_original once and starts CameraImpulse using
  obj_levelmanager/Alarm_11's ten offsets at two-tick intervals. Utility's
  camera_effect changes only the render transform; camera tracking getters
  retain the base position, and world collision coordinates stay fixed. The
  impulse ignores a second mid-sequence request and clears on retry, edit and exit.
- muncher_test exercises actual GUI input, both signed SWE wrappers, source
  origins/flags, size undo, four-cell drag bounds, fall/cap/drag traces, clock
  synchronization, normal/spin/side contacts, both helmets, crushing, columns,
  moving semisolids, upward passage/headroom, actual shells/fireballs/head blocks,
  forest water, lava immunity, POW defeat, giant audio/impulse and retry/exit.
  Import and all twenty-two regression scenes pass; preparation reports
  136 sprites / 502 frames / twelve audio clips.
  --editor-muncher and --muncher OpenGL captures were visually checked. Verbose
  shutdown inspection found only the existing base death/music Ogg playback
  diagnostics, with no Muncher, Part, camera or other leaked Node instances.
- Evidence: obj_muncher[_b][_res] Create, Step_0/1, Draw_0, alarms0/9 and
  Other_10/13/14/24; obj_physicssolid player/enemy/powerup collisions;
  obj_physicsparent/Collision_obj_blockparent; obj_mario Other_12/18 and Step_0;
  obj_helmet[/_spiny] collision handlers; obj_levelmanager Step_2/Alarm_11,
  init_shake and scr_edit_to_play. Other styles and full binary parity remain open.

## M2 Thwomp family — historical DeepSeek description

The following four feature sections describe that session's original state.
The current source corrections and verification are in
[REVIEW-2026-10-20.md](REVIEW-2026-10-20.md); do not implement their superseded
placement rules, projectile assumptions or long helmet immunity again.

- ThwompPart enables enemy palette pages[1].items[2] and maps obj_thwomp_res /
  obj_thwomp_b_res to typed ThwompVariant Resources. The pinned small resource
  declares no popup; the giant entry opens the source size/type window with a
  Thwomp choice and an explicitly disabled Grrrol slot. The direction button
  cycles direct_t 1/2/3 (down/left/right) and is an editor-only overlay. History
  records size, direction and the independent wings/parachute flags as one
  dependent action, and the card keeps the chosen type for later placements.
- Small art is 24x32 with origin (12,16); giant is 48x64 with origin (24,0).
  scr_edit_to_play adds (16,16) for small and no offset for giant; loading
  converts that anchor to the native feet position and saving converts it back.
  Legacy and modern signed wrappers retain object aliases, direct_t, wings/
  paracaidas, off-grid coordinates and unknown nested data. New placements are
  not snapped, and the source direction stays per instance.
- Runtime phases are WAITING/ATTACKING/IMPACT/RETURNING with the source 60-tick
  impact wait (1s), 1px/tick return (60px/s) and per-direction triggers: down
  uses the 32px window and the y+17 check, left/right use the 4px inset, 112px
  reach and 40/7px height band. Gravity is 720px/s^2 with the 240px/s
  pre-gravity cap, 90/30 in water and the night sky/airship/forest cases, and
  360/24 under a parachute. Side attacks accelerate at 180px/s^2 to 180px/s
  (90 underwater). The giant's left attack breaks flip blocks and passes
  question blocks; its down/right attacks activate blocks. Impacts emit
  snd_thwomp_original and the ten-phase utility camera impulse.
- hardness 99 with stomp 2 means an ordinary top contact hurts Mario while a
  spin jump recoils; fire/shell projectiles are rejected, POW only defeats a
  resting actor and bumped_from_below kills it. Falling impacts crush native
  enemies and flipped Galoombas. The source top-edge void boundary is retained.
- The worn helmet is a physical collider in obj_helmet: Buzzy bounces a falling
  Thwomp at 2px/frame (or its own upward speed minus 2, and -0.5 when terrain
  blocks the bounce) while Spiny defeats it for 200 points. Godot Areas report
  the overlap one physics step after the crossing, so PlayerHelmet.deflect also
  accepts the actor's swept bottom edge and Thwomp supplies its pre-move
  bounding box. A bounced actor without that collider stays inside Mario's body
  while retreating; PlayerHelmet.shields keeps the helmet effective for that
  contact until the actor falls again. Both use the typed rule sounds.
- thwomp_test drives the actual palette/card/arrow clicks, the giant size
  window, dependent undo and both signed SWE wrappers; all six size/direction
  cycles, strict trigger edges, gravity/parachute/water caps, normal vs spin
  contacts, both helmets, real flip/question blocks, crushing, POW/void and
  retry cleanup. All twenty-three regressions pass. OpenGL captures
  --editor-thwomp and --thwomp were visually checked; the runtime capture shows
  the falling angry frame, both directions and both sizes.
- Verbose shutdown leaves only the known Ogg music playback references
  (play.ogg plus its packet/playback streams), with no Thwomp, ThwompPart, dead
  actor, camera or test-scene Node in the leak list.
- Evidence: obj_thwomp[_b][_res] Create/Step_0/Step_2/Alarms 0,1,10/
  Other_10,13,14/Draw_0; obj_enemyparent/Collision_obj_mario (stomp 2,
  hardness 99 and the helmet exemption); obj_helmet/Collision_obj_thwomp;
  obj_helmet_spiny/Collision_obj_thwomp; obj_thwomp_res/Mouse_4;
  obj_thwomp_b_res Other_10/11/13; obj_panel_circle/Other_14; scr_edit_to_play;
  obj_mario Other_10/11/12. Other styles and exact binary parity remain M6.

## M2 Monty Mole — historical DeepSeek description

- MontyPart enables enemy palette pages[1].items[3] and maps obj_monty_res to a
  typed MontyVariant. The source resource declares no type popup; the native
  window therefore shows only the two independent wings/parachute toggles
  (Part._create_window now opens for modifier-only parts). History, signed SWE
  and undo work like the other enemy Parts.
- Monty placement is restricted to ground/block cells (it is a burrower): an
  empty cell is rejected, saved Monty cells overlap their ground tile, and the
  runtime actor is built on the cell's top surface so it pops out instead of
  spawning buried. Parts are non-monitoring Areas, so the rule looks up
  GroundPart's ground_parts group instead of a physics query.
- The source editor object draws 27x24 style art from origin (5,6) and keeps its
  authored cell: loading restores the exact off-grid position, build adds the
  source +8 x offset for the runtime actor, and saving writes the Part position
  back. Both signed wrappers retain wings/paracaidas and unknown nested fields.
- obj_monty_chase charges after its two-tick alarm: horizontal acceleration is
  116.64px/s^2 toward Mario, capped at 90px/s (36 underwater and in the night
  sky/airship cases). Before the alarm it stands still. A wall reverses the walk
  and, while grounded, hops at 90px/s (obj_physicsparent/Other_13 reverses
  hspeed and Monty normalizes it). Direction always faces Mario.
- Wings use the shared BOUNCE profile with a 180px/s grounded hop instead of the
  Koopa value; the profile carries manual_walk so the chase acceleration is not
  overwritten by the shared slide. Parachutes use the shared 360/24 gravity/cap,
  the +/-16px 30px/s sway and the shrinking canopy on landing. Defeat uses
  spr_monty_deads frame 2; a normal or spin stomp detaches wings first
  (obj_monty_chase/Other_11), then the next stomp defeats it and awards the
  source 200 points (obj_score/Other_10).
- monty_test loads both signed wrappers with an off-grid row and an unknown
  field, drives the actual palette slot and window toggle, verifies dependent
  undo, saving/reopening, the two-tick charge and 90/36 caps, the wall reverse
  and hop, wing stripping and 200-point defeat, the grounded wing hop, the
  parachute cap/sway/landing and cleanup. All twenty-four regressions pass.
  OpenGL captures --editor-monty (native window) and --monty (chasing, winged
  hopping and parachuting) were visually checked.
- Evidence: obj_monty_res Step_2/.yy; obj_monty_chase Create/Step_0/Other_10/11/
  Alarm_10/Draw_0; obj_physicsparent Other_13/14; scr_edit_to_play 1329-1340;
  scr_play_to_edit 203-210; scr_musicalscale; obj_score/Other_10. Other styles
  and exact binary parity remain M6.

## M2 Rocky Wrench — historical DeepSeek description

- RockyPart enables enemy palette pages[1].items[4] and maps obj_rocky_res to a
  typed RockyVariant. The pinned resource declares only Step_2, so it has no
  type or attachment window and the native Part opens none. The authored
  off-grid cell is kept; build adds the source +8 x offset for obj_rocky.
  Legacy and modern signed wrappers retain aliases, unknown fields and the
  exact position.
- The runtime cycle follows ready/ready2: spawn pops up at 90px/s (48
  underwater) under 720/240 gravity, settles at its anchor and waits 60 ticks.
  With 16px of headroom it rises 2px at 30px/s, waits 90 ticks, rises to the
  source 9px throw height, winds up 2 ticks, holds spr_rocky_throw for 30
  ticks, spawns one obj_wrench, holds spr_rocky_idle for 30 ticks, sinks at
  30px/s with spr_rocky_idle2 and repeats after another 60 ticks. Without
  headroom it retries every 10 ticks. Losing the solid under a settled actor
  defeats it (ready == 2 check), and stomps destroy it for 200 points with
  spr_rocky_deads frame 2.
- Wrench is a native Entity: constant 60px/s (30 underwater) flight, one of the
  source 0/5/13/21/29px arcs at 180px/s^2 capped to 30px/s, SMW frame 2 art, a
  10x10 player area, 6s blinking every 7 ticks, 8s expiry, source camera
  culling (128px with a 2px scale tolerance) and no terrain collision.
- rocky_test verifies both signed wrappers with an off-grid row and an unknown
  field, the palette slot, the absent popup, saving/reopening, the settle/rise/
  high-wait/throw/sink cycle, wrench direction and flight, arc bounds, player
  damage, 8s expiry, camera culling, stomp score/defeat and support removal.
  All twenty-five regressions pass. OpenGL captures --editor-rocky and --rocky
  were visually checked.
- Evidence: obj_rocky_res Step_2/.yy; obj_rocky Create/Step_0/Alarms 0..4/
  Other_7,10,11,12,14,16,17/Draw_0; obj_wrench Create/Step_0/
  Collision_obj_mario/Alarms 0,1/Draw_0; scr_edit_to_play; obj_deactenemyparent.
  Other styles and exact binary parity remain M6.

## M2 Hammer Bro family — historical DeepSeek description

- HammerBroPart enables enemy palette pages[1].items[5] and maps
  obj_hammerbro_res/obj_firebro_res/obj_icebro_res/obj_boomerangbro_res and
  obj_sledgebro_res to five typed HammerBroVariant Resources. The native window
  exposes five type buttons and the wings toggle; the source's separate sledge
  conversion is folded into the fifth type. Each type keeps its own art and
  projectile; history and signed SWE round-trip the exact object ID, wings and
  off-grid cell.
- The shared runtime follows obj_hammerbro: patrol within +/-16px of the spawn
  x at 24px/s, face Mario and run burst throwing (17-tick entry delay, 20/30/
  30/90-tick throw delays, 80/120/120/120 burst cooldowns). Hammer Bro jumps
  every 6s at the source -371.4/-150px/s heights; Sledge Bro uses the larger
  18x24 mask, 40x40 throw art, 8s fixed -360px/s jumps and an 80-tick throw
  cadence. Sledge landings play the source thwomp sound, camera shake and
  smoke; Mario's 80-tick source stun state is not ported yet (no native stun
  state). A normal stomp strips wings first, the next defeats for 200 points;
  spin/helmet/shell interactions use the existing Enemy APIs.
- BroProjectile is one native Entity with four source motions: hammer (90px/s,
  -180px/s launch, 450px/s^2 gravity, rotating), fireball and snowball
  (150/144px/s with the source floor bounce at -132px/s), and boomerang
  (120px/s outbound, reverses after the source 0.55s/15-tick phases and flies
  back to its thrower). All damage on player overlap, blink at 6s, expire at
  8s and cull at 32px beyond the camera.
- hammer_bro_test loads both signed wrappers with off-grid rows, verifies the
  palette slot, the five-type window, dependent type/wings state and saving/
  reopening, every type's patrol window, projectile kind/speed/direction, the
  boomerang return, source jump heights, the Sledge mask/-360px/s jump, wing
  stripping and the 200-point defeat. All twenty-six regressions pass. OpenGL
  captures --editor-hammerbro and --hammerbro were visually checked.
- Evidence: obj_hammerbro_res/firebro_res/icebro_res/boomerangbro_res/
  sledgebro_res Create/Other_10/13; obj_ventana number 12 (Other_22);
  obj_hammerbro Create/Step_0/Alarms 1..7,10/Other_7,10,11,13,14,17,25;
  obj_firebro/icebro/boomerangbro Alarm_2/3 overrides; obj_sledgebro Create/
  Step_0/Alarms 1..6,10/Other_7,10,11,13; obj_brohammer Create/Step_0/
  Collision_obj_mario; obj_fireball_bro and obj_snowball_bro Create/Step_0;
  obj_boomerang Create/Step_0/Alarms 0..4; scr_edit_to_play. Other styles and
  exact binary parity remain M6.

## M2 free Chain Chomp delivered

- Native page2 slot6 now selects ChompPart. Its size/wings/parachute window
  retains the source editor decorations. Size replacement moves y-/+16 and
  resets both flags; one undo action restores type, position and flags.
  Giant selection/dragging covers four cells. New placements remain small.
- Both obj_chomp_res and obj_chomp_b_res retain fractional source coordinates,
  unknown fields, flags and legacy/modern aliases through signed SWE saving.
  Build adds source centers +8/+16, then converts to native feet. Neither
  editor flag reaches the runtime, exactly as scr_edit_to_play.
- ChompVariant stores the source dimensions, hop/speed/gravity data and art.
  ChainChomp uses an elliptical head mask, two-tick startup, overspeed decay,
  free bouncing/reversal and four noncolliding links from pre-motion history.
  Small/giant spacing is7/14, including the source duplicate history slots0/1.
  The head rounds x only; links retain their historical world positions.
- Normal Mario contact hurts; spin recoils. Fire is rejected. Shell, Spiny
  helmet, block and eligible ground POW hits spawn the current head and four
  chain corpses at their own origins. The head gets a random signed impulse;
  links always move left. POW's dead_h does not change this family policy.
- Full-water versus forest/beach startup/caps, inclusive liquid sampling,
  inherited gravity overwritten to .125/frame, size-specific water hops and
  head-only molten/poison sinks have focused regressions. Normal corpse water
  sampling retains Create's initial beach mask before using each selected art.
- WorldDeath cancels startup/history/art/automatic motion while preserving
  the explicit supported y-- without stale-floor drift. ActorActivity retains
  clocks/history offscreen. Pre-motion room culling and revision-owned compound
  effects prevent retry leftovers. chomp_test and two OpenGL capture modes
  exercise these editor/runtime paths.
- Correction to the old next-task text: this pinned source contains only
  obj_chain_chomp_free and its giant child. There is no Chomp stake, tether,
  escape, held variant or Bowser Jr variant to implement from that description.

## M2 Grrrol and rotation rendering delivered

- Giant Thwomp's enabled Grrrol choice builds legacy obj_grrrol_res, shifts
  editor y by -16 and resets direction/flags. This legacy form has no popup.
  Enemy page5 slot3 independently selects GrrrolPart and obj_grrrol_new_res;
  its size window selects obj_grrrol_b_res. New-size changes retain position
  but reset direct_t=2 and both flags. Native undo restores all dependent fields.
  New and legacy cards stay separate. Giant placement validates all sixteen cells.
- Source Draw overrides omit editor wings/parachute decorations, and runtime
  conversion copies only direction. Flags still survive signed legacy/modern
  SWE with fractional positions and unknown data. Held previews hide the arrow.
- GrrrolVariant extends the shared editor-family data with the three origins,
  fixed ellipse masks and rolling rules. Native feet differ from source centers;
  the new small editor center(+16,+16) differs from its runtime(+20,+18).
  Giant sprite origin is the serialized (32,32), not mathematical (32.5,32.5).
- Two-tick startup, initial landing bounce, wall hop, asymmetric night chase,
  swimming/air drag and constant 3.5-degree source steps keep event ordering.
  All three source objects turn against legacy Grrrol only. Any liquid sets
  swimming; castle/forest-night can latch lava mode without replacing the body.
  Falling liquids explicitly reposition it; only legacy survives deep molten cull.
- Normal Mario is hurt, spin recoils, Buzzy helmet deflects and Spiny defeats.
  Shells are destroyed with no combo reward; fire/global POW/crush are rejected.
  Rising blocks can defeat hardness99. Source corpses reset facing/angle and
  retain the family frame/origin. BlockBreakRequest owns the next-tick block
  alarm, so a defeated roller cannot cancel it; area teardown still cancels it.
  Thwomp reuses the same block-break operation and retains its regression coverage.
- WorldDeath stops automatic motion while retaining pending startup and explicit
  night drawing events. ActorActivity preserves clocks, visibility and colliders.
  grrrol_test covers all three IDs, actual editor clicks, Mario/helmet/shell/block
  contacts, liquid boundaries and teardown. Captures: --grrrol, --editor-grrrol.
- Sprite conversion now uses saved sequence origins before preset fallbacks.
  Besides giant Grrrol, this fixes odd-width spr_spinthump and three splash
  origins by half a pixel. Mario metadata is unchanged. Five Python metadata
  regressions run before the native scenes.
- pixel_rotation.gdshader blends neighboring texels only within their current
  screen-pixel footprint, in premultiplied alpha space. It samples no history
  or screen texture and does not move vertices, pivots, masks or clocks.
  Cardinal directions bypass filtering. Apply only to full converted PNGs,
  not native terrain atlases or Mario. The baked pixel-art silhouette and
  discrete source animation/rotation steps remain visible by design.
- --rotation-render is a separate real-OpenGL probe, not a headless shader
  test. It checks cardinal equality at scales1/2.25/4, oblique edge coverage,
  no dark alpha fringe, tint, unchanged actual Mario/ground controls and three
  Grrrol forms at eight angles. Its contact sheet pairs old/new rows for each
  form; rotation_render.json records the origins and readback results.

## Basic flow and enemy surface alignment

The user selected this review now, then reported floating enemy art and asked
for the same one-source-pixel terrain overlap as Mario. Existing movement,
growth/low ceilings, terrain load/paint/erase/gap-fill and SMW completion have
native regressions and real-render captures; no new gameplay systems are added.

enemy_grounding_test reproduced missing/incorrect overlap in38 of41 existing
grounded/inverted/ceiling cases. Small Muncher and both modern Grrrol sizes were
already correct. SpriteLibrary.contact_draw_y now caches a stable origin from
the union of a reference rest animation's actual alpha pixels. Its one-pixel
offset changes drawing only: body coordinates, masks, gravity, AI, collision
queries and SWE positions remain unchanged. It never re-snaps each animation
frame, so authored foot/jaw motion remains intact. Inverted shells account for
transparent margins; ceiling Buzzy/Spiny overlap upward. Burrowing Rocky and
swimming/flying actors are not force-positioned against imaginary ground.

The41-case probe settles real bodies against real solids, then measures visible
frame pixels against physics rays. It also checks both ceiling crawlers; its
OpenGL capture uses native terrain art on the physical test ceiling. Run
capture_slice.py --enemy-grounding; the ordered case/overlap data is in
.godot/porting-tests/enemy_grounding.json. Existing source-position/cadence and
physics checks remain; only old zero-overlap drawing expectations are updated
to the user's requested one-pixel policy.

This bounded review/fix round is complete:40 native scenes and41 grounding
cases pass, as do the real-GL contact/rotation/Mario checks. Final shell/old-corpse
material integration has focused regressions and an expanded real-GL probe.
The user subsequently selected editor static-preview synchronization **now**,
then requested SMM2-style lower-right pixel shadows. See the follow-up below.

## Authorized editor contact and pixel-shadow follow-up

EnemyPartPreview aligns each displayed static frame's alpha edge to its native
placement footprint with one source pixel of overlap. It handles ceiling and
side-attached plants as well as both ceiling crawlers. Every refresh restores
the authored base first; attachments follow the same visual correction. Native
Part coordinates, collision footprints, source origins, direction buttons and
saved data do not move. Static fish/Blooper thumbnails are included; swimming
and burrowing runtime behaviour is unchanged. Giant Thwomp was already correct.
Modern small Grrrol's editor art previously overlapped by4; giant Grrrol and
both Chomp sizes exposed transparent-margin gaps. Their distinct draw shifts
now target the same contact policy rather than adding1 indiscriminately.

editor_grounding_test covers36 existing variants/attachments with alpha-pixel
scans, repeated load/refresh, hold/drop, modifier undo/redo and SWE snapshots.
Run capture_slice.py --editor-grounding for the native editor contact sheet;
editor_grounding.json records its ordered cases. It is separate from the41
real-physics runtime contact cases, which retain their existing anchors.
Type/size and attachment changes are also exercised through native undo/redo.
That expanded check caught Muncher icon generation resizing a borrowed Image
in the dummy renderer. Icons now duplicate it before resizing, so their24/48px
thumbnails cannot change a16/32px preview's alpha data.

The user clarified that shadows mean lower-right pixel silhouettes on Mario,
enemies and scene objects. PixelShadows uses a native CanvasGroup behind the
foreground, offset(2,2) world pixels with33% black opacity applied once to the
combined silhouette. It mirrors draw commands only, never gameplay actors or
animation clocks. Parts/runtime art, native atlases, current animation frames,
flips, source alpha and opt-in rotation sampling are retained. Starting-ground
geometry reuses GroundDrawer; UI, backgrounds, direction controls and grabbers
are excluded. These aesthetic settings implement the requested style; they
are not a pixel comparison with an executing SMM2 binary.

RenderingServer.frame_pre_draw submits Texture2D draw commands immediately.
A queued Sprite2D redraw at that point would lag one frame and was rejected
by the real-render probe. No previous frame or screen image is used as the
silhouette source; CanvasGroup's private transparent buffer only combines
the current copied art. Removal/hiding/edit-play transitions clear copies.
Run `capture_slice.py --pixel-shadows --fps 120` for alpha/union,
frame/flip/rotation, atlas/sheet, fractional zoom and native editor/play checks.
Output is slice_pixel_shadows.png plus
separate editor/play PNGs and pixel_shadows.json. Headless cannot test shaders.

Verification: five metadata regressions, import and41 native scenes passed.
After the final icon-copy fix, expanded editor_grounding_test and muncher_test
passed again. Actual GL --editor-grounding, --pixel-shadows at60/120fps,
--player-render at120fps, --player-motion, --rotation-render, --editor and
--completion passed and their images were inspected. The final verbose120fps
shadow run retains only six WAV/Ogg stream/playback references at shutdown;
there are no leaked Nodes or unexpected script/render errors.

## Latest controls and Bro palette correction

The user prioritized these six existing bugs before new SMM1 content, and
confirmed that walking reversals should only flip the walking art; the skid
pose belongs to full running. PlayerMovingState retains the existing motion
constants and full-run meter condition for the skid pose. Dust separately
starts on an opposing input at a brisk walk (60px/s), every eight physics
ticks, without a SceneTreeTimer chain. It is emitted on the trailing shoe
side, with a world anchor one pixel below Mario's feet. The user then supplied
a5.1-second,30fps SMM2 recording. Its frames49–58 show a rapidly expanding,
filled white cloud, then a separating small puff and contraction, rather than
a hollow pixel atlas with a long fade. SkidSmoke now draws filled rounded
lobes through a per-instance native canvas shader, reaching its peak in about
45ms and disappearing after300ms. Interior white stays opaque; only the
outline is antialiased at screen resolution. The effect casts no world pixel
shadow. Its age/material freeze during the shared death policy.

The user's next correction distinguishes running dust: it must be denser and
stay close to the shoes. Running brakes now emit every five physics ticks,
2px behind travel at feet+1px, with180ms puff lifetimes. A fresh puff follows
the feet for67ms, then releases and contracts in place. The weak owner link
does not retain Mario; ground/state exits stop following. Actual speed above
the walking limit selects this mode, latched until the opposing brake ends,
so it does not become sparse halfway through deceleration. Walking's eight-tick,
300ms world-anchored puff and the existing skid pose/audio rules are preserved.
The initial three-tick running attempt was too dense according to the user;
the current five-tick cadence reduces a full-speed reversal from8 to5 puffs.

The looped SMW skid clip has its own AudioStreamPlayer, rather than occupying
Mario's general sound player. Leaving the skid condition or movement state
stops it; power snapshots stop it before pausing. Tests exercise matching
momentum, release, jump, crouch, standstill, power changes, freezing, death,
retry, completion and editor return. No delayed callback can restart it.

Down now crouches small and super Mario, including held-item poses. Small uses
the source12x13 duck mask and super uses12x15, retaining feet/shoe overlap.
Ground crouching slows existing momentum without accelerating; crouch jumps
retain their pose while rising. Release restores standing only with enough
solid clearance, including low ceilings. Spin input and buffered spin input
cannot bypass crouching. Forced low-ceiling growth remains a separate state
that can walk out, preserving the earlier growth fix. Buzzy/Spiny helmet
positions follow the small/super and held/unheld duck heads.

Bro editor-resource frames were correct but too small in the UI: raw32px
canvases included large margins. Cached native60px palette canvases now center
48px-high art with its original aspect ratio and nearest sampling. The ring,
center, top card and type window share the normalized icon. Native preview,
collision and runtime textures are untouched; independent image regions keep
the original sprite images unchanged. Lazy lookup guards autoload startup.

player_controls_test checks these actual inputs, geometry, native audio
playback state/lifecycle and palette selection. Its real-GL capture mode
is `capture_slice.py --player-controls --fps 120` (also checked at60fps),
writing slice_player_controls.png, slice_player_controls_palette.png and
player_controls.json. The ordered trace distinguishes36/78/180px/s reversals
in both sizes and directions and samples the puff growth/decay. Actual GL
readbacks test filled white interiors and shrinking opaque coverage at eight
ages, saving player_controls_dust_profile.png. Continuous real input captures
of a brisk-walk reversal go to player_controls_reel_60/120; these are actual
rendered frames, rather than a synthetic sprite animation. The user reference
frames/contact sheets remain under the ignored smm2-dust-reference folder.
Running reversals now also go to player_controls_run_reel_60/120, with rendered
foot-follow error and released-cloud stationarity checks. The headless trace
checks both sizes/directions, denser running emission, slow final braking,
Run-key-only walking and cloud cleanup. player_controls_run_walk_braking.gif
compares actual walk/run input captures side by side.

Verification: five metadata tests, import and all42 native scenes passed for
the six-fix round. After the user-video particle replacement, focused controls,
player physics and world-death scenes passed again. Actual GL controls at60
and120fps checks filled-puff pixels and captures continuous input reversals.
Earlier in the same round, actual GL player motion,120fps camera/animation and
pixel-shadow checks also passed. The final verbose controls log contains
only WAV/Ogg stream/playback references at shutdown, without leaked Nodes.
player_controls_braking.gif is a preview encoded from the actual120fps reversal
frames, sampled at30fps with a brief pause between loops.
After the initial running-density refinement, focused controls/physics/death plus the
required slice_001 and sprite-library scenes passed. Actual GL at60/120fps
checks both walk/run reels:1/8 puffs per reversal, zero fresh-cloud anchor error,
and stationary released clouds. Both sizes/directions retain dense emissions
through the final slow braking steps. The regenerated audit is248 scripts,
129 scenes and31,771 GDScript lines; the reference checkout remains clean.

## Single-frame spin-contact flash and pulsing defeat stars

The user next requested less running dust, a growing/shrinking flash for spin
recoil from Spiny-like enemies, and the same size progression on spin-defeat
stars. They explicitly selected keeping only one flash frame. SpinThump now
draws the existing full-size white frame only, centered on the impact, with a
20%-to-full attack in50ms and contraction to zero within its previous190ms
lifetime. No new image assets or star particles are added.

SpinSmoke retains the existing four diagonal star paths, central smoke and
sound. Stars grow to full size in55ms and shrink through the original267ms
travel. Each star scales about its own moving center, so size does not alter
its trajectory. The size getter uses current tween progress; completion waits
for the central animation, star travel and audio. Contact flashes now use the
area's deferred/revision-owned foreground path rather than becoming unmanaged
siblings of Foreground. Both effects are discarded on editor return.

spin_effects_test exercises actual falling-spin collisions with Spiny, an empty
Spiny shell, Galoomba and Koopa, checking their recoil/defeat outcomes, pulse
phases, single-contact emission, audio cleanup and invalidated deferred spawns.
Its --spin-effects GL mode also reads actual flash/star pixel coverage at eight
ages, writes slice_spin_effects.png and spin_effects.json, and records continuous
spiny/galoomba contacts under spin_effects_<kind>_60/120.

Verification: import, five Python metadata checks and all43 native scenes pass.
Final --spin-effects actual GL captures at60/120fps pass with one effect per
contact and unchanged recoil/defeat results. At2x zoom the eight-age opaque
coverage is21/198/536/362/33/0/0/0 for the single-frame flash, and
5/72/176/136/64/22/0/0 for the four stars, demonstrating expansion then
contraction in rendered pixels. Current regenerated audit:250 scripts,
130 scenes,31,989 GDScript lines. The pinned reference checkout stays clean.
Final --player-controls GL checks also pass at60/120fps after reducing running
dust: five running puffs versus one walking puff per reversal, with zero fresh
foot-anchor error. mario_skid_spin_effects.gif previews the actual120fps run,
Spiny recoil and Galoomba defeat reels, sampled at30fps; its contact sheet was
visually inspected. Artifacts remain under ignored .godot/porting-tests/.

## Latest user corrections: stationary dust, growth compression and start joins

These instructions supersede earlier foot-follow and growth-animation notes.
The user asked to try running dust without following Mario. Both walk/run
puffs now remain at their emission world point throughout their lifetimes;
running retains five-tick emission, its shorter180ms life and braking latch.
The old weak foot target, follow duration and process-priority adjustment are
removed. The real-GL controls probe checks every cloud's stationary anchor.

The new4s/30fps recording20261020-1528 was read frame by frame. The user's
initial small/big-alternation clarification was retracted on2026-10-21. The
current rule is immediate big art, then only vertical compression of that same
original texture. PowerupAnimation uses standing heights24/20/26/20/28 at
6/5/5/6/6 ticks, including a full-height final GrowthPose before resuming the
ordinary big animation. No small art appears during growth and no pixels are
edited. Big duck/held-duck uses the same scale ratios without enlarging its
original height. The texture-bottom pivot retains feet+1px. The timings/heights
are local visual choices, not extracted Nintendo data. Damage flashing keeps
its separate behavior. Pause, cancellation, one-visible-body and stable
screen-anchor checks are preserved.

StartingGround's cells and authored GroundParts now share an occupancy map and
the original GodotWE atlas decision tree. All53 choices and adjacency branches
were mechanically checked against HEAD; no parallel connection algorithm was
added. The start caches native region choices, shared by editor drawing, pixel
shadows and runtime tile construction. Painting, erasing, dragging, height
changes and undo/redo refresh both sides. Virtual start cells are not saved as
Parts. Native plain dirt(16,16) has no SWE frame, so its saved index uses the
equivalent(32,16) dirt variant while the displayed native atlas remains intact.
The native editor regression deterministically covers that variant and also
found/fixed new-course second-save rejection: a successful full snapshot now
marks its generated SWE source complete. Incomplete/metadata-only guards remain.

player_visual_test checks the alternating small/compressed-big stage order,
original texture paths, growth/shrink interruption and fixed feet/camera.
`capture_slice.py --player-growth --fps 60|120` is a focused real-render path,
writing120 native frames per direction under player_growth_<direction>_<fps>.
It avoids the full --player-motion matrix's30s capture limit. editor_flow_test
covers native paint, erase, height changes, undo/redo, save/reopen and play joins;
`--starting-ground` writes its before/edit/play comparison. Reference extracts,
GIFs and generated comparisons stay in ignored .godot/porting-tests/.

Final verification: five metadata checks, import, and a final all43-scene run
pass after the deterministic SWE dirt fallback fix. Growth renders pass at60
and120fps in both directions, with120 real input frames per direction, exactly
one visible body and a stable paused screen anchor. Traces retain the same
original big texture path/source height while only drawn height changes. The
latest2026-10-21 captures also verify only_big_texture=true; the former small
snapshot phases have been removed. Stationary dust
passes actual60fps controls and the focused120fps --braking-dust probe: one
walking cloud and five running clouds remain at their emission positions.
Native start-join captures and120fps pixel-shadow readbacks also pass.

The full120fps --player-controls matrix exceeded its30s capture bound; use
--braking-dust to render the relevant pixel profile and continuous walk/run
reels without the unrelated crouch/palette matrix. The full headless controls
test and60fps complete GL matrix pass. mario_growth_stationary_dust.gif combines
actual120fps frames for the latest two effects, and starting_ground_connection.png
shows the native before/edit/play seam. Both were inspected. Current audit:
250 scripts /130 scenes /32,137 lines; git diff --check passes and the pinned
reference checkout remains clean. No new content or assets were added.

## Next work stays within the latest user scope

The earlier now / not now / later selection rule has been superseded by the
explicit request to prioritize **SMM1 course-making content**, then by this
six-bug priority. Do not start new content during the controls correction, or
treat the entire OpenWE roadmap as approved. Keep already requested visual
improvements, including pixel shadows. Additions absent from SMM1, such as
Spike, Grrrol, extra Bro types, parachutes and night variants, wait.
Pipe plants and other SMM1 systems remain on that content backlog; none were
implemented in this controls round. Read the reviewed native actor, held,
death and collision contracts before extending them.

The previous palette page obj_panel_circle/Other_13 slot3 is obj_ground with
disabled=1 and must stay disabled; do not advertise it as Spiketop. Keep all
forty-three regressions and the separate real-GL rotation/shadow probes green; preserve Mario's camera/physics clock,
atomic growth snapshots, cadence and one-pixel floor overlap. Real OpenWE
execution remains a separate interoperability check when its runtime is
available. Metadata and area-specific edit history remain incomplete.

## Remaining limits and traps

- M1 is a local playable slice, not full OpenWE parity. Goal-height bonuses,
  castle endings and other powers are not ported. Other styles/themes keep
  metadata but still use fallback graphics. Preserving unknown SWE data does
  not mean its unported objects are simulated in GodotWE.
- Core Koopa behavior covers the SMW overworld represented subset, including
  wings/parachutes. SMW Buzzy/empty shells and their helmet are now implemented;
  Spiny's SMW overworld walking/ceiling/wings, shells and helmet are ported.
  Blooper's SMW jets/sinking and air/water enemy interactions are ported;
  red/yellow Cheep Cheeps and their surface-dependent behavior are now ported.
  Standalone SMW jump/fire Piranha Plants are ported; pipe variants remain open.
  Both Muncher sizes, columns and their physical-solid interactions are ported.
  The Thwomp family's SMW small/giant sizes, three directions, phases, blocks
  and helmet contacts are ported. Legacy/new-small/new-giant Grrrol are ported;
  other styles and unported block/one-way/note/held-POW systems remain open.
  Monty Mole's chase, wall hop and wings/parachute are ported; its other styles
  and the remaining page-2 palette entries are not.
  Rocky Wrench's emerge/throw/sink cycle and obj_wrench projectile are ported;
  other styles and the remaining page-2 palette entries are not.
  Hammer/Fire/Ice/Boomerang/Sledge Bro patrol, jumps, burst throws and their
  projectiles cover the reviewed ground cases, including Sledge stun and ice
  freezing; remaining source edge cases are listed in the review. Other styles
  remain open.
  Both free SMW Chain Chomp sizes and their editor/history/SWE paths are ported;
  source-derived collision/tick checks do not establish exact binary parity.
  Liquid surface movement/graphics is implemented; player swimming, liquid
  damage, water-height editing, special mounts and full theme backgrounds
  remain open. Other water enemies are not ported.
  Other stacked/giant enemies, water/night variants (including Spiny's underwater ball),
  key contents and other helmets,
  other styles and the full profile/life system are not claimed.
  Source-derived constants and local integration tests are not a recording
  from a running OpenWE binary; exact collision/tick parity is still M6 work.
- The physics trace is a regression oracle checked against reference constants,
  not a recording from a running OpenWE binary. See SLICE-001.md for tolerances.
- The source physics is obj_mario/Other_12.gml; scr_mario* mostly select sprites.
  GML px/frame speeds multiply by 60, accelerations by 3600. GravityComponent
  and the stomped-enemy scene now use px/s²; do not reintroduce frame units.
- SWE HMAC hashes the base64 text using key 2559F35097-2021, not the raw JSON.
- Ground frame table values are pixel atlas coordinates, not tile coordinates.
  Reuse GroundPart._connect() and the native atlas. Do not freeze imported
  sprites or replace the atlas with individual manifest frames: that bypasses
  terrain connections. atlas() synchronizes swe_frame/swe_atlas for saving.
- Runtime-load level/editor scenes where needed; preloading the level template
  through save/editor dependencies creates a circular PackedScene load.
- Goomba-family type changes use object IDs, not direct_t. The parent resource
  initializes direct_t to 0; it is not a saved facing preference for these
  actors. Preserve source fields without inventing a direction selector.
- Defer new collision bodies via SubArea.add_deferred() so they cannot leak
  across a retry or survive as unparented nodes after area teardown.
- Keep source goal placement off the grid: SMW gate height is 137px.
- Sprite metadata fps is intrinsic; entities override object animation speed.
  GameMaker Mario is top-origin on a 32px canvas; Player uses its feet.
  Both gameplay and SMW goal Draw_0 add y+1, so retain the 1px floor overlap.
- GMS2 .yy files permit trailing commas; use the tolerant tooling reader.
- Godot reports Area overlaps after the crossing. Fast actors can need their
  swept previous edge (PlayerHelmet.deflect, Thwomp._before). The source helmet
  is non-solid; the native retreat bridge is bounded to two steps and head
  geometry, alongside obj_enemyparent's falling-head guard. Do not replace this
  with source-margin inflation or a remembered two-second immunity.
- Source icons are not all square (the Bros are 16x32). Palette centre, ring
  sectors and the editor card must keep TextureRect stretch_mode on
  KEEP_ASPECT_CENTERED; otherwise the icon is squashed.
- Entity art anchors differ per family: 32px-tall actors whose source origin is
  y=16 need Graphics at -16 so the drawn bottom lands on the feet (Hammer Bro
  was 16px into the ground with Graphics at 0). Measure the drawn rect against
  the feet before changing Graphics offsets.
- Monty uses the normal resource-overlap placement rule. Do not reintroduce
  the source-absent ground-only rule or its GroundPart group/lifecycle override.
- Check collisionKind as well as bbox sizes. Current source_mask_test verifies
  ellipse corners for Monty/Rocky/Bros/hammer and rectangular ice corners, on
  physical bodies and player sensors. A rectangular bbox does not imply a
  rectangular collision mask. Helmet/Thwomp pixel tests also preserve faint
  alpha, transparent holes and the drawing-only flips/angles.

## Working rules

Port behavior into Godot-native modules; do not transliterate thousands of
GML events. Update ARCHITECTURE.md and regenerate GAP_REPORT.md when coverage
changes. New reference-derived code carries AGPL-3.0-or-later notices.

Never commit or redistribute assets/openwe/ or the sibling reference checkout.
Do not push, publish builds, or install system-wide software without user
approval. No Antigravity for this continuation.
