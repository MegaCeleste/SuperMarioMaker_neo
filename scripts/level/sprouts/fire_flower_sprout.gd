# SPDX-License-Identifier: AGPL-3.0-or-later
class_name FireFlowerSprout
extends RiseSprout


func _init(progressive := false) -> void:
	resource_local_to_scene = true
	item = preload("res://scenes/level/entities/fire_flower.tscn")
	texture = SpriteLibrary.get_frames(&"spr_fireflower").get_frame_texture(&"default", 0)
	offset = Vector2(0, 8)
	_progressive = progressive


var _progressive := false


func end_sprout(at: Vector2, direction: Vector2) -> void:
	# Progressive contents are decided when released, as in obj_powerupsprout.
	if _progressive:
		var area := _find_sub_area()
		if area != null and is_instance_valid(area.level.hud.player) \
				and area.level.hud.player.get_powerup() is SmallPowerup:
			item = preload("res://scenes/level/entities/mushroom.tscn")
			texture = SpriteLibrary.get_frames(&"spr_mushroom").get_frame_texture(&"default", 0)
	super(at, direction)
