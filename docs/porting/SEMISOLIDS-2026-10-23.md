# Ordinary SMW semisolid platforms — 2026-10-23

The user explicitly selected this next foundation after swimming: placement,
width/height resizing, the original three appearances, signed save/history and
passing upward through the platform while standing on its top. This does not
select mushroom platforms, bridges, moving platforms, wings or other styles.

## Reference and behaviour

Read-only OpenWE reference `2f84414054c576bf7ca03dfa33b244ee730d57da`:

- `obj_semisolid_platform1/Create`, Step2, Mouse4 and Draw: initial3x3,
  minimum3x3, source effective caps21x27, a top-right drag anchored at the
  left/bottom, and the original animated `spr_move_semisolid` handle.
- Its resource-collision event exits immediately. Platforms can overlap
  ground, actors and each other. Decorative bodies never reserve ordinary
  one-cell editor occupancy, nor become solid walls/ceilings.
- Other10/11: a native three-button appearance window and persistent palette
  choice. Other13 creates `obj_modelsizable`; Other15 computes top-y depth.
- `obj_modelsizable/Other10`: twelve original tile frames, with3/4/5 versus
  6/7/8 alternation toggled after every cell and again after each row. Even
  widths therefore need different row parity. Alarm0 creates an ordinary
  `obj_solidtop`, using `spr_square_b`'s five-pixel one-way mask.
- `scr_semisolid_platform{1,2,3}_sprites`: the six selected SMW themes use
  `spr_ssp{1,2,3}_{overworld,underground,underwater,ghost,airship,castle}`.
- `obj_button_save_changes/Other10` and `obj_load_level/Other10`: platform
  records belong in `PLATAFORMAS`, with object/position/sprite/color/depth/
  width/height/direct_t/wings fields, independently of NIVEL.

Source images are unchanged. The atlas is composed with exact16px blits and
cached in at most64 derived textures; each source cell image is read once per
composition. This avoids hundreds of per-panel drawing/shadow sprites and
unbounded cache growth during repeated resizing/theme changes.

## Native integration

SemisolidPart enables the existing disabled terrain slot on page0 sector6.
It reuses Part drag/place animations, EditorWindow and remembered card choice,
and records each completed resize as one native history geometry action.
Undo/redo includes dependent position, size and appearance. Saving while a
slope/platform resize is active is rejected before any write. Room bounds are
checked independently of overlap. The original source handle animates at
3.6fps while resizing; its existing GrabberSprite name keeps editor aids out
of PixelShadows. A background panel yields ordinary picking to foreground
Parts and preserves the existing slope-over-ground selection rule.

Only the top five-pixel surface is a native one-way StaticBodyExt. Player,
existing enemy and item physics use it directly. Editor return/replay clears
and rebuilds area-owned runtime bodies normally.

The GPU check exposed a real first implementation error: translating source
depth directly into negative z values put high platforms below their OWN
shadow group. Final art uses z0, above shadows(-1)/background(-2), behind
ordinary terrain/actors. Within that layer, sibling order retains exact top-y
ordering (stable scene order for ties). Sorting is deferred/coalesced to avoid
moving children while loaded scenes are entering the tree. No global layer
or native terrain-connection rule was changed.

## Signed SWE preservation

Platform rows are loaded/saved separately from object rows. Legacy
MAIN.PLATAFORMAS and project-supported modern S0.S7 aliases retain unknown
platform types, fields and source ordering. Geometry, color and current theme
sprite/depth are updated only for represented semisolid rows. Successful saves
commit each Part's source index/revision; erase/save/undo/re-save can restore
detached Parts without replacing unknown records. A malformed non-array source
platform collection rejects saving rather than discarding it. External OpenWE
binary verification remains a roadmap item; it is not implied by native
signed-wrapper tests.

## Verification

semisolid_test covers native palette placement; atomic resize/variant history;
minimum/maximum/room constraints; the real three-button window/card choice;
legacy and modern signed platform collections; actual saved-course entry;
unknown row/field retention and repeated erase/save/undo; ordinary objects
inside decorations; source art for all18 theme/appearance combinations;
actual upward player passage and downward landing; walking off the edge;
ordinary item/enemy support; and edit/replay ownership.

The source-art oracle independently runs the imperative source alternation and
compares complete RGBA tiles, including alpha, at odd/even sizes. Actual GL
60/120 captures verify six editor scenes with all three appearances, a
runtime standing view and moved overlapping panels. Both final rates pass
1038/1038 original pixels. Only
opaque source samples outside UI and the original visible handle are counted;
every counted pixel must match. Native geometry/actors also run in those
actual-render probes. Matching semisolid_*.png, slice_semisolid.png and logs
retain_60/_120 suffixes under ignored .godot/porting-tests/.

Final fresh import, five metadata guards and all57 native scenes pass; the
complete report is .godot/porting-tests/final_semisolid_native_suite_2026-10-23.txt.
The regenerated inventory contains310 scripts /163 scenes /40,681 lines.
Preparation selects269 sprites /1308 frames /42 sounds; the additive manifest
contains282 sprites /1354 frames. No production changes followed acceptance.
