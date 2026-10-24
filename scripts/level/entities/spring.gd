# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Spring
extends Entity
## Ordinary SMW portable spring: source4-frame/.3-per-tick compression,
## a9-tick rider hold, and313.5px/s launch through the native jump states.

var active := false
var age := 0
var compression := 0.0
var _rider: WeakRef
var _surface: AnimatableBody2D
var _surface_shape: CollisionShape2D
var _sprite: AnimatedSprite2D
@onready var pickup: PickupComponent = $PickupComponent

func uses_source_deactivation() -> bool:
	return true

func uses_source_death_stop() -> bool:
	return true

func _ready() -> void:
	_sprite = SpriteLibrary.make_sprite(&"spr_spring")
	_sprite.name = "Sprite"
	_sprite.pause()
	_sprite.position = Vector2(-8, -15)
	add_child(_sprite)
	_surface = AnimatableBody2D.new()
	_surface.name = "SpringSurface"
	_surface.sync_to_physics = false
	_surface.collision_layer = 1
	_surface.collision_mask = 0
	add_child(_surface)
	_surface_shape = CollisionShape2D.new()
	_surface_shape.shape = RectangleShape2D.new()
	_surface_shape.shape.size = Vector2(16, 3)
	_surface_shape.one_way_collision = true
	_surface_shape.one_way_collision_margin = 2
	_surface_shape.position.y = -13.5
	_surface.add_child(_surface_shape)
	add_collision_exception_with(_surface)
	_surface.add_collision_exception_with(self)
	pickup.use_default_behavior = false
	pickup.picked_up.connect(_picked_up)
	pickup.dropped.connect(_dropped)
	process_physics_priority = -10

func top_y() -> float:
	return global_position.y - 15 + compression

func player_launch_speed() -> float:
	# obj_spring/Step_0: submerged Mario uses the lower spring impulse.
	var liquid := sub_area.liquid
	var player := level.hud.player
	return 217.5 if sub_area.level_theme == Level.LevelTheme.UNDERWATER or (is_instance_valid(liquid) \
			and liquid.is_water() and player.global_position.y > liquid.global_position.y + 16) else 313.5

func _physics_process(delta: float) -> void:
	if source_death_stopped():
		return
	if pickup.get_holder() != null or (is_instance_valid(level.hud.player) and level.hud.player.held_item == self):
		velocity = Vector2.ZERO
		return
	velocity.y = minf(240, velocity.y + 540 * delta)
	move_source_and_slide()
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, 306 * delta)
	if is_on_wall():
		velocity.x = 0
	if position.y > Player.VOID_LEVEL:
		queue_free()
		return
	if active:
		age += 1
		var frame := mini(3, floori(age * 0.3 + 0.0001))
		_sprite.frame = frame
		compression = float([0, 4, 8, 4][frame])
		_surface_shape.position.y = -13.5 + compression
		if age >= 14:
			active = false
			compression = 0
			_sprite.frame = 0
			_surface_shape.position.y = -13.5
			pickup.can_be_held = true
		return
	var player := level.hud.player
	if is_instance_valid(player) and not player.is_dead() and not player.is_frozen() \
			and not player.state_machine.current_state is PlayerStunnedState and player.velocity.y >= 0:
		var bounds := Utility.get_bounding_box(player)
		var previous := bounds.end.y + player.previous_position.y - player.global_position.y
		if bounds.end.x > global_position.x - 8 and bounds.position.x < global_position.x + 8 \
				and bounds.end.y >= top_y() - 3 and bounds.end.y <= top_y() + 5 and previous <= top_y() + 6:
			begin_compression()
			_rider = weakref(player)
			var state := Utility.find_child_by_class(player.state_machine, PlayerSpringState) as PlayerSpringState
			state.spring = self
			player.state_machine.switch(PlayerSpringState)
			return
	_bounce_actor()

func begin_compression() -> void:
	active = true
	age = 0
	pickup.can_be_held = false

func detach_rider(player: Player) -> void:
	if _rider != null and _rider.get_ref() == player:
		_rider = null

func _picked_up(_player: Player) -> void:
	velocity = Vector2.ZERO
	_surface.collision_layer = 0
	collision_layer = 0

func _dropped(player: Player, release: PickupComponent.ReleaseType) -> void:
	_surface.collision_layer = 1
	collision_layer = 8
	pickup.pickup_immunity_left = 0.25
	if release == PickupComponent.ReleaseType.THROWN_UP:
		velocity = Vector2(30 * player.direction if player.velocity.x != 0 else 0, -367.5)
	elif release == PickupComponent.ReleaseType.DETACHED:
		velocity = Vector2.ZERO
	else:
		velocity = Vector2(60 * player.direction if player.velocity.x == 0 else player.velocity.x / 2, 0)

func _bounce_actor() -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = Vector2(16, 3)
	query.transform.origin = Vector2(global_position.x, top_y() - 1)
	query.collision_mask = 2 | 8
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var body := hit.collider as CharacterBodyExt
		if body == null or body is Spring or body.velocity.y < 0 or body.is_queued_for_deletion() \
				or body is Thwomp or body is Rocky or body is CheepCheep or body is BroProjectile or body is PlayerFireball:
			continue
		if Utility.get_bounding_box(body).end.y > top_y() + 5:
			continue
		var flight := body.get_node_or_null("FlightComponent") as EnemyFlightComponent
		if body.get_parent() is Player or (flight != null and flight.wings) \
				or ((body is BuzzyBeetle or body is Spiny) and body.ceiling):
			continue
		body.velocity.y = -30 if body.test_move(body.global_transform, Vector2.UP) else -313.5
		body.velocity.x = 0
		begin_compression()
		EnemyEffect.sound_once(sub_area, "res://assets/openwe/sounds/snd_spring.ogg")
		return
