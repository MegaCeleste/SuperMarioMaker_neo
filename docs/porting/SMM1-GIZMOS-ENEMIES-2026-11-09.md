# SMM1 gizmos and enemies — 2026-11-09

The user selected four groups of SMM1 SMW content in one round, with OpenWE
and SMM2 as the reference: the P-switch and POW block, the Bill Blaster and
Fire Bar, lifts and the bridge, and Boo, Bob-omb and Dry Bones. Work is on
branch `feat/smm1-gizmos-enemies`, one commit per group.

## P-switch and POW (`gizmos_test`)

- `CarryBlock` (new) is the shared carryable 16x16 block: gravity, friction,
  kick/throw releases like the spring, and a one-way top Mario can stand on.
- `PSwitch` (obj_pswitch, obj_pswitch_press): Mario landing on it presses it
  (SMW thud `snd_door_close`, flattened switch for 8 ticks).
- `PSwitchTimer` (obj_levelmanager Other_11/Alarm_10/Step_2): 600 ticks of
  `snd_switchsong`, `snd_switchalert` once 100-120 ticks before the end; while
  it runs every coin becomes a turn block and every plain turn block (no
  contents, not spinning, not used) becomes a coin (obj_coin/obj_flipblock
  `convertirse`). The end swaps exactly those objects back and restores the
  course music. A second press restarts the clock.
- `PowBlock` (obj_block_pow_hold/active): goes off when Mario bumps it from
  below or when a thrown POW first lands or hits a wall. Screen shake,
  `snd_pow`, the explosion sprite; on-screen enemies standing on the ground
  (hardness < 99, not Thwomps) are defeated; on-screen coins become falling
  `PowCoin`s (obj_coin_pow). POW frames cycle at 9fps; gravity 0.2px/tick².
- Saved as NIVEL `obj_pswitch_res` / `obj_pow_res`; Gizmos slots 3 and 4.

## Bill Blaster and Fire Bar (`hazards_test`)

- `BillBlaster` (obj_bullebill_base): a solid column, 2-5 cells in the Part
  window (loaded rows keep up to 18). First check after 90 ticks; fires at
  Mario when he is within 256px on that side, not more than 160px above, and
  the cell beside the head is clear; 192 ticks after a shot, 15 while its
  last bullet on that side lives, 60 when idle. `snd_explode` and smoke.
- `BulletBill` (obj_bulletbill): 1px/tick straight through terrain;
  stompable; removed 96px outside the view.
- `FireBar` (obj_firebar): solid base, 4/6/8/10 fireballs (source size_x,
  steps of 2) 8px apart, 1 degree per tick, clockwise toggle (direct_t);
  each ball hurts Mario at two points ±4px; a starred Mario passes.
- Both are native `PLATAFORMAS` rows (`obj_bullebill_base_res` with height,
  `obj_firebar_res` with width/color angle/direct_t). `LevelProcessor.
  PLATFORM_PARTS` maps PLATAFORMAS ids to Parts with `read_platform` /
  `write_platform`; unrepresented rows stay as unknown data. Gizmos 5 and 6.

## Lifts and bridge (`platforms_test`)

- `Lift` (obj_plataforma): 4-cell one-way platform; the Part window picks
  the first direction (down/right/up/left); 0.6px/tick, turning back 32px
  up/down or 48px sideways from the start. Mario rides it.
- Falling lift (obj_plataforma_blue): falls 15 ticks after Mario stands on
  it, 0.06px/tick² to 2px/tick, and returns at its start 180 ticks after
  leaving the room.
- `Bridge` (obj_puente_res, obj_modelsizable type 2): 3/5/7/9 cells; one-way
  surface on the sprite origin line, theme art like obj_puente_res Step_2
  (snow day/night, night set for dark themes and night).
- Rows: `obj_platform_res` (direct_t), `obj_platform_blue_res`,
  `obj_puente_res`. Lift in Gizmos 7, bridge in the Terrain bridge slot.
- The lift moves unsynced in the physics step: a synced AnimatableBody2D
  stalled once the rider it carried pressed against something.

## Boo, Bob-omb, Dry Bones (`enemies_test`)

- `Boo` (obj_boo, Other_18): accelerates 0.015px/tick² toward Mario up to
  0.4px/tick only while he faces away; otherwise hides (frame 1) and slows by
  0.025px/tick. Passes through terrain; not stompable; fireproof; star
  power defeats it.
- `BobOmb` (obj_bobomb, obj_bobomb_ready, obj_explosion): walks like a
  Galoomba; a stomp lights it, it stops and explodes 300 ticks later; the
  38x38 blast (`snd_explode`) hurts Mario, defeats enemies and breaks turn
  and hard blocks.
- `DryBones` (obj_drybones, obj_crumblebones): walks 0.5px/tick and turns at
  ledges; a stomp collapses it (`snd_crumble`): standing frame 8 ticks, heap
  200, ten 5+5-tick shakes, 8 ticks, then it stands and walks. Collapsed
  bones cannot be hurt; fireproof; a POW or star defeats it.
- NIVEL `obj_boo_res`, `obj_bobomb_res`, `obj_drybones_res`, in the enemy
  palette's Boo / Bob-Omb / Dry Bones placeholder slots.

## Verification

- Four new native scenes (`gizmos_test`, `hazards_test`, `platforms_test`,
  `enemies_test`); `editor_history_test` lists the new Parts. Full suite:
  62 scenes plus import and sprite conversion pass.
- `python -I tools/porting/capture_slice.py --smm1-round` renders all nine in
  the editor and in play (`.godot/porting-tests/smm1_round_*.png`); inspected.

## Known limits

- Fixed widths: lifts are 4 cells; bridge/cannon/fire bar sizes come from a
  few Part-window choices rather than drag-resizing. Loaded rows keep their
  own sizes. The fire bar start angle is not editable (loaded rows keep it).
- Dry Bones does not throw bones (the source's bone-throwing pause is not
  ported). Wings, parachutes and ceiling variants are not offered.
- The P-switch does not make blue coins or affect ON/OFF content; the switch
  song does not coordinate with a running Super Star song.
- Bob-omb blast breaks turn and hard blocks only; other block kinds are left.
- Other game styles' art is not converted.
