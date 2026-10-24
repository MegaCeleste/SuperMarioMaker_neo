# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Galoomba
extends Enemy

@export var variant: GoombaVariant = preload("res://resources/content/smw_goomba_normal.tres")


func _ready() -> void:
	super()
	$SlideComponent.avoid_ledges = variant.avoid_ledges
	$FlightComponent.setup(variant.flight, variant.walk_sprite, 9)


func _physics_process(delta: float) -> void:
	$FlightComponent.before_move(delta)
	super(delta)
	$FlightComponent.after_move()


func apply_source_death() -> void:
	super()
	$FlightComponent._burst_pause = INF # The death object cancels Galoomba alarm0.


func _stomped(player: Player) -> void:
	if is_queued_for_deletion() or player.is_dead():
		return
	super(player)
	player.score += 200
	if is_queued_for_deletion():
		return
	if $FlightComponent.strip_wings():
		return
	var stomp: StompedGaloomba = preload("uid://x314ug2d52hj").instantiate()
	stomp.variant = variant
	stomp.recovery_direction = $SlideComponent.direction
	stomp.position = sub_area.get_foreground().to_local(global_position)
	sub_area.add_deferred(stomp)
	queue_free()


func _turned(direction: Vector2) -> void:
	if direction == Vector2.RIGHT:
		%Sprite.flip_h = false
	elif direction == Vector2.LEFT:
		%Sprite.flip_h = true


func get_defeat_sprite() -> StringName:
	return variant.dead_sprite


func get_defeat_frame() -> int:
	return 2
