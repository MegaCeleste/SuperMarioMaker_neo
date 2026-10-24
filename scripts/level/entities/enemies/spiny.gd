# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Spiny
extends Enemy
## Native SMW walking/ceiling/winged states; obj_spiny Step_0 and alarms0..3.

@export var variant: SpinyVariant = preload("res://resources/content/smw_spiny.tres")
@export var ceiling := false
var _attack_left := 0.0
var _attack_phase := 0
var _diagonal := false


func _ready() -> void:
	super()
	stomp_behavior = Stompability.RECOIL
	$FlightComponent.setup(variant.flight, variant.walk_sprite, variant.walk_fps, ceiling)
	if ceiling:
		%Sprite.flip_v = true
	if $FlightComponent.wings:
		# Its wing Step bypasses the parent's solid-collision/gravity events.
		collision_mask = 0
		_attack_left = variant.attack_wait + 1.0 / 60


func _physics_process(delta: float) -> void:
	if ceiling:
		var player := level.hud.player
		if is_instance_valid(player) and not player.is_dead() \
				and absf(player.global_position.x - global_position.x) < 32 \
				and player.global_position.y - 32 > global_position.y - 16:
			var shell := _make_flipped_shell()
			shell.motion = KoopaShell.Motion.CEILING_DROP
			shell.velocity = Vector2.ZERO
			sub_area.add_deferred(shell)
			queue_free()
			return
		var slide: SlideComponent = $SlideComponent
		var query := PhysicsPointQueryParameters2D.new()
		query.position = global_position + Vector2(slide.direction * 8, -20)
		query.collision_mask = 1
		if is_on_wall() or get_world_2d().direct_space_state.intersect_point(query, 1).is_empty():
			slide.direction *= -1
		velocity = Vector2(slide.speed * slide.direction, 0)
		%Sprite.flip_h = slide.direction < 0
		super(delta)
	else:
		$FlightComponent.before_move(delta)
		super(delta)
		$FlightComponent.after_move()
		if $FlightComponent.wings:
			_advance_attack(delta)


func _advance_attack(delta: float) -> void:
	_attack_left -= delta
	if _attack_left > 0.00001:
		return
	match _attack_phase:
		0:
			_attack_phase = 1
			_attack_left += variant.attack_windup
			SpriteLibrary.configure_sprite(%Sprite, variant.ball_sprite, &"ball", 4.8)
		1:
			_fire_needles()
			_diagonal = not _diagonal
			_attack_phase = 2
			_attack_left += variant.attack_recover
		2:
			_attack_phase = 0
			_attack_left += variant.attack_wait
			SpriteLibrary.configure_sprite(%Sprite, variant.flight.wing_body_sprite, &"walk", 0)
			%Sprite.pause()
			%Sprite.frame = variant.flight.wing_body_frame


func _fire_needles() -> void:
	var specs := [[Vector2(0, -9), Vector2(0, -1), 0],
		[Vector2(18, 8), Vector2(1, 0), 270], [Vector2(0, 18), Vector2(0, 1), 180],
		[Vector2(-18, 8), Vector2(-1, 0), 90]]
	if _diagonal:
		specs = [[Vector2(14, -7), Vector2(1, -1), 315], [Vector2(14, 23), Vector2(1, 1), 225],
			[Vector2(-14, 23), Vector2(-1, 1), 135], [Vector2(-14, -7), Vector2(-1, -1), 45]]
	for spec in specs:
		var needle: SpinyNeedle = load("res://scenes/entities/spiny_needle.tscn").instantiate()
		needle.variant = variant
		needle.position = sub_area.get_foreground().to_local(global_position + Vector2(0, -16) + spec[0])
		needle.velocity = spec[1] * variant.needle_speed
		needle.draw_angle = -spec[2]
		sub_area.add_deferred(needle)


## A block below flips this occupant into a recoverable shell, not a defeat.
func bumped_from_below(activator: PhysicsBody2D) -> void:
	if is_queued_for_deletion():
		return
	if is_instance_valid(level.hud.player) and not level.hud.player.is_dead() and level.status == Level.Status.PLAYING:
		level.hud.player.score += 200 # obj_enemyparent/Collision_obj_blockparent.
	var shell := _make_flipped_shell()
	_drop_wing()
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -16),
			global_position + Vector2(0, -18), 1)
	if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		shell.velocity.y = -180
	var side := 1 if activator.global_position.x <= global_position.x else -1
	shell.velocity.x = 30 * side
	shell.position.y -= 2
	sub_area.add_deferred(shell)
	queue_free()


func kill(launch_direction := 0.0) -> void:
	if not is_queued_for_deletion():
		_drop_wing()
	super(launch_direction)


func _drop_wing() -> void:
	if not $FlightComponent.wings:
		return
	var effect := DetachedEnemyAttachment.new()
	var direction: int = $SlideComponent.direction
	effect.position = sub_area.get_foreground().to_local(global_position + Vector2(8 * direction, -7))
	effect.turn_direction = direction
	var sprite := SpriteLibrary.make_sprite($FlightComponent.rules.wing_dead_sprite)
	sprite.pause()
	sprite.frame = 2
	sprite.flip_h = direction < 0
	effect.add_child(sprite)
	sub_area.add_deferred(effect)


func _make_flipped_shell() -> KoopaShell:
	var shell: KoopaShell = load("res://scenes/entities/koopa_shell.tscn").instantiate()
	shell.variant = variant
	shell.inverted = true
	shell.facing_direction = $SlideComponent.direction
	shell.position = sub_area.get_foreground().to_local(global_position)
	return shell


func get_defeat_sprite() -> StringName:
	return variant.dead_sprite
