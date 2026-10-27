"""Prepare the local SMW slice/editor assets and generated SWE fixture.

Usage: python -I tools/porting/prepare_slice.py [path/to/openwe-ref]
Third-party images are generated under gitignored assets/openwe only.
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOUNDS = {
    "bgm_smwclear": ("bgm_smwclear", "bgm_smwclear.ogg", b"OggS"),
    "snd_count": ("snd_count.wav", "snd_count.wav", b"RIFF"),
    "snd_countend": ("snd_countend.wav", "snd_countend.wav", b"RIFF"),
    "snd_helmet": ("snd_helmet", "snd_helmet.ogg", b"OggS"),
    "snd_helmet_add": ("snd_helmet_add", "snd_helmet_add.ogg", b"OggS"),
    "snd_helmet_remove": ("snd_helmet_remove", "snd_helmet_remove.ogg", b"OggS"),
    "snd_helmet_spiny": ("snd_helmet_spiny", "snd_helmet_spiny.ogg", b"OggS"),
    "snd_helmet_spiny_add": ("snd_helmet_spiny_add", "snd_helmet_spiny_add.ogg", b"OggS"),
    "snd_podoboo": ("snd_podoboo", "snd_podoboo.ogg", b"OggS"),
    "snd_bump": ("snd_bump", "snd_bump.ogg", b"OggS"),
    "snd_thwomp_original": ("snd_thwomp_original", "snd_thwomp_original.ogg", b"OggS"),
    "snd_klock": ("snd_klock", "snd_klock.ogg", b"OggS"),
    "snd_break": ("snd_break", "snd_break.ogg", b"OggS"),
    "snd_change_arrow": ("snd_change_arrow", "snd_change_arrow.ogg", b"OggS"),
    "snd_NSMBU_snowball_freeze": ("snd_NSMBU_snowball_freeze", "snd_NSMBU_snowball_freeze.ogg", b"OggS"),
    "snd_NSMBU_snowball_break": ("snd_NSMBU_snowball_break", "snd_NSMBU_snowball_break.ogg", b"OggS"),
    "snd_estalactita_break": ("snd_estalactita_break", "snd_estalactita_break.ogg", b"OggS"),
    "snd_fireball": ("snd_fireball", "snd_fireball.ogg", b"OggS"),
    "snd_stomp": ("snd_stomp", "snd_stomp.ogg", b"OggS"),
    "snd_starman": ("snd_starman", "snd_starman.ogg", b"OggS"),
    "snd_switchalert": ("snd_switchalert", "snd_switchalert.ogg", b"OggS"),
    "snd_1up": ("snd_1up", "snd_1up.ogg", b"OggS"),
    "snd_spring": ("snd_spring", "snd_spring.ogg", b"OggS"),
    "snd_swim": ("snd_swim", "snd_swim.ogg", b"OggS"),
}
for name in ["snd_kick", *[f"snd_kick{i}" for i in range(2, 8)], "snd_kick_1up"]:
    SOUNDS[name] = (name, name + ".ogg", b"OggS")
for theme in ("underground", "underwater", "desert", "snow", "sky", "forest", "ghost", "airship", "castle"):
    for prefix in ("snd_editor_", "snd_music_"):
        name = prefix + theme
        SOUNDS[name] = (name, name + ".ogg", b"OggS")
for theme in ("ground", "underground", "underwater", "desert", "snow", "sky", "forest", "ghost", "airship", "castle"):
    name = f"snd_music_{theme}_night"
    SOUNDS[name] = (name, name + ".ogg", b"OggS")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference", type=Path, nargs="?", default=ROOT.parent / "openwe-ref")
    args = parser.parse_args()
    catalog = json.loads((ROOT / "resources/content/smw_player_sprites.json").read_text(encoding="utf-8"))
    names = {entry[0] for power in catalog.values() for entry in power.values()}
    for pattern in ("smw_goomba_*.tres", "smw_koopa_*.tres", "smw_buzzy_*.tres", "smw_spiny*.tres", "smw_blooper*.tres",
                    "smw_cheep_cheep_*.tres", "smw_liquids.tres", "smw_piranha_*.tres", "smw_muncher_*.tres",
                    "smw_flight_*.tres", "smw_enemy_flight_*.tres", "smw_helmet_*.tres", "smw_thwomp_*.tres",
                    "smw_monty*.tres", "smw_rocky*.tres", "smw_wrench*.tres", "smw_hammerbro*.tres", "smw_bro_*.tres",
                    "smw_player_stun.tres", "smw_chomp_*.tres", "smw_grrrol_*.tres"):
        for variant in (ROOT / "resources/content").glob(pattern):
            names.update(re.findall(r'^[a-z0-9_]+_sprite = &"([^"]+)"',
                                    variant.read_text(encoding="utf-8"), re.MULTILINE))
    names.update({"spr_1up", "spr_coin", "spr_goomba_res", "spr_ground", "spr_galoomba",
                  "spr_galoomba_hold", "spr_galoomba_deads", "spr_goalgate", "spr_goal",
                  "spr_qblock", "spr_qblock_empty", "spr_flipblock", "spr_mushroom",
                  "spr_fireflower", "spr_fireflower_res",
                  "spr_star", "spr_star_res", "spr_sparkles", "spr_sparkletrail",
                  "spr_block_rock", "spr_madera", "spr_shard_g", "spr_shard_th", "spr_block_hidden", "spr_points",
                  "spr_block_ice", "spr_shard_ice", "spr_nube", "spr_pinchos", "spr_pinchos_swin",
                  "spr_donut", "spr_donut_fall", "spr_donut_res", "spr_noteblock", "spr_spring",
                  "spr_hammer", "spr_fireball", "spr_snowball", "spr_boomerang",
                  "spr_hammerbro", "spr_hammerbro_jump", "spr_hammerbro_throw", "spr_hammerbro_res",
                  "spr_frozenblock_32x32_2", "spr_frozenblock_32x48", "spr_smokespin",
                  "spr_NSMBU_snowball_destroy", "spr_bubble", "spr_bubble2"})
    names.update({f"spr_ground{i}" for i in range(2, 11)})
    names.update({"spr_ground4_night", "spr_ground10_night"})
    names.update({f"spr_ssp{i}_{theme}" for i in (1, 2, 3)
                  for theme in ("overworld", "underground", "underwater", "desert", "snow", "snow_night",
                                "forest", "ghost", "airship", "castle")})
    names.update({"spr_ssp2_sky", "spr_ssp3_sky"})
    names.add("spr_move_semisolid")
    names.update({"bg_castle", "bg_airship", *[f"bg_underground_{i}" for i in range(1, 5)],
                  *[f"bg_underwater_{i}" for i in range(1, 5)], *[f"bg_ghost_house_{i}" for i in range(1, 4)],
                  "bg_desert", "bg_snow", "bg_forest", "bg_ghost_house_night",
                  *[f"bg_night_{i}" for i in range(1, 5)], *[f"bg_sky_night_{i}" for i in range(1, 4)],
                  *[f"bg_underwater_night_{i}" for i in range(1, 5)]})
    command = [sys.executable, "-I", str(ROOT / "tools/porting/port_sprites.py"),
               str(args.reference.resolve()), str(ROOT)]
    for name in sorted(names):
        command.extend(["--sprite", name])
    subprocess.run(command, check=True)
    manifest = json.loads((ROOT / "assets/openwe/manifests/sprites.json").read_text(encoding="utf-8"))
    missing = names - manifest["sprites"].keys()
    if missing:
        raise FileNotFoundError("Required reference sprites are missing: " + ", ".join(sorted(missing)))
    sound_dir = ROOT / "assets/openwe/sounds"
    sound_dir.mkdir(parents=True, exist_ok=True)
    for name, (source_file, output_file, header) in SOUNDS.items():
        source = args.reference / "sounds" / name / source_file
        if source.read_bytes()[:4] != header:
            raise ValueError(f"Unexpected audio format: {source}")
        shutil.copyfile(source, sound_dir / output_file)
    print(f"Prepared {len(SOUNDS)} local gameplay audio assets")
    subprocess.run([sys.executable, "-I", str(ROOT / "tools/porting/make_test_level.py"),
                    str(ROOT / "tests/fixtures/port_slice.swe"), "--width", "60"], check=True)


if __name__ == "__main__":
    main()
