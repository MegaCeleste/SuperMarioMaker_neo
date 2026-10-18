# Agent handoff

This repository is a Godot reimplementation of **SMM:WE (OpenWE edition)**.

**Read `docs/porting/HANDOFF.md` first.** It contains the current state,
environment paths, known traps, and the next concrete task.

Quick orientation:

- Branch: `port/openwe`
- Base: GodotWE (`NCubss/GodotWE`, GPL-3.0), commit `4a836e6`
- Spec reference: sibling checkout `../openwe-ref`, OpenWE commit
  `2f84414054c576bf7ca03dfa33b244ee730d57da` (AGPL-3.0, reference only)
- Engine: Godot 4.7.2 portable at
  `../.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`
- Current milestone: `port: milestone 0 - audit, tooling and slice harness`
- Next milestone: vertical slice 001 (`docs/porting/SLICE-001.md`)

Rules:

1. Port behaviour into Godot-native modules; do not transliterate GML files.
2. Keep `tests/scenes/slice_001.tscn` and `tests/scenes/sprite_library_test.tscn`
   green (exit code 0).
3. `assets/openwe/` and the `../openwe-ref` checkout are third-party and
   Nintendo IP; never commit or redistribute them.
4. Do not push, publish, or install system-wide software without user approval.
5. Regenerate audit data with the scripts in `tools/porting/` instead of
   hand-editing generated JSON.
