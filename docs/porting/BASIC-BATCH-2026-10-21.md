# SMM1 basics batch and actor contacts — 2026-10-21

The user requested several features before one combined validation round.
This batch selects ordinary SMW1UP, hard blocks and hidden question blocks.
Two later corrections are included: contents enter containers by dragging a
loose item into them, and existing enemies/items need their missing contacts.
The stored-content icon was also enlarged after the user reported its16px
presentation as too small. No Antigravity, subagent, commit, push or publication
was used. The pinned OpenWE reference remains read-only.

## Implemented contracts

| Reference | Native behavior |
|---|---|
| obj_1up_res / obj_1up; constant-18 | OneUpPart enables item slot8, builds the ordinary SMW1UP, and supports signed SWE/history. It starts walking right after settling, reverses at walls/resting carryables, uses source air/water gravity/caps and precise alpha-union mask, and disappears in lethal liquid. Pickup adds one session extra_lives reward without changing power, score or pausing. Source snd_1up and spr_points frame8 provide feedback. Death/retry/editor cleanup uses existing ownership. |
| obj_rock_res / obj_block_rock / obj_rockparent | HardBlockPart enables terrain page1 slot2. Native16px solids retain rock art or wood in mansion/airship. Ordinary head bumps and small Thwomps do not break them. Giant Thwomps, existing rolling breakers and Spiny-helmet head bumps arm a block-owned next-tick break, using the proper rock/wood shards. They are not item containers. |
| obj_block_hidden_res / obj_block_hidden | HiddenBlockPart enables terrain page1 slot3 and retains the source's editor outline. Its runtime sensor has no art or solid body until an upward Mario/shell head crossing; side/downward passages do not reveal it. Reveal produces a solid used block and releases the authored content once through the existing sprout lifecycle. |
| block_res / qblock_res / block_hidden_res resource collisions | ContainerBlockPart shares content IDs, previews and sprout factories across turn, question and hidden blocks. Supported inserted Parts are coins, mushrooms, ordinary/progressive flowers, stars and1UPs. Dragging consumes the loose Part and replaces prior contents in one history action. Undo restores the original Part, cell and unknown data. Palette placement on the container uses the same insertion policy. |
| resource hold window | Long press shows only the stored content, with an enlarged64px nearest-filtered icon. Its content icon starts a drag out; releasing elsewhere records extraction and final cell as one undo action. An invalid drop returns the item to its source container. Other objects keep their normal variant/attachment windows. Old stable-ID methods remain for serialization/history compatibility, not a visible contents picker. |
| scr_sprite_get_constant_res / scr_edit_to_play | Contents use mushroom1, flower2/progresivo, star-21,1UP-18. Default question/hidden coin remains0; an empty turn block is0. Inserting a coin encodes-1: question/turn blocks use the source200-active-tick multi-coin window; hidden blocks remain single-coin. Occupied turn blocks release contents and become used instead of spinning. |
| obj_enemyparent/Other_12 | ActorContacts captures active body bounds once before movement and indexes them in32px cells. Galoomba/Goombud, Koopa, ordinary/ceiling Buzzy and Spiny, Monty and walking beach Koopas receive their missing neighbour turns. The query excludes the bottom4px; held-family overlap follows the ordinary query, and equal centers use creation IDs. Both actors see the same starting snapshot, so native movement order cannot turn only one. Existing Chain Chomp has its own source-reviewed neighbour controller. Winged Buzzy/Spiny branches, fish, stationary plants and special hazards retain their distinct policies. |
| obj_powerupparent/Other_13 | Powerups turn at resting held-family objects, but ordinary enemies and other collectible powerups are not universal solid barriers. Source movement/draw/masks are kept separate. |
| obj_enemyparent_held contacts | Rising/thrown flipped Galoombas defeat vulnerable enemies. A carried Galoomba acts as a consumable shield, clearing both owners. Held-family pairs and moving-shell versus flipped-Galoomba contacts now use their appropriate defeat path. Existing shell enemy contacts retain their combo/score/hardness policy. |

The shared BlockComponent setter now accepts null sprouts safely. This is
required for empty turn blocks; it also guards a sprout replaced before tree
entry. Turn history retains the default empty state, while question and hidden
blocks restore their default coin after extraction. Existing editor-history
tests now drag a mushroom into the block before inspecting it; their previous
contents-selector expectation was the incorrect interaction the user reported.

## Verification

The combined basic_items_blocks_test covers both signed formats/unknown fields,
the three palette entries, all supported item/container combinations, replace/
insert/extract/cancel undo/redo, palette insertion, invalid non-container drops,
real1UP collection for all three powers, wall reversal, hidden-block head
reveal/downward passage, ordinary/giant/helmet hard-block contacts, occupied
turn blocks and timed multi-coins. Its actor matrix checks all16 ordered pairs
of four walking families, equal centers, vertical exclusion, resting shells,
moving-shell rewards, thrown/held Galoomba contacts, allowed item passages and
death/retry/editor cleanup. Assertions use actual native movement/contacts.

```powershell
python -I tools/porting/prepare_slice.py
python -I tools/porting/run_tests.py --import
python -I tools/porting/capture_slice.py --basic-items-blocks --fps 60
python -I tools/porting/capture_slice.py --basic-items-blocks --fps 120
python -I tools/porting/capture_slice.py --startup-flow --fps 60
```

The aggregate49-scene run passed47 and caught two regressions: neighbour turns
overwrote Monty's final Mario-facing, and the new controller dependency exposed
FireFlower's preloaded mushroom PackedScene cycle. The fixes retain Monty's
target-facing/slide direction while reversing its motion, and resolve the
replacement scene at runtime. Clean targeted reruns pass world_death_test,
fire_flower_test, monty_test, recent_enemy_defeat_test and this batch test. The
other47 aggregate results are retained instead of repeating the full suite.
Final cold import and required slice/sprite guards pass. Final batch GL60/120
and actual-GL startup/editor/play/return flow pass and were visually inspected.

GL mode runs a shorter contact matrix and saves the editor's
actual content window, a before/after actor contact reel and runtime art under
ignored .godot/porting-tests/. These are correctness captures, not new real-time
latency/frame-pacing measurements. Mario stays outside the contact pair so the
reel cannot accidentally enter the world-death stop; the1UP is captured after
settling onto real hard blocks. Preparation selects211 sprites/752 frames and
30 gameplay audio assets; the additive manifest has224 sprites/798 frames.
Final generated inventory:277 scripts /145 scenes /35,566 GDScript lines.
Editor/runtime/contact-reel images and logs have retained_60/_120 suffixes;
basic_stored_content.png shows the actual enlarged native content window.

Enemy contents, item/container attachments, giant item variants, other game
styles and unported machinery remain future work. Session extra_lives is the
existing counter; this batch does not add a profile/challenge lives UI. The
reference binary interoperability milestone remains open. No blanket solid
collision or automatic expansion to all OpenWE content is implied.
