"""Extract reviewed UI frames; keep originals and refuse to replace differing local art."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True, help="Original textures/ui directory")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    source = args.source.resolve()
    manifest = json.loads((root / "data/assets/editor_reference.json").read_text(encoding="utf-8"))
    evidence = []
    for entry in manifest["frames"]:
        origin = (source / entry["source"]).resolve()
        origin.relative_to(source)
        output = (root / entry["destination"]).resolve()
        output.relative_to(root / "textures")
        output.parent.mkdir(parents=True, exist_ok=True)
        if "region" in entry:
            image = Image.open(origin).convert("RGBA")
            x, y, width, height = entry["region"]
            assert x >= 0 and y >= 0 and x + width <= image.width and y + height <= image.height
            image = image.crop((x, y, x + width, y + height))
            if entry.get("remove_sheet_background"):
                background = image.getpixel((0, 0))
                image.putdata([(r, g, b, 0) if (r, g, b, a) == background else (r, g, b, a) for r, g, b, a in image.getdata()])
            if output.exists():
                assert Image.open(output).convert("RGBA").tobytes() == image.tobytes(), f"Refusing to overwrite {output}"
            else:
                image.save(output)
        else:
            if output.exists():
                assert origin.read_bytes() == output.read_bytes(), f"Refusing to overwrite {output}"
            else:
                shutil.copy2(origin, output)
        evidence.append({**entry, "source_sha256": hashlib.sha256(origin.read_bytes()).hexdigest(), "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest()})
    # Rasterize small original SVGs at their reference-screen size, keeping pixel part art nearest.
    svg_imports = list((root / "textures/ui/editor").rglob("*.svg.import"))
    svg_imports += [root / "textures/ui/btn_menu.svg.import"]
    for file in svg_imports:
        original = file.read_text(encoding="utf-8")
        text = re.sub(r"(?m)^base_scale=[0-9.]+$", "base_scale=5.0", original)
        if text != original:
            file.write_text(text, encoding="utf-8")
    (root / "local_debug_output/editor-reference-assets.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Installed {len(evidence)} reviewed frames; original files preserved")


if __name__ == "__main__":
    main()
