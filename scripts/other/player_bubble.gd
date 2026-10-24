# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerBubble
extends Node2D
## Original bubble sprite/path, owned by the current runtime area revision.

var sub_area: SubArea
var _sprite: AnimatedSprite2D
var _start := Vector2.ZERO
var _distance := 0.0
var _popping := false
const POINTS = [Vector2.ZERO, Vector2(8, -8), Vector2(-8, -24), Vector2(0, -32)]


func _ready() -> void:
	_start = position
	_sprite = SpriteLibrary.make_sprite(&"spr_bubble")
	_sprite.sprite_frames = SpriteLibrary.get_animations({"bubble": ["spr_bubble", 6, true],
			"pop": ["spr_bubble2", 6, false]})
	_sprite.modulate.a = 0.8
	_sprite.play(&"bubble")
	_sprite.animation_finished.connect(queue_free)
	add_child(_sprite)
	z_index = GameConstants.Layers.Z_PARTICLES
	add_to_group(&"player_bubbles")


func _physics_process(delta: float) -> void:
	if _popping:
		return
	_distance += 60 * delta
	var remaining := _distance
	for i in range(1, POINTS.size()):
		var segment: Vector2 = POINTS[i] - POINTS[i - 1]
		if remaining <= segment.length() or i == POINTS.size() - 1:
			position = _start + POINTS[i - 1] + segment.normalized() * remaining
			break
		remaining -= segment.length()
	var liquid := sub_area.liquid
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collision_mask = 1
	if global_position.y < -Level.LEVEL_HEIGHT * Level.GRID_SIZE.y - 32 \
			or (sub_area.level_theme != Level.LevelTheme.UNDERWATER \
			and (not is_instance_valid(liquid) or not liquid.is_water() or global_position.y <= liquid.global_position.y + 8)) \
			or not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty():
		_popping = true
		_sprite.play(&"pop")
