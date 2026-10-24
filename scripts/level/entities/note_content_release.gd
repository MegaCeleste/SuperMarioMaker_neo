# SPDX-License-Identifier: AGPL-3.0-or-later
class_name NoteContentRelease
extends Node
## Block-owned two-alarm release; no unparented actor survives retry/edit.

var sub_area: SubArea
var content_id: StringName
var direction: Vector2
var position: Vector2
var _ticks := 2


func _physics_process(_delta: float) -> void:
	_ticks -= 1
	if _ticks > 0:
		return
	var item: CharacterBodyExt
	var player := sub_area.level.hud.player
	match content_id:
		&"mushroom": item = load("res://scenes/entities/mushroom.tscn").instantiate()
		&"one_up": item = OneUp.new()
		&"star": item = SuperStar.new()
		&"flower", &"progressive_flower":
			if content_id == &"progressive_flower" and is_instance_valid(player) and player.get_powerup() is SmallPowerup:
				item = load("res://scenes/entities/mushroom.tscn").instantiate()
			else:
				item = FireFlower.new()
	if item != null:
		item.position = position + Vector2(8, 32 if direction.y > 0 else -1)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = RectangleShape2D.new()
		query.shape.size = Vector2(12, 15)
		query.transform.origin = item.position + Vector2(0, -7.5)
		query.collision_mask = 1
		query.exclude = [get_parent().get_rid()]
		if not get_parent().get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			EnemyEffect.play_once(sub_area, &"spr_smoke", item.position + Vector2(-8, -16), 18)
			item.free()
		else:
			var water := sub_area.level_theme == Level.LevelTheme.UNDERWATER or (is_instance_valid(sub_area.liquid) \
					and sub_area.liquid.is_water() and position.y > sub_area.liquid.global_position.y + 16)
			item.velocity.y = 0 if direction.y > 0 else -120 if water else -300
			var slide := Utility.find_child_by_class(item, SlideComponent) as SlideComponent
			if slide != null:
				slide.direction = 1
			sub_area.add_deferred(item)
			EnemyEffect.sound_once(sub_area, "uid://bexd6cvyd4onk")
	queue_free()
