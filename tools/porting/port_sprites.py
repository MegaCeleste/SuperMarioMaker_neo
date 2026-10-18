"""Convert GameMaker GMS2 sprites into a Godot asset tree + JSON manifest.

Usage:
  python -I tools/port_sprites.py <openwe_root> <godot_root> [--all | --sprite NAME ...] [--dry-run]

Layout produced inside the Godot project:
  assets/openwe/sprites/<sprite_name>/frame_<n>.png
  assets/openwe/manifests/sprites.json

The runtime SpriteLibrary autoload reads the manifest and builds SpriteFrames
on demand, so converted assets do not need hand-authored .tres files.
"""
import argparse
import json
import re
import shutil
import sys
from pathlib import Path

TRAILING_COMMA_RE = re.compile(r",\s*([}\]])")
ORIGIN_PRESETS = {
    0: (0.0, 0.0),
    1: (0.5, 0.0),
    2: (1.0, 0.0),
    3: (0.0, 0.5),
    4: (0.5, 0.5),
    5: (1.0, 0.5),
    6: (0.0, 1.0),
    7: (0.5, 1.0),
    8: (1.0, 1.0),
}


def read_yy(path: Path):
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    text = TRAILING_COMMA_RE.sub(r"\1", text)
    return json.loads(text)


def frame_order(data):
    ids = []
    try:
        tracks = data["sequence"]["tracks"]
        for track in tracks:
            for key in track["keyframes"]["Keyframes"]:
                fid = key["Channels"]["0"]["Id"]["name"]
                if fid not in ids:
                    ids.append(fid)
    except (KeyError, IndexError, TypeError):
        pass
    if not ids:
        ids = [f["name"] for f in data.get("frames", [])]
    return ids


def sprite_origin(data):
    w = float(data.get("width") or 0)
    h = float(data.get("height") or 0)
    mode = int(data.get("origin") or 0)
    seq = data.get("sequence", {}) or {}
    if mode == 9:
        return float(seq.get("xorigin", 0)), float(seq.get("yorigin", 0))
    fx, fy = ORIGIN_PRESETS.get(mode, (0.0, 0.0))
    return fx * w, fy * h


def convert_sprite(sprite_dir: Path, openwe_root: Path, godot_root: Path, dry_run: bool):
    yy = sprite_dir / f"{sprite_dir.name}.yy"
    if not yy.exists():
        return None, "missing .yy"
    data = read_yy(yy)
    name = data.get("name") or sprite_dir.name
    seq = data.get("sequence", {}) or {}
    speed = float(seq.get("playbackSpeed", 1.0))
    speed_type = int(seq.get("playbackSpeedType", 1))
    fps = speed * 60.0 if speed_type == 1 else speed
    playback = int(seq.get("playback", 1))

    ids = frame_order(data)
    out_dir = godot_root / "assets" / "openwe" / "sprites" / name
    frames = []
    copied = 0
    for index, fid in enumerate(ids):
        src = sprite_dir / f"{fid}.png"
        if not src.exists():
            continue
        dst = out_dir / f"frame_{index:03d}.png"
        if not dry_run:
            out_dir.mkdir(parents=True, exist_ok=True)
            if not dst.exists() or dst.stat().st_size != src.stat().st_size:
                shutil.copyfile(src, dst)
                copied += 1
        frames.append(f"res://assets/openwe/sprites/{name}/frame_{index:03d}.png")

    origin_x, origin_y = sprite_origin(data)
    entry = {
        "width": int(data.get("width") or 0),
        "height": int(data.get("height") or 0),
        "origin": [origin_x, origin_y],
        "fps": fps,
        "loop": playback == 1,
        "frames": frames,
        "folder": (data.get("parent") or {}).get("path"),
    }
    return (name, entry, copied), None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("openwe_root")
    parser.add_argument("godot_root")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--sprite", action="append", default=[])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    openwe_root = Path(args.openwe_root).resolve()
    godot_root = Path(args.godot_root).resolve()
    sprites_root = openwe_root / "sprites"

    if args.all:
        targets = sorted(p for p in sprites_root.iterdir() if p.is_dir())
    elif args.sprite:
        targets = [sprites_root / n for n in args.sprite]
    else:
        parser.error("pass --all or at least one --sprite NAME")

    manifest_path = godot_root / "assets" / "openwe" / "manifests" / "sprites.json"
    manifest = {"format_version": 1, "sprites": {}}
    if manifest_path.exists():
        loaded = json.loads(manifest_path.read_text(encoding="utf-8"))
        if isinstance(loaded, dict) and "sprites" in loaded:
            manifest = loaded

    converted = skipped = total_frames = total_copied = 0
    for sprite_dir in targets:
        result, err = convert_sprite(sprite_dir, openwe_root, godot_root, args.dry_run)
        if err:
            skipped += 1
            continue
        name, entry, copied = result
        if not entry["frames"]:
            skipped += 1
            continue
        manifest["sprites"][name] = entry
        converted += 1
        total_frames += len(entry["frames"])
        total_copied += copied

    if not args.dry_run:
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=1, sort_keys=True),
            encoding="utf-8",
        )
    print(
        json.dumps(
            {
                "converted": converted,
                "skipped": skipped,
                "frames": total_frames,
                "files_copied": total_copied,
                "manifest": str(manifest_path),
                "last_manifest_entries": len(manifest["sprites"]),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    sys.exit(main())
