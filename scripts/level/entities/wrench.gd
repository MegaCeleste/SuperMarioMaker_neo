# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Wrench
extends Entity
## obj_wrench: constant flight, an animated precise mask, source arc/alarm
## clocks and intentionally asymmetric view culling. Terrain is ignored.

@export var direction := -1
@export var swimming := false
@export var rules: WrenchRules = preload("res://resources/content/smw_wrench_rules.tres")
var _age := 0.0
var _start_y := 0.0
var _height := 0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	_start_y = global_position.y
	_height = randi_range(0, 4)
	velocity = Vector2(rules.water_speed if swimming else rules.speed, 0) * direction
	_sprite = AnimatedSprite2D.new()
	SpriteLibrary.configure_sprite(_sprite, rules.flight_sprite, &"default", rules.flight_fps)
	add_child(_sprite)
	var shapes := SpriteCollision.precise(rules.flight_sprite)
	SpriteCollision.add_shapes(self, shapes)
	var area := Area2D.new()
	area.name = "PlayerArea"
	area.collision_layer = 0
	area.collision_mask = 4
	SpriteCollision.add_shapes(area, shapes)
	area.body_entered.connect(func(body):
		if body is Player and not is_queued_for_deletion():
			body.damage())
	add_child(area)


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	_age += delta
	if _age >= rules.lifetime - 0.00001 or _outside_source_view():
		queue_free()
		return
	if _age >= rules.blink_time - 0.00001:
		_sprite.visible = int(floor((_age - rules.blink_time + 0.00001) / rules.blink_interval)) % 2 == 1
	var player := level.hud.player
	if is_instance_valid(player) and player.is_dead():
		velocity = Vector2.ZERO
	_arc(delta)
	position += velocity * delta
	_sprite.position = global_position.round() - global_position


func _outside_source_view() -> bool:
	var view := Utility.get_visible_rect()
	# Step_0 groups right AND above; left/below are independent clauses.
	return global_position.x < view.position.x - rules.view_margin \
			or (global_position.x > view.end.x + rules.view_margin and global_position.y < view.position.y - rules.view_margin) \
			or global_position.y > view.end.y + rules.view_margin


## Source height 1..4 rises 5/13/21/29px at 180px/s^2 capped at 30px/s.
func _arc(delta: float) -> void:
	if _height == 0:
		return
	var target := rules.arc_heights[_height]
	velocity.y = maxf(velocity.y - rules.arc_acceleration * delta, -rules.arc_speed)
	if global_position.y <= _start_y - target:
		velocity.y = 0
		_height = 0


## obj_invincibility calls Other_10; it is not a helmet/enemy-parent response.
func kill(launch_direction := 0.0) -> void:
	if is_queued_for_deletion():
		return
	var effect := SwimmingEnemyDefeat.new()
	effect.variant = rules
	effect.sub_area = sub_area
	effect.direction = 1
	effect.velocity.x = 60 * signf(launch_direction)
	effect.position = sub_area.get_foreground().to_local(global_position + Vector2(0, 8))
	sub_area.add_deferred(effect)
	EnemyEffect.sound_once(sub_area, SoundLibrary.path("snd_stomp"))
	queue_free()
