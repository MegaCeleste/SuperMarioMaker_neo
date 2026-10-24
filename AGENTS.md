# Agent handoff

**Project separation (user direction, 2026-10-25):** this is SMMneo, an
independent development project at `C:/Working/SMMneo/GodotWE`, on branch
`SMMneo`. The former workspace folder `C:/Working/新建文件夹` was renamed to
`C:/Working/SMMneo`; the inner `GodotWE` folder name is unchanged.
`C:/Working/GodotWE` is a separate repository for focused upstream PRs.
Both projects remain active. Select the repository according to the user's
requested project; do not mix their working trees or automatically merge the
large SMMneo integration into the upstream contribution repository.
The publication remote `origin` is
`https://github.com/MegaCeleste/SuperMarioMaker_neo.git`; `upstream` is
`https://github.com/NCubss/GodotWE.git`. Publish this project's work to the
`SMMneo` branch. Existing remote `main` and historical branches belong to an
earlier project; preserve them. Its MIT license does not relicense this
GodotWE-based branch. Keep GPL/AGPL notices and exclude converted assets plus
locally generated slope-art templates from source commits.
Share useful fixes in either direction as individually reviewed adaptations,
with tests appropriate to the receiving project's architecture. In particular,
SMMneo's existing WorldPresentation and the separate GodotWE branch's native
physics interpolation are different implementations; compare them before
porting rendering changes. This separation does not select new gameplay scope.


**Latest user quality direction (2026-10-23):** fewer additions are acceptable;
conformance to the original project's contribution rules takes priority.
Explain every implemented feature to the user: intended rule, native control/
data flow, file entry points, design reason, verification and known limits.
The Chinese guide at docs/porting/IMPLEMENTATION-GUIDE.zh-CN.md is the current
feature explanation; docs/porting/CURRENT.md is the short contributor entry.
Keep it current. A green gameplay suite is not a code-style approval.
The first style batch is explicitly listed in tools/porting/check_style.py;
add fully reviewed future scripts there and run the check. Do not claim the
whole repository conforms while --all still reports legacy backlog. Current
work is a quality/documentation round, with no additional gameplay selected.

This repository is **SMMneo**, an independent GodotWE-based project using OpenWE as a behavior reference.

**Read `docs/porting/HANDOFF.md` first**, then the current correction record
`docs/porting/REVIEW-2026-10-20.md`. The original
`docs/porting/HANDOFF-DEEPSEEK.md` is historical: its green tests missed several
source differences, and the review records the fixes and remaining gaps.

Quick orientation:

- Branch: `SMMneo` (created from `port/openwe`, preserving local work)
- Base: GodotWE (`NCubss/GodotWE`, GPL-3.0), commit `4a836e6`
- Spec reference: sibling checkout `../openwe-ref`, OpenWE commit
  `2f84414054c576bf7ca03dfa33b244ee730d57da` (AGPL-3.0, reference only)
- Engine: Godot 4.7.2 portable at
  `../.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`
- Current milestone: M1 verified; M2 save/history, enemy variants, Buzzy/Spiny helmets, Blooper, Cheep Cheeps, standalone Piranha Plants, small/giant Munchers, small/giant Thwomps, Monty Mole, Rocky Wrench, five Hammer Bros, both free Chain Chomp sizes and all three Grrrol forms; liquid surface, Mario visuals/camera and opt-in rotation sampling verified
- Completed authorized rounds: reviewed existing Mario movement/growth, terrain
  connections and completion; corrected enemy surface alignment and rotation
  sampling. The user then selected static editor contact synchronization and
  requested SMM2-style lower-right pixel shadows on existing world art. Both
  are delivered:41 native scenes,41 runtime contact cases,36 editor contact
  cases and actual GL/120fps shadow/Mario probes pass. The final Muncher icon
  image-copy correction also passes focused preview/Muncher and GL checks.
  The latest user direction authorizes SMM1 course-making content first,
  deferring additions absent from SMM1. The user then prioritized six existing
  bugs over new content: walk/run skid art, walk-speed dust, dust size/height,
  skid audio cleanup, small/super crouching, and Bro palette icon size.
  That controls/UI correction is delivered. A subsequent user-supplied SMM2
  video replaced the initial hollow/fading dust with filled shader-drawn puffs,
  rapid expansion, separation and contraction. Full42 scenes passed before
  that visual replacement; final focused controls/physics/death and real-GL
  60/120fps pixel/reversal captures passed afterward. No new content was
  started in that earlier round. Fire Flower was only investigated then;
  the latest selected content round below now implements it.
  The latest particle refinement separates dense running brakes from walking:
  five-tick emission (reduced from three at the user's request), short-lived
  stationary clouds shrinking at their emission point (the user's latest
  instruction removed foot-following). The profile lasts through deceleration.
  Focused controls/physics/death, required slice/sprite scenes and actual GL
  walk/run captures at60/120fps pass, with zero fresh-cloud foot-anchor error.
  Latest requested visual polish: SpinThump uses only one white frame and a
  continuous size pulse; SpinSmoke's four stars pulse independently of their
  outward travel. The new spin_effects_test checks real contacts and cleanup.
  Import, five metadata checks and all43 native regressions pass. The final
  spin-effect GL probes at60/120fps verify actual pixel growth/contraction and
  real contact reels. Current audit:250 scripts /130 scenes /32,137 lines.
  The pinned Chain Chomp has no stake, tether or release system.
  Latest growth correction (2026-10-21): the user retracted the small/big
  alternation. Switch immediately to the original big texture, then vary only
  its vertical scale through24/20/26/20/28px standing heights. Keep one big
  texture visible throughout the pause; duck/held-duck uses the big crouched
  texture at the same ratios. Do not edit source pixels. GroundPart's
  original 53 atlas choices now serve starting-platform cells and authored
  terrain together, including editor/runtime/history/SWE paths. New-course
  repeat saves and the native-only plain dirt frame also have save fixes.
  Final43-scene regression run passes, as do actual60/120fps growth and
  stationary-dust probes, native start-join captures and120fps pixel shadows.
  Use --player-growth and --braking-dust for focused GL capture; the larger
  controls/motion matrices can exceed their30s render bound.
  Latest authorized round (2026-10-21): runtime smoothness. WorldPresentation
  synchronizes display-only actor/camera/parallax interpolation while physics
  stays60Hz. PixelShadows caches commands and skips distant sprites. All44
  native scenes pass, including the new presentation lifecycle oracle; real GL
  fractional pixels,120fps locomotion/growth and shadow checks pass. Read
  docs/porting/SMOOTHNESS-2026-10-21.md for measured gains and latency limits.
  No new SMM1 content was started.
  Latest reported startup error: EditorPlayer._process read level.status while
  level was Nil. The cursor now waits for valid context, checks editor/player
  lifetimes, and Part input ignores unbound context. startup_flow_test includes
  the failing unbound-cursor case plus the configured disclaimer/intro/title,
  native editor, playable Mario and return path. Its real-GL --startup-flow
  capture passes. Import, five metadata checks and all45 native regressions
  pass. Current audit:254 scripts /133 scenes /32,664 lines.
  Latest selected content (2026-10-21): the user chose now for ordinary/
  progressive SMW Fire Flower. FireFlowerPart and typed question-block contents
  support native history and both signed SWE formats. FirePowerup shares the
  player body/states and adds original fire art, ordinary/spin shooting and
  Fire-to-Super damage; PlayerFireball has distinct bounce/contact/lifecycle
  policies from Bro fire. See docs/porting/FIRE-FLOWER-2026-10-21.md.
  Winged flowers and other powers/styles remain future work.
  Import, five metadata checks and all46 native scenes pass. Actual GL flower
  captures at60/120fps pass; keep their inspected_60/_120 sheets under ignored
  .godot/porting-tests/. Current generated audit:260 scripts /136 scenes /
  33,573 lines.
  Latest selected round (2026-10-21): basic SMW Super Star and the user's Bro
  palette/top-card disappearance. Default Bro art was read before the sprite
  library was ready; absent metadata is no longer cached, ready clears early
  derived caches, and default Bro icon generation uses an explicit runtime
  method. palette_icon_test checks the cold path and actual clipped UI pixels.
  StarPart/SuperStar/StarSprout and sprout-21 support placement/history/signed
  SWE. PlayerStar adds600-tick invincibility, refresh, speed bonus, source
  flash/sparkles/trails/music, enemy chains and goal/death/editor/retry cleanup.
  Import, five metadata checks and all48 native scenes pass. The icon GL probe,
  star60/120fps captures and actual-GL startup flow pass and were inspected.
  Current generated audit:266 scripts /140 scenes /34,307 lines. Verbose star
  exit diagnostics contain audio streams/packet/playback references only;
  no leaked player, enemy or editor nodes were reported.
  Read docs/porting/STAR-2026-10-21.md. Item attachments/other styles remain open.
  Latest user-authorized batch (2026-10-21): implement several basics, then
  validate together.1UP, hard/hidden blocks, drag-based question/hidden/turn
  contents, enlarged inspect/extract icons, atomic history and source timed
  multi-coins are implemented. A later request adds missing ordinary enemy
  turns, resting-carryable item contacts and thrown/held Galoomba collisions.
  ActorContacts snapshots before motion; special controllers retain their
  policies. Focused native matrix and actual GL60/120fps batch probes pass.
  Read docs/porting/BASIC-BATCH-2026-10-21.md; final suite acceptance is in
  HANDOFF.md. The aggregate49-scene run passed47 and exposed two regressions:
  Monty must retain Mario-facing after contact, and FireFlower's replacement
  must load Mushroom at runtime to avoid an unfinished preloaded PackedScene.
  Both are fixed; world_death/fire_flower/monty/recent_enemy_defeat/basic batch
  all pass targeted reruns. Current audit:277 scripts /145 scenes /35,566 lines.
  Final cold import plus slice/sprite guards and actual-GL startup flow pass.
  Final batch GL60/120 captures pass; inspected editor/runtime/contact reels
  and matching logs are retained with_60/_120 suffixes in .godot/porting-tests/.
  Enemy contents, attachments, other styles and profile/lives UI remain open.

Latest continuation (2026-10-21): SMW spike, ice and cloud terrain have native
palette Parts/history/signed SWE and runtime contact/surface behavior. Read
docs/porting/TERRAIN-BASICS-2026-10-21.md. Import and five metadata checks pass;
the50-scene aggregate passed49, with only a stale editor_history supported-Part
list failing. That assertion is updated and its focused rerun passes. Final
actual GL60/120 native editor/runtime captures pass and were inspected; clean
images/logs retain_60/_120 suffixes under .godot/porting-tests/.
Current audit:284 scripts /149 scenes /36,097 lines. Source room-boundary
spike extensions and other style/attachment machinery remain future work.

Latest user correction/continuation (2026-10-21): fix the spike clock before
content. SpikeTile now samples source banim3 at shared6fps instead of60fps
metadata autoplay, with cadence/late-creation/pause guards. Ordinary SMW donut
and note blocks are implemented; read docs/porting/PLATFORM-BLOCKS-2026-10-21.md.
Import/five metadata checks and all51 native scenes pass. Final actual GL60/120
editor/runtime captures and30-frame GPU spike/source-pixel/cadence probes pass;
they were visually inspected. The120Hz sampler records canvas transforms in
frame_pre_draw after WorldPresentation, matching the GPU frame. Artifacts/logs
retain_60/_120 suffixes; see HANDOFF.md. Current inventory:291 scripts /
152 scenes /36,892 lines. Donut wings, musical note variants and other styles
remain future.

Latest explicit selection (2026-10-22): SMW floor slopes, an exception to the
older SMM1-first filter. Read docs/porting/SLOPES-2026-10-22.md for the primary
Nintendo editor footage, separate palette entries, shared endpoint editing,
native terrain/polygon/motion integration, reported fringe correction and
display-only actor foot contact. Slopes save as explicit project SWE extension
objects; original OpenWE executable support is not claimed.
The user's later five-issue correction REPLACES the filled-triangle model with
one-tile diagonal ribbons and reversible staircase fusion. Exact decomposed
ribbon queries allow monsters one cell away and reject actual contact. Only
caps draw square atlas tiles, fixing stray5x5/6x6 corners. Coordinate-seeded
variants preserve the original53 rules without whole-map rerolls; unchanged
art is cached. Intersected terrain gets derived cropped art/runtime polygons;
diagonal grass draws above dirt regardless of placement order. User PNGs go in
textures/tiles/slopes/; read its README and editable32x32 templates. Missing
gentle art still uses temporary sampling. Ceiling editing, alternative stair
art and other styles/themes remain future. Earlier verification in HANDOFF:
aggregate52-scene pass, affected focused reruns and final GL60/120 paired-fringe,
visible-handle and one-pixel shoe probes pass. The120 capture omits redundant
long walk/actor matrices to stay inside30s. Final audit296 scripts /155 scenes /
37,843 lines. No Antigravity or subagents were used.
Correction acceptance is recorded at the top of HANDOFF and in SLOPES; do not
reuse that historical full-suite pass as proof of the rejected triangle model.
The corrected aggregate now passes import, five metadata checks and all52
native scenes. Current inventory296 scripts /155 scenes /38,123 lines.
The later two screenshots exposed deep concave profiles at central/high-end
pillars. The old sub-cell-only fusion limit is superseded. Native terrain
components with actual ribbon contact now project their tops through the slope
footprint; independent islands cannot activate fusion. All derived bridge cells
use the native53-choice atlas and one complete editor/runtime outline. The
expanded slope_fusion_test checks30 basic wedges plus152 deeper points in both
directions, actual GL soil/edge RGB, runtime collision and reversible history.
Read the latest HANDOFF/SLOPES acceptance, not the historical52-scene claim.

The user explicitly selected ordinary portable SMW spring next. Gizmos page0
slot0, native place/history/both signed SWE wrappers, carry/releases, source
compression, normal/high/spin player launch and ordinary actor bounce are
implemented. Read SPRING-2026-10-22.md. Its real GPU probe caught4.08px transient
foot separation; display anchoring keeps contact through the stepped source
frames and shares the transform with PixelShadows. Horizontal/winged springs,
other styles and further unselected content remain future. Final aggregate/
GL acceptance and regenerated counts are at the top of HANDOFF.md. Final
import/five metadata checks/all54 native scenes and --slope-fusion/--slopes/
--spring GL60/120 pass. Spring shoes216/216 and432/432, anchor error0.08px;
slopes retain1099/1099 fused grass,476/476 gentle and8/8 shoe pixels. Actual
irregular-profile views are cropped in slopes_irregular_fixed.png. Current
audit301 scripts /159 scenes /38,905 lines; selected224 sprites/777 frames /
31 sounds, additive manifest237/823. Verbose spring exit refs are audio-only.

Latest user selection after that completed round: course-theme switching,
clarified as ground/underground/castle environments. Read THEMES-2026-10-22.md
and the top of HANDOFF. Native SMW SMM1 six-theme popout, background/ground/
start/slope/previews/music refresh, history and signed SWE are implemented.
Native53 terrain rules stay unchanged. The first GPU oracle caught stale
non-liquid water settings flooding castle entry; source bottom defaults plus
complete theme/liquid history fix it. Background child transforms use the display
camera; frame_pre_draw sampling verifies actual pixels. Other styles, SMM2-only
themes, Mario swimming, room travel and endings remain separate future work.
Final import/five metadata checks/all55 native scenes pass after theme
integration. Final GL acceptance/artifacts are recorded at HANDOFF's top.
Current regenerated audit304 scripts /160 scenes /39,292 lines. Selected242
sprites/1066 frames/41 sounds; additive manifest255/1112. Final --theme-switch
GL60/120 pass108/108 background pixels per rate across six editor/play views;
menu and six editor captures were inspected. Matching logs/images retain_60/
_120 suffixes and themes_six_verified.png is an actual120fps sheet. Affected
final --spring120 and --slopes60 foot/source-pixel checks also pass.

Latest user correction(2026-10-23): theme terrain/source-frame roles and the
original-game menu. Read current HANDOFF/THEMES acceptance. Ordinary ground
assets are present; the old adapter incorrectly used SWE's saved-frame table
as raw sprite order. Rendering now uses smw_ground_frames.json independently:
raw43=filled,44=isolated,45=vertical,46=horizontal; underground50+ include
diagonal assets and must not become square-edge decorations. The native53
chooser and original overworld atlas stay unchanged. The previous55-scene/
background-pixel pass missed this bug; new thick/strip/isolated source and GPU
checks supersede that coverage claim. The theme menu uses landscape cards,
the EXISTING ButtonHoverEffect red corners and NO name labels/tooltips, per
explicit user steering. Optional artist-supplied slopes now support16x32 steep
and32x32 gentle per theme, directions and standalone/filled; preserve old root
gentle aliases. Exact missing-art groups and geometry are in slopes/README.md.
No further content scope is selected by these corrections.
Final production import/five metadata checks/all55 native scenes pass. A final
test-fixture batch refresh has focused theme and actual GL60/120 reruns; see
HANDOFF for final source-pixel artifacts and the39411-line regenerated audit.

Latest user selection(2026-10-23): ordinary SMW swimming now. Read current
HANDOFF and SWIMMING-2026-10-23.md for source constants, original art, held
buoyancy/diving, floor/solid/block/enemy contacts, entry/exit hysteresis,
interrupted states and edit/replay cleanup. Pickup during a continuous state
now receives the existing hand offset after deferred reparenting. Do not
expand this selection into other styles/mounts/night or new themes. The active
SMM1-completeness goal remains incomplete. Final fresh import/five metadata
guards/ALL56 native scenes pass. Actual GL60/120 verifies5752/5752 and
11595/11595 unobscured source pixels; inspected captures/logs retain rate
suffixes. The first52/56 report is historical, with its fixture corrections
and final acceptance recorded in HANDOFF. Current generated audit308 scripts /
161 scenes /40,054 lines; selected250 sprites/1088 frames/42 sounds, manifest
263 sprites/1134 frames. No production changes followed the final checks.

Latest explicit selection(2026-10-23): ordinary SMW semisolid platforms now.
Read SEMISOLIDS-2026-10-23.md and current HANDOFF for source tiling/overlap,
bottom-left anchored resize, three appearances/card choice, separate signed
platform collections, unknown-data preservation, native one-way top and
real player/item/enemy contacts. The original animated handle is reused.
Final GL60/120 passes1038/1038 source pixels per rate, including moved overlap.
Fresh import/five metadata guards/all57 native scenes pass; HANDOFF records the
complete report. Current audit310 scripts /163 scenes /40,681 lines; selected
269 sprites/1308 frames/42 sounds, additive manifest282 sprites/1354 frames.
Other platform types/styles/wings remain unselected.

Rules:

1. Port behaviour into Godot-native modules; do not transliterate GML files.
2. Keep `tests/scenes/slice_001.tscn` and `tests/scenes/sprite_library_test.tscn`
   green (exit code 0). Run the full suite with
   `python -I tools/porting/run_tests.py --import`.
3. `assets/openwe/` and the `../openwe-ref` checkout are third-party and
   Nintendo IP; never commit or redistribute them.
4. Do not push, publish, or install system-wide software without user approval.
5. Regenerate audit data with the scripts in `tools/porting/` instead of
   hand-editing generated JSON.
6. User direction: do not use Antigravity. Reuse GodotWE's existing terrain
   connection rules; do not replace them with a parallel implementation.
7. User backlog scope: SMM1 course-making features (including its updates) first;
   leave non-SMM1 additions for later. Prioritize the latest six-bug report over
   that content backlog. Older per-item approval notes are historical and must
   not undo this explicit authorization or expand it to all of OpenWE.
   The user explicitly selected slopes on2026-10-22, overriding that filter
   for slopes only; other SMM2 additions remain unselected.
