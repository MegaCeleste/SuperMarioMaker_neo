# SPDX-License-Identifier: AGPL-3.0-or-later
class_name MushroomSprout
extends RiseSprout
## OpenWE sprout=1: a Super Mushroom rises from a question block.


func _init() -> void:
	resource_local_to_scene = true
	item = preload("res://scenes/level/entities/mushroom.tscn")
	texture = preload("res://textures/styles/smw/entities/mushroom.png")
	if SpriteLibrary.has_sprite(&"spr_mushroom"):
		texture = SpriteLibrary.get_frames(&"spr_mushroom").get_frame_texture(&"default", 0)
	offset = Vector2(0, 8)
