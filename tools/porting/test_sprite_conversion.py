"""Source metadata regressions, runnable without Godot or private images."""
import runpy
import unittest
from pathlib import Path

CONVERTER = runpy.run_path(str(Path(__file__).with_name("port_sprites.py")))


class SpriteOriginTests(unittest.TestCase):
    def test_saved_pixel_origin_overrides_center_preset(self):
        # spr_grrrol_b: preset center, but a65px canvas stores32 in its sequence.
        data = {"width": 65, "height": 65, "origin": 4,
                "sequence": {"xorigin": 32, "yorigin": 32}}
        self.assertEqual(CONVERTER["sprite_origin"](data), (32, 32))

    def test_top_center_odd_effect_preserves_pixel_anchor(self):
        data = {"width": 37, "height": 31, "origin": 1,
                "sequence": {"xorigin": 18, "yorigin": 0}}
        self.assertEqual(CONVERTER["sprite_origin"](data), (18, 0))

    def test_custom_negative_and_external_origin(self):
        data = {"width": 16, "height": 16, "origin": 9,
                "sequence": {"xorigin": -3, "yorigin": 24}}
        self.assertEqual(CONVERTER["sprite_origin"](data), (-3, 24))

    def test_presets_remain_a_fallback_without_saved_offsets(self):
        data = {"width": 16, "height": 32, "origin": 4}
        self.assertEqual(CONVERTER["sprite_origin"](data), (8, 16))

    def test_invalid_offsets_cannot_enter_the_manifest(self):
        data = {"width": 16, "height": 16, "origin": 4,
                "sequence": {"xorigin": float("inf"), "yorigin": 0}}
        with self.assertRaises(ValueError):
            CONVERTER["sprite_origin"](data)


if __name__ == "__main__":
    unittest.main()
