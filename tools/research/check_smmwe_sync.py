"""Compare native measurements to the archived, independently derived source model.

Run measure_player_motion.tscn twice with --output and --profile as documented
in docs/plans/2026-10-08-smmwe-physics-sync.md, then run this script.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'local_debug_output/smmwe-sync'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def main():
    native = read(WORK / 'native-metrics.json')
    previous = read(WORK / 'previous-metrics.json')
    historical = read(ROOT / 'docs/research/smmwe-4.0.0/metrics.json')
    failures = []
    checks = []

    def check(name, actual, expected, tolerance=0.001):
        passed = abs(actual - expected) <= tolerance
        checks.append({'name': name, 'actual': actual, 'expected': expected, 'passed': passed})
        if not passed:
            failures.append(name)

    for speed, kind in [('0.0', 'standing'), ('78.0', 'walking'), ('180.0', 'running')]:
        for hold in [1, 6, 12, 600]:
            key = f'jump_vx_{speed}_hold_{hold}'
            reference = historical['smmwe'][f'jump_{kind}_hold_{hold}']
            for field in ['height_px', 'apex_frames', 'air_frames']:
                check(f'{key}.{field}', native[key][field], reference[field])
    for hold in [1, 6, 12, 600]:
        for field in ['height_px', 'apex_frames', 'air_frames']:
            check(f'spin_hold_{hold}.{field}', native[f'spin_hold_{hold}'][field], historical['smmwe'][f'jump_spin_hold_{hold}'][field])
    for key in ['reverse_air', 'reverse_ground']:
        check(key, native[key]['sign_change_frame'], historical['smmwe'][key]['frames'], 0)
    for key in ['accelerate_walk', 'accelerate_run', 'release_run', 'release_run_key_keep_direction']:
        check(key, native[key]['frames'], historical['smmwe'][key]['frames'], 0)
    for key, expected in historical['smmneo'].items():
        for field, value in expected.items():
            if isinstance(value, (int, float)):
                check(f'legacy.{key}.{field}', previous[key][field], value)
    boundaries = read(WORK / 'boundary-results.json')
    if boundaries['failures']:
        failures += boundaries['failures']
    # Walking release starts at 79.8 after actual soft-cap acceleration, while
    # the historical comparison intentionally starts at its 78 threshold.
    report = {
        'date': '2026-10-08', 'status': 'PASS' if not failures else 'FAIL',
        'scope': 'Ordinary daytime SMW motion; native Godot synthetic floor and real Player collisions',
        'reference': 'docs/research/smmwe-4.0.0/metrics.json',
        'units': {'tile_px': 16, 'fps': 60},
        'numeric_checks': len(checks), 'boundary_results': boundaries,
        'failures': failures, 'checks': checks,
        'native': {k: v for k, v in native.items() if k != 'traces'},
        'previous': {k: v for k, v in previous.items() if k != 'traces'},
        'assumptions': [
            'Reference assumes gravity before displacement and terminal clamping before gravity.',
            'Spin excludes the separate source y-- offset of 0.5 normalized px.',
            'Walking release starts at the achieved soft-cap speed rather than exactly 78.',
            'No SMMWE GameMaker execution or human playtest acceptance.',
        ],
        'runtime_sha256': {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in [
            'data/physics/base_physics.tres', 'data/physics/pre_smmwe_physics.tres',
            'src/gameplay/player/player_motion.gd', 'src/gameplay/player/player_physics_profile.gd',
            'src/gameplay/player/player.gd', 'src/gameplay/debug/physics_dashboard.gd',
        ]},
    }
    destination = ROOT / 'docs/research/smmwe-sync-2026-10-08.json'
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f"{report['status']}: {len(checks)} numerical comparisons, {boundaries['checks']} boundary assertions; {len(failures)} failures.")
    if failures:
        raise SystemExit('\n'.join(failures))


if __name__ == '__main__':
    main()
