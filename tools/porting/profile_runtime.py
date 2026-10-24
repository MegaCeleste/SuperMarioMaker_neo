"""Measure wall-clock GL frame intervals without --fixed-fps or image readback.

Uses a visible window and temporarily disables VSync in the probe only. This
measures software frame pacing and shadow CPU cost, not display/input latency.
"""
import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT.parent / ".tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fps", type=int, choices=(60, 120, 144), default=120)
    parser.add_argument("--label", default="runtime")
    parser.add_argument("--no-interpolation", action="store_true")
    args = parser.parse_args()
    if not args.label.replace("-", "").replace("_", "").isalnum():
        parser.error("label must contain only letters, digits, '-' or '_'")
    logs = ROOT / ".godot/porting-tests"
    logs.mkdir(parents=True, exist_ok=True)
    stem = f"pacing_{args.label}_{args.fps}"
    command = [str(ENGINE), "--path", str(ROOT), "--rendering-method", "gl_compatibility",
               "--audio-driver", "Dummy", "--resolution", "960x540", "--position", "40,40",
               "--log-file", str(logs / (stem + ".engine.log")),
               "res://tests/scenes/frame_pacing_test.tscn", "--",
               f"--rate={args.fps}", f"--label={args.label}"]
    if args.no_interpolation:
        command.append("--no-interpolation")
    with (logs / (stem + ".stdout.log")).open("w", encoding="utf-8") as output:
        result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=35)
    output = (logs / (stem + ".stdout.log")).read_text(encoding="utf-8", errors="replace")
    # Preserve restricted-host diagnostics in logs; never accept script errors.
    errors = [line for line in output.splitlines() if line.startswith(("SCRIPT ERROR:", "ERROR:"))
              and not line.startswith(("ERROR: Failed to read the root certificate store.",
                                       "ERROR: Can't create shader cache folder, no shader caching will happen: user://",
                                       "ERROR: 2 resources still in use at exit"))]
    if result.returncode or "FRAME_PACING_RESULT PASS" not in output or errors:
        print(output[-6000:])
        return 1
    report = json.loads((logs / (stem + ".json")).read_text(encoding="utf-8"))
    print(json.dumps(report["configuration"]))
    for sample in report["samples"]:
        sample.pop("intervals_ms", None)
        positions = sample.pop("positions", [])
        if positions:
            sample["unique_physics_positions"] = len({round(row["physical_x"], 4) for row in positions})
            sample["unique_display_positions"] = len({round(row["displayed_x"], 4) for row in positions})
        print(json.dumps(sample))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
