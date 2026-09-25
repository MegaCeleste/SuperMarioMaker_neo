#!/usr/bin/env python3
"""Create a normalized sprite copy and draft JSON manifests from PNG strips.

Only facts present in the filename and PNG header are generated. Sprite pivots,
animation semantics, frame timing, and looping remain review items.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import struct
import sys
from pathlib import Path
from typing import Any


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
STRIP_PATTERN = re.compile(r"_Strip(?P<count>\d+)\.png$", re.IGNORECASE)
TOKEN_REPLACEMENTS = {
    "atack": "attack",
    "atackv": "attack_v",
    "acender": "ascend",
    "decender": "descend",
    "pballon": "p_balloon",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(24)
    if len(header) != 24 or header[:8] != PNG_SIGNATURE or header[12:16] != b"IHDR":
        raise ValueError("invalid PNG signature or IHDR chunk")
    width, height = struct.unpack(">II", header[16:24])
    if width < 1 or height < 1:
        raise ValueError("PNG has an empty dimension")
    return width, height


def normalized_label(source_stem: str, style: str) -> str:
    label = source_stem
    prefix = f"spr_{style}_"
    if label.lower().startswith(prefix.lower()):
        label = label[len(prefix) :]

    normalized_tokens: list[str] = []
    for token in label.lower().split("_"):
        replacement = TOKEN_REPLACEMENTS.get(token, token)
        normalized_tokens.extend(part for part in replacement.split("_") if part)
    return "_".join(normalized_tokens)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path, help="Original PNG directory")
    parser.add_argument("--output", required=True, type=Path, help="Normalized output directory")
    parser.add_argument("--style", default="SMW", help="Style name used in canonical filenames")
    parser.add_argument("--dry-run", action="store_true", help="Report results without writing files")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source_dir = args.source.expanduser().resolve()
    output_dir = args.output.expanduser().resolve()
    style = args.style.strip().upper()

    if not source_dir.is_dir():
        print(f"Source directory does not exist: {source_dir}", file=sys.stderr)
        return 2
    if not re.fullmatch(r"[A-Z0-9]+", style):
        print("Style must contain only ASCII letters and digits", file=sys.stderr)
        return 2
    if output_dir == source_dir or source_dir in output_dir.parents:
        print("Output must be outside the original source directory", file=sys.stderr)
        return 2

    source_files = sorted(
        (path for path in source_dir.iterdir() if path.is_file() and path.suffix.lower() == ".png"),
        key=lambda path: path.name.casefold(),
    )
    if not source_files:
        print(f"No PNG files found in: {source_dir}", file=sys.stderr)
        return 2

    records: list[dict[str, Any]] = []
    errors: list[str] = []
    names_seen: set[str] = set()
    ids_seen: set[str] = set()

    for source_path in source_files:
        match = STRIP_PATTERN.search(source_path.name)
        if not match:
            errors.append(f"{source_path.name}: expected a _StripN.png suffix")
            continue

        frame_count = int(match.group("count"))
        if frame_count < 1:
            errors.append(f"{source_path.name}: frame count must be positive")
            continue

        try:
            image_width, image_height = png_dimensions(source_path)
        except (OSError, ValueError) as error:
            errors.append(f"{source_path.name}: {error}")
            continue

        if image_width % frame_count:
            errors.append(
                f"{source_path.name}: width {image_width} is not divisible by frame count {frame_count}"
            )
            continue

        source_stem = STRIP_PATTERN.sub("", source_path.name)
        label = normalized_label(source_stem, style)
        normalized_name = f"spr_{style}_{label}_Strip{frame_count}.png"
        asset_id = f"{style}/{label}"
        folded_name = normalized_name.casefold()
        folded_id = asset_id.casefold()
        if folded_name in names_seen:
            errors.append(f"{source_path.name}: canonical filename collision: {normalized_name}")
            continue
        if folded_id in ids_seen:
            errors.append(f"{source_path.name}: asset_id collision: {asset_id}")
            continue
        names_seen.add(folded_name)
        ids_seen.add(folded_id)

        digest = sha256_file(source_path)
        records.append(
            {
                "source_path": source_path,
                "source_original": source_path.name,
                "normalized_file": normalized_name,
                "manifest_file": Path(normalized_name).with_suffix(".json").name,
                "asset_id": asset_id,
                "source_sha256": digest,
                "source_width": image_width,
                "source_height": image_height,
                "frame_count": frame_count,
                "frame_width": image_width // frame_count,
                "frame_height": image_height,
            }
        )

    if errors:
        print("No files were written. Resolve these inventory errors first:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 2

    conflicts: list[str] = []
    if output_dir.exists():
        for record in records:
            normalized_path = output_dir / record["normalized_file"]
            if normalized_path.exists() and sha256_file(normalized_path) != record["source_sha256"]:
                conflicts.append(f"{normalized_path.name}: existing file differs from source")

            manifest_path = output_dir / record["manifest_file"]
            if manifest_path.exists():
                try:
                    previous = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
                except (OSError, json.JSONDecodeError) as error:
                    conflicts.append(f"{manifest_path.name}: cannot read existing manifest ({error})")
                else:
                    if previous.get("source_sha256") != record["source_sha256"]:
                        conflicts.append(f"{manifest_path.name}: existing manifest belongs to another source image")

    if conflicts:
        print("No files were written. Resolve these output conflicts first:", file=sys.stderr)
        for conflict in conflicts:
            print(f"- {conflict}", file=sys.stderr)
        return 2

    if args.dry_run:
        print(f"Would process {len(records)} PNG files into {output_dir}")
        return 0

    output_dir.mkdir(parents=True, exist_ok=True)
    created_images = 0
    created_manifests = 0
    catalog_assets: list[dict[str, Any]] = []

    for record in records:
        output_image = output_dir / record["normalized_file"]
        if not output_image.exists():
            shutil.copy2(record["source_path"], output_image)
            created_images += 1

        manifest_path = output_dir / record["manifest_file"]
        if not manifest_path.exists():
            manifest = {
                "schema_version": 1,
                "asset_id": record["asset_id"],
                "source": record["normalized_file"],
                "source_original": record["source_original"],
                "source_sha256": record["source_sha256"],
                "frame_width": record["frame_width"],
                "frame_height": record["frame_height"],
                "frame_count": record["frame_count"],
                "layout": "horizontal_strip",
                "pivot": None,
                "frame_offsets": None,
                "animations": {},
                "metadata_state": "draft",
                "unresolved": [
                    "logical_animation_mapping",
                    "pivot_or_alignment_profile",
                    "frame_offsets_if_needed",
                    "animation_fps",
                    "animation_loop",
                ],
            }
            write_json(manifest_path, manifest)
            created_manifests += 1
        current_manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))

        catalog_assets.append(
            {
                "asset_id": record["asset_id"],
                "source_original": record["source_original"],
                "source": record["normalized_file"],
                "manifest": record["manifest_file"],
                "source_sha256": record["source_sha256"],
                "source_size_px": {
                    "width": record["source_width"],
                    "height": record["source_height"],
                },
                "frame_size_px": {
                    "width": record["frame_width"],
                    "height": record["frame_height"],
                },
                "frame_count": record["frame_count"],
                "metadata_state": current_manifest.get("metadata_state", "draft"),
                "unresolved": current_manifest.get("unresolved", []),
            }
        )

    catalog = {
        "schema_version": 1,
        "style": style,
        "naming_rule": "spr_<STYLE>_<ASSET_ID>_StripN.png",
        "assets": catalog_assets,
    }
    write_json(output_dir / "asset_catalog.json", catalog)

    print(f"PNG files inventoried: {len(records)}")
    print(f"New normalized image copies: {created_images}")
    print(f"New draft manifests: {created_manifests}")
    print(f"Catalog: {output_dir / 'asset_catalog.json'}")
    print("Original files and old .import sidecars were left unchanged.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
