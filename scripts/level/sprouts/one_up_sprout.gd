# SPDX-License-Identifier: AGPL-3.0-or-later
class_name OneUpSprout
extends RiseSprout


func _init() -> void:
	resource_local_to_scene = true
	item = preload("res://scenes/level/entities/one_up.tscn")
	texture = SpriteLibrary.get_frames(&"spr_1up").get_frame_texture(&"default", 1)
	offset = Vector2(0, 8)
