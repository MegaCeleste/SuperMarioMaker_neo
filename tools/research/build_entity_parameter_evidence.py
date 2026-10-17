"""Rebuild adopted-value evidence from the preserved local public SMMWE source.

This records Codex's event/branch audit; it is not an automatic GML interpreter.
Run from any directory after installing the documented 4.0.0 source archive.
"""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'local_debug_output/smmwe-research/source/objects'
CONFIG = json.loads((ROOT / 'data/gameplay/prototype_entities.json').read_text(encoding='utf-8'))
BEFORE = json.loads((ROOT / 'data/gameplay/pre_smmwe_entities.json').read_text(encoding='utf-8'))
RECORDS = []


def record(key, original, factor, event, note=''):
    section, parameter = key.split('.')
    path = SOURCE / event
    raw = path.read_bytes()
    adopted = CONFIG[section][parameter]
    expected = original * factor
    if abs(adopted - expected) > 0.00001:
        raise ValueError(f'{key}: adopted {adopted} differs from reference {expected}')
    RECORDS.append(dict(parameter=key, original=original, conversion_factor=factor,
        converted=expected, adopted=adopted, before=BEFORE.get(section, {}).get(parameter),
        event=event, local_source='local_debug_output/smmwe-research/source/objects/' + event,
        source_sha256=hashlib.sha256(raw).hexdigest(),
        evidence='SMMWE_SOURCE_REFERENCE_WITH_GODOT_ADAPTATIONS', adaptation=note))


record('enemy.speed', 1, 30, 'obj_galoomba/Alarm_10.gml', 'SMB1 squash behavior supplies Goomba; SMW stun supplies Galoomba. Existing art choices retained.')
record('enemy.gravity', .4, 1800, 'obj_physicsparent/Other_14.gml', 'Godot move_and_slide replaces GameMaker pixel prediction and gravity=0 grounding.')
record('enemy.max_fall', 8, 30, 'obj_physicsparent/Other_14.gml', 'Limit before gravity; a full falling step may reach 252 px/s.')
record('enemy.death_initial', 4, -30, 'obj_enemy_dead/Alarm_0.gml', 'Ordinary enemy branch spd=4, vspeed=-spd; no separate dead object in Godot.')
record('goomba.squash_frames', 30, 1, 'obj_stomped/Create_0.gml')
record('galoomba.recovery_frames', 600, 1, 'obj_galoomba_hold/Create_0.gml', 'Holding suspends recovery; actor owns remaining time.')
record('galoomba.bump_initial', -6, 30, 'obj_galoomba/Other_15.gml')
record('galoomba.throw_speed', 4, 30, 'obj_holdparent/Other_12.gml', 'Held release adds absolute player velocity; component still provides the release gesture.')
record('galoomba.throw_lift', -3, 30, 'obj_holdparent/Other_12.gml')
record('galoomba.throw_up_initial', -12.25, 30, 'obj_holdparent/Other_12.gml', 'Existing carry offset and zero horizontal high toss retained.')
record('galoomba.friction', .17, 1800, 'obj_holdparent/Step_0.gml')
record('mushroom.speed', 2, 30, 'obj_mushroom/Alarm_10.gml')
record('mushroom.bump_initial', -6, 30, 'obj_mushroom/Collision_obj_blockparent.gml')
record('flower.bump_initial', -6, 30, 'obj_powerupparent/Collision_obj_blockparent.gml')
record('coin.popup_initial', -4, 30, 'obj_blockcoin/Alarm_0.gml')
record('coin.popup_gravity', .2, 1800, 'obj_blockcoin/Alarm_0.gml', 'Update displacement before gravity, using 60 Hz physics.')
record('coin.popup_end_offset', -20, .5, 'obj_blockcoin/Step_0.gml', 'Popup ends when downward travel crosses this height; 60-frame maximum is an engineering cleanup guard.')
record('naked_koopa.eject_speed', 6, 30, 'obj_koopa/Other_11.gml')
record('naked_koopa.slide_decel', .1, 1800, 'obj_beachkoopa/Step_0.gml')
record('naked_koopa.immunity_frames', 30, 1, 'obj_koopa/Other_11.gml')
record('naked_koopa.recovery_frames', 90, 1, 'obj_beachkoopa/Step_0.gml')
record('naked_koopa.enter_jump', -5.2, 30, 'obj_beachkoopa/Step_0.gml', 'Forward-shell and landing overlap use explicit Godot geometry candidates.')
record('naked_koopa.recover_jump', -4, 30, 'obj_beachkoopa/Alarm_10.gml')
record('shell.kick_initial', 4, 30, 'obj_shell/Other_12.gml', 'Stationary kick reuses this release constant; moving held release starts at 4.4 plus half player speed.')
record('shell.slide_speed', 4.4, 30, 'obj_shell/Other_12.gml', 'Kick and held release are distinct; stationary held release accelerates toward 5 instead.')
record('shell.held_slide_speed', 5, 30, 'obj_shell/Other_12.gml')
record('shell.held_slide_cap', 6.4, 30, 'obj_shell/Other_12.gml')
record('shell.slide_accel', .1, 1800, 'obj_shell_held/Step_0.gml')
record('shell.kick_protection_frames', 15, 1, 'obj_enemyparent_held/Create_0.gml', 'Protection expires even before a wall return; shell sweeps query crossed targets.')
record('shell.enter_green_frames', 60, 1, 'obj_beachkoopa/Collision_obj_shell.gml')
record('shell.enter_red_frames', 70, 1, 'obj_beachkoopa_red/Collision_obj_shell.gml')
record('shell.bump_recovery_frames', 600, 1, 'obj_koopa/Other_15.gml', 'Bumped Koopa ejects a naked Koopa; bumped Buzzy recovers as Buzzy. New headroom check defers conversion.')
record('shell.throw_up_initial', -12.25, 30, 'obj_shell/Other_12.gml', 'Keep vertical high toss; source small moving-player horizontal drift omitted as explicit adaptation.')
record('buzzy.recovery_frames', 640, 1, 'obj_buzzybeetle/Other_11.gml', 'Recovery advances only while stationary; moving obj_shell_held has no stationary wake alarms, and holding suspends the actor.')
record('spiny.recovery_frames', 640, 1, 'obj_spiny/Other_15.gml', 'Flipped ground shell is derived internally; wearable shell remains out of scope.')
record('bob_omb.fuse_frames', 300, 1, 'obj_bobomb_hold/Create_0.gml', 'Fuse is a pausable child component that ticks while held; state changes retain its remaining time.')
record('bob_omb.fireball_push', 1.2, 30, 'obj_fireball/Collision_obj_bobomb_hold.gml', 'First fireball ignites only; later fireballs push without refreshing fuse.')
record('bob_omb.fireball_lift', -1.5, 30, 'obj_fireball/Collision_obj_bobomb_hold.gml')
record('bob_omb.bump_initial', -3, 30, 'obj_bobomb/Other_15.gml')
record('piranha.speed', 1, 30, 'obj_piranhaplant/Alarm_0.gml')
record('piranha.travel_frames', 32, 1, 'obj_piranhaplant/Alarm_0.gml', '32 source pixels become 16 world pixels, not 32; travel remains 32 frames.')
record('piranha.wait_frames', 90, 1, 'obj_piranhaplant/Alarm_1.gml')
record('piranha.damage_threshold', 16, .5, 'obj_piranhaplant/Alarm_0.gml', 'Alarm_5 toggles hardness after 16 travel frames, equivalent to 8 world pixels; exposed collision still changes continuously.')
record('star.speed', 1, 30, 'obj_star/Alarm_10.gml')
record('star.gravity', .125, 1800, 'obj_star/Step_0.gml')
record('star.bounce_initial', -4, 30, 'obj_star/Step_0.gml')
record('star.duration_frames', 600, 1, 'obj_invincibility/Create_0.gml')
record('star.speed_bonus', 1, 30, 'obj_mario/Other_12.gml', 'Temporary walk/run threshold bonus; permanent PlayerPhysicsProfile remains unchanged.')
record('one_up.speed', 1, 30, 'obj_1up/Alarm_10.gml')
record('one_up.bump_initial', -3, 30, 'obj_1up/Collision_obj_blockparent.gml')
record('explosion.frames', 30, 1, 'obj_explosion/Create_0.gml', 'Each target settles once; neighboring bombs are defeated rather than igniting a new fuse.')

objects = ['obj_galoomba', 'obj_galoomba_hold', 'obj_koopa', 'obj_koopa_red', 'obj_beachkoopa', 'obj_beachkoopa_red',
    'obj_shell', 'obj_shell_held', 'obj_buzzybeetle', 'obj_spiny', 'obj_bobomb', 'obj_bobomb_ready', 'obj_bobomb_hold',
    'obj_piranhaplant', 'obj_mushroom', 'obj_fireflower', 'obj_star', 'obj_1up', 'obj_coin', 'obj_coin10']
chains = {}
for obj in objects:
    chain = [obj]
    while True:
        text = (SOURCE / chain[-1] / (chain[-1] + '.yy')).read_text(encoding='utf-8')
        match = re.search(r'"parentObjectId"\s*:\s*\{\s*"name"\s*:\s*"([^"]+)"', text)
        if not match:
            break
        parent = match[1]
        if parent in chain:
            raise ValueError('Inheritance cycle: ' + parent)
        chain.append(parent)
    chains[obj] = chain

archive = ROOT / 'local_debug_output/smmwe-research/SMM_WE_4.0.0.zip'
output = dict(schema_version=1, version='SMMWE 4.0.0', audit_date='2026-10-09',
    source_index='https://github.com/arichornlover/SMMWE-SourceCode',
    archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
    scale='32px to 16px, 60Hz: velocity ×30, acceleration ×1800, distance ×0.5, frame timers unchanged',
    evidence_scope='Source-derived reference plus explicit Godot adaptations; no SMM2 measurement or owner play approval',
    inheritance_chains=chains, parameters=RECORDS,
    art_timing=[dict(group=key, original=.15, converted_fps=9, event=event) for key,event in [
        ('fire_flower','obj_fireflower/Create_0.gml'), ('coin','obj_coin/Create_0.gml')]],
    candidates=['Godot terrain/hurt/stomp/pickup geometry and shape queries', 'cleanup boundaries and popup guard',
        'carry offsets from existing player profile', 'stationary kick speed/call-path adaptation',
        'bomb side kick 126px/s', 'rotated proximity region for horizontal/downward piranha (source horizontal equality bug)',
        'circle explosion radius 11.5 from source mask bbox2..47 at half scale; hand victim explicitly included',
        'warning/tint timing and visual animation candidates where not directly mapped'])
path = ROOT / 'data/gameplay/entity_parameter_evidence.json'
path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Wrote {len(RECORDS)} adopted parameter records and {len(chains)} inheritance chains.')
