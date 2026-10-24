# SPDX-License-Identifier: AGPL-3.0-or-later
class_name StarSprout
extends RiseSprout


func _init() -> void:
	resource_local_to_scene = true
	item = preload("res://scenes/entities/super_star.tscn")
	texture = SpriteLibrary.get_frames(&"spr_star").get_frame_texture(&"default", 0)
	offset = Vector2(0, 8)
