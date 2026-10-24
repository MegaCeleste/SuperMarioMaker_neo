# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Monty
extends Enemy
## Ported from obj_monty_chase. The source alarm starts the charge after two
## ticks; a wall reverses the walk and hops it while grounded. Wings/parachute
## use the shared native flight rules (obj_physicsparent/Other_14).

@export var variant: MontyVariant = preload("res://resources/content/smw_monty.tres")
var wings := false
var parachute := false
var direction := -1
var charge := false
var _charge_left := 2.0 / 60


func _ready() -> void:
	super()
	charge = false
	_charge_left = 2.0 / 60
	for path in ["CollShape", "PlayerArea/CollShape"]:
		get_node(path).shape = SpriteCollision.ellipse(variant.mask_size, Vector2.ZERO)
	$GravityComponent.set_physics_process(false)
	$SlideComponent.set_physics_process(false)
	$SlideComponent.speed = 0
	$FlightComponent.wings = wings
	$FlightComponent.parachute = parachute
	$FlightComponent.rules = $FlightComponent.rules.duplicate()
	$FlightComponent.setup(variant.flight.duplicate(), variant.walk_sprite, variant.walk_fps)
	$Graphics/Sprite.flip_h = direction < 0


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	_charge_left -= delta
	if _charge_left <= 0.0:
		charge = true
	var player := level.get_living_player()
	var swimming := _in_water()
	direction = -1 if not is_instance_valid(player) or player.global_position.x < global_position.x else 1
	if charge and not parachute:
		var cap := variant.water_left_speed if swimming and direction < 0 else variant.walk_speed
		velocity.x = move_toward(velocity.x, cap * direction, variant.acceleration * delta)
	$SlideComponent.direction = direction
	# The parent source clamps before adding gravity. These post-add caps retain
	# that last increment without changing the already ported enemy families.
	$FlightComponent.rules.gravity = 72.0 if swimming else 720.0
	$FlightComponent.rules.fall_speed = 61.2 if swimming else 252.0
	$FlightComponent.rules.parachute_fall_speed = 30.0
	$FlightComponent.profile.wing_hop_speed = 120.0 if swimming else 180.0
	var incoming := velocity.x
	$FlightComponent.before_move(delta)
	super(delta)
	$FlightComponent.after_move()
	wings = $FlightComponent.wings
	parachute = $FlightComponent.parachute
	if not parachute and (is_on_wall() or _contact_turned) and not is_zero_approx(incoming):
		velocity.x = -signf(incoming) * (variant.water_wall_speed if swimming else variant.walk_speed)
		if is_on_floor():
			velocity.y = -variant.wall_hop
			position.y -= 1
	$Graphics/Sprite.flip_h = $SlideComponent.direction < 0


## obj_monty_chase/Other_11: wings detach first; the next stomp defeats it.
func _stomped(player: Player) -> void:
	if is_queued_for_deletion():
		return
	if player.state_machine.current_state is PlayerSpinJumpingState:
		player.bounce()
		_spin_stomp()
		return
	player.bounce()
	player.sounds.stream = preload("uid://c345xnns7om3m")
	player.sounds.play()
	player.spawn_spin_thump()
	if wings:
		wings = false
		$FlightComponent.strip_wings()
		return
	player.score += 200
	hit_by_actor(&"stomp", player)


func hit_by_actor(kind: StringName, impact: CollisionObject2D, _fallback_direction := 0.0) -> bool:
	return hit_by_projectile(kind, source_hit_direction(impact, true))


func hit_by_projectile(kind: StringName, launch_direction := 0.0) -> bool:
	if kind == &"pow":
		if is_queued_for_deletion() or velocity.y != 0:
			return false
		spawn_source_defeat(variant, direction, 0, true)
		return true
	return super(kind, launch_direction)


func bumped_by_block(block: PhysicsBody2D, _activator: PhysicsBody2D) -> void:
	source_block_defeat(block)


func kill(launch_direction := 0.0) -> void:
	spawn_source_defeat(variant, direction, launch_direction)


func get_defeat_sprite() -> StringName:
	return variant.dead_sprite


func get_defeat_frame() -> int:
	return 2


func _in_water() -> bool:
	if sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP]):
		return true
	var liquid := sub_area.liquid
	return is_instance_valid(liquid) and liquid.is_water() \
			and global_position.y - 8 > liquid.global_position.y
