# SPDX-License-Identifier: AGPL-3.0-or-later
class_name CheepCheep
extends Enemy
## Native swimmer/jumper from obj_cheepcheep[2] Step_0 and alarms0/2/10.
## Their own step bypasses the parent solid-physics events (Other_24 exits).

@export var variant: CheepCheepVariant = preload("res://resources/content/smw_cheep_cheep_red.tres")
@export var wings := false
@export var parachute := false
var water_mode := false
var direction := -1.0
var jump_index := 0
var lava := false
var gliding := false
var _glide_armed := false
var _glide_left := 0.0
var _resume_left := 4.0 / 60
var _turn_left := 0.0
var _ember_left := 0.0
var _origin := Vector2.ZERO
var _wings_sprite: AnimatedSprite2D
var _parachute_sprite: AnimatedSprite2D
var _aura: AnimatedSprite2D
var _mask_shapes: Array[ConvexPolygonShape2D] = []


func _ready() -> void:
	super()
	_origin = global_position
	_build_mask()
	SpriteLibrary.configure_sprite(%Sprite, variant.swim_sprite, &"swim", variant.animation_fps)
	_wings_sprite = SpriteLibrary.make_sprite(variant.flight.wings_sprite)
	_wings_sprite.name = "Wings"
	_wings_sprite.sprite_frames = SpriteLibrary.get_animations({"flap": [String(variant.flight.wings_sprite), variant.wings_fps, true]})
	_wings_sprite.play(&"flap")
	$Graphics.add_child(_wings_sprite)
	var flight: EnemyFlightPhysics = preload("res://resources/content/smw_enemy_flight_physics.tres")
	_parachute_sprite = SpriteLibrary.make_sprite(flight.parachute_sprite)
	_parachute_sprite.name = "Parachute"
	_parachute_sprite.pause()
	_parachute_sprite.frame = 2
	$Graphics.add_child(_parachute_sprite)
	$Graphics.move_child(_wings_sprite, $Graphics.get_child_count() - 1)
	_update_visuals()
	_update_contact_policy()


func _build_mask() -> void:
	_mask_shapes = SpriteCollision.precise(variant.swim_sprite, Vector2(0, -16))
	for body in [self, hitbox]:
		SpriteCollision.add_shapes(body, _mask_shapes)


func _physics_process(delta: float) -> void:
	if _turn_left > 0:
		_turn_left -= delta
		if _turn_left < 0.00001:
			velocity.x = -velocity.x
			_turn_left += variant.turn_time
	if _resume_left > 0:
		_resume_left = maxf(0, _resume_left - delta)
		if _resume_left < 0.00001:
			_resume_left = 0
			_resume()
	if _glide_left > 0:
		_glide_left -= delta
		if _glide_left < 0.00001:
			gliding = false
	if _ember_left > 0:
		_ember_left -= delta
		if _ember_left < 0.00001:
			_effect(variant.ember_sprite, global_position + Vector2(randf_range(-4, 12), randf_range(-20, -4)), 9)
			_ember_left += 4.0 / 60
	var swimming := _swim_motion()
	if not swimming:
		_air_motion(delta)
	if not parachute and velocity.x != 0:
		direction = signf(velocity.x)
	if wings and swimming:
		velocity.y = _sway(global_position.y - _origin.y, velocity.y, delta)
		var liquid := sub_area.liquid
		if water_mode and is_instance_valid(liquid) and liquid.velocity > 0 \
				and global_position.y - 16 <= liquid.global_position.y + 16:
			global_position.y = liquid.global_position.y + 32
	if parachute and (sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (_uses_room_bottom() and global_position.y >= 0)):
		_detach_parachute(false)
	_update_contact_policy()
	super(delta)
	_update_visuals()


func _swim_motion() -> bool:
	return sub_area.level_theme == Level.LevelTheme.UNDERWATER or water_mode


func apply_source_death() -> void:
	super()
	_turn_left = INF
	%Sprite.frame = 0


func _uses_room_bottom() -> bool:
	return sub_area.level_theme not in [Level.LevelTheme.FOREST, Level.LevelTheme.CASTLE]


func _resume() -> void:
	if velocity.x != 0:
		return
	if _swim_motion():
		velocity.x = variant.swim_speed * direction
		if wings:
			velocity.y = variant.sway_speed
		_turn_left = variant.turn_time
	elif parachute:
		velocity.x = variant.swim_speed


func _air_motion(delta: float) -> void:
	if _glide_armed and velocity.y > 0 and _free_below():
		gliding = true
		_glide_left = variant.glide_time
		_glide_armed = false
	var gravity := 0.0
	if parachute:
		gravity = variant.float_gravity
		velocity.y = minf(velocity.y, variant.float_fall_speed)
	elif not gliding:
		gravity = variant.gravity
		if absf(velocity.x) > variant.swim_speed:
			velocity.x = move_toward(velocity.x, variant.swim_speed * direction, variant.horizontal_drag * delta)
		velocity.y = minf(velocity.y, variant.fall_speed)
	else:
		velocity.y -= variant.glide_acceleration * delta
		velocity.x = variant.glide_speed * direction
		if velocity.y < variant.glide_rise_speed:
			velocity.y = -variant.glide_rise_speed
	var liquid := sub_area.liquid
	if (is_instance_valid(liquid) and global_position.y - 16 >= liquid.global_position.y) \
			or (_uses_room_bottom() and global_position.y >= 0):
		_jump_from_surface()
	if parachute:
		direction = -1
		velocity.x = _sway(global_position.x - _origin.x, velocity.x, delta)
	# Source caps before applying its built-in gravity; retain that tick order.
	velocity.y += gravity * delta


func _jump_from_surface() -> void:
	if parachute:
		_detach_parachute(true)
	if jump_index == 2 and variant.aim_large_jump:
		var player := level.hud.player
		direction = -1 if not is_instance_valid(player) or player.global_position.x < global_position.x else 1
	velocity.x = (variant.wing_jump_speed if wings else variant.jump_speed) * direction
	if sub_area.level_theme == Level.LevelTheme.CASTLE:
		if not lava:
			_ember_left = 8.0 / 60
		lava = true
	elif sub_area.level_theme == Level.LevelTheme.FOREST and sub_area.night_mode:
		lava = true
	velocity.y = -variant.large_jump if jump_index == 2 else -variant.small_jump
	if jump_index == 2 and wings:
		_glide_armed = true
	jump_index = (jump_index + 1) % 3
	if sub_area.level_theme != Level.LevelTheme.CASTLE:
		_effect(variant.bubble_sprite, global_position + Vector2(-13, -22), 21)


func _sway(offset: float, speed: float, delta: float) -> float:
	if offset > variant.sway_distance:
		return -variant.sway_speed if speed < -variant.sway_speed else speed - variant.sway_acceleration * delta
	if offset < -variant.sway_distance:
		return variant.sway_speed if speed > variant.sway_speed else speed + variant.sway_acceleration * delta
	return speed


func _free_below() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.collision_mask = 1
	query.transform = global_transform.translated(Vector2.DOWN)
	for shape in _mask_shapes:
		query.shape = shape
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return false
	return true


func _update_contact_policy() -> void:
	var water := sub_area.level_theme == Level.LevelTheme.UNDERWATER
	var liquid := sub_area.liquid
	if is_instance_valid(liquid) and sub_area.level_theme == Level.LevelTheme.FOREST \
			and not sub_area.night_mode and global_position.y - 16 >= liquid.global_position.y:
		water = true
	# The source deliberately tests forest/underwater, not beach's modo_water.
	stomp_behavior = Stompability.NONE if water or lava else Stompability.STOMPABLE


func _stomped(player: Player) -> void:
	if is_queued_for_deletion() or player.is_dead():
		return
	if stomp_behavior == Stompability.NONE:
		player.damage()
		return
	super(player)
	player.score += 200
	if is_queued_for_deletion():
		return
	if wings:
		_shed_wing(9)
		wings = false
		velocity.y = 0
		_glide_armed = false
		_glide_left = 1.0 / 60
		_resume_left = 2.0 / 60
		_update_visuals()
	else:
		# dead_h is a POW flag, not a normal-stomp flag. Other_10 chooses
		# the incoming horizontal speed, or relative bbox-lefts when Mario stops.
		var launch := signf(player.velocity.x)
		if launch == 0:
			launch = signf(Utility.get_bounding_box(self).position.x - Utility.get_bounding_box(player).position.x)
		_defeat(60 * launch)


func _spin_stomp() -> void:
	if wings:
		_shed_wing(8)
		wings = false
	super()


func bumped_from_below(_activator: PhysicsBody2D) -> void:
	if velocity.y >= 0 and not is_queued_for_deletion():
		var player := level.hud.player
		if is_instance_valid(player) and not player.is_dead():
			player.score += 200
		kill()


func kill(launch_direction := 0.0) -> void:
	if launch_direction == 0:
		launch_direction = level.hud.player.direction if is_instance_valid(level.hud.player) else -1
	_defeat(60 * signf(launch_direction))


func _defeat(horizontal_speed: float) -> void:
	if is_queued_for_deletion():
		return
	if wings:
		_shed_wing(8)
		wings = false
	var effect := SwimmingEnemyDefeat.new()
	effect.variant = variant
	effect.sub_area = sub_area
	effect.direction = direction
	effect.velocity.x = horizontal_speed
	effect.position = sub_area.get_foreground().to_local(global_position + Vector2(0, -8))
	sub_area.add_deferred(effect)
	queue_free()


func _shed_wing(offset_x: float) -> void:
	var effect := DetachedEnemyAttachment.new()
	effect.position = sub_area.get_foreground().to_local(global_position + Vector2(offset_x * direction, -7))
	effect.turn_direction = 1
	if sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP]):
		effect.terminal_speed = 48
	var rules: EnemyFlightPhysics = preload("res://resources/content/smw_enemy_flight_physics.tres")
	var sprite := SpriteLibrary.make_sprite(rules.wing_dead_sprite)
	sprite.pause()
	sprite.frame = 2
	sprite.flip_h = direction < 0
	effect.add_child(sprite)
	sub_area.add_deferred(effect)


func _detach_parachute(stop_horizontal: bool) -> void:
	parachute = false
	if stop_horizontal:
		velocity.x = 0
	_resume_left = 10.0 / 60
	var rules: EnemyFlightPhysics = preload("res://resources/content/smw_enemy_flight_physics.tres")
	var sprite := SpriteLibrary.make_sprite(rules.parachute_land_sprite)
	sprite.pause()
	sprite.frame = 2
	sprite.position = sub_area.get_foreground().to_local(global_position + Vector2(3 * direction, -16))
	sub_area.add_deferred(sprite)
	sprite.ready.connect(func():
		var shrink := sprite.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		shrink.tween_property(sprite, "scale", Vector2(0.2, 0.2), 8.0 / 60)
		shrink.tween_callback(sprite.queue_free))


func _effect(sprite_name: StringName, at: Vector2, fps: float) -> void:
	var effect := SpriteLibrary.make_sprite(sprite_name)
	effect.z_index = GameConstants.Layers.Z_PARTICLES
	effect.sprite_frames = SpriteLibrary.get_animations({"effect": [String(sprite_name), fps, false]})
	effect.position = sub_area.get_foreground().to_local(at)
	effect.play(&"effect")
	effect.animation_finished.connect(effect.queue_free)
	sub_area.add_deferred(effect)


func _update_visuals() -> void:
	%Sprite.flip_h = direction < 0
	_wings_sprite.visible = wings
	_wings_sprite.position = Vector2(-9 * direction, -20)
	_wings_sprite.flip_h = direction < 0
	_wings_sprite.speed_scale = variant.glide_wings_fps / variant.wings_fps if gliding else 1
	_parachute_sprite.visible = parachute
	if lava and _aura == null:
		_aura = SpriteLibrary.make_sprite(variant.poison_sprite if sub_area.level_theme == Level.LevelTheme.FOREST else variant.fire_sprite)
		_aura.name = "LavaAura"
		_aura.sprite_frames = SpriteLibrary.get_animations({"aura": [String(variant.poison_sprite if sub_area.level_theme == Level.LevelTheme.FOREST else variant.fire_sprite), 9, true]})
		_aura.play(&"aura")
		$Graphics.add_child(_aura)
		$Graphics.move_child(_aura, 0)
