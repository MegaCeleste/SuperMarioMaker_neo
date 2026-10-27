# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BuzzyBeetle
extends Enemy
## obj_buzzybeetle/{Step_0,Other_11} and obj_buzzy_ceiling/Step_0.

@export var variant: BuzzyVariant = preload("res://resources/content/smw_buzzy_beetle.tres")
@export var ceiling := false
var _age := 0.0


func _ready() -> void:
	super()
	fireproof = variant.fireproof
	$FlightComponent.setup(variant.flight, variant.walk_sprite, variant.walk_fps, ceiling)
	if ceiling:
		%Sprite.flip_v = true
	if $FlightComponent.wings:
		stomp_behavior = Stompability.CUSTOM


func _physics_process(delta: float) -> void:
	_age += delta
	if ceiling:
		var player := level.hud.player
		if is_instance_valid(player) and not player.is_dead() \
				and absf(player.global_position.x - global_position.x) < 32 \
				and player.global_position.y - 32 > global_position.y - 16:
			_drop_from_ceiling()
			return
		var slide: SlideComponent = $SlideComponent
		if not _ceiling_support(slide.direction * 8):
			slide.direction *= -1
		if _age >= 5.0 / 60 and not _ceiling_support(0):
			kill(slide.direction)
			return
		if is_on_wall():
			slide.direction *= -1
		velocity = Vector2(slide.speed * slide.direction, 0)
		%Sprite.flip_h = slide.direction < 0
		super(delta)
	else:
		$FlightComponent.before_move(delta)
		super(delta)
		$FlightComponent.after_move()


func _ceiling_support(x_offset: float) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position + Vector2(x_offset, -20)
	query.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func _drop_from_ceiling() -> void:
	var shell := _make_shell()
	shell.motion = KoopaShell.Motion.CEILING_DROP
	shell.inverted = true
	sub_area.add_deferred(shell)
	queue_free()


func _stomped(player: Player) -> void:
	if is_queued_for_deletion() or player.is_dead() or $FlightComponent.wings:
		return
	super(player)
	player.score += 200
	if is_queued_for_deletion():
		return
	var shell := _make_shell()
	shell.inverted = ceiling
	sub_area.add_deferred(shell)
	queue_free()


func _make_shell() -> KoopaShell:
	var shell: KoopaShell = load("res://scenes/level/entities/koopa_shell.tscn").instantiate()
	shell.variant = variant
	shell.facing_direction = $SlideComponent.direction
	shell.position = sub_area.get_foreground().to_local(global_position)
	return shell


func get_defeat_sprite() -> StringName:
	return variant.dead_sprite
