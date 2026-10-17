"""Preserve baseline and prepare a public-source-only Gemini research workspace."""
from pathlib import Path
import hashlib, json, shutil

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'local_debug_output/delegations/2026-10-09-entity-batch'
OUT.mkdir(parents=True, exist_ok=True)
baseline = ROOT / 'local_debug_output/entity-batch-baseline.json'
if not baseline.exists():
    paths = ['src/main/game.tscn', 'data/physics/base_physics.tres', 'project.godot', 'src/editor/editor.tscn', 'src/editor/maker_theme.tres']
    baseline.write_text(json.dumps({p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths if (ROOT/p).exists()}, indent=2), encoding='utf-8')
backup = ROOT / 'data/gameplay/pre_smmwe_entities.json'
if not backup.exists():
    shutil.copyfile(ROOT/'data/gameplay/prototype_entities.json', backup)
source = ROOT/'local_debug_output/smmwe-research/source'
workspace = OUT/'public-source'
workspace.mkdir(exist_ok=True)
objects = ['obj_galoomba', 'obj_galoomba2', 'obj_galoomba_hold', 'obj_koopa', 'obj_koopa_red', 'obj_beachkoopa', 'obj_beachkoopa_red', 'obj_shell', 'obj_shell_held', 'obj_enemyparent', 'obj_enemyparent_held', 'obj_deactenemyparent', 'obj_buzzybeetle', 'obj_spiny', 'obj_bobomb', 'obj_bobomb_ready', 'obj_bobomb_hold', 'obj_explosion', 'obj_piranhaplant', 'obj_mushroom', 'obj_fireflower', 'obj_powerupparent', 'obj_star', 'obj_invincibility', 'obj_1up', 'obj_coin', 'obj_coin10', 'obj_coin30', 'obj_coin50', 'obj_score', 'obj_enemy_dead', 'obj_stomped', 'obj_mario']
for name in objects:
    for path in (source/'objects'/name).glob('*'):
        if path.suffix in {'.gml', '.yy'}:
            target = workspace/'objects'/name/path.name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
prompt = '''Read ONLY the public SMMWE 4.0.0 source files in this workspace. This is a copy of public arichornlover/SMMWE-SourceCode, not private project code. Do not modify files. Do not access other paths, credentials, network services, or send messages.
Extract SMW (global.apariencia=2), ground/daytime rules and values for Koopa green/red, naked Koopas, Koopa shells, Buzzy Beetle/shell, Spiny, Bob-omb including held fuse, Piranha Plant, Mushroom/Fire Flower, Star/invincibility, 1UP, Goomba/Galoomba (SMB1 squash vs SMW stun branches), coin10/30/50. Trace inherited events before claiming values.
Output a compact Chinese table: original constants with file/event citations; 32px to 16px at 60Hz conversions (velocity *30, acceleration *1800, frame timers unchanged); interaction matrix for normal stomp/spin/fireball/shell/star/explosion/block bump/holding. Explain which attack ignites a bomb vs defeats it, shell immunity and held fuse timing, star immunity/refresh/speed bonus, and piranha cycle. Distinguish uncertain geometry from source facts. No implementation or private-source review. We authorize the official Google-account Antigravity CLI to send this public source for this analysis.'''
(OUT/'task.md').write_text(prompt, encoding='utf-8')
print(OUT)
