#!/usr/bin/env python3
"""Install the reviewed basic sprite mapping without changing original images."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import struct
import io
import re
import zipfile
from pathlib import Path


def validate_catalog(catalog: dict) -> None:
    """Check declared mappings; visual meaning still requires inspecting the source."""
    assets = catalog["assets"]
    rejected = {record["source_original"] for record in catalog.get("rejected_sources", [])}
    for asset in assets.values():
        if asset["source_original"] in rejected:
            raise ValueError(f"Rejected source entered the runtime catalog: {asset['source_original']}")
    for group, definition in catalog["groups"].items():
        for name, mapping in definition["animations"].items():
            asset = assets[mapping["asset"]]
            style = asset.get("visual_style", asset["asset_id"].split("/", 1)[0].lower())
            if "visual_style" in definition and style != definition["visual_style"]:
                raise ValueError(f"Mixed style mapping: {group}/{name}: {style}")
            if name == "walk" and asset.get("source_role", "locomotion") != "locomotion":
                raise ValueError(f"Non-locomotion sheet mapped to walk: {group}/{name}")
            frames = mapping["frames"]
            if not frames or any(type(index) is not int or index < 0 or index >= asset["frame_count"] for index in frames):
                raise ValueError(f"Invalid frame indices: {group}/{name}")
            fps = mapping["fps"]
            if isinstance(fps, bool) or not isinstance(fps, (int, float)) or not math.isfinite(fps) or fps < 0:
                raise ValueError(f"Invalid animation timing: {group}/{name}")
            if not isinstance(mapping["loop"], bool):
                raise ValueError(f"Invalid loop flag: {group}/{name}")


def retire_existing_sidecars(project: Path, catalog: dict) -> None:
    for record in catalog.get("rejected_sources", []):
        texture = (project / record["retired_texture_path"].removeprefix("res://")).resolve()
        texture.relative_to(project / "textures")
        sidecar = texture.with_suffix(".json")
        if sidecar.exists():
            manifest = json.loads(sidecar.read_text(encoding="utf-8"))
            manifest.update(metadata_state="rejected", animations={}, source_role=record["source_role"], reviewed_at=record["reviewed_at"], rejection_reason=record["reason"], unresolved=["not_a_runtime_animation"])
            sidecar.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_sprite_frames(project: Path, catalog: dict) -> None:
    output = project / "data/visuals"
    output.mkdir(parents=True, exist_ok=True)
    for group, definition in catalog["groups"].items():
        asset_ids = list(dict.fromkeys(mapping["asset"] for mapping in definition["animations"].values()))
        lines = ['[gd_resource type="SpriteFrames" format=3]', '']
        for asset_id in asset_ids:
            asset = catalog["assets"][asset_id]
            lines += [f'[ext_resource type="Texture2D" path="{asset["texture_path"]}" id="t_{asset_id}"]', '']
        for asset_id in asset_ids:
            asset = catalog["assets"][asset_id]
            for index in range(asset["frame_count"]):
                lines += [f'[sub_resource type="AtlasTexture" id="f_{asset_id}_{index}"]', f'atlas = ExtResource("t_{asset_id}")', f'region = Rect2({index * asset["frame_width"]}, 0, {asset["frame_width"]}, {asset["frame_height"]})', '']
        animations = []
        for name, mapping in definition["animations"].items():
            frame_refs = ', '.join('{"duration": 1.0, "texture": SubResource("f_' + mapping['asset'] + '_' + str(index) + '")}' for index in mapping["frames"])
            animations.append('{"frames": [' + frame_refs + '], "loop": ' + str(mapping["loop"]).lower() + ', "name": &"' + name + '", "speed": ' + str(float(mapping["fps"])) + '}')
        lines += ['[resource]', 'animations = [' + ',\n'.join(animations) + ']', '']
        (output / f"basic_smw_{group}.tres").write_text('\n'.join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path, help="Original textures/styles directory")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    source_root = args.source.resolve()
    catalog = json.loads((project / "data/assets/basic_smw.json").read_text(encoding="utf-8"))
    validate_catalog(catalog)
    records: list[dict] = []
    prepared: list[tuple[Path, Path, dict]] = []
    for manifest in catalog["assets"].values():
        if "source_archive" in manifest:
            from PIL import Image
            archive = (project / manifest["source_archive"]).resolve()
            archive.relative_to(project / "local_debug_output")
            if hashlib.sha256(archive.read_bytes()).hexdigest() != manifest["source_archive_sha256"]:
                raise ValueError("Source archive differs from the reviewed SHA256: " + str(archive))
            with zipfile.ZipFile(archive) as bundle:
                prefix = manifest["archive_sprite_directory"]
                document = bundle.read(prefix + "spr_explosion.yy").decode("utf-8")
                frame_names = re.findall(r'"resourceType":"GMSpriteFrame".*?"name":"([^"]+)"', document)
                frames = [Image.open(io.BytesIO(bundle.read(prefix + name + ".png"))).convert("RGBA") for name in frame_names]
                strip = Image.new("RGBA", (frames[0].width * len(frames), frames[0].height))
                for index, frame in enumerate(frames):
                    strip.paste(frame, (index * frame.width, 0))
                source = project / "local_debug_output/entity-batch-source" / Path(manifest["source_original"]).name
                source.parent.mkdir(parents=True, exist_ok=True)
                strip.save(source)
        else:
            source = (source_root / manifest["source_original"]).resolve()
            source.relative_to(source_root)
        destination = (project / manifest["texture_path"].removeprefix("res://")).resolve()
        destination.relative_to(project / "textures")
        header = source.read_bytes()[:24]
        if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
            raise ValueError(f"Invalid PNG: {source}")
        width, height = struct.unpack(">II", header[16:24])
        expected = (manifest["frame_width"] * manifest["frame_count"], manifest["frame_height"])
        if (width, height) != expected or manifest["metadata_state"] != "verified":
            raise ValueError(f"Unverified mapping or size mismatch: {source}: {(width, height)} != {expected}")
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest() != digest:
            raise ValueError(f"Existing local asset differs; refusing to overwrite: {destination}")
        sidecar = dict(manifest, sha256=digest)
        prepared.append((source, destination, sidecar))
    for source, destination, sidecar in prepared:
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists():
            shutil.copyfile(source, destination)
        destination.with_suffix(".json").write_text(json.dumps(sidecar, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        records.append({"asset_id": sidecar["asset_id"], "source_original": sidecar["source_original"], "source": destination.name, "sha256": sidecar["sha256"]})
    report = project / "data/assets/basic_smw_installation.json"
    report.write_text(json.dumps({"schema_version": 1, "asset_count": len(records), "records": records, "rejected_sources": catalog.get("rejected_sources", [])}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_sprite_frames(project, catalog)
    retire_existing_sidecars(project, catalog)
    print(f"Installed {len(records)} PNG assets with sidecar manifests; archive frames assembled without resampling; originals preserved.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
