"""Reproduce the audited ordinary SMMWE Mario rules without executing GML.

This is a Decimal-based numerical model, NOT GameMaker runtime measurement.
Current SMMneo curves come from measure_player_motion.tscn, not a Python port.
"""
from __future__ import annotations

import argparse
import csv
from decimal import Decimal as D
import hashlib
import json
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
SCALE = D('0.5')  # 32-pixel reference tiles -> 16-pixel project tiles.
FPS = D('60')


def horizontal(v: D, axis: int, run: bool, ground: bool) -> D:
    """Other_12:295-380, ordinary non-crouching, no ice/star/carry."""
    cap = D('6') if run else D('2.6')
    if axis == 1:
        if v < cap:
            if v < 0:
                v += D('0.14')
            v += D('0.12')
    elif axis == -1:
        if v > -cap:
            if v > 0:
                v -= D('0.14')
            v -= D('0.12')
    elif ground:
        if v > 0:
            v -= D('0.10')
        elif v < 0:
            v += D('0.10')
        if abs(v) < D('0.10'):
            v = D('0')
    if ground and abs(v) > cap:
        v += -D('0.05') if v > 0 else D('0.05')
        if abs(v) < D('0.05'):
            v = D('0')
    return v


def jump(initial: str, hold: int, *, integrate_first: bool = True) -> tuple[dict, list]:
    """Other_12:25-37,272-273,382-428. Synthetic same-height floor.

    Primary assumption: builtin gravity updates velocity before displacement.
    Alternate integration exposes the one-step-order sensitivity.
    No source collision queries, landing prediction, pixel rounding, or spin y--.
    """
    v, y, minimum = D(initial), D('0'), D('0')
    apex, latched, trace = 0, True, [{'frame': 0, 'y_px': 0.0}]
    for frame in range(1, 601):
        # The literal fall clamp occurs BEFORE automatic gravity integration.
        v = min(v, D('8'))
        if frame > hold:
            latched = False
        if v > D('-1') or not latched:
            g, latched = D('0.6'), False
        else:
            g = D('0.2')
        if integrate_first:
            v += g
            y += v
        else:
            y += v
            v += g
        trace.append({'frame': frame, 'y_px': float(y * SCALE),
                      'vy_px_s': float(v * SCALE * FPS)})
        if y < minimum:
            minimum, apex = y, frame
        if y >= 0:
            break
    return {'height_px': float(-minimum * SCALE), 'height_tiles': float(-minimum / D('32')),
            'apex_frames': apex, 'air_frames': frame,
            'air_seconds': float(D(frame) / FPS)}, trace


def horizontal_metric(start: str, axis: int, run: bool, ground: bool, target: str) -> dict:
    v, distance = D(start), D('0')
    target_v = D(target)
    decreasing = v > target_v
    for frame in range(1, 601):
        v = horizontal(v, axis, run, ground)
        distance += v * SCALE
        reached = v <= target_v if decreasing else v >= target_v
        if reached:
            break
    return {'frames': frame, 'seconds': float(D(frame) / FPS),
            'distance_px': float(distance), 'last_speed_px_s': float(v * SCALE * FPS)}


def verify_source(source: Path) -> dict:
    expected = {
        'options/main/options_main.yy': ['"option_game_speed": 60'],
        'objects/obj_ground/Create_0.gml': ['move_snap(32, 32)'],
        'objects/obj_mario/Other_12.gml': [
            'hspeedmax = (6 +', 'hspeedmax = (2.6 +',
            'hspeed += 0.14', 'hspeed += 0.12', 'hspeed -= 0.10',
            'vspeed = -7.9', 'vspeed = -8.1', 'vspeed = -8.6', 'vspeed = -6.6',
            'vspeed > -1 || jumpnow != 1', 'gravity = 0.2', 'gravity = 0.6',
            'if (statedelay > 4)', 'else if (vspeed > 8)',
        ],
    }
    evidence_files = list(expected) + [
        'objects/obj_mario/Create_0.gml', 'objects/obj_mario/Step_0.gml',
        'objects/obj_mario/Step_2.gml', 'objects/obj_mario/Other_11.gml',
        'objects/obj_mario/Other_25.gml', 'objects/obj_levelmanager/Create_0.gml',
        'objects/obj_levelmanager/Alarm_7.gml', 'objects/obj_levelmanager/Alarm_8.gml',
        'objects/obj_levelmanager/Alarm_9.gml', 'objects/obj_persistent/Step_0.gml',
        'objects/obj_mario/Other_13.gml', 'scripts/slope_collision/slope_collision.gml',
        'sprites/spr_smallmask/spr_smallmask.yy', 'sprites/spr_bigmask/spr_bigmask.yy',
        'sprites/spr_smallduckmask/spr_smallduckmask.yy',
    ]
    evidence = {}
    for relative in evidence_files:
        path = source / relative
        raw = path.read_bytes()
        text = raw.decode('utf-8-sig')
        for literal in expected.get(relative, []):
            if literal not in text:
                raise ValueError(f'Audited literal missing: {relative}: {literal}')
        evidence[relative] = {'sha256': hashlib.sha256(raw).hexdigest(),
                              'lines': len(text.splitlines())}
    return evidence


def chart(traces: dict, output: Path) -> None:
    """Self-contained SVG with data coordinates; no third-party libraries."""
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="800" viewBox="0 0 1200 800">',
             '<rect width="1200" height="800" fill="#101827"/>',
             '<style>text{font-family:Arial,sans-serif;fill:#dce6f2} .grid{stroke:#334155;stroke-width:1}</style>',
             '<text x="55" y="36" font-size="23">SMMneo vs SMMWE 4.0.0: movement curves</text>',
             '<text x="55" y="62" font-size="14">16 px tiles / 60 Hz. SMMneo: real PlayerMotion. SMMWE: source-derived model.</text>']
    panels = [
        (55, 125, 'Standing jump, full hold', 'Height (tiles)', 1.4, 7.2,
         [('SMMneo standing', '#fb7185', 'neo_jump_vx_0.0_hold_600'),
          ('SMMWE standing', '#38bdf8', 'we_jump_standing_hold_600')], True),
        (660, 125, 'Full-speed jump, full hold', 'Height (tiles)', 1.4, 7.2,
         [('SMMneo running', '#fb7185', 'neo_jump_vx_180.0_hold_600'),
          ('SMMWE running', '#38bdf8', 'we_jump_running_hold_600')], True),
        (55, 485, 'Air: hold opposite direction', 'Speed (px/s)', 3, 180,
         [('SMMneo air', '#fb7185', 'neo_reverse_air'),
          ('SMMWE air', '#38bdf8', 'we_reverse_air')], False),
        (660, 485, 'Ground: hold opposite direction', 'Speed (px/s)', 3, 180,
         [('SMMneo ground', '#fb7185', 'neo_reverse_ground'),
          ('SMMWE ground', '#38bdf8', 'we_reverse_ground')], False),
    ]
    for left, top, title, ylabel, xmax, ymax, series, is_jump in panels:
        w, h = 480, 210
        def tx(x: float) -> float:
            return left + x / xmax * w
        def ty(y: float) -> float:
            return top + h - (y / ymax if is_jump else (y + ymax) / (2 * ymax)) * h
        parts.append(f'<text x="{left}" y="{top-28}" font-size="18">{title}</text>')
        parts.append(f'<text x="{left}" y="{top-9}" font-size="12">{ylabel}</text>')
        for i in range(5):
            x = i * xmax / 4
            parts.append(f'<path class="grid" d="M{tx(x):.2f},{top} V{top+h}"/>')
            parts.append(f'<text x="{tx(x):.2f}" y="{top+h+20}" font-size="12" text-anchor="middle">{x:.2f}</text>')
        ticks = [0, 2, 4, 6] if is_jump else [-180, -90, 0, 90, 180]
        for y in ticks:
            parts.append(f'<path class="grid" d="M{left},{ty(y):.2f} H{left+w}"/>')
            parts.append(f'<text x="{left-9}" y="{ty(y)+4:.2f}" font-size="12" text-anchor="end">{y}</text>')
        for i, (label, color, key) in enumerate(series):
            points = []
            for row in traces[key]:
                x = row['frame'] / 60
                y = max(0, -row['y_px'] / 16) if is_jump else row['vx_px_s']
                if x <= xmax:
                    points.append(f'{tx(x):.2f},{ty(y):.2f}')
            parts.append(f'<polyline points="{" ".join(points)}" fill="none" stroke="{color}" stroke-width="3"/>')
            parts.append(f'<text x="{left+12+i*240}" y="{top+h+46}" font-size="13" style="fill:{color}">{label}</text>')
        parts.append(f'<text x="{left+w}" y="{top+h+20}" font-size="12">s</text>')
    parts.append('<text x="55" y="786" font-size="12">SMMWE curves assume gravity before displacement; no world collision or pixel rounding. These are not official SMM2 measurements.</text>')
    parts.append('</svg>')
    output.write_text('\n'.join(parts), encoding='utf-8')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=PROJECT / 'local_debug_output/smmwe-research/source')
    parser.add_argument('--native', type=Path, default=PROJECT / 'local_debug_output/smmwe-research/smmneo-native-metrics.json')
    parser.add_argument('--out', type=Path, default=PROJECT / 'docs/research/smmwe-4.0.0')
    args = parser.parse_args()
    evidence = verify_source(args.source)
    manifest_path = args.source.parent / 'source-manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    native = json.loads(args.native.read_text(encoding='utf-8-sig'))
    traces = {'neo_' + k: v for k, v in native.pop('traces').items()}
    reference = {}
    sensitivity = {}
    for name, initial in [('standing', '-7.9'), ('walking', '-8.1'), ('running', '-8.6'), ('spin', '-6.6')]:
        for hold in [1, 6, 12, 600]:
            key = f'jump_{name}_hold_{hold}'
            reference[key], traces['we_' + key] = jump(initial, hold)
            sensitivity[key], _ = jump(initial, hold, integrate_first=False)
    for name, start, axis, run, ground, target in [
        ('accelerate_walk', '0', 1, False, True, '2.6'),
        ('accelerate_run', '0', 1, True, True, '6'),
        ('release_walk', '2.6', 0, False, True, '0'),
        ('release_run', '6', 0, True, True, '0'),
        ('reverse_ground', '6', -1, True, True, '0'),
        ('reverse_air', '6', -1, True, False, '0'),
        ('release_run_key_keep_direction', '6', 1, False, True, '2.6'),
    ]:
        reference[name] = horizontal_metric(start, axis, run, ground, target)
    for ground in [False, True]:
        v, rows = D('6'), [{'frame': 0, 'vx_px_s': 180.0}]
        for frame in range(1, 181):
            v = horizontal(v, -1, True, ground)
            rows.append({'frame': frame, 'vx_px_s': float(v * SCALE * FPS)})
        traces['we_reverse_ground' if ground else 'we_reverse_air'] = rows
    # Native metrics are obtained by running the current real Godot class.
    output = {
        'status': {'smmwe': 'SOURCE_DERIVED_MODEL_NOT_GAME_RUNTIME',
                   'smmneo': 'NATIVE_PLAYER_MOTION_SYNTHETIC_FLOOR',
                   'owner_playtest_accepted': False},
        'units': {'fps': 60, 'smmwe_tile_px': 32, 'smmneo_tile_px': 16,
                  'speed_multiplier': 30, 'acceleration_multiplier': 1800},
        'assumptions': ['ordinary daytime SMW, no ice/star/powerup/carry/mount',
                        'reference gravity before displacement; Decimal exact literals',
                        'synthetic same-height floor, no predictive landing, collision or camera',
                        'spin curve excludes the separate y-- (0.5 normalized px)'],
        'smmwe': reference, 'smmneo': native,
        'smmwe_alternate_move_before_gravity': sensitivity,
        'source_files': evidence,
        'source_archive': {key: manifest[key] for key in [
            'source_index', 'source_file_id', 'download_name', 'archive_bytes',
            'archive_sha256', 'archive_prefix']},
        'smmneo_files': {relative: hashlib.sha256((PROJECT / relative).read_bytes()).hexdigest()
                        for relative in ['data/physics/base_physics.tres',
                                         'src/gameplay/player/player_motion.gd',
                                         'src/gameplay/player/player_physics_profile.gd',
                                         'tools/research/measure_player_motion.gd']},
    }
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / 'metrics.json').write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    with (args.out / 'traces.csv').open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['scenario', 'frame', 'seconds', 'y_px', 'vx_px_s', 'vy_px_s'])
        writer.writeheader()
        for key, rows in traces.items():
            for row in rows:
                writer.writerow({'scenario': key, 'seconds': row['frame'] / 60, **row})
    chart(traces, args.out / 'curves.svg')
    print(json.dumps({'reference': reference,
                      'native_key_results': {k: native[k] for k in ['reverse_air', 'reverse_ground', 'jump_vx_0.0_hold_600', 'jump_vx_180.0_hold_600']}}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
