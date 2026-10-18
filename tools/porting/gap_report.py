"""Compare OpenWE (GMS2 spec) against GodotWE (Godot base) and emit a report.

Usage: python -I tools/gap_report.py <openwe.json> <godotwe.json> <output.md>
"""
import json
import sys
from collections import defaultdict
from pathlib import Path

# Longest-prefix match against the folder path below "folders/Objects/".
# Status: present | partial | minimal | missing | n/a
COVERAGE = {
    "Main/Player": ("partial", "Player + Idle/Moving/Jumping/Falling/SpinJump/Death states; only SMW, small/super powers"),
    "Main/Parents": ("partial", "Part/Entity/Enemy component+state-machine base classes exist"),
    "Main/Controllers": ("partial", "LevelManager, audio, cursor, camera scaffolding; most controllers missing"),
    "Main": ("partial", "Global controller/persistent scaffolding only"),
    "Enemies/Land": ("minimal", "Only Galoomba and green Koopa"),
    "Enemies/Underground": ("missing", "No underground enemies"),
    "Enemies/Underwater": ("missing", "No underwater enemies"),
    "Enemies/Castle": ("missing", "No castle enemies/hazards"),
    "Enemies/Ghost": ("missing", "No ghost-house enemies"),
    "Enemies/Sky": ("missing", "No sky enemies"),
    "Enemies/Snow": ("missing", "No snow enemies"),
    "Enemies/Desert": ("missing", "No desert enemies"),
    "Enemies/Forest": ("missing", "No forest enemies"),
    "Enemies/Beach": ("missing", "No beach enemies"),
    "Enemies/Airship": ("missing", "No airship enemies"),
    "Enemies/Boss": ("missing", "No bosses"),
    "Enemies": ("partial", "Enemy parent, dead and wings scaffolding only"),
    "Blocks/Item Blocks": ("partial", "Question block + turn block only"),
    "Blocks/Bricks": ("partial", "Basic ground/brick collision only"),
    "Interactive/Collectables/Power Ups": ("partial", "Mushroom only (small/super)"),
    "Interactive/Collectables": ("partial", "Coin and mushroom only"),
    "Interactive/Platforms": ("missing", "No moving platforms (conveyor, mushroom, semisolid variants)"),
    "Interactive/Goals": ("missing", "No goal pole / castle endings"),
    "Interactive/Special": ("missing", "No doors, warps, transitions, meteorites, score effects"),
    "Interactive/Others": ("missing", "Suits/helmets and misc interactive objects"),
    "Interactive": ("missing", "Interactive parent and misc runtime objects"),
    "Blocks": ("partial", "Block parents + question/turn blocks only"),
    "Editor Res Objects": ("partial", "Editor framework + 6 parts; ~150 resource objects, most missing"),
    "Editor Sounds Effects": ("missing", "Editor sound parts missing"),
    "Editor Res Sounds Effects": ("missing", "Editor sound resource parts missing"),
    "UI/Editor": ("partial", "Editor shell/palette/popouts exist; most part-specific UIs missing"),
    "UI/Title": ("present", "Title screen"),
    "UI/Intro": ("present", "Intro sequence"),
    "UI/Menu Principal": ("partial", "Main menu shell"),
    "UI/Guardabot": ("partial", "Coursebot level list shell"),
    "UI/Settings": ("missing", "Settings menus missing"),
    "UI/Login": ("missing", "Account/login flow missing"),
    "UI/Niveles Mundiales": ("missing", "World-level UI missing"),
    "UI/Desafio Super Mario": ("missing", "Challenge UI missing"),
    "UI/Others": ("partial", "Alerts/toasts/credits partially present"),
    "Decorations": ("missing", "Only one SMW overworld background"),
    "Collisions": ("partial", "Uses Godot physics; collision parents need mapping"),
    "Items": ("missing", "Item layer not ported"),
    "Demo": ("n/a", "Demo-only objects"),
    "Discord Webhook": ("n/a", "External integration, out of scope"),
}


def area_name(folder_path):
    if not folder_path:
        return "(no folder)"
    path = folder_path
    if path.startswith("folders/Objects/"):
        path = path[len("folders/Objects/"):]
    elif path.startswith("folders/"):
        path = path[len("folders/"):]
    if path.endswith(".yy"):
        path = path[:-3]
    return path


def coverage_for(area):
    best = None
    for prefix in COVERAGE:
        if area == prefix or area.startswith(prefix + "/"):
            if best is None or len(prefix) > len(best):
                best = prefix
    if best is None:
        return ("unassessed", "")
    return COVERAGE[best]


def main():
    openwe = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    godotwe = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
    out_path = Path(sys.argv[3]).resolve()

    groups = defaultdict(lambda: {
        "objects": 0, "lines": 0, "res": 0, "runtime": 0, "examples": []
    })
    for obj in openwe["objects"]:
        area = area_name(obj.get("folder"))
        group = groups[area]
        group["objects"] += 1
        group["lines"] += obj.get("gml_lines", 0)
        if obj["name"].endswith("_res"):
            group["res"] += 1
        else:
            group["runtime"] += 1
        if len(group["examples"]) < 6:
            group["examples"].append(obj["name"])

    total_lines = sum(o.get("gml_lines", 0) for o in openwe["objects"])
    total_script_lines = openwe["counts"].get("gml_lines_total", 0)

    lines = []
    lines.append("# OpenWE → GodotWE gap report\n")
    lines.append("Generated by `tools/gap_report.py`.\n")
    lines.append("## Source sizes\n")
    lines.append(f"- OpenWE: {openwe['counts'].get('objects', 0)} objects, "
                 f"{openwe['counts'].get('scripts', 0)} scripts "
                 f"({total_script_lines} script lines), "
                 f"{openwe['counts'].get('rooms', 0)} rooms, "
                 f"{openwe['counts'].get('sprites', 0)} sprites, "
                 f"{openwe['counts'].get('sounds', 0)} sounds")
    lines.append(f"- Object event code: {total_lines} lines")
    lines.append(f"- GodotWE: {godotwe['counts'].get('scripts', 0)} GDScript files "
                 f"({godotwe['counts'].get('gd_lines_total', 0)} lines), "
                 f"{godotwe['counts'].get('scenes', 0)} scenes\n")

    lines.append("## Coverage by resource folder\n")
    lines.append("| Area | Objects | Runtime | Editor res | GML lines | Status | Notes |")
    lines.append("|---|---:|---:|---:|---:|---|---|")
    for area, g in sorted(groups.items(), key=lambda kv: -kv[1]["lines"]):
        status, note = coverage_for(area)
        lines.append(
            f"| {area} | {g['objects']} | {g['runtime']} | {g['res']} | "
            f"{g['lines']} | {status} | {note} |"
        )

    lines.append("\n## Largest objects by event-code size\n")
    lines.append("| Object | Folder | GML lines | Events |")
    lines.append("|---|---|---:|---:|")
    largest = sorted(openwe["objects"], key=lambda o: -o.get("gml_lines", 0))[:30]
    for obj in largest:
        lines.append(
            f"| {obj['name']} | {area_name(obj.get('folder'))} | "
            f"{obj.get('gml_lines', 0)} | {obj.get('gml_files', 0)} |"
        )

    lines.append("\n## Largest GML scripts\n")
    script_rows = sorted(openwe["scripts"], key=lambda s: -s.get("lines", 0))[:40]
    lines.append("| Script | Lines | Functions |")
    lines.append("|---|---:|---:|")
    for script in script_rows:
        lines.append(
            f"| {script['name']} | {script.get('lines', 0)} | "
            f"{len(script.get('functions', []))} |"
        )

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
