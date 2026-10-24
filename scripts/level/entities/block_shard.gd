# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BlockShard
extends Node2D
## obj_shard: source air/water drag, gravity, spin and 32px camera culling.

var sub_area: SubArea
var velocity: Vector2
var spin_direction := 1.0
var sprite_name: StringName = &"spr_shard"
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_sprite = SpriteLibrary.make_sprite(sprite_name)
	_sprite.pause()
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	var water := sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP])
	if sub_area.level_theme == Level.LevelTheme.FOREST and not sub_area.night_mode and is_instance_valid(sub_area.liquid):
		water = water or global_position.y > sub_area.liquid.global_position.y + 16
	velocity.x = signf(velocity.x) * (30 if water else 60)
	velocity.y = minf(90 if water else 180, velocity.y) + (360 if water else 720) * delta
	global_position += velocity * delta
	rotation += deg_to_rad(180 if water else 360) * spin_direction * delta
	_sprite.global_position = Vector2(roundf(global_position.x), global_position.y)
	if not Utility.get_visible_rect().grow(32).has_point(global_position):
		queue_free()
