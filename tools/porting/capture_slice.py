"""Render a local slice screenshot using Godot's real OpenGL renderer.

Creates a temporary off-screen window, captures, and exits within 30 seconds.
Usage: python -I tools/porting/capture_slice.py [--godot path]
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ENGINE = ROOT.parent / ".tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
MODES = {
    "completion": "play to the goal before capturing",
    "editor": "capture the editor and native content window",
    "editor-enemy": "capture enemy type selection and its card",
    "editor-koopa": "capture green/red Koopa selection",
    "koopa": "capture Koopa, empty shell and beach sprites",
    "editor-flight": "capture wings/parachute toggles and previews",
    "flight": "capture descending, bouncing and hovering enemies",
    "editor-buzzy": "capture Buzzy and empty-shell selection",
    "buzzy": "capture crawling, ceiling and riding Buzzy plus a worn helmet",
    "helmet-completion": "play to SMW's helmet-specific victory pose",
    "player-motion": "verify and capture mushroom growth, low ceilings and walking",
    "player-growth": "capture continuous mushroom growth in both directions without the full controls matrix",
    "player-render": "capture fixed-screen running pixels and camera/physics synchrony",
    "editor-spiny": "capture native Spiny type and attachment selection",
    "spiny": "capture Spiny, its shells, ceiling crawl, needle volley and helmet",
    "spiny-completion": "play to the Spiny helmet's distinct original victory pose",
    "editor-blooper": "capture the Blooper tool and imported legacy decorations",
    "blooper": "capture rising, sinking and inverted defeated Bloopers",
    "editor-cheep-cheep": "capture native red/yellow fish types, attachments and tool card",
    "cheep-cheep": "capture jumping fish, wings and parachute",
    "cheep-water": "capture swimmers under the source moving water surface",
    "cheep-lava": "capture lava jumps and native fire aura",
    "editor-piranha": "capture native jump/fire plant selection, flags and card",
    "piranha": "capture SMW jumps, wings, ceiling and side attachments",
    "piranha-fire": "capture source fire-plant poses and actual aimed projectiles",
    "piranha-water": "capture fire plants/projectiles under the source water surface",
    "editor-muncher": "capture native small/giant Muncher sizes and editor flags",
    "muncher": "capture physical Muncher columns and a falling giant",
    "editor-thwomp": "capture the native Thwomp size/type window and direction arrow",
    "thwomp": "capture source directions, both sizes and a falling attack",
    "editor-monty": "capture Monty's palette entry and wings/parachute window",
    "monty": "capture Monty chasing, winged hopping and parachuting",
    "editor-rocky": "capture Rocky's palette entry and source art",
    "rocky": "capture Rocky's emerge cycle and a flying wrench",
    "editor-hammerbro": "capture the four-type Bro window with size and wings toggles",
    "hammerbro": "capture Hammer/Fire/Ice/Boomerang Bro with their projectiles",
    "bro-status": "capture an actual frozen Mario and hovering winged Sledge Bro",
    "bro-environment": "capture an actual ice/Spiny helmet rebound and poison-sinking Bro",
    "rocky-environment": "capture Rocky's fixed-pose lava sink, vertical defeat and animated wrench",
    "thwomp-environment": "capture precise Thwomp silhouettes and paired moving-liquid splashes",
    "held-stun": "capture a real Sledge landing, forced held drop and source stun animation",
    "enemy-defeat": "capture Monty and all five Bro typed spinning corpses",
    "world-death": "capture real Mario death with stopped enemies/hammer and an independent boomerang",
    "chomp": "capture both free Chomp sizes, history-following chains and compound defeat",
    "editor-chomp": "capture native Chomp size/wings/parachute window and editor previews",
    "grrrol": "capture all three native source Grrrol forms with fixed masks and rolling art",
    "editor-grrrol": "capture legacy and new Grrrol previews and its native size/flag window",
    "rotation-render": "compare real rotated pixels, cardinal sharpness, alpha and Mario/terrain controls",
    "enemy-grounding": "verify actual grounded opaque pixels and capture existing enemy rest poses",
    "editor-grounding": "verify existing native editor previews against their placement surfaces",
    "pixel-shadows": "verify current-frame pixel silhouettes and capture native editor/gameplay shadows",
    "player-controls": "capture walk/run braking, growing/shrinking dust, both crouch sizes and native Bro palette icons",
    "braking-dust": "capture continuous stationary walk/run dust without the full controls/UI matrix",
    "spin-effects": "capture real spiked recoil/spin defeats and flash/star growth and shrinkage",
    "starting-ground": "capture native starting-ground caps, joined editor terrain and matching gameplay tiles",
    "world-presentation": "verify fractional actor/camera positions against actual GPU pixels",
    "startup-flow": "run the configured startup, title, editor and play/return lifecycle",
    "fire-flower": "capture native flower variants, Fire Mario, shots and spin fire",
    "palette-icon": "verify the native Bro palette and top-card rendered icons",
    "star": "capture native star placement, timed star tint and source sparkle effects",
    "basic-items-blocks": "capture1UP, hard/hidden blocks and native container contents",
    "terrain-basics": "capture native spike, ice and cloud terrain with their editor entries",
    "platform-blocks": "capture donut/note platforms and verify the corrected shared spike clock",
    "slopes": "capture endpoint-edited steep/gentle slopes and native terrain movement",
    "slope-fusion": "verify corner-touch single-cell stairs against real editor/runtime pixels",
    "spring": "verify ordinary portable SMW spring placement, carrying, compression and launches",
    "theme-switch": "verify six native SMM1 SMW theme choices, terrain, backgrounds, music and saves",
    "player-swim": "verify SMW swimming, held buoyancy, water entry/exit and actual original sprite pixels",
    "semisolid": "verify native semisolid resize, styles, signed platform collections and one-way contacts",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=DEFAULT_ENGINE)
    parser.add_argument("--fps", type=int, choices=(30, 60, 120),
                        help="simulation render rate (player-render defaults to 120; other modes to 60)")
    mode = parser.add_mutually_exclusive_group()
    for name, description in MODES.items():
        mode.add_argument("--" + name, dest="mode", action="store_const", const=name, help=description)
    parser.set_defaults(mode="preview")
    args = parser.parse_args()
    fps = args.fps or (120 if args.mode == "player-render" else 60)
    logs = ROOT / ".godot/porting-tests"
    logs.mkdir(parents=True, exist_ok=True)
    output_path = logs / f"capture_{args.mode}.stdout.log"
    command = [str(args.godot.resolve()), "--path", str(ROOT), "--rendering-method",
               "gl_compatibility", "--audio-driver", "Dummy", "--fixed-fps",
               str(fps),
               "--resolution", "1152x648", "--position", "-10000,-10000",
               "--log-file", str(logs / f"capture_{args.mode}.engine.log"),
               "res://tests/scenes/player_visual_test.tscn" if args.mode in ("player-motion", "player-growth")
               else "res://tests/scenes/player_render_test.tscn" if args.mode == "player-render"
               else "res://tests/scenes/world_presentation_test.tscn" if args.mode == "world-presentation"
               else "res://tests/scenes/startup_flow_test.tscn" if args.mode == "startup-flow"
               else "res://tests/scenes/fire_flower_test.tscn" if args.mode == "fire-flower"
               else "res://tests/scenes/palette_icon_test.tscn" if args.mode == "palette-icon"
               else "res://tests/scenes/star_test.tscn" if args.mode == "star"
               else "res://tests/scenes/basic_items_blocks_test.tscn" if args.mode == "basic-items-blocks"
               else "res://tests/scenes/terrain_basics_test.tscn" if args.mode == "terrain-basics"
               else "res://tests/scenes/platform_blocks_test.tscn" if args.mode == "platform-blocks"
               else "res://tests/scenes/slopes_test.tscn" if args.mode == "slopes"
               else "res://tests/scenes/slope_fusion_test.tscn" if args.mode == "slope-fusion"
               else "res://tests/scenes/spring_test.tscn" if args.mode == "spring"
               else "res://tests/scenes/theme_switch_test.tscn" if args.mode == "theme-switch"
               else "res://tests/scenes/player_swim_test.tscn" if args.mode == "player-swim"
               else "res://tests/scenes/semisolid_test.tscn" if args.mode == "semisolid"
               else "res://tests/scenes/bro_projectile_test.tscn" if args.mode == "bro-status"
               else "res://tests/scenes/bro_environment_test.tscn" if args.mode == "bro-environment"
               else "res://tests/scenes/rocky_environment_test.tscn" if args.mode == "rocky-environment"
               else "res://tests/scenes/thwomp_environment_test.tscn" if args.mode == "thwomp-environment"
               else "res://tests/scenes/held_stun_test.tscn" if args.mode == "held-stun"
               else "res://tests/scenes/recent_enemy_defeat_test.tscn" if args.mode == "enemy-defeat"
               else "res://tests/scenes/world_death_test.tscn" if args.mode == "world-death"
               else "res://tests/scenes/chomp_test.tscn" if args.mode in ("chomp", "editor-chomp")
               else "res://tests/scenes/grrrol_test.tscn" if args.mode in ("grrrol", "editor-grrrol")
               else "res://tests/scenes/rotation_render_test.tscn" if args.mode == "rotation-render"
               else "res://tests/scenes/enemy_grounding_test.tscn" if args.mode == "enemy-grounding"
               else "res://tests/scenes/editor_grounding_test.tscn" if args.mode == "editor-grounding"
               else "res://tests/scenes/pixel_shadows_test.tscn" if args.mode == "pixel-shadows"
               else "res://tests/scenes/player_controls_test.tscn" if args.mode in ("player-controls", "braking-dust")
               else "res://tests/scenes/spin_effects_test.tscn" if args.mode == "spin-effects"
               else "res://tests/scenes/editor_flow_test.tscn" if args.mode == "starting-ground"
               else "res://tests/scenes/play_slice.tscn", "--",
               "--capture" if args.mode == "preview" else "--capture-" + args.mode]
    if args.mode == "slopes" and fps == 120:
        # Native/60Hz checks already run the complete contact matrix. Keep the
        # high-refresh GPU/feet/editor probe inside the bounded30s window.
        command.append("--slopes-visual-only")
    with output_path.open("w", encoding="utf-8") as output:
        try:
            result = subprocess.run(command, cwd=ROOT, stdout=output,
                                    stderr=subprocess.STDOUT, timeout=30)
        except subprocess.TimeoutExpired:
            print(f"FAIL capture: timed out; see {output_path}")
            return 1
    text = output_path.read_text(encoding="utf-8", errors="replace")
    errors = re.findall(r"^(?:SCRIPT ERROR:|ERROR:).*", text, re.MULTILINE)
    errors = [error for error in errors if not re.match(
        r"ERROR: (?:\d+ RID allocations of type|\d+ resources still in use at exit|"
        r"Failed to read the root certificate store\.|"
        # The managed user:// directory cannot hold the optional GL shader cache;
        # the renderer continues normally. Preserve the diagnostic in the log.
        r"Can't create shader cache folder, no shader caching will happen: user://$)", error)]
    ok = result.returncode == 0 and "CAPTURE_RESULT PASS" in text and not errors
    name = "slice_" + args.mode.replace("-", "_") + ".png"
    if args.mode == "player-render":
        name = f"slice_player_run_{fps}_animated.png"
    elif args.mode == "player-growth":
        name = "slice_player_motion_right.png"
    elif args.mode == "braking-dust":
        name = "player_controls_dust_profile.png"
    print("PASS" if ok else "FAIL", "capture", logs / name)
    if not ok:
        print("\n".join(text.splitlines()[-35:]))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
