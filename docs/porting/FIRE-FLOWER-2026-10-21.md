# SMW Fire Flower — 2026-10-21

The user selected **now** for this bounded SMM1 content item after the startup
fix. This round implements ordinary and progressive ground-based Fire Flowers,
native editor placement, question-block contents, undo and signed SWE data,
Fire Mario and his bouncing projectiles. Other styles, winged flowers and
other powers remain future work. No reference checkout/assets were committed,
and no Antigravity, external agent, push or publication was used.

## Reference and native implementation

The source remains OpenWE2f84414054c576bf7ca03dfa33b244ee730d57da.

| Source contract | Native implementation |
|---|---|
| obj_fireflower, obj_powerupparent: SMW9fps art, falling/stationary floor contact,1000-point collection; duplicate flower retains Fire Mario | FireFlower owns precise alpha-union collision shapes, area context, pickup guard and the native actor/death lifecycle. |
| obj_fireflower_res/progresivo: visible progressive flowers become mushrooms while Mario is small | FireFlowerPart offers ordinary/progressive types with the original two preview frames. Runtime replacement uses the area-owned deferred spawn path. |
| obj_qblock_res sprout2/progresivo | QuestionBlockPart has four stable content IDs: coin, mushroom, flower, progressive_flower. Legacy contains_mushroom callers/scenes still work. FireFlowerSprout uses the existing rise/tween mechanism and binds Entity context at insertion. |
| Mushroom/flower body behavior: no downgrade when the power is already present | An ordinary flower upgrades either small or Super to Fire. Another flower or mushroom grants its reward/sound without another pause or downgrade. |
| obj_mario/Other10 default powered damage chooses mushroom | Fire damage changes to Super with the existing atomic snapshot pause and immunity. Existing helmet, freeze and small/Super damage behavior remains separate. |
| Alarm10: just-pressed run/throw, unheld/non-duck/non-skid/non-spin, fewer than two shots; source x±14,y+12 | FirePowerup polls the existing action, keeps the native movement states and applies the original shoot pose for9 ticks. Source y+12 maps to native feet-20. Counts include deferred shots, so insertion cannot admit a third. |
| Alarm7/8: spin first shot after10 ticks, second10 later; horizontal4.5/-4.5; bounce restarts first alarm at5 | The existing spin state arms FirePowerup; shots move at270/-270px/s with source facing-based8px offsets. Ordinary shots move at180px/s. |
| obj_fireball/Other14: gravity0.2, max4, floor bounce-2 and y--; distinct from Bro fire's bounce-2.2 | PlayerFireball uses720px/s²,240px/s cap and-120px/s bounce, a precise source mask, native solid/one-way collisions and the existing display interpolation/shadows. This is a separate controller from BroProjectile. |
| Enemy fire policies and Other0 smoke/bump | Native enemy hit_by_actor/fire policies choose susceptibility, fireproof bodies and their typed defeat. A successful hit awards200; both accepted and blocked hits consume the shot. Walls/embedded spawns burst; source32px camera limits cull shots. |
| Floor support precedes liquid; water retains player-fire gravity; castle/poison entries splash/remove | PlayerFireball keeps these source distinctions. FireFlower also uses native liquid/death cleanup. |
| Existing flower on a bumped block rises or is crushed under a ceiling | The existing block query includes the item layer. FireFlower responds with its source upward impulse/headroom check. |

Small-to-Fire growth follows the user's latest big-texture clarification:
immediate original Fire Mario art, vertical24/20/26/20/28 standing heights,
stable feet and unchanged source pixels. Super-to-Fire and Fire-to-Super use
the existing exclusive old/new pause. Fire art covers walking, running,
crouching/held crouching, jumps/spins, carrying, kicking and all three SMW
goal/helmet poses through the shared catalog; movement physics remains60Hz.

## Validation

`fire_flower_test` covers native palette/hold window/place/variant undo-redo,
legacy and S0/S1/S2/S4 signed save/reopen with unknown fields, real pickup
contacts for small/Super/duplicate powers, fixed physical feet, run input,
held-button repeat suppression, shot limits including deferred insertion,
left/right/spin shots and pose recovery. Real floor/wall/embedded and
Galoomba/Buzzy contacts distinguish bounce, burst, defeat, resistance and
scoring. It also exercises ordinary/progressive block release, supported-item
bump, water/lava differences, physical death stop, same-step retry and leaving
during growth. The shared rise sprouter disposes an uninserted child on exit.

Commands (repository root):

```powershell
python -I tools/porting/prepare_slice.py
python -I tools/porting/run_tests.py --import
python -I tools/porting/capture_slice.py --fire-flower --fps 60
python -I tools/porting/capture_slice.py --fire-flower --fps 120
```

Logs and the actual GL contact sheet remain under ignored
.godot/porting-tests/. The contact sheet is slice_fire_flower.png; each run
overwrites it, and capture_fire-flower.stdout.log records its renderer run.
Final import, five metadata checks and **all46 native regression scenes pass**.
Actual GL Fire Flower runs at60/120fps also pass; inspected sheets are preserved
as slice_fire_flower_60.png and slice_fire_flower_120.png. These are correctness
checks, not new frame-pacing or input-latency measurements. Current generated
audit:260 scripts /136 scenes /33,573 GDScript lines.
The actual-GL configured startup/editor/play/return probe also passes after
this content round (--startup-flow at60fps).
A verbose native exit check identified retained Ogg/WAV/audio-playback objects
only, consistent with prior engine shutdown diagnostics; no new retained
gameplay nodes/textures were found. The certificate-store diagnostic also
remains distinct from script failures. No native OpenWE binary comparison is
claimed by this local source/GL verification.
