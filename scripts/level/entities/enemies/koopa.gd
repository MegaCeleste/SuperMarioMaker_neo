# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Koopa
extends Enemy

@export var variant: KoopaVariant = preload("res://resources/content/smw_koopa_green.tres")
var physics: ShellPhysics = preload("res://resources/content/smw_shell_physics.tres")


func _ready() -> void:
	super()
	$SlideComponent.avoid_ledges = variant.avoid_ledges
	$FlightComponent.setup(variant.flight, variant.walk_sprite, variant.walk_fps)


func _physics_process(delta: float) -> void:
	$FlightComponent.before_move(delta)
	super(delta)
	$FlightComponent.after_move()


## obj_koopa/Other_11: SMW ejects a separate beach Koopa and an empty shell.
func _stomped(player: Player) -> void:
	if is_queued_for_deletion() or player.is_dead():
		return
	super(player)
	player.score += 200
	if is_queued_for_deletion():
		return
	if $FlightComponent.strip_wings():
		return
	var shell: KoopaShell = load("res://scenes/entities/koopa_shell.tscn").instantiate()
	shell.variant = variant
	shell.position = sub_area.get_foreground().to_local(global_position)
	var beach: BeachKoopa = load("res://scenes/entities/beach_koopa.tscn").instantiate()
	beach.variant = variant
	beach.position = shell.position
	beach.direction = 1 if player.global_position.x <= global_position.x else -1
	beach.velocity.x = physics.eject_speed * beach.direction
	sub_area.add_deferred(shell)
	sub_area.add_deferred(beach)
	queue_free()


func get_defeat_sprite() -> StringName:
	return variant.dead_sprite


func _turned(direction: Vector2) -> void:
	if direction == Vector2.RIGHT:
		%Sprite.flip_h = false
	elif direction == Vector2.LEFT:
		%Sprite.flip_h = true
