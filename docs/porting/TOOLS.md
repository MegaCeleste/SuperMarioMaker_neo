# Porting tools

All tools are plain Python 3 (stdlib only) and read the GameMaker project as
untrusted input. Run them with `-I` (isolated mode) and pass the reference
checkout as an argument; never `cd` into the reference checkout to run them.

From the repository root, with the OpenWE reference at `../openwe-ref`:

```bash
python -I tools/porting/inventory_gms.py ../openwe-ref docs/porting/generated/openwe.json
python -I tools/porting/inventory_godot.py . docs/porting/generated/godotwe.json
python -I tools/porting/gap_report.py docs/porting/generated/openwe.json docs/porting/generated/godotwe.json docs/porting/GAP_REPORT.md
```

## Sprite conversion

```bash
# Selected sprites
python -I tools/porting/port_sprites.py ../openwe-ref . --sprite spr_1up --sprite spr_SMB_mario_small_idle

# Everything (large; thousands of PNGs)
python -I tools/porting/port_sprites.py ../openwe-ref . --all
```

Outputs:

- `assets/openwe/sprites/<name>/frame_NNN.png`
- `assets/openwe/manifests/sprites.json`

`SpriteLibrary` (autoload) builds `SpriteFrames` lazily from the manifest. The
manifest is additive: converting one sprite does not drop previous entries.

## Notes

- `.yy` files are not strict JSON; the parsers tolerate trailing commas.
- Inventory grouping uses the project's own resource folders (`folders/...`),
  not filename heuristics.
- Generated inventories are committed so gap-report changes are reviewable in
  diffs.
