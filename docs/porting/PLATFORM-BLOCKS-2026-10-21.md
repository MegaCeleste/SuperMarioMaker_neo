# Spike cadence correction and SMW platform blocks — 2026-10-21

The user reported overly fast spike animation and authorized continuing after
the fix. This round corrects the clock, then implements ordinary SMW donut
platforms and note blocks together. The pinned OpenWE reference remains
read-only. No Antigravity, subagent, commit, push or publication was used.

## Spike correction

The previous SpikeTile let AnimatedSprite2D play at the converted resource's
60fps default. obj_pinchos/Draw_0 instead uses levelmanager.banim3, advanced by
0.1 per60Hz tick in Step_2:6fps, one frame change per10 physics ticks. Runtime
spikes now sample the existing Level.animation_time at6fps and never autoplay.
Late-created spikes inherit the same phase. The test verifies30 consecutive
ticks, three changes, late creation and transformation-pause behavior. This
supersedes the prior terrain batch's still-image-only animation acceptance.

## Native contracts

| Source | Implementation |
|---|---|
| obj_donut_res, obj_donut; spr_mask_donut | DonutPart enables terrain page1 slot4, with source editor/runtime/falling art and the16x5 one-way mask. Thirty continuous player-loaded ticks start the fall. Leaving during warning cancels/reset clocks and art. Source2px,4-tick shaking moves the mask/art within the body, retaining stable Mario x; it must not become native platform carrying velocity. |
| obj_donut alarms0..3, Step_2 | Air gravity360px/s²,150px/s pre-gravity cap, native downward rider carry, and terrain pass-through. Below native room y64 it hides/disables collision, waits180 ticks and creates a fresh body at the authored origin, growing from0.2 by0.05/tick. Replacing the body follows Alarm1 and avoids a return teleport imparting huge platform velocity. |
| obj_noteblock_res, obj_noteblock | NoteBlockPart enables page1 slot5. NoteBlock is a moving16x16 solid, animated from the source shared9fps clock. A top rider compresses it downward8px at2px/tick, then returns; a head bump uses the opposite stroke. At tick10 it releases contents/launches a rider; after two recovery ticks it can be retriggered. |
| obj_noteblock Alarm1, Mario jumpnow | PlayerNoteState briefly follows compression through native movement with gravity suspended and only the note collision excepted. Walking off, death, state replacement and freed blocks release that ownership. Normal/spin launch uses existing player states, consuming a one-shot external speed of300px/s (180 in the underwater theme). Held Jump extends the bounce with the existing variable-height profile; eligible Spin selects spin jumping and retains Fire Mario's spin shots. The note stays active after its contents are empty. |
| obj_noteblock Other14 | Supported falling native actors use a313.5px/s upward impulse,30 if blocked above, halved in water. Special projectile/Thwomp/Rocky/fish and held/ceiling policies are excluded. This is not a generic enemy defeat or shell score event. |
| obj_noteblock Other10/11; obj_powerupsprout_note | Top compression ejects a stored powerup downward; a head bump ejects upward. A block-owned two-tick release creates the existing mushroom/ordinary-progressive flower/star/1UP, with the source upward300px/s or water120px/s launch and right-facing mushroom motion. Blocked exits smoke instead of inserting a trapped actor. Runtime contents clear once; retry/edit discards pending releases. |
| Native editor/SWE | Both Parts reuse painting/history, signed formats and unknown-field preservation. Note powerups are dragged in and inspected/extracted through the existing container window, with atomic undo. Empty notes use SWE sprout0; runtime empty remains a reusable note. Coins are not mapped to a multi-coin note slot because the pinned note factory has no coin creation branch. |

WorldPresentation includes both moving block bodies so120Hz display stays
synchronized with their passengers. PixelShadows discovers their ordinary
sprite nodes. No new draw/collision system or external helper is introduced.

## Grouped verification

```powershell
python -I tools/porting/prepare_slice.py
python -I tools/porting/run_tests.py --import
python -I tools/porting/capture_slice.py --platform-blocks --fps 60
python -I tools/porting/capture_slice.py --platform-blocks --fps 120
```

platform_blocks_test covers both signed formats/unknown fields, palette/history,
all five supported note powerup insertions, invalid coin drops, extraction undo,
donut warning cancellation/stable rider x/falling carry/return/growth, normal/
held/spin player bounces, physical compression/head bump/enemy rebound, actual
head-triggered contents, both release sides and pending release cancellation.
terrain_basics_test adds the spike cadence/late-creation/pause oracle.

Actual-GL platform mode runs the native contact matrix, saves editor/runtime
overviews, and checks30 rendered spike ticks at both render rates. Still
captures alone do not prove cadence. Logs/images stay in ignored
.godot/porting-tests/. Final acceptance is recorded in HANDOFF.md.

Import, five metadata checks and all51 native regression scenes pass. Final
actual GL60/120 editor/runtime captures pass and were visually inspected.
The spike probe compares every opaque rendered source pixel across30 sampled
physics ticks and observes exactly three frame changes at each render rate.
Its canvas transform is sampled in frame_pre_draw after WorldPresentation;
reading a later canvas/clamp value produced a false120Hz mismatch. Fixing the
sampler did not alter gameplay/rendering. Retained editor/runtime images and
matching logs have_60/_120 suffixes in .godot/porting-tests/.

Current generated inventory:291 scripts /152 scenes /36,892 GDScript lines.
Preparation selects220 sprites/770 frames and31 gameplay sounds. The additive
manifest contains233 sprites/816 frames.

Wings/other attachments, musical-note variants/instrument sounds, other styles
and broader machinery remain future work. Existing underwater player physics
is not expanded by the note's source launch-speed branch. This is a bounded
SMM1 basics batch, not complete OpenWE interaction parity.
