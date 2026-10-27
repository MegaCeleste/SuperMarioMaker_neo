# Roadmap

Latest explicit selection (2026-10-27): ordinary SMW door pairs (DOORS-2026-10-27.md).
Pipes and sub-area travel were rolled back after review and are not selected now.

Latest explicit selection(2026-10-23): ordinary SMW semisolid platforms now.
Native resizing/three looks/overlap/history/separate platform SWE collections
and one-way runtime contacts are implemented; see SEMISOLIDS-2026-10-23.md
and HANDOFF for verification. Bridges, mushroom/moving platforms, wings and
other styles remain future content.

Latest explicit selection (2026-10-23): ordinary SMW swimming after six-theme
switching. Native source strokes/float art, held buoyancy/diving, water floor
motion, surface entry/exit, water rebound/bubbles and state/retry ownership are
implemented. Read SWIMMING-2026-10-23.md and HANDOFF for final verification.
Other styles/mounts/night and additional themes remain unselected.

Latest explicit selection: SMW course-theme switching, clarified by the user
as ground/underground/castle environments. SMM1's six day themes now have native
selection, backgrounds, themed ground/start/slope art, relevant previews/icons,
edit/play music, atomic history and signed SWE. See THEMES-2026-10-22.md.
That theme-only selection did not include swimming; the later explicit
swimming selection above now adds it. Other styles, SMM2 themes, doors/pipes
and endings remain future work.

Latest explicit next-feature selection (2026-10-22): ordinary SMW portable
spring after correcting the two irregular slope screenshots. SpringPart,
source compression, carrying/releases, normal/high/spin launches, ordinary
actor bounce and both signed SWE wrappers are implemented. Read
SPRING-2026-10-22.md and the current HANDOFF acceptance before continuing.
The slope correction now projects contacted terrain components beneath the
ribbon, closing deeper concave gaps; independent islands remain separate.

Latest explicit selection (2026-10-22): SMW floor slopes, overriding the prior
SMM1-first filter for this one feature. Native steep/gentle palette entries,
endpoint editing/history, thin floor ribbons, reversible staircase fusion, ordinary actor
traversal and player sliding are implemented; see SLOPES-2026-10-22.md for the
visual sources, extension-only SWE contract and remaining slope variants.
This does not select other SMM2-only additions.
The user's subsequent five-issue correction supersedes the initial filled
triangle: empty space stays empty, monster clearance follows the ribbon,
decorative terrain variants stay stable during resize, and custom gentle art
belongs in textures/tiles/slopes/ (README and32x32 templates supplied).

The long-term reference is behavioural parity with SMM:WE OpenWE through native
Godot modules. Milestones are cumulative and end with a playable build and a
regression scene. The basic-flow/visual-bug round is complete. The user selected
static editor contact synchronization next and explicitly requested SMM2-style
lower-right pixel shadows; that bounded follow-up is delivered and verified.
The latest user direction selects **SMM1 course-making features first**,
including its updates; leave additions absent from SMM1 for later. It does not
authorize the entire OpenWE backlog. Before starting content, the user then
prioritized six controls/UI bugs. That correction and subsequent startup/
rendering fixes are complete. The user then selected the basic SMW Fire Flower
round: ordinary/progressive editor and block contents, save/history, Fire Mario
and player fireballs are implemented. See FIRE-FLOWER-2026-10-21.md.
The next explicitly selected Super Star and reported Bro palette/card icon
correction are implemented; see STAR-2026-10-21.md for their bounded scope.
The next user-authorized batch implements1UP, hard/hidden blocks, drag-based
container contents, timed multi-coins and missing existing actor contacts;
see BASIC-BATCH-2026-10-21.md. Validation is grouped after implementation.
The next continuation implements ordinary SMW spikes, ice blocks and cloud
platforms with native editor/history/SWE and surface/contact policies; see
TERRAIN-BASICS-2026-10-21.md for bounded scope and grouped validation.
The user then reported fast spikes: their runtime clock now uses source6fps,
followed by an authorized ordinary SMW donut/note-block batch. See
PLATFORM-BLOCKS-2026-10-21.md for its source timers, contacts and deferred scope.

## M0 — Audit and tooling

- [x] Pin base (GodotWE `4a836e6`) and reference (OpenWE `2f84414`).
- [x] Inventory both projects (objects, folders, scripts, rooms, sprites).
- [x] Gap report by OpenWE resource folder.
- [x] Sprite conversion pipeline + runtime `SpriteLibrary`.
- [x] Generated SWE test fixture (no third-party level data).
- [ ] Sound conversion pipeline.
- [x] Headless test runner (`tools/porting/run_tests.py`).

## M1 — Vertical slice: SMW overworld basics

See `SLICE-001.md`. Exit criterion: a fixture level is playable end to end
with SMW small/super Mario, Goomba, coin/question blocks, HUD and goal.

- [x] Restore SWE style/theme/timer and ground-derived spawn; reuse native terrain connections.
- [x] Manifest-driven slice sprites, with an idempotent preparation command.
- [x] SMW Goomba resource (Galoomba), stomp/carry/kick and spin stomp.
- [x] Coin and mushroom question blocks, turn blocks and HUD score/coins/time.
- [x] Small/super, damage immunity, timer/void death and local retry.
- [x] Goal gate, automatic walk, clear music, time tally, victory pose and exit.
- [x] Thirty-seven regression scenes and real OpenGL start/completion/editor/enemy/flight/helmet/player/liquid captures.
- [x] Stable mushroom growth/headroom, immediate sprite origins and source walking/coasting cadence.
- [x] Original Mario y+1 drawing offset and one-pixel floor overlap, checked against opaque shoe pixels.
- [x] Camera/body physics synchronization and fixed-screen pixel-stability regression at high render rates.

The slice is complete. Goal-height bonuses, castle endings and other
styles/powers remain in later milestones.

## M2 — Editor parity (SMW)

- [x] Save/reopen the represented SWE subset, preserving unported source data.
- [x] Editor Save/Save As and Coursebot Edit/Play entry points.
- [x] Load/save, write-failure, concurrent request and editor-flow regressions.
- [x] Goomba and standalone mushroom palette entries; question-block content window.
- [x] Ordinary/progressive SMW Fire Flower placement and block contents, native history/signed SWE, Fire Mario, ordinary/spin fireballs, Fire-to-Super damage and runtime cleanup.
- [x] Basic SMW Super Star placement/block content, history/signed SWE, additive timed/refreshable invincibility, source speed/flash/particles/music, enemy chain rewards and lifecycle cleanup.
- [x] Basic SMW1UP, hard/hidden block palette/placement/history/signed SWE and native pickup/head/giant/helmet contacts.
- [x] Drag item into question/hidden/turn containers; inspect/extract enlarged contents, atomic undo/redo and source multi-coin window.
- [x] Shared ordinary-enemy neighbour turns, resting-carryable item contacts, thrown/held Galoomba attacks and moving-shell/flipped-body contacts.
- [x] Basic SMW spike/ice/cloud palette Parts, signed SWE/history, solid hazard contacts, source ice traction and one-way platforms/Thwomp crushing.
- [x] Source shared6fps spike cadence; ordinary SMW donut warning/fall/carry/return and note compression/bounces/powerup contents, native history/signed SWE and render interpolation.
- [x] SMW SMM1 six-theme editor switching, background/terrain/previews/music refresh, complete liquid-state history and both signed SWE wrappers.
- [x] Ordinary SMW swimming: source strokes/floating and small/Super/Fire art, held buoyancy/diving, submerged floor movement, water entry/exit, enemy rebound/bubbles, solid/block contacts and interrupted-state/edit/replay cleanup. Read SWIMMING-2026-10-23.md for current acceptance.
- [x] Ordinary SMW semisolid platforms: native palette/three looks, bottom-left anchored resize/history, source tile parity across six themes, overlapping decorations, separate signed platform collections and player/item/enemy one-way contacts. Read SEMISOLIDS-2026-10-23.md for current acceptance.
- [x] Ordinary SMW portable spring palette/placement/history, signed SWE, carry/drop/upward release, four-frame compression, normal/high/spin Mario launches and ordinary actor bounces.
- [x] Galoomba/Goombud type window, persistent tool-card type, ledge avoidance and typed recovery.
- [x] Green/red Koopa selection, history and SWE round-trip; SMW shell/ejection/reentry lifecycle.
- [x] Shell carrying/releases, ricochets, native block activation, enemy chains and held shields.
- [x] Independent Goomba/Koopa wings/parachute toggles, previews, history and signed SWE round-trips.
- [x] Typed wing flight, parachute sway/landing, wing-loss stomps and deferred effect cleanup.
- [x] Buzzy/empty-shell palette types, dependent variant undo and topology-derived ceiling attachment.
- [x] Occupied-shell recovery, ceiling drops and rideable winged Buzzy with native platform motion.
- [x] SMW Buzzy helmet equip/armor/head interactions, original sounds and helmet goal pose.
- [x] SMW Spiny/empty-shell palette, dependent undo/SWE, ceiling drops and block-flipped recovery.
- [x] Winged Spiny cruise, alternating timed needles, native spiked-shell contacts and cleanup.
- [x] Typed Spiny helmet equip/armor/head defeat/deflection, original sounds and distinct goal frame.
- [x] Native Blooper palette/save/history, timed jets/sinking, air/water contacts and floating defeat.
- [x] Red/yellow Cheep Cheep types, card/dependent history/SWE, swimming, jumps, glide and parachute.
- [x] Fish precise native masks, normal/spin/head/shell/block contacts, lava/poison aura and typed rotating defeat.
- [x] SWE water positions/speeds and native SMW surface animation, rise/fall/hold/reset foundation.
- [x] Standalone jump/fire Piranha types, card/SWE and native ceiling/side topology with dependent history.
- [x] Source jump/fire timings, water shots, native projectile contacts, lava sink and effect cleanup.
- [x] Small/giant Muncher size/flag window, source origins, four-cell bounds and dependent undo/SWE.
- [x] Native Muncher solid stacks, crushing, moving semisolids, source helmet/block/POW hits and giant landing impulse/audio.
- [x] Small/giant Thwomp palette, direct_t direction cycle, size/type window, dependent undo and signed SWE.
- [x] Source wait/attack/impact/return phases, block breaking/activation, enemy crushing, POW and swept native helmet contacts.
- [x] Monty Mole palette/window/signed SWE, two-tick chase, wall reverse hop, wings/parachute and 200-point defeat.
- [x] Rocky Wrench palette/signed SWE, source emerge/throw/sink cycle, obj_wrench arc/blink/expiry and support-removal defeat.
- [x] Hammer/Fire/Ice/Boomerang Bro four-type window, source patrol/jumps/burst throws and native hammer/fireball/snowball/boomerang projectiles.
- [x] Sledge conversion/window/2x2 bounds, jump warning, wing hover, parachute, landing stun/sound/shake/smoke.
- [x] Source review fixes for Monty origins/sway/water, Rocky settlement/masks and bounded Thwomp helmet contacts.
- [x] Distinct fire/ice terrain contacts, native ice freeze/thaw and gradual boomerang alarm phases.
- [x] Bro multi-platform random/room probes, narrow/blocked/one-way landings and moving-platform carry.
- [x] Source Bro/shot liquid entry, sinking/splashes, physical-shot helmet responses and frozen-mask early thaw/cleanup.
- [x] Rocky water sampling/cycle, fixed-pose liquid sink, vertical SMW defeat and Wrench animation/mask/arc/alarm/asymmetric-cull corrections.
- [x] Source ellipse/rectangle distinctions for Monty/Rocky/Bros/hammer/ice, physical sensors and offset bounding boxes.
- [x] Per-frame helmet/precise Thwomp masks, faint-alpha/transparent-hole preservation and direct-contact geometry.
- [x] Thwomp return probes/clocks, independent rebound, moving-liquid alarms and vertical corpse motion.
- [x] Theme-specific liquid contact widths and frozen held-item detachment/pose/tween/retry ownership.
- [x] Sledge forced held drops, source immunity/recovery distinctions and overlapping pickup polling.
- [x] Source shake-Mario animation, repeat-impact clock refresh and state/retry cleanup.
- [x] Physical actor strip/cadence, native suspension/resumption, inherited projectile policies and revision cleanup.
- [x] Monty/five-Bro typed corpse origins/facing/frames, actual collision-partner impulses, block hits, POW and spin-stomp policies.
- [x] Corpse initial-mask/water sampling, descending pre-motion culling, shot view boundaries and boomerang lifetime/catch removal order.
- [x] Central death motion/animation/selected-alarm policies, independent objects, held/power/retry ownership and replacement targets.
- [x] Small/giant free Chain Chomp palette/window, source origins/flag reset, four-cell validation, dependent undo and fractional signed SWE.
- [x] Chomp elliptical heads, historical links, source hops/startup/water/liquid rules, compound defeat and native death/activation/retry integration.
- [x] Legacy/new-small/new-giant Grrrol native cards/windows, source offsets, flag reset, sixteen-cell validation, dependent undo and fractional signed SWE.
- [x] Grrrol fixed ellipses, rolling/bounce/night/water/drag policies, legacy-only turning, block-owned delayed breaks and source contact/defeat/death/activation/culling rules.
- [x] Serialized sprite origins for odd dimensions, metadata conversion regressions and explicit giant-Grrrol pivot validation.
- [x] User-requested opt-in rotation edge sampling, alpha/tint/cardinal readbacks and unchanged actual Mario/terrain controls in a separate real-GL probe.
- [x] User-requested existing-enemy one-pixel surface overlap, stable alpha-reference anchors, inverted/ceiling margins and41 real physical-surface pixel cases.
- [x] User-selected static editor enemy contact synchronization, attachment alignment, unchanged placement/SWE and36 native preview cases.
- [x] User-requested lower-right pixel shadows on existing world art; current-frame silhouettes, union opacity and real-GL pixel/lifecycle checks.
- [x] Reviewed recent-enemy fidelity cases in REVIEW-2026-10-20.md; unported interaction systems remain listed separately.
- [x] Transformation pause and sprite/tween cleanup when leaving during a power change.
- [x] Exact outgoing pose snapshots and atomic growth/shrink visibility without autoplay shifts or double drawings.
- [x] Cancel deferred stomp/recovery bodies when restarting or leaving the course.
- [x] Undo/redo for place, move, paint, erase, block contents and starting-ground resize.
- [x] Undo across saves preserves unknown SWE data and releases detached nodes correctly.
- [ ] Port every SMW palette part as a `Part` subclass.
- [ ] Variant windows (part types, wings, direction, contents).
- [ ] Extend edit history and placement rules to every newly ported part/variant.
- [ ] Verify saved files in a running OpenWE binary.
- Exit criterion: build a level in GodotWE, save, reopen it in OpenWE.

Filter the remaining roadmap through the latest SMM1-only scope. Features
absent from SMM1 (for example Grrrol, the extra Bro types, parachutes, night
variants and SMM2-only themes/powers) are retained where already implemented,
but receive no new content expansion in this phase. Follow the user's current
bug-fix priority in HANDOFF.md before returning to the SMM1 backlog.

## M3 — Content breadth: SMW

- All SMW enemies and hazards, theme by theme.
- Remaining platforms/semisolids, doors/warps and P-switches; note variants and horizontal/winged springs remain future.
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
