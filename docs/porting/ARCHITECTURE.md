# Architecture and module mapping

This document is the contract between the OpenWE specification and the Godot
implementation. When a system is ported, add or update its row and link the
implementation files.

## Engine-side model (GodotWE base)

```
Level (Node2D)
├── SubArea (Node2D)               one per playable area
│   ├── background (Parallax2D)
│   ├── parts (Part, Area2D)       editor-placeable elements
│   ├── tiles (GroundTile, ...)    runtime solids spawned from parts
│   └── entities (Entity)          player, enemies, powerups
├── HUD
└── Editor (Control, when editing)
```

- `Part` is the editor-side representation of one GameMaker `*_res` object.
  It builds runtime nodes via `build()`.
- Ordinary DonutPart/NoteBlockPart reuse the same palette/history/SWE system.
  DonutPlatform uses a native one-way AnimatableBody2D for downward carrying,
  with warning mask/art shake and fresh-body respawn. NoteBlock has a native
  compression/rebound cycle; PlayerNoteState temporarily owns its passenger
  until a one-shot speed is consumed by the existing jump/spin state. Note
  contents use a block-owned release alarm and SubArea deferred insertion.
  Both bodies participate in WorldPresentation. Read PLATFORM-BLOCKS-2026-10-21.md.
- SpikeTile samples the shared Level.animation_time at6fps (banim3), rather
  than autoplaying the source sprite resource's60fps metadata.
- SpikePart, IceBlockPart and CloudPart reuse the native one-cell placement,
  painting/history and signed SWE pipeline. SpikeTile is a14x16 solid with
  player damage/helmet-head guards. IceBlock specializes HardBlock art/shards;
  PlayerState selects the source ice traction only at the supporting foot
  strip. CloudPlatform is a16x5 one-way solid; downward Thwomp impact consumes
  its touched clouds. See TERRAIN-BASICS-2026-10-21.md for source contracts.
- EditorPlayer waits for a valid Level before processing and checks the editor
  and runtime player before accessing them. Part pointer input also ignores
  unbound/freed context. startup_flow_test covers a cursor entering before
  factory binding and the real startup/title/editor/play/return lifecycle.
- `Entity extends CharacterBodyExt` is the runtime representation of GameMaker
  `obj_enemyparent` descendants.
- `Component` nodes attach reusable behaviour (gravity, pickup, sliding,
  block bumping) to a parent node instead of deep inheritance.
- SemisolidPart reuses the native terrain palette, Part/window/history APIs
  for three appearances and bottom-left anchored resize. Its decoration is
  separate from an ordinary5px one-way top; layer0/deferred sibling ordering
  retains exact top-y depth above shadows and behind terrain/actors. Signed
  platform rows merge in PLATAFORMAS/S7 separately, preserving unported rows
  and save-revision bindings. Read SEMISOLIDS-2026-10-23.md.
- PlayerSwimmingState shares Player's body/powerups and handles source strokes,
  submerged floor movement and held-item buoyancy. The Player environment
  resolver preserves interrupted/goal/death states, and restores native air
  jump gravity on surface exit. PlayerBubble is an area-owned deferred sprite
  effect with the source path and WorldPresentation interpolation. Read
  SWIMMING-2026-10-23.md for the SMW constants and verification contract.
- ContainerBlockPart shares authored contents for question, hidden and turn
  blocks. Editor insertion consumes a loose Part, while history owns its
  restoration. Long press inspects/extracts the stored item; it is not a content
  picker. OneUp/OneUpSprout and HardBlock/HiddenBlock use the existing area,
  sprout and delayed-break ownership. See BASIC-BATCH-2026-10-21.md.
- ActorContacts snapshots active body bounds before motion in32px buckets.
  Ordinary enemy turns read that same snapshot and synchronize their Slide
  direction; powerups and carryable attacks use separate source policies.
  Native terrain masks are unchanged. Reset drops stale records on edit/retry;
  special enemy/shot controllers retain their distinct responses.
- FireFlowerPart and typed QuestionBlockPart contents build FireFlower or the
  existing rising sprouter. Entity sprouts receive SubArea/Level context when
  inserted; abandoned sprouters own/dispose their uninserted child.
  FirePowerup reuses the player body/states, adds the source fire catalog and
  firing/spin clocks, while PlayerFireball is a separate native controller
  from enemy Bro shots. Both new actors share activity/death/presentation and
  shadow ownership. See FIRE-FLOWER-2026-10-21.md for source policies.
- `StateMachine`/`State` implement player state logic; each OpenWE `scr_*`
  player state becomes one `Player*State`.
- PlayerStar is additive status, preserving the current Powerup and single
  Mario sprite. Its600 physical ticks own the shader, following sparkles,
  stationary trails, collision/score chain and dedicated looping music.
  StarPart/StarSprout build SuperStar through the existing area-owned paths.
  SpriteLibrary never caches absent metadata; startup clears derived caches.
  Computed default Bro icons are requested through get_icon() after readiness,
  covering the cold Resource-property path missed by variant-only checks.

## OpenWE resource folder → Godot module

| OpenWE folder | Godot target | Status |
|---|---|---|
| `Objects/Main/Player` | `scripts/level/entities/player.gd`, `scripts/level/entities/states/` | partial |
| `Objects/Main/Parents` | `scripts/level/entities/entity.gd`, `enemies/enemy.gd`, `parts/part.gd`, `scripts/components/` | partial |
| `Objects/Main/Controllers` | `scripts/singletons/`, `scripts/level/level.gd`, `sub_area.gd` | partial |
| `Objects/Enemies/<theme>` | `scripts/level/entities/enemies/`, `scenes/entities/` | minimal |
| `Objects/Blocks/*` | `scripts/level/parts/`, `scripts/level/tiles/` | partial |
| `Objects/Interactive/Collectables` | `scripts/level/powerups/`, `scripts/level/tiles/coin.gd` | partial |
| `Objects/Interactive/Platforms` | `parts/semisolid_part.gd`, `donut_part.gd`, `cloud_part.gd`, `note_block_part.gd`, `spring_part.gd` | partial: ordinary SMW subset; remaining families/variants open |
| `Objects/Interactive/Goals` | `parts/goal_pole_part.gd`, `tiles/goal_gate.gd`, `smw_goal_sequence.gd`, `states/player_goal_state.gd` | partial: SMW gate/walk/tally/pose/exit |
| `Objects/Interactive/Special` | `scripts/level/parts/` (doors, warps, effects) | missing |
| `Objects/Editor Res Objects` | one `Part` subclass per resource + palette resources | partial |
| `Objects/UI/<area>` | `scripts/ui/<area>/`, `scenes/ui/` | partial |
| `Objects/Decorations` | `scripts/level/background.gd`, `scenes/backgrounds/` | minimal |
| `Objects/Collisions` | Godot physics layers + collision parents | partial |
| `Objects/Demo`, `Objects/Discord Webhook` | not ported | n/a |
| `Scripts/Mario` | player states | partial |
| `Scripts/Editor` | `scripts/ui/editor/` | partial |
| `Scripts/Backgrounds` | background controllers | minimal |
| `Scripts/Sounds`, `Scripts/Music` | `scripts/singletons/music_player.gd`, audio bus | partial |
| `Scripts/Misc` | scattered; classify per function during port | partial |
| `Sprites/*` | `assets/openwe/` via `tools/porting/port_sprites.py` | tooling ready |
| `Sounds/*` | `assets/openwe/sounds/` via `prepare_slice.py` | partial: three SMW clear sounds |

## Level data flow

1. `LevelProcessor.decode_swe()` verifies the HMAC and decodes Base64 JSON.
2. `LevelProcessor._from_swe()` reads sections `S1/AJUSTES`, `S2/SUELO`,
   `S4/NIVEL` (new format) or `MAIN`/`AJUSTES`/`SUELO`/`NIVEL` (legacy).
3. Terrain entries become `GroundPart`; object entries are looked up in
   `SWE_OBJECT_TABLE` and instantiated.
4. Unknown object IDs are skipped with a warning containing the name, count
   and file path. Valid style/theme/timer values are preserved; unsupported
   style graphics use an explicit fallback warning.
5. Course spawn derives from `ground2` (`obj_load_guardabot/Other_11.gml`).
   `obj_mariostart` is an intro overlay, not a saved player marker. The editor
   test cursor is session state and is not written to `NIVEL`.
   `GroundPart.refresh_all()` supplies the loaded neighbours to GodotWE's
   existing `_connect()` rules before runtime tiles build. Terrain keeps the
   native atlas, and `atlas()` synchronizes its current SWE frame for saving.
6. OpenWE normally derives its SMW gate from `ground3_x`/`ground3_y`. The
   loader adds this gate unless an explicit `obj_goalgate` is present. Goal
   origins retain their pixel coordinates (the post is 137px tall).
7. `SWELevelSerializer.snapshot()` captures live Parts on the main thread.
   Original root/settings/sections, unknown objects, ordering and unknown
   fields on represented objects survive save/reopen. Incomplete/metadata-only
   loads, multiple active areas and unsavable Parts are rejected explicitly.
8. The worker encodes Base64 + HMAC-SHA1 and stages the file beside its target,
   with backup/recovery for replacement. Source bindings and the active path
   update only after success. Editor Save/Save As and Coursebot Edit/Play use
   these APIs; runtime loading avoids circular PackedScene preloads.
9. Every successful save advances `Level.swe_revision`. Source indices on
   currently serialized Parts advance with it; a detached Part restored by
   undo retains its fields but is appended on its next save. This prevents a
   stale index from overwriting another object after a deletion was saved.

## Editor actions and palette

- Existing `PaletteCategory`/`PalettePage`/`PaletteItem` resources select the
  native `EditorCard` entries. Goomba uses `GoombaPart`; standalone mushrooms
  use `MushroomPart`, which builds the existing `Mushroom` runtime. Anonymous
  unimplemented placeholder entries remain visible and disabled until ported.
- `Part.get_variants()` exposes stable option IDs and existing part icons.
  The existing `EditorWindow` hosts these type options. Supported container
  blocks receive loose items by drag; long press inspects/extracts the stored
  contents with enlarged icons. The popup converts
  between the part and window canvas transforms instead of assuming a camera
  scale or ignoring scroll position.
- `GoombaVariant` Resources describe normal Galoomba (`obj_goomba_res`) and
  Goombud (`obj_goombrat_res`). The same native window selects the type and
  native history records the change. The tool card retains that choice for
  subsequent placements, matching OpenWE's resource-swap behavior. Object
  undo and the current placement-tool default are independent session state.
- `KoopaVariant` uses the same window/history/card flow for `obj_koopa_res`
  and `obj_koopa_red_res`. Resources select native icons, sprite families,
  walking FPS, ledge behavior and reentry delay. SWE saves the selected object
  ID, keeping unknown fields; `direct_t` is not a facing selector.
- Part modifiers are independent of type IDs. Wings/parachute toggles in
  EditorWindow.Content/Attachments use EditorHistory.set_modifier; the existing
  type buttons are now under Content/Options. Both flags can be set together,
  survive type changes, and serialize as integer wings/paracaidas fields.
  EnemyPartDecoration draws the original editor overlays under the Part's drag
  transform. Attachment changes do not change the next-placement defaults.
- BuzzyPart selects beetle/empty-shell resource IDs with the same window. Its
  source type swap removes wings while retaining parachute metadata, and does
  not update the next-placement card default. Variant history snapshots both
  ID and dependent modifier state, so undo restores the complete object.
  Ceiling attachment and saved inup derive from surrounding solid Parts.
- BlooperPart has no variant or attachment window, matching its source resource.
  Its source-offset preview uses SMW style frame 2. Legacy wings/paracaidas
  fields still render inherited editor decorations and survive SWE unchanged;
  scr_edit_to_play does not forward these flags to Blooper's runtime.
- CheepCheepPart selects red/yellow native Resources and retains the selected
  type on its palette card. A type swap copies wings and drops parachute;
  EditorHistory's dependent snapshot restores both. Source 19px preview canvases
  use style frame 2 with the (2,2) origin. Editor water mode derives from actual
  liquid depth and is serialized, rather than trusting stale modo_water fields.
- `EditorHistory` uses native Godot `UndoRedo`. Placement/deletion retain the
  same Part nodes, including unported SWE fields, with do/undo references.
  Undo operations run backwards within each action. One paint/erase gesture
  is one action; move, content changes and starting-ground resize are recorded.
  Resizing records the removed Parts in the same action and restores both
  collider dimensions and terrain when undone. Terrain refreshes are batched
  using `GroundPart.refresh_all()` and its existing connection rules.
- Route interactive removal through `Editor.erase_part()` rather than freeing
  history-owned Parts. Replacing a redo branch or clearing history releases
  detached Parts; live Parts remain in the level. The history owns and frees
  its native UndoRedo object when disposed.
- Buttons and Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z invoke the same history. Editing
  controls pause while a Part is held, a variant window is open, a save runs,
  or the level is playing. Mouse release ends a gesture even over UI controls.

## Slice 001 runtime

- `resources/content/smw_player_physics.tres` records SMW overworld constants
  from `obj_mario/Other_12.gml` in pixels/second and pixels/second squared.
  `Player` evaluates its state and gravity before moving in each fixed tick.
- `resources/content/smw_player_sprites.json` describes named small/super
  animations; `SpriteLibrary.get_animations()` caches the manifest-backed
  `SpriteFrames`. Power changes preserve the same Sprite node.
- GroundPart.atlas_for is the unchanged native53-choice terrain decision tree.
  A shared occupancy map includes ordinary unheld tiles and StartingGround's
  seven-column platform cells, without creating synthetic Parts. Both sides
  of a seam therefore use the same neighbours. StartingGround caches the
  chosen regions for GroundDrawer, its shadow and runtime tiles. Load, paint,
  erase, hold/drop, resizing and history refresh that same map. Only authored
  Parts are serialized. Native plain dirt(16,16), absent from SWE's atlas table,
  saves as the equivalent(32,16) interior while retaining its live native art.
- `obj_goomba_res` becomes `GoombaPart`. OpenWE's SMW runtime is a Galoomba:
  normal stomps flip it into a carryable body; spin stomps destroy it.
  `obj_goombrat_res` uses a Goombud Resource and the same runtime. Its existing
  SlideComponent enables a leading-foot support probe to turn at ledges.
  Both types use the source's 10px collision width. Walking, flipped and
  recovered actors retain their type and sprite set. Flipped actors shake
  after nine seconds and recover after ten; being held at the warning check
  resets both clocks, as in the source alarms.
- `SubArea.add_deferred()` owns pending bodies and tags them with the current
  runtime revision. Stomp/recovery callbacks use it so a restart rejects an
  old pending spawn; exiting the area frees pending unparented nodes.
- `Koopa` normal stomps spawn an empty `KoopaShell` and separate `BeachKoopa`;
  spin stomps destroy it. Red variants enable SlideComponent ledge avoidance.
  `ShellPhysics` stores source launch/eject speeds, seconds-based acceleration,
  different idle-shell/moving-shell gravity, fall cap and recovery timing.
- `KoopaShell` uses stationary/moving/carried states and the existing native
  PickupComponent. Custom release handles kick/up/down; default pickup velocity
  is disabled. Shells reflect at walls, activate BlockComponent, defeat enemies
  with chained scores, stop on normal stomps and break on spin. Enemy overlap
  handles shell pairs and a consumed carried shield. Player stores a validated
  held reference and can forget a consumed shield without throwing it again.
- `ShellVariant` is the common shell policy Resource; KoopaVariant/BuzzyVariant/SpinyVariant
  add their family data. The shared runtime also supports ceiling drops and
  configurable collision width, occupant scene, recovery/warning delays and
  wearability. Occupied Buzzy shells recover, empty Koopa/helmet shells do not.
  Native shapes are per-instance. Carried Buzzy recovery clears ownership safely.
  Spiny adds a 14px empty-shell height, spiked top and typed helmet Resource;
  a departing spin jumper cannot be kicked by stale overlap events.
- `BeachKoopa` slides, waits and walks; crawling contact immunity is rechecked
  after expiry. A matching empty shell accepts its hop and returns the typed
  Koopa after 60/70 ticks. Empty SMW shells have no wake timer. Squashed sprites
  expire with their own physics Timer. Death graphics and pending restoration
  actors use SubArea's revision guard; dead graphics also clean up below void.
  Chain 1UPs currently increment a session counter, not persisted profile lives.
- BlockComponent.activate() shares head/shell bumps. Tween completion resolves
  the activator ID safely if it died in the meantime. Enemy.kill() accepts the
  projectile's launch direction and selects colour-specific manifest death art.
- `EnemyFlightComponent` drives Galoomba/Koopa gravity and SlideComponent before
  their single native move, then handles landing and ceiling responses. Typed
  `EnemyFlightProfile` resources select burst hops, repeated hops or vertical
  patrol plus source sprite anchors. `EnemyFlightPhysics` holds speeds, delays,
  sway limits, gravity and fall caps. Parachutes independently override descent,
  sway and floating art until landing; enabled wings remain and resume afterward.
  A first normal stomp strips wings, a later stomp uses the original unwinged
  behavior, and a spin destroys the actor. `DetachedEnemyAttachment` and the short
  canopy shrink use SubArea's pending-spawn ownership for retry/exit safety.
- Buzzy's ride profile owns an external one-way AnimatableBody2D; native platform
  velocity carries Mario while the actor sinks/rises under load. Its normal
  runtime handles topology-derived ceiling crawling and inverted shell drops.
  Parent ownership, not just is_inside_tree(), governs platform teardown.
- SpinyPart shares CeilingAttachment's native Part-topology check with Buzzy.
  Spiny runtime uses existing flight/gravity/slide and shared occupied shells.
  BlockComponent queries supported bodies immediately above a bump and invokes
  their bumped_from_below capability, with the source bottom-edge +5px guard;
  Spiny flips, awards 200 points and later recovers. Descending Blooper dies.
- A CRUISE flight profile supplies Spiny wing motion independently of terrain.
  Its runtime owns the windup/volley/recovery state machine; SpinyNeedle is an
  independent Entity with its source damage area, component speed, lifetime and
  viewport culling. Pending insertion uses SubArea's existing revision guard.
  Editor parachute flags survive SWE but are not passed to this source runtime.
- BlooperRules stores jet/cooldown times, seconds-based motion, art origins and
  defeat policy. Blooper owns WAITING/JETTING/COOLDOWN, locks each diagonal jet
  toward Mario, sinks between eligible jets and uses no solid collision mask.
  Its native 32-vertex convex ellipse follows the source 10x18 mask instead of
  accepting its bounding rectangle. Source instance origins are converted to
  native feet for the height checks. Underwater contact disables stomping.
- FloatingEnemyDefeat handles Blooper's inverted, animated, non-spinning death
  with different air/water gravity and a slow fall cap. It has no collisions;
  insertion uses SubArea's revision guard and it culls below the viewport.
- CheepCheep owns its swim/jump/glide alarms and source-specific attachment
  motion. It bypasses solid movement, like its source override, while a native
  precise mask is built from frame alpha with BitMap/convex decomposition.
  Resources select yellow's periodic water turns and aimed large jump. Wings
  sway vertically in water and glide after a large air jump; parachutes sway
  horizontally, detach at the source boundaries and retain their restart alarm.
  Shared native Enemy, helmet, shell, block and deferred-insertion APIs apply.
- SwimmingEnemyDefeat uses EnemyDefeatStyle for typed Cheep/Piranha/Monty/Bro art, frame
  and origin offsets, with signed spinning and
  distinct air/water physics. Normal stomps retain Other_10's horizontal death
  direction; dead_h is a POW flag, not a normal-stomp flag. Detached wings,
  parachutes, bubble and ember effects use SubArea's pending ownership.
  Its initial launch samples obj_enemy_dead's default beach-Koopa mask before
  the caller's art assignment; subsequent Steps use the selected rotating
  mask, and descending-only camera/liquid removal precedes motion.
  Enemy.hit_by_actor retains a real collision partner for source speed/bounds
  decisions. Generic families keep their existing directional API. The native
  block dispatch supplies both block and activator, preserving older flip
  handlers while Monty/Bros use the block's speed/bounds and award 200 points.
- PiranhaPart shares CeilingAttachment's native floor/ceiling/side topology.
  Part environment-state hooks let EditorHistory group support-dependent flag
  removal with the editing action; a transient drag is canonicalized on release.
  PiranhaVariant selects standalone jump/fire motion, masks, art and timings.
  PiranhaPlant owns jumping or IDLE/WINDUP/RECOVERY attack phases, attachment
  support checks and liquid sinking. Pipe-contained plants are a separate path.
  PlantFireball uses native movement, precise shapes, a player area, terrain
  bursts and camera culling. SpriteCollision shares alpha/ellipse construction;
  SinkingEnemy and finite EnemyEffect nodes use SubArea's deferred ownership.
- MuncherPart converts giant SWE origins to a native lower-left cell, with typed
  mask/art data and two/four-cell editor geometry. Size undo restores dependent
  flags; runtime conversion intentionally receives neither editor flag.
  Muncher is an Entity with solid layer 1 and query layer 2, not an Enemy.
  Native ellipses, move_and_slide, floor queries and a lower-actor reference
  provide falling solids, columns, moving-platform carrying and crush contacts.
  Its source-specific hit capability allows the dedicated Spiny helmet/POW
  defeat while shells/fireballs treat it as terrain. Block bumps use the existing
  capability query. Size-specific EnemyDefeatStyle art reuses SwimmingEnemyDefeat.
  StompedGaloomba exposes a typed defeat capability for physical crush, cancels
  recovery and clears any holder before its body is freed.
- ThwompPart stores the source editor origin and converts it to native feet;
  ThwompVariant supplies per-size art, masks, triggers, gravity/caps and return
  speed. The giant window exposes the source size/type choice with an enabled
  legacy Grrrol entry, and the direction arrow cycles direct_t without a window.
  Thwomp is a native Enemy with source phases, per-direction triggers, block
  breaking/activation, enemy crush queries and the shared camera impulse.
  Hardness 99/stomp 2 flow through the existing stomp behavior. PlayerHelmet
  accepts a swept previous bottom edge. Its source falling-head guard and a
  two-step, geometry-bounded retreat bridge account for native Area latency;
  later side contacts still consume armor. The source helmet is non-solid.
  Precise source masks retain holes: small uses its explicit vertical mask,
  giant uses its selected sprite. Leading return probes preserve unrelated
  home/velocity components and cannot retrigger in the same Step. Liquid
  effects retain source one-tick retries/12-tick pairs and the instance/local
  sprite distinction recorded in the review. dead_h=1 defeat retains pose,
  facing and source origin with no horizontal motion or resulting spin.
- GrrrolVariant extends ThwompVariant's common editor data; legacy conversion
  remains on the Thwomp card, while GrrrolPart owns the new small/giant card.
  Dependent history includes position, direction and flags. Runtime Grrrol
  retains fixed ellipses while rotating only art, with distinct source/feet
  origins, source startup/night/water/drag/bounce policies and legacy-only
  peer turning. BlockBreakRequest is block-owned and shared with Thwomp:
  delayed breaks survive their requester, while area revision teardown cancels
  pending work. Grrrol uses the ordinary source corpse/death/activation APIs
  with its own allowed contacts, molten/culling and uncancelled-event policies.
- SpriteLibrary.ROTATION_MATERIAL opts converted full-PNG Grrrol, hammer/
  boomerang shots, Spiny needles, shell shake and spinning source corpses into a canvas
  shader. Four neighboring texels are blended only at screen-footprint edges,
  with premultiplied-alpha interpolation; cardinal axes bypass it exactly.
  It changes no vertices, transforms, physics or animation clocks and samples
  no previous frame. Mario, terrain atlases and UI retain existing sampling.
  rotation_render_test is a separate real-GL readback/capture probe; headless
  native regressions cannot verify shader pixels.
  Generic DeadEntity checks for converted full frames before applying it, so
  native fallback atlases keep their original material. The real-GL probe also
  exercises actual old Galoomba corpses and shell rotation.
- SpriteLibrary.contact_draw_y supplies the requested one-source-pixel contact
  overlap for existing grounded art. It caches the union of a reference rest
  animation's actual alpha bounds, including flipped margins and upward ceiling
  contact. Alive drawing uses this stable origin across frame changes; physics
  source origins, masks, queries, motion and saved positions remain separate.
  The already-correct small Muncher and modern Grrrol anchors are retained.
  enemy_grounding_test checks41 real settled floor/ceiling cases against rays;
  --enemy-grounding adds an actual OpenGL contact sheet.
- EnemyPartPreview aligns existing static enemy thumbnails to their native
  CollShape footprints with one source pixel of floor/ceiling/side overlap.
  Family refresh methods restore their source draw bases first; wings/parachute
  art follows the same correction, while direction controls, Part coordinates,
  footprints and SWE records stay separate. editor_grounding_test checks36
  cases, refresh stability, hold/drop and undo/redo against saved snapshots.
- PixelShadows is a drawing-only CanvasGroup behind Parts/runtime foreground,
  offset(2,2) world pixels. Its shader applies33% black alpha once to the union
  of current silhouette commands. frame_pre_draw uses Texture2D's immediate
  RenderingServer API so frame changes do not wait for the next redraw pass.
  Native texture regions, flips, inherited sampling/alpha and rotation materials
  are reused; starting ground shares GroundDrawer geometry. No gameplay actor,
  physics shape or animation clock is copied. UI/backgrounds and editor controls
  are excluded; native Z ordering of originals is retained. Source removal and
  edit/play transitions retire the corresponding commands. pixel_shadows_test
  is a separate real-GL readback probe, not a headless shader assertion.
  Source/copy draw signals now invalidate cached commands; unchanged static
  silhouettes retain their server commands, and distant sprites skip further
  synchronization work. Copies use WorldPresentation's displayed transforms.
- MontyPart keeps obj_monty_res's off-grid cell and adds the source +8 x offset
  only when building obj_monty_chase. It has no type variants, so its window
  exposes just the two flag toggles; Part._create_window accepts modifier-only
  parts. Monty drives its own horizontal chase (two-tick alarm, 116.64px/s^2 to
  90px/s, with the source asymmetric 60/90px/s underwater chase) and skips the
  shared slide via EnemyFlightProfile.manual_walk. Its BOUNCE wings use
  180/120px/s air/water hops. Flags are assigned before setup so parachute sway
  starts; per-instance flight rules preserve the other families. Native build
  adds (8,16) to the source Part, with no special ground-only placement rule.
  Parachutes reuse the shared sway/land handling. A normal stomp strips wings first,
  then defeats it for the source 200 points with spr_monty_deads.
  Its runtime body and player sensor now retain the source elliptical mask.
  MontyVariant extends EnemyDefeatStyle: frame2, native foot offset-8 and the
  rotating source bbox. Corpses retain facing independently of their impulse.
  Stationary partner comparisons preserve Monty's left+right/2 quirk; regular
  Bros use left edges. POW uses an exact zero vertical speed and smoke with no
  horizontal impulse. Spin stomps destroy either winged or ordinary actors.
- RockyPart keeps obj_rocky_res's off-grid cell (no popup in the pinned source)
  and adds the +8 x offset only at build. Rocky owns the ready/ready2 cycle:
  fall, pop, settle, 2px rise, 90-tick wait, 9px rise, windup, throw art, one
  obj_wrench, idle art, sink and repeat; it dies when its settled support is
  removed. Settlement resets the native home to surface+16, buries the body
  behind its support and uses the hidden pose's shorter 14x12 ellipse. Full-width
  post-pop sweeps and translated shape probes distinguish supported solids
  from static semisolids. Step-end liquid sampling includes lava; castle and
  poison produce a fixed-frame SinkingEnemy. SMW defeat is vertical and does
  not spin. Wrench is a plain Entity with resource-driven 12fps animation,
  alpha-union mask, exact arc overshoot/alarm boundaries and intentionally
  asymmetric source view culling. Deferred area ownership handles throws,
  liquid replacements and defeat effects. Its defeat API is ready for the
  future invincibility system; it does not give a helmet deflection response.
- HammerBroPart maps five obj_*bro_res IDs to typed Resources. Regular types
  expose four icons plus size/wings, while Sledge exposes size/wings/parachute.
  Size conversion retains flags and shifts source x; dependent undo restores
  position too. Native footprints validate the larger selected tool and drag.
  HammerBro owns independent throw/windup/recovery clocks, fixed throw poses,
  native platform passing/landing and runtime wing/parachute art. Lower-support
  probes, the two-platform random branch and room margin select jump height;
  full-width sweeps and solid clearance restore native platform carry. An
  airborne regular jump alarm deliberately does not rearm, matching the unused
  source alarm[0]. Sledge owns
  its 30-tick jump warning, one 60-tick wing hover and landing stun/effects.
  BroProjectile uses distinct masks, animated fire/ice, native wall/floor
  contacts, resource-driven water/air motion and gradual boomerang alarm phases.
  Distinct liquid entry/splash rules include ice's floor precedence, hammer's
  molten sink and the source beach-launch exception. Hammer rotates its mask
  as well as its art. Dedicated helmet responses do not award enemy points;
  held shells leave these shots alive. Bro liquid defeat uses SinkingEnemy's
  elliptical mask at the source origin, as do the runtime Bros and hammer.
  Ice retains its source offset rectangular mask. Piranha keeps its ellipse.
  Only boomerangs have the 6s blink/8s expiry. Shots use deferred area ownership.
  Shot origin culling precedes motion; hammer deliberately has no top edge.
  Boomerang alarm480 and caught-shrink removal also precede motion. A defeated
  owner cannot catch a returning shot. HammerBroVariant extends EnemyDefeatStyle
  with regular native offsets-13/type frames0..3 and Sledge offset-16/frame0.
- ChompPart maps obj_chomp_res/obj_chomp_b_res to small/giant ChompVariant data.
  Its modifier-only window owns size/wings/parachute; size replacement shifts
  source y-/+16 and resets both flags. Dependent history includes position.
  Selection/drag validation use16x16/32x32 bounds; SWE preserves fractional
  source coordinates and unknown data. The source build does not pass either
  flag to the runtime. Editor decorations stay separate from behavior.
  ChainChomp is an Enemy with a native elliptical head; four Sprite2D links
  have no colliders and sample pre-motion world history. The source's slot0/1
  duplication and7/14 spacing are retained. Only the head's drawing x rounds.
  Two-tick startup, cap/deceleration, wall/neighbor reversal and floor hops use
  seconds-based source constants. Ground probes also reject deep embedding.
  Full water, forest and beach retain distinct launch/cap conditions. Inherited
  swimming samples any liquid inclusively; .125/frame gravity overrides the
  parent's water gravity. Lava/poison creates only a source-origin head sink.
  Fireproof/recoil policies use the shared hitbox APIs. Typed defeat creates
  five SwimmingEnemyDefeat nodes through SubArea's revision-owned queue, with
  current head frame, wrapped chain frame, independent masks and source impulses.
  Source room culling precedes automatic motion. WorldDeath cancels startup,
  animation and history but retains the supported y-- event. Geometry probes
  prevent stale-floor drift while native motion is stopped. ActorActivity owns
  suspension/resumption. No tether/stake/release state exists in the pinned source.
- PlayerStunnedState locks controls for 80 ticks while retaining gravity,
  stops Mario before forcing a held drop at y-1/vx±60, and avoids a normal kick.
  PickupComponent polls overlaps and respects immunity plus the player's stun
  lock. Shells clear the 15-tick alarm; Galoomba's unused alarm6 retains the
  block until recovery, after which a fresh held actor gets normal alarm3.
  PlayerStunRules supplies the source duration and 15fps shake sprite at source
  Mario y+5. Repeated impacts refresh time without replacing its visual loop;
  state exit/replacement/retry disposes that player-owned effect.
  PlayerFrozenState holds the captured pose at the ice contact point, draws
  the source back/front ice layers and restores contacts at 180 ticks. Frozen
  players ignore stale enemy overlaps. A dedicated, nonblocking contact layer
  retains fresh ice-shot collisions; strict lava/poison entry thaws next tick.
  Frozen entry detaches carried items without a throw impulse, clears native
  pickup ownership and stops held-item turn tweens. Deferred detachment checks
  the area revision before reparenting, including immediate retry. The captured
  helmet frame/origin is retained with the saved direct at angle0 while frozen.
  Frozen Draw omits ordinary Mario/helmet's y+1, which returns after thaw.
  Blocked-growth headroom and crouch-animation updates also pause while frozen.
  Thawing and retry release state, contact proxy and graphics.
  Remaining recent-enemy fidelity gaps are in REVIEW-2026-10-20.md.
- WorldDeath is a Level-owned end-step policy, derived from
  obj_deadmario/Other_10. It stops selected bodies' automatic motion/gravity
  and animation without disabling their events or collisions. Enemy and the
  other physical families opt in through CharacterBodyExt; native move gates
  account for GameMaker's automatic movement occurring after all Step events.
  Family handlers cancel only the corresponding source alarms. Pending Bro
  throws/recovery and held-enemy recovery continue, while new throw/jump starts
  stop. Rocky's explicit rise/sink continues. Normal corpses and source smoke
  stop; boomerangs, plant-fire shots, splashes and the separate lava sink keep
  their own rules. Muncher drawing still uses the manager's banim2 clock.
  EnemyEffect marks source smoke separately from splash effects. SMW ice-shot
  bursts use ordinary smoke, without NSMBU's style-specific break sound.
- PlayerDeathState uses PlayerPhysics data for the 30-tick hold and 120-tick
  post-launch retry, on the same physics clock as movement. Its separate Draw
  has no normal y+1 offset or facing flip. It cancels power snapshots, releases
  held owners/tweens without a kick and preserves an externally owned pause.
  Level freezes the visible course time and camera, retains world processing,
  and clears the death policy on edit/retry. Deferred retry and held detachment
  validate the area revision. Source obj_mario queries for the recent enemies
  reject frozen, dead and goal replacements; frozen Mario cannot trigger Thwomps.
- Level.animation_time supplies the common banim2 clock. CameraImpulse owns
  finite source impact offsets and teardown; Utility.camera_effect composes a
  render-only offset with the tracked camera, including zoom compensation.
  Giant Muncher impacts use this plus the original finite sound effect.
- ActorActivity belongs to each SubArea. CharacterBodyExt tree entry and the
  ordinary add path weakly register source obj_deactivation descendants,
  including carried/replacement actors and block-sprouted mushrooms. The
  resource controls a two-tick end-step scan, camera x±128 and room-height
  vertical margins of 96px. Deferred revision-checked changes suspend native
  processing, animation, visibility and collisions and restore saved modes.
  Bounding boxes determine membership. Fire/ice shots inherit the strip;
  independent projectiles retain their own culling. Native terrain connection
  and collision generation stay with GodotWE; terrain/background/sound-parent
  activation is not claimed by this actor module.
- LiquidSurface belongs to SubArea, outside the disposable foreground. Its
  initial position is water_start_y+12; source speed, phase and two-second
  holds drive movement. Retry/edit reset it before Parts build. SWE stores
  water_level/water_level_limit with the 432px coordinate offset and validates
  the 0.2/0.5/0.8 speed table. Native source sprites draw the tiled surface and
  body. This foundation supplies actor depth checks; full player swimming,
  liquid damage, special mounts, editor handles and other theme content remain.
  Source contact bounds follow camera x and scale the theme's sprite bbox x24:
  forest/beach water is 768x16, lava/poison 384x16. Visual tiling remains separate.
- PlayerHelmet is created with Player, initially inactive; deferred monitoring
  activation avoids creating physics nodes in a collision flush. Empty wearable
  shells equip it from above or when held with Down. It has separate armor,
  head deflection/block activation, source small/super art/offsets and sounds.
  SMW goal pose uses the original helmet frame with the overlay hidden.
  HelmetRules now chooses Buzzy/Spiny collision, sounds, defeat policy and goal
  frame. Spiny defeats Enemy/shell objects, deflects other held Entity types and
  gives the same independent one-hit armor. Shape changes are deferred at equip.
  Buzzy/looking-up silhouettes are frame-specific, while normal Spiny uses an
  ellipse. Source bbox metadata is separate from the silhouette. Drawing-only
  flips, wobble and y+1 do not transform collision geometry. Direct callbacks
  use shape checks and coalesced deferred sensor replacement. SpriteCollision
  merges opaque pixel runs into convex shapes to preserve faint alpha/holes.
- Player.set_powerup_hitbox queries native stand-up room and retains the short
  mask/duck pose until a low ceiling clears; upward growth ignores one-way
  platform undersides. Feet stay fixed through growth/shrink. Original held-duck
  art and helmet offsets stay aligned. AnimatedSprite.animation_changed applies
  the source origin synchronously, and transformation snapshots retain their frame.
  The source's y+1 drawing offset retains one pixel of floor overlap, separately
  from the unchanged feet/collider. Source walking-frame bobbing is preserved.
- PlayerAnimationRules and play_ground_animation share source distance-based
  cadence for moving/coasting/held walking: abs(vx)/5, capped at 18fps. SpriteFrames
  remain cached and per-instance speed_scale supplies the rate; render delta
  never multiplies it. Actual frame counts pass at 30/60/120 render rates.
- Player's existing camera follower runs immediately after its body movement
  in _physics_process. Updating it in _process makes Mario move backwards
  between 60Hz body steps on faster renderers. Fixed-screen/fixed-pose OpenGL
  captures verify stable pixels independently of animation and collider state.
  The existing Level camera clamp commits synchronously before physics-side
  culling; its deferred render clamp still supports editor camera gestures.
  WorldPresentation subsequently interpolates actor translations and this
  physical camera together immediately before drawing. It writes actor canvas
  transforms without moving collision nodes. Utility.camera_render_offset
  keeps AI/activation on the physical camera, while Background parallax uses
  the same display correction. Pauses retain the displayed pose, resumes seed
  from it, large teleports snap, and editor/reparent transitions clear history.
  Pose basis changes and render-time effects remain instantaneous. Global
  engine interpolation stays disabled; physics_jitter_fix is0 for this path.
  See SMOOTHNESS-2026-10-21.md for timing and input-latency limitations.
- PowerupAnimation owns a transformation's bound tween, old-sprite instance ID
  and prior tree/music pause state. Completion, superseding animations and tree
  exit cancel cleanly; no callback retains an already-freed sprite.
  The outgoing frame is a static Sprite2D snapshot, since an AnimatedSprite2D
  duplicate re-runs autoplay when entering the tree. Both visibility flags
  switch in one callback, preventing double drawings from bool interpolation.
  Damage/other default transform phases last6/7/7/7/7 ticks. Normal SMW mushroom
  growth follows the user's latest2026-10-21 correction: use the original big
  texture immediately and only change scale.y, including its final full-size
  pause phase. No small snapshot is shown and no intermediate pixels are
  generated. Standing heights are24/20/26/20/28. A texture-bottom pivot retains
  feet+1px through every scale.
  The five growth phases last6/5/5/6/6 ticks as a visual reconstruction of the
  supplied clip; these are not extracted Nintendo parameters. Duck/held-duck
  growth uses the original big crouched art with those same height ratios,
  never exceeding its unscaled height. Exactly one drawing is visible and
  the temporary pose is released on completion/cancellation/tree exit.
  Replacements cancel the preceding pause before snapshotting; instant changes
  cancel it as well.
- PlayerMovingState distinguishes the full-run skid pose/sound from brisk-walk
  braking dust. Walking dust uses an eight-tick physics cadence; running dust
  uses five ticks (the user rejected the denser three-tick attempt) and stays
  in that mode through the braking episode's slow
  final steps. Actual incoming speed selects it, rather than the Run key alone.
  Neither mode uses timer callbacks.
  Its dedicated looped audio stops on state/condition exits and before a power
  pause. SkidSmoke uses a per-instance canvas shader for filled rounded lobes,
  rapid growth, a separating small puff and contraction, based on the user's
  SMM2 recording. White interiors remain opaque; screen derivatives smooth
  the outline. This Node2D effect is outside the world-sprite shadow copier.
  Walking puffs stay at their ground anchor for300ms. Running puffs live180ms,
  start closer to the shoe (2px vs4px behind travel), and remain at their emitted
  world position. The latest user request removes all foot-following, including
  the previous weak target/priority mechanism. Both modes start at feet+1px and obey the
  shared smoke death policy. No actor motion or camera interpolation changes.
- SpinThump draws just the full-size white source frame and varies its size
  continuously around the fixed impact center, peaking at50ms and shrinking
  away within the previous4/21s lifetime. It no longer changes flipbook frames.
  Player.spawn_spin_thump inserts into SubArea's revision-owned foreground,
  so pending contact effects and editor-return cleanup follow the actor contract.
  It is a drawing-only Node2D, outside the world-sprite shadow copier.
- SpinSmoke keeps its central smoke animation, finite sound and four outward
  star trajectories. Each star now grows from20% to full size in55ms, then
  contracts over the remainder of the existing16-tick travel. Size is sampled
  directly from current tween progress, avoiding a stale render-frame scale.
  Cleanup waits for the smoke animation's finished signal, travel and sound.
- Voluntary crouching is independent of the existing blocked-growth crouch.
  Down selects source small/super (and held) art and12x13/12x15 masks with
  stable feet. Ground motion coasts to a stop; ordinary crouch jumps preserve
  the mask until descent/clearance permits standing. Ground and buffered spin
  gates share that condition. Helmet visual/sensor offsets follow each head.
- HammerBroVariant caches a60px palette icon from an independent alpha-cropped
  source region, fitting the visible body to48px without changing aspect or
  touching native preview/runtime source images. Palette/card/type-window
  routes share it; initialization tolerates the autoload startup order.
- CharacterBodyExt removes freed bodies from last_collided before typed-array
  lookup, so a disappearing ceiling/block cannot leave an invalid collision ref.
- Enemy.hit_by_projectile exposes accepted/rejected hits; Buzzy fire resistance
  is a policy used by that API, while full fireball/player-power content remains
  unported. Explicit kill() bypasses such projectile policy.
- Question blocks restore `sprout=0` (coin) and `sprout=1` (mushroom).
  `MushroomSprout` uses the existing `RiseSprout` animation.
- `Level.complete()` emits one completion event and stops the level clock.
  `SMWGoalSequence` selects `PlayerGoalState`, plays the local SMW clear music,
  walks at up to 90px/s to end-ground +106, turns left, converts time starting
  at reference frame 240, poses at 440, and finishes at 560. Editor test-play
  returns to editing; Coursebot play returns to Coursebot. Standalone hosts
  receive `completion_finished`. No placeholder result panel is added.
  Timer expiry and void death still use the local retry path.
- Headless regressions cover the full input-driven course, interactions,
  loader compatibility/concurrent requests, sprites, player physics, SWE
  save/reopen, terrain editing, the actual editor flow and the clear sequence.

## Conventions for new systems

- SMWTheme reads resources/content/smw_themes.json for SMM1's six course themes.
  resources/content/smw_ground_frames.json maps RAW sprite frames to the native
  atlas. Never use SWE_GROUND_FRAME_TABLE for this: its saved indices diverge
  at43. Raw43=filled,44=isolated,45=vertical,46=horizontal; underground50+
  include diagonal pieces. GroundPart's53-choice topology stays
  authoritative. SubArea.set_theme replaces environment nodes and refreshes
  authored art without rebuilding Parts. EditorHistory stores the whole theme/
  liquid state, and MusicPlayer follows edit/play lifecycle. The existing SWE
  aliases persist this selection. See THEMES-2026-10-22.md for source clocks,
  castle-entry initialization, theme slope adaptation and bounded scope.

- SlopePart/GentleSlopePart share fixed-angle endpoint geometry and native
  history. GroundPart.refresh_all updates slope adjacency and terrain-contact
  fusion floors before its existing
  occupancy/atlas pass. Diagonal-only texture sampling preserves paired grass
  fringes and unscaled soil; ordinary cells retain the53-choice decision tree.
  SlopeBody owns native thin ribbon polygons. Exact convex decomposition also
  governs editor clearance; no hull/triangle blocks empty space. Authored ground
  intersecting a ribbon gets derived clipped art/runtime polygons, restored on
  slope removal. Slope grass overlays square terrain independently of placement
  order. Native53-rule atlas variation uses a coordinate-seeded local RNG;
  unchanged GroundParts/slopes retain their cached art during global refresh.
  Optional per-theme16x32 steep and32x32 gentle PNGs are documented in
  textures/tiles/slopes/README.md; root gentle files remain overworld aliases.
  See SLOPES-2026-10-22.md for the project-only SWE contract and remaining scope.
  Eight-neighbour terrain components identify actual ribbon contact. Contacted
  components project their column tops to the slope across its footprint,
  including deep concave profiles. Independent islands cannot activate fusion.
  The previous sub-cell-only rule missed the user's two later screenshots.
  The resulting
  outline also drives editor selection/clearance and runtime collision. Native
  atlas body pixels retain exterior grass; the old7px grass probe and broad
  24px native-terrain dirt overwrite are removed. slope_fusion_test checks the
  reported single-cell chains and both irregular pillar/concave profiles.
- In slope courses, WorldPresentation includes a native center-foot surface
  sample in actor display transforms. It interpolates that correction and
  shares the resulting hierarchy with PixelShadows; it never moves physics.
- SpringPart builds an ordinary portable Spring with PickupComponent, a
  one-way child surface and the source four-frame compression clock. The
  PlayerSpringState holds contact for nine ticks, then enters existing native
  ordinary/spin jump states with the source impulse and variable jump gravity.
  WorldPresentation anchors a spring rider to the displayed source frame's
  stepped top after both body transforms are interpolated. PixelShadows uses
  the same transform. Physics and source sprite pixels are unchanged.
  See SPRING-2026-10-22.md for release/save contracts and bounded scope.


- One folder per system under `scripts/`; no new top-level dumping grounds.
- Content tables (enemy stats, per-style physics, palette entries) are
  `Resource` files under `resources/content/`, not constants in scripts.
- Runtime nodes are built from `Part` classes; `Part` classes own editor
  behaviour only.
- Public API gets doc comments; behaviour that mirrors an OpenWE script links
  the source path in a short comment (e.g. `# Ported from scr_mariojump.gml`).
- Every ported system gets a minimal test scene under `tests/scenes/` once the
  test harness is added.
