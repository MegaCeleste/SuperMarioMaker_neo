"""Generate a minimal SMM:WE (.swe) level for regression tests.

Usage: python -I tools/make_test_level.py <output.swe> [--width 200]

The format is: base64(json) followed by a hex HMAC-SHA1 of the base64 text,
using the same key as LevelProcessor.SWE_HMAC_KEY. Keeping the fixture
generated (instead of committing a real community level) avoids shipping
third-party level data.
"""
import argparse
import base64
import hashlib
import hmac
import json
import sys
from pathlib import Path

SWE_HMAC_KEY = b"2559F35097-2021"


def build_level(width_tiles=200):
    settings = {
        "date": "01/01/2026",
        "time": "12:00",
        "user": "port-test",
        "etiqueta1": 1,
        "etiqueta2": 0,
        "apariencia": 2,
        "entorno": "ground",
        "cronometro": 300,
        "autoavance": 0,
        "modo_noche": 0,
        "ground2": 432,
        "ground3_x": 0,
        "ground3_y": 432,
        "size": max(496, width_tiles * 16),
        "water_level": 0,
        "water_level_limit": 0,
        "water_level_speed": 0.2,
        "condiciones": 0,
        "condiciones_type": 0,
        "condiciones_object": 0,
        "condiciones_count": 0,
        "description": "Generated porting fixture",
    }
    terrain = [
        {"x_pos": x * 16, "y_pos": 432, "index": 0}
        for x in range(width_tiles)
    ]
    objects = [
        # Starting marker and a small spread of objects the base already knows.
        {"object": "obj_mariostart", "x_pos": 32, "y_pos": 400},
        {"object": "obj_coin_res", "x_pos": 128, "y_pos": 384},
        {"object": "obj_coin_res", "x_pos": 144, "y_pos": 384},
        {"object": "obj_qblock_res", "x_pos": 192, "y_pos": 384},
        {"object": "obj_block_res", "x_pos": 224, "y_pos": 384},
        {"object": "obj_goomba_res", "x_pos": 320, "y_pos": 400},
    ]
    return {
        "MAIN": {
            "AJUSTES": [settings],
            "SUELO": terrain,
            "NIVEL": objects,
        }
    }


def encode_level(level):
    raw = json.dumps(level, separators=(",", ":"), ensure_ascii=False)
    b64 = base64.b64encode(raw.encode("utf-8"))
    digest = hmac.new(SWE_HMAC_KEY, b64, hashlib.sha1).hexdigest()
    return b64 + digest.encode("ascii")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output")
    parser.add_argument("--width", type=int, default=200, help="level width in tiles")
    args = parser.parse_args()
    payload = encode_level(build_level(args.width))
    Path(args.output).write_bytes(payload)
    print(f"wrote {args.output} ({len(payload)} bytes)")


if __name__ == "__main__":
    sys.exit(main())
