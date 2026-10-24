"""Run bounded Godot headless regression scenes, failing on script errors.

Usage: python -I tools/porting/run_tests.py [--godot path] [--import]
Logs stay in .godot/porting-tests; no assets or user settings are bundled.
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ENGINE = ROOT.parent / ".tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
SCENES = {"slice_001": "SLICE001_RESULT PASS", "sprite_library_test": "SPRITE_LIBRARY_RESULT PASS",
          "interactions_test": "INTERACTIONS_RESULT PASS", "loader_compatibility_test": "LOADER_RESULT PASS",
          "player_physics_test": "PLAYER_PHYSICS_RESULT PASS", "swe_roundtrip_test": "SWE_ROUNDTRIP_RESULT PASS",
          "editor_flow_test": "EDITOR_FLOW_RESULT PASS", "smw_goal_test": "SMW_GOAL_RESULT PASS",
          "editor_history_test": "EDITOR_HISTORY_RESULT PASS",
          "goomba_variants_test": "GOOMBA_VARIANTS_RESULT PASS",
          "koopa_test": "KOOPA_RESULT PASS",
          "enemy_flight_test": "ENEMY_FLIGHT_RESULT PASS",
          "buzzy_test": "BUZZY_RESULT PASS", "helmet_test": "HELMET_RESULT PASS",
          "player_visual_test": "PLAYER_VISUAL_RESULT PASS", "spiny_test": "SPINY_RESULT PASS",
          "blooper_test": "BLOOPER_RESULT PASS",
          "cheep_cheep_test": "CHEEP_CHEEP_RESULT PASS", "liquid_surface_test": "LIQUID_SURFACE_RESULT PASS",
          "piranha_test": "PIRANHA_RESULT PASS", "muncher_test": "MUNCHER_RESULT PASS",
          "player_render_test": "PLAYER_RENDER_RESULT PASS", "thwomp_test": "THWOMP_RESULT PASS",
          "monty_test": "MONTY_RESULT PASS", "rocky_test": "ROCKY_RESULT PASS",
          "hammer_bro_test": "HAMMERBRO_RESULT PASS",
          "bro_projectile_test": "BRO_PROJECTILE_RESULT PASS",
          "bro_platform_test": "BRO_PLATFORM_RESULT PASS",
          "bro_environment_test": "BRO_ENVIRONMENT_RESULT PASS",
          "rocky_environment_test": "ROCKY_ENVIRONMENT_RESULT PASS",
          "source_mask_test": "SOURCE_MASK_RESULT PASS",
          "helmet_mask_test": "HELMET_MASK_RESULT PASS",
          "thwomp_environment_test": "THWOMP_ENVIRONMENT_RESULT PASS",
          "held_stun_test": "HELD_STUN_RESULT PASS",
          "actor_activity_test": "ACTOR_ACTIVITY_RESULT PASS",
          "recent_enemy_defeat_test": "RECENT_ENEMY_DEFEAT_RESULT PASS",
          "world_death_test": "WORLD_DEATH_RESULT PASS",
          "chomp_test": "CHOMP_RESULT PASS",
          "grrrol_test": "GRRROL_RESULT PASS",
          "enemy_grounding_test": "ENEMY_GROUNDING_RESULT PASS",
          "editor_grounding_test": "EDITOR_GROUNDING_RESULT PASS",
          "player_controls_test": "PLAYER_CONTROLS_RESULT PASS",
          "spin_effects_test": "SPIN_EFFECTS_RESULT PASS",
          "world_presentation_test": "WORLD_PRESENTATION_RESULT PASS",
          "startup_flow_test": "STARTUP_FLOW_RESULT PASS",
          "fire_flower_test": "FIRE_FLOWER_RESULT PASS",
          "palette_icon_test": "PALETTE_ICON_RESULT PASS",
          "star_test": "STAR_RESULT PASS",
          "basic_items_blocks_test": "BASIC_ITEMS_BLOCKS_RESULT PASS",
          "terrain_basics_test": "TERRAIN_BASICS_RESULT PASS",
          "platform_blocks_test": "PLATFORM_BLOCKS_RESULT PASS",
          "slopes_test": "SLOPES_RESULT PASS",
          "slope_fusion_test": "SLOPE_FUSION_RESULT PASS",
          "spring_test": "SPRING_RESULT PASS",
          "theme_switch_test": "THEME_SWITCH_RESULT PASS",
          "player_swim_test": "PLAYER_SWIM_RESULT PASS",
          "semisolid_test": "SEMISOLID_RESULT PASS"}

# This regression needs render frames between 60Hz physics ticks.
FRAME_RATES = {"player_render_test": 120}


def run(engine, name, args, timeout, marker=None):
    log_dir = ROOT / ".godot/porting-tests"
    log_dir.mkdir(parents=True, exist_ok=True)
    output_path = log_dir / f"{name}.stdout.log"
    command = [str(engine), "--headless", "--path", str(ROOT), "--log-file",
               str(log_dir / f"{name}.engine.log"), *args]
    with output_path.open("w", encoding="utf-8") as output:
        try:
            result = subprocess.run(command, cwd=ROOT, stdout=output,
                                    stderr=subprocess.STDOUT, timeout=timeout)
        except subprocess.TimeoutExpired:
            print(f"FAIL {name}: exceeded {timeout}s; see {output_path}")
            return False
    text = output_path.read_text(encoding="utf-8", errors="replace")
    errors = re.findall(r"^(?:SCRIPT ERROR:|ERROR:).*", text, re.MULTILINE)
    # Dummy-renderer resource diagnostics are not gameplay errors.
    errors = [error for error in errors if not re.match(
        r"ERROR: (?:\d+ RID allocations of type|\d+ resources still in use at exit|"
        r"Failed to read the root certificate store\.)", error)]
    if name == "import":
        # The editor profiler cannot create its user:// snapshots in this
        # managed environment. Asset import and script errors still fail.
        errors = [error for error in errors if error != "ERROR: Could not open 'user://' directory: 'user://'."]
    ok = result.returncode == 0 and not errors and (marker is None or marker in text)
    print(f"{'PASS' if ok else 'FAIL'} {name} (exit {result.returncode})")
    if not ok:
        print("\n".join(errors[:15]))
        print("\n".join(text.splitlines()[-45:]))
        print(f"Full log: {output_path}")
    return ok


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=DEFAULT_ENGINE)
    parser.add_argument("--import", dest="import_assets", action="store_true")
    parser.add_argument("--timeout", type=int, default=45)
    parser.add_argument("scenes", nargs="*", choices=SCENES)
    args = parser.parse_args()
    engine = args.godot.resolve()
    if not engine.is_file():
        parser.error(f"Godot executable not found: {engine}")
    metadata_log = ROOT / ".godot/porting-tests/sprite_conversion.stdout.log"
    metadata_log.parent.mkdir(parents=True, exist_ok=True)
    with metadata_log.open("w", encoding="utf-8") as output:
        metadata = subprocess.run([sys.executable, "-I", str(ROOT / "tools/porting/test_sprite_conversion.py")],
                                  cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=20)
    print(f"{'PASS' if metadata.returncode == 0 else 'FAIL'} sprite_conversion (exit {metadata.returncode})")
    if metadata.returncode != 0:
        print(metadata_log.read_text(encoding="utf-8", errors="replace"))
        return 1
    if args.import_assets and not run(engine, "import", ["--import"], 180):
        return 1
    passed = True
    for name in args.scenes or SCENES:
        passed = run(engine, name, ["--fixed-fps", str(FRAME_RATES.get(name, 60)), f"res://tests/scenes/{name}.tscn"],
                     args.timeout, SCENES[name]) and passed
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
