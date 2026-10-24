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
    "Main/Player": ("partial", "SMW small/super/fire land and water motion, source strokes/float art, held buoyancy/diving, surface exit, water rebound/bubbles and interruption/retry cleanup; player fireballs and Fire-to-Super damage; additive Super Star duration/refresh/speed, shader/particles/music, enemy chains and lifecycle cleanup; growth/camera/cadence, source 1px overlap, damage/retry/death, Buzzy/Spiny helmets, stun/freeze/held cleanup verified; other powers/styles missing"),
    "Main/Parents": ("partial", "Native component/state-machine base, source physical-actor activation strip/cadence, inherited shot policies, central death motion/animation with uncancelled events and held pickup/immunity distinctions; terrain/model/sound activation incomplete"),
    "Main/Controllers": ("partial", "SWE load/save/reopen, six SMW theme/background/terrain/music switching, native terrain/spawn and SMW clear; liquid surface settings/movement, physical actor suspension/resumption, WorldDeath selected policies and independent objects, shared animation clock and source render-only impact shake; most controllers missing"),
    "Main": ("partial", "Global controller/persistent scaffolding only"),
    "Enemies/Land": ("minimal", "SMW Galoomba/Goombud and green/red Koopa types, flight, ledges, shells/reentry; standalone jump/fire Piranha types, native attachments, water motion/shots and liquid defeat verified; most land enemies and pipe plants missing"),
    "Enemies/Underground": ("minimal", "SMW Buzzy walking, occupied recovery shells, ceiling drops, rideable wings, parachutes and fire-hit policy verified; other underground enemies missing"),
    "Enemies/Underwater": ("minimal", "SMW Blooper and red/yellow Cheep Cheep swimming/jumps, wings/glide/parachutes, air/water/lava contacts and typed defeat; ordinary SMW player swimming/held buoyancy/surface exit integrated; other water enemies and other player styles missing"),
    "Enemies/Castle": ("minimal", "SMW small/giant Thwomp phases, precise masks, return clocks, liquid effects, blocks, crushing and helmet/POW defeat; legacy/new-small/new-giant Grrrol fixed ellipses, rolling/night/water, source contacts/defeat/death/activation/culling and block-owned break alarms verified; other styles and castle enemies missing"),
    "Enemies/Ghost": ("missing", "No ghost-house enemies"),
    "Enemies/Sky": ("missing", "No sky enemies"),
    "Enemies/Snow": ("missing", "No snow enemies"),
    "Enemies/Desert": ("minimal", "SMW Spiny walking/ceiling/wings, spiked shells, block-flipped recovery and timed cardinal/diagonal needles; small/giant free Chain Chomp historical links, source motion/water/liquid, compound defeat, death/activation/retry verified; other styles, Spiny underwater/night and other desert enemies missing"),
    "Enemies/Forest": ("missing", "No forest enemies"),
    "Enemies/Beach": ("missing", "No beach enemies"),
    "Enemies/Airship": ("minimal", "Source-reviewed SMW Monty chase/origin/sway, Rocky water/settlement/sink/defeat, animated precise Wrench with source arcs/alarms/asymmetric culling, Bro multi-platform jumps/wings/liquids and typed masks, Sledge hover/stun, Monty/Bro typed corpse/block/POW/spin/partner policies and shot pre-motion culling/lifetimes; remaining fidelity cases in REVIEW-2026-10-20.md and other airship enemies missing"),
    "Enemies/Boss": ("missing", "No bosses"),
    "Enemies": ("partial", "Enemy parent/death/projectile-hit API, Galoomba/Koopa/Buzzy/Spiny flight, Blooper/Cheep Cheep motion, standalone Piranha jump/fire/attachments/defeat, Thwomp phases/impacts, Monty Mole chase, Rocky Wrench cycle, five Bros with projectiles, both free Chain Chomp sizes and three Grrrol forms; broader enemy support missing"),
    "Blocks/Item Blocks": ("partial", "Native drag-based coin/mushroom/flower/star/1UP contents for question/hidden/turn blocks; inspect/extract/atomic history, timed multi-coins and upward hidden reveal verified; enemy contents and attachments missing"),
    "Blocks/Bricks": ("partial", "Native ground/turn blocks and SMW hard rock/wood/ice solids; supporting ice traction, giant/Spiny-helmet delayed breaks and typed shards; remaining variants missing"),
    "Interactive/Collectables/Power Ups": ("partial", "Mushroom, ordinary/progressive SMW Fire Flower, basic Super Star and1UP from blocks/native palette, signed SWE/history, physical pickup/motion, Fire Mario/shots/downgrade and timed star speed/flash/particles/music/chain rewards; item attachments and other powers missing"),
    "Interactive/Collectables": ("partial", "Coin, mushroom, ordinary/progressive SMW Fire Flower, basic Super Star and1UP; other collectibles missing"),
    "Interactive/Platforms": ("partial", "SMW solid spike terrain with corrected shared6fps clock and player damage/helmet/star policies; native donut warning/fall/carry/return and winged Buzzy riding; ordinary semisolid three-look/theme art, anchored resizing/history, overlapping decoration/exact top-y depth, separate signed platform collections and native one-way player/item/enemy contacts; moving platforms, conveyors and other semisolid styles missing"),
    "Interactive/Goals": ("partial", "SMW gate/tape, automatic walk, clear music, time tally, victory pose and exit verified; height bonuses and castle endings missing"),
    "Interactive/Special": ("minimal", "SMW Koopa/Buzzy/Spiny shells, occupied recovery, spiked top, throw/ricochet/block impacts/chain scores and native ice freeze/thaw; most specials missing"),
    "Interactive/Others": ("minimal", "SMW Buzzy/Spiny helmet equip, armor, head deflection/defeat, source art/sounds and distinct goal frames; ordinary portable spring carry/releases/compression/player and actor bounces; horizontal/winged springs and other helmets/suits missing"),
    "Interactive": ("missing", "Interactive parent and misc runtime objects"),
    "Blocks": ("partial", "Native question/hidden/turn/hard/ice/note/cloud blocks; explicitly selected SMW thin steep/gentle floor ribbons with reversible connected-terrain fusion, endpoint history and project-only SWE extensions; diagonal ceilings/other slope variants, other block types and note instruments missing"),
    "Editor Res Objects": ("partial", "Editor framework + slice Parts, Galoomba/Goombud, green/red Koopa, Buzzy/Spiny/empty types, Blooper, red/yellow Cheep Cheep, standalone Piranha, small/giant Muncher, small/giant Thwomp, Monty Mole, Rocky Wrench, five Bros, both free Chain Chomp sizes and three Grrrol forms with separate cards, dependent position/flag history and fractional SWE; ~150 resource objects, most missing"),
    "Editor Sounds Effects": ("missing", "Editor sound parts missing"),
    "Editor Res Sounds Effects": ("missing", "Editor sound resource parts missing"),
    "UI/Editor": ("partial", "SWE Save/Save As, SMM1 six-theme SMW background/terrain/music selection with complete environment history, native type/size/attachment windows, drag into question/hidden/turn containers and enlarged inspect/extract view, atomic contents history; current enemy and mushroom/flower/star/1UP/hard/hidden/spring palette; remaining parts/variants incomplete"),
    "UI/Title": ("present", "Title screen"),
    "UI/Intro": ("present", "Intro sequence"),
    "UI/Menu Principal": ("partial", "Main menu shell"),
    "UI/Guardabot": ("partial", "Coursebot level list, async Edit/Play entry and clear return; real OpenWE interoperability not verified"),
    "UI/Settings": ("missing", "Settings menus missing"),
    "UI/Login": ("missing", "Account/login flow missing"),
    "UI/Niveles Mundiales": ("missing", "World-level UI missing"),
    "UI/Desafio Super Mario": ("missing", "Challenge UI missing"),
    "UI/Others": ("partial", "Alerts/toasts/credits partially present"),
    "Decorations": ("partial", "SMM1 six SMW day backgrounds with play animation/editor frame0, native theme selection and shared display camera; other styles/night/themes and authored decorations missing"),
    "Decorations/Hazards": ("minimal", "SMW small/giant Muncher native solid ellipses, falling columns, crushing, semisolid carrying, source helmet/block/POW hits and giant impact verified; other hazards/styles missing"),
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
    lines.append("Generated by `tools/porting/gap_report.py`.\n")
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
