"""Inventory a Godot 4 project (project.godot, .tscn, .gd).

Usage: python -I tools/inventory_godot.py <project_root> <output.json>
"""
import json
import re
import sys
from pathlib import Path

FUNC_RE = re.compile(r"^\s*func\s+([A-Za-z_]\w*)\s*\(", re.MULTILINE)
SIGNAL_RE = re.compile(r"^\s*signal\s+([A-Za-z_]\w*)", re.MULTILINE)
CLASS_RE = re.compile(r"^\s*class_name\s+([A-Za-z_]\w*)", re.MULTILINE)
EXTENDS_RE = re.compile(r"^\s*extends\s+([A-Za-z_\w\.\"]+)", re.MULTILINE)
EXPORT_RE = re.compile(r"^\s*@export[^\n]*\bvar\s+([A-Za-z_]\w*)", re.MULTILINE)
NODE_RE = re.compile(
    r'^\[node name="([^"]*)"(?:\s+type="([^"]*)")?(?:\s+parent="([^"]*)")?', re.MULTILINE
)
EXT_RES_RE = re.compile(r'^\[ext_resource[^\]]*?path="([^"]+)"([^\]]*)\]', re.MULTILINE)
SCENE_RE = re.compile(
    r'^\[gd_scene.*?format=(\d+)', re.MULTILINE
)


def parse_project_godot(root: Path):
    path = root / "project.godot"
    info = {"application": {}, "autoloads": [], "input_actions": []}
    if not path.exists():
        return info
    section = None
    for raw in path.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        line = raw.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section == "application" and "=" in line:
            key, _, value = line.partition("=")
            info["application"][key.strip()] = value.strip().strip('"')
        elif section == "autoload" and "=" in line:
            info["autoloads"].append(line.split("=")[0].strip())
        elif section == "input" and line.endswith("={"):
            info["input_actions"].append(line.split("=")[0].strip())
    return info


def inventory_scripts(root: Path):
    out = []
    for gd in sorted(root.rglob("*.gd")):
        if ".godot" in gd.parts:
            continue
        text = gd.read_text(encoding="utf-8-sig", errors="replace")
        out.append(
            {
                "name": gd.stem,
                "path": gd.relative_to(root).as_posix(),
                "class_name": next(iter(CLASS_RE.findall(text)), None),
                "extends": next(iter(EXTENDS_RE.findall(text)), None),
                "functions": sorted(set(FUNC_RE.findall(text))),
                "signals": sorted(set(SIGNAL_RE.findall(text))),
                "exports": sorted(set(EXPORT_RE.findall(text))),
                "lines": text.count("\n") + 1,
            }
        )
    return out


def inventory_scenes(root: Path):
    out = []
    for tscn in sorted(root.rglob("*.tscn")):
        if ".godot" in tscn.parts:
            continue
        text = tscn.read_text(encoding="utf-8-sig", errors="replace")
        nodes = NODE_RE.findall(text)
        node_types = {}
        for _name, ntype, _parent in nodes:
            if ntype:
                node_types[ntype] = node_types.get(ntype, 0) + 1
        scripts = [p for p, _attrs in EXT_RES_RE.findall(text) if p.endswith(".gd")]
        out.append(
            {
                "name": tscn.stem,
                "path": tscn.relative_to(root).as_posix(),
                "format": next(iter(SCENE_RE.findall(text)), None),
                "nodes": len(nodes),
                "node_types": node_types,
                "scripts": scripts,
            }
        )
    return out


def main():
    root = Path(sys.argv[1]).resolve()
    out_path = Path(sys.argv[2]).resolve()
    report = {
        "root": str(root),
        "project": parse_project_godot(root),
        "scripts": inventory_scripts(root),
        "scenes": inventory_scenes(root),
    }
    report["counts"] = {
        "scripts": len(report["scripts"]),
        "scenes": len(report["scenes"]),
        "gd_lines_total": sum(s["lines"] for s in report["scripts"]),
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    print(json.dumps(report["counts"], ensure_ascii=False))


if __name__ == "__main__":
    main()
