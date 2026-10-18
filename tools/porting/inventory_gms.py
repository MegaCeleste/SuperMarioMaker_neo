"""Inventory a GameMaker Studio 2 project (.yy metadata + .gml sources).

Usage: python -I tools/inventory_gms.py <project_root> <output.json>
"""
import json
import re
import sys
from pathlib import Path

EVENT_NAMES = {
    "Create": "create",
    "Destroy": "destroy",
    "CleanUp": "cleanup",
    "PreCreate": "pre_create",
    "Step": "step",
    "Alarm": "alarm",
    "Collision": "collision",
    "Keyboard": "keyboard",
    "Mouse": "mouse",
    "Other": "other",
    "Draw": "draw",
    "KeyPress": "key_press",
    "KeyRelease": "key_release",
    "Gesture": "gesture",
    "Trigger": "trigger",
}

FUNC_RE = re.compile(r"^\s*function\s+([A-Za-z_]\w*)\s*\(", re.MULTILINE)
TRAILING_COMMA_RE = re.compile(r",\s*([}\]])")


def read_json(path: Path):
    # GameMaker .yy files allow trailing commas, unlike strict JSON.
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    text = TRAILING_COMMA_RE.sub(r"\1", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def resource_name(value):
    if isinstance(value, dict):
        return value.get("name")
    return None


def inventory_objects(root: Path):
    out = []
    for yy in sorted((root / "objects").glob("*/*.yy")):
        data = read_json(yy) or {}
        obj_dir = yy.parent
        gml_paths = sorted(p for p in obj_dir.glob("*.gml") if p.is_file())
        events = sorted({p.stem for p in gml_paths})
        gml_lines = sum(
            p.read_text(encoding="utf-8-sig", errors="replace").count("\n") + 1
            for p in gml_paths
        )
        event_kinds = sorted({e.split("_")[0] for e in events})
        out.append(
            {
                "name": data.get("name") or obj_dir.name,
                "path": yy.relative_to(root).as_posix(),
                "folder": (data.get("parent") or {}).get("path"),
                "parent_object": resource_name(data.get("parentObjectId")),
                "sprite": resource_name(data.get("spriteId")),
                "solid": bool(data.get("solid")),
                "persistent": bool(data.get("persistent")),
                "events": events,
                "event_kinds": [EVENT_NAMES.get(k, k.lower()) for k in event_kinds],
                "gml_files": len(events),
                "gml_lines": gml_lines,
            }
        )
    return out


def inventory_scripts(root: Path):
    out = []
    for gml in sorted((root / "scripts").rglob("*.gml")):
        text = gml.read_text(encoding="utf-8-sig", errors="replace")
        out.append(
            {
                "name": gml.stem,
                "path": gml.relative_to(root).as_posix(),
                "functions": sorted(set(FUNC_RE.findall(text))),
                "lines": text.count("\n") + 1,
            }
        )
    return out


def inventory_rooms(root: Path):
    out = []
    for yy in sorted((root / "rooms").glob("*/*.yy")):
        data = read_json(yy) or {}
        settings = data.get("roomSettings", {}) or {}
        layers = data.get("layers", []) or []
        instance_count = 0
        for layer in layers:
            if isinstance(layer, dict):
                instance_count += len(layer.get("instances", []) or [])
        out.append(
            {
                "name": data.get("name") or yy.parent.name,
                "path": yy.relative_to(root).as_posix(),
                "width": settings.get("Width"),
                "height": settings.get("Height"),
                "layers": [l.get("name") for l in layers if isinstance(l, dict)],
                "instances": instance_count,
            }
        )
    return out


def inventory_sprites(root: Path):
    out = []
    for yy in sorted((root / "sprites").glob("*/*.yy")):
        data = read_json(yy) or {}
        frames = data.get("frames", []) or []
        seq = data.get("sequence", {}) or {}
        out.append(
            {
                "name": data.get("name") or yy.parent.name,
                "path": yy.relative_to(root).as_posix(),
                "folder": (data.get("parent") or {}).get("path"),
                "width": data.get("width"),
                "height": data.get("height"),
                "origin": data.get("origin"),
                "frames": len(frames),
                "speed": seq.get("playbackSpeed"),
                "speed_type": seq.get("playbackSpeedType"),
            }
        )
    return out


def inventory_sounds(root: Path):
    out = []
    for yy in sorted((root / "sounds").glob("*/*.yy")):
        data = read_json(yy) or {}
        out.append(
            {
                "name": data.get("name") or yy.parent.name,
                "path": yy.relative_to(root).as_posix(),
                "folder": (data.get("parent") or {}).get("path"),
                "file": data.get("soundFile"),
                "type": data.get("type"),
                "duration": data.get("duration"),
            }
        )
    return out


def main():
    root = Path(sys.argv[1]).resolve()
    out_path = Path(sys.argv[2]).resolve()
    report = {
        "root": str(root),
        "counts": {},
        "objects": inventory_objects(root),
        "scripts": inventory_scripts(root),
        "rooms": inventory_rooms(root),
        "sprites": inventory_sprites(root),
        "sounds": inventory_sounds(root),
    }
    report["counts"] = {k: len(v) for k, v in report.items() if isinstance(v, list)}
    report["counts"]["gml_lines_total"] = sum(s["lines"] for s in report["scripts"])
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    print(json.dumps(report["counts"], ensure_ascii=False))


if __name__ == "__main__":
    main()
