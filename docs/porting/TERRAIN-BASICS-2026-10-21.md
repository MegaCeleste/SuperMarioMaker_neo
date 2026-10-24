# SMW terrain basics — 2026-10-21

The user continued the SMM1-first work and requested grouped implementation
and validation. This bounded batch enables spikes, ice blocks and cloud
platforms. It does not select the entire OpenWE backlog. The reference remains
OpenWE2f84414054c576bf7ca03dfa33b244ee730d57da, read-only. No Antigravity,
subagent, commit, push or publication was used.

## Source contracts

| Reference | Native implementation |
|---|---|
| obj_pinchos_res, obj_pinchos; spr_pinchos / spr_pinchos_swin | SpikePart enables terrain page0 slot4. SpikeTile is a14x16 rectangular solid at source x+1..14, y0..15, with original animated SMW art. Floor/side contacts use Player.damage, retaining downgrade, armor, immunity and star policies. Upward head contacts are protected by either existing shell helmet without consuming it. It is not a stompable enemy. Underwater uses its source alternate art. |
| obj_ice_res, obj_block_ice / obj_rockparent | IceBlockPart enables page1 slot7. IceBlock inherits the existing hard-block native solidity, head bump, Spiny-helmet/giant impact and block-owned delayed breaking, overriding only the original ice/shard sprites. It has no contents. Fire Mario's shots retain their terrain bounce; this is not a frozen-coin block. |
| obj_mario/Step_0 and Other_12 snow branch | Only an actual supporting foot strip over IceBlock selects ice traction. Ground acceleration is180px/s², reverse braking108, coasting18 and crouch braking36, converted from0.05/0.03/0.005/0.01px/tick² at60Hz. Horizontal caps and overspeed decay stay shared. Air control immediately uses the existing ordinary profile. No new night-theme behavior is introduced. |
| obj_nube_res, obj_nube, spr_square_b | CloudPart enables page1 slot6. CloudPlatform has a16x5 native one-way collision shape, with16x16 original art and the source underwater frame. Mario, enemies and powerups pass upward and land from above. Down-attacking Thwomps consume the touched cloud, play smoke and enter their existing impact wait. |
| scr_edit_to_play and signed SWE IDs | The three Part factories, palette entries and native serializer/loader use obj_pinchos_res, obj_ice_res and obj_nube_res. Existing placement, painting, move/erase/history and unknown-field preservation are reused. Runtime bodies are disposed on retry/editor return. |

Cloud crushing is dispatched from Thwomp's actual post-motion stop condition.
Enemy._physics_process does not emit StaticBodyExt collision notifications;
the first grouped probe caught an ineffective cloud-side callback. That
callback was removed, without changing generic enemy collision emission.

## Validation

terrain_basics_test covers both signed SWE formats, unknown fields, all three
palette slots, native placement/move/erase undo/redo, actual ice coasting and
air/normal-ground transitions, converted ice constants in both directions,
delayed ice fragmentation, Mario rising through/landing on clouds, side passage,
enemy/powerup landings, Thwomp crushing, repeated spike damage after immunity,
Super damage, both protected helmet heads, star support and retry/edit cleanup.

```powershell
python -I tools/porting/prepare_slice.py
python -I tools/porting/run_tests.py --import
python -I tools/porting/capture_slice.py --terrain-basics --fps 60
python -I tools/porting/capture_slice.py --terrain-basics --fps 120
```

Actual-GL mode saves terrain_basics_editor.png and slice_terrain_basics.png in
ignored .godot/porting-tests/. These are functionality/art correctness probes,
not frame-pacing or input-latency measurements. Final acceptance is recorded
in HANDOFF.md.

Import and five metadata tests pass. The aggregate50-scene run passed49 and
caught a stale editor_history_test supported-Part list. The list now includes
the three implemented Parts; its clean focused rerun passes. The other49
results were retained. Final actual GL60/120 captures pass and were visually
inspected. The overview reloads the fixture after the contact matrix, clearing
legitimate helmet debris/star trails before rendering the terrain overview.
Editor/runtime images and matching logs retain_60/_120 suffixes. Current
generated inventory:284 scripts /149 scenes /36,097 GDScript lines.
Preparation selects216 sprites/762 frames and30 gameplay sounds; the additive
manifest has229 sprites/808 frames. The reference checkout remains clean.

Resizing/connected semisolids, conveyors, moving platforms, item attachments,
frozen coins and other game styles remain future work. The pinned source's
room-boundary spike extensions and broader environment/attachment machinery
are not added by this ordinary terrain batch.
