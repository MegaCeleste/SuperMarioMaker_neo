# Handoff — milestone 0 complete

Written for the next agent taking over this port. Read this first, then
`README.md`, `ARCHITECTURE.md`, `ROADMAP.md` and `SLICE-001.md` in this folder.

## State

- Repository: `C:\Working\新建文件夹\GodotWE`
- Branch: `port/openwe` (based on GodotWE `4a836e6`, GPL-3.0)
- Reference checkout: `C:\Working\新建文件夹\openwe-ref`
  - SMM:WE OpenWE `2f84414054c576bf7ca03dfa33b244ee730d57da` (2024-01-12),
    AGPL-3.0, reference only — never commit or redistribute it
- Engine: Godot **4.7.2.stable** portable, outside the repo:
  `C:\Working\新建文件夹\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe`
- No changes have been pushed. `origin` is still NCubss/GodotWE.

## What milestone 0 delivered

1. **Project audit** — `docs/porting/generated/openwe.json`,
   `docs/porting/generated/godotwe.json` and `docs/porting/GAP_REPORT.md`.
   OpenWE is ~120k lines of object-event GML plus ~23k script lines;
   the Godot base is ~8.3k lines. Treat the gap report as the source of truth
   for what is missing.
2. **Tooling** (`tools/porting/`, stdlib Python only, always run with `-I`):
   - `inventory_gms.py`, `inventory_godot.py`, `gap_report.py`
   - `port_sprites.py` converts GMS2 sprites + manifest
   - `make_test_level.py` writes a valid HMAC-signed `.swe` fixture
3. **Runtime plumbing**
   - `scripts/singletons/sprite_library.gd` (autoload `SpriteLibrary`) builds
     `SpriteFrames` lazily from `assets/openwe/manifests/sprites.json`.
   - Converted assets under `assets/openwe/` are **gitignored** by design.
4. **Tests** (headless, both passing):
   - `tests/scenes/slice_001.tscn` — loads `tests/fixtures/port_slice.swe`
     and asserts exact Part counts (`GroundPart=60`, `CoinPart=2`,
     `QuestionBlockPart=1`, `TurnBlockPart=1`, `GaloombaPart=1`).
   - `tests/scenes/sprite_library_test.tscn` — checks manifest loading,
     frame counts, texture sizes and origin offsets for four sample sprites.
5. **Docs** — porting workspace layout, architecture mapping, roadmap,
   slice scope, licensing, tool usage.

## Commands

Run from `C:\Working\新建文件夹\GodotWE` (Git Bash):

```bash
# Re-import after adding assets
"../.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import

# Regression tests (exit code 0 = pass)
"../.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/scenes/slice_001.tscn
"../.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/scenes/sprite_library_test.tscn

# Regenerate audit data
python -I tools/porting/inventory_gms.py ../openwe-ref docs/porting/generated/openwe.json
python -I tools/porting/inventory_godot.py . docs/porting/generated/godotwe.json
python -I tools/porting/gap_report.py docs/porting/generated/openwe.json docs/porting/generated/godotwe.json docs/porting/GAP_REPORT.md

# Convert sprites for a system (repeat --sprite as needed)
python -I tools/porting/port_sprites.py ../openwe-ref . --sprite spr_1up --sprite spr_coin
```

Ignore RID/ObjectDB leak warnings at shutdown: they come from the existing
`LevelProcessor` background thread and the dummy headless renderer.

## Next task — SLICE-001

Follow `SLICE-001.md`. Recommended order:

1. **Map fixture objects to real parts.** Today `SWE_OBJECT_TABLE` in
   `scripts/singletons/level_processor.gd` has only four entries. Add mappings
   for the objects used by the slice and make unknown IDs warn with the name
   instead of silently returning. The old and new key styles (`object`/`ID`,
   `x_pos`/`xx`) are already handled by `_get_value`.
2. **Restore stored data the loader currently drops.** `S2/SUELO` stores an
   `index` used by `SWE_GROUND_FRAME_TABLE`; `_from_swe` ignores it. Restore
   atlas selection. Stop hardcoding `game_style = SMW` and
   `level_theme = OVERWORLD` (`apariencia`, `entorno`) — validate against
   `Level.GameStyle` / `Level.LevelTheme`.
3. **Convert slice sprites** into `assets/openwe/` and wire entity scenes to
   `SpriteLibrary` (or preload generated `.tres` if performance demands it).
4. **Port Goomba** from OpenWE (`obj_goomba_res` runtime parents and
   `obj_goomba*` objects) using the existing `Enemy`/`Galoomba` pattern; add a
   `GoombaPart`.
5. **Goal + HUD + level completion** for SMW: `obj_flagpole`, `obj_goalcard`,
   SMW HUD objects.
6. **Player parity** for SMW small/super: compare `obj_mario` events and
   `scr_mario*.gml` against `player.gd` + `states/`. Port behaviour, not GML
   syntax. Add a physics trace test (fixed input sequence → positions).
7. Extend `slice_001.gd` assertions as each item lands; keep it passing.

## Known issues / traps

- `LevelProcessor.decode_swe()` verifies the HMAC with
  `SWE_HMAC_KEY = "2559F35097-2021"`, hashing the **base64 text**, not the raw
  JSON. The fixture generator matches this; keep them in sync.
- `LevelProcessor` runs on a background thread and is never stopped; shutdown
  warnings are expected. Do not "fix" by removing the thread without checking
  `_request` concurrency.
- `Label` handling has an operator-precedence bug: `int(x) + 1 % 14` does not
  wrap tags. Check before relying on tags.
- Saving `.swe` files is unimplemented (`_Command.SAVE` is a TODO).
- Sprite `fps` in the manifest is the sprite's intrinsic rate; GMS2 projects
  commonly store `playbackSpeed=1, playbackSpeedType=1` (one frame per game
  frame ⇒ 60 fps) and override `image_speed` per object in GML. Set animation
  speed in entity code where OpenWE does.
- Object origins can be presets or custom; `port_sprites.py` already resolves
  both (`origin == 9` uses sequence xorigin/yorigin).
- GMS2 `.yy` files are not strict JSON (trailing commas). Use the tolerant
  reader in the tooling.
- Licensing: combined work is AGPL-3.0-or-later. Nintendo assets are not
  licensed; never commit `assets/openwe/` or publish builds.

## Working rules

- Port behaviour into Godot-native modules; do not transliterate thousands of
  GML event files.
- Update `ARCHITECTURE.md` and `GAP_REPORT.md` when a system's status changes.
- Keep headless tests green before claiming a system is ported.
- Do not push, publish, or install system-wide software without user approval.
