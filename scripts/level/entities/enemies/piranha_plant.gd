# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PiranhaPlant
extends Enemy
## Native SMW standalone jump/fire plants; pipe emergence is a separate actor.

enum Attack { IDLE, WINDUP, RECOVERY }

@export var variant: PiranhaVariant = preload("res://resources/content/smw_piranha_jump.tres")
@export var wings := false
@export var parachute := false
var attachment := 0
var direction := 1.0
var attack := Attack.IDLE
var aiming_up := false
var swimming := false
var _attack_left := 0.0
var _jump_left := 3.0
var _start_left := 2.0 / 60
var _age := 0.0
var _origin := Vector2.ZERO
var _sprite_name: StringName
var _wings_sprite: AnimatedSprite2D
var _parachute_sprite: AnimatedSprite2D
var _shape: ConvexPolygonShape2D


func _ready() -> void:
	super()
	stomp_behavior = Stompability.RECOIL
	direction = -1 if variant.fire else 1
	_shape = SpriteCollision.ellipse(variant.mask_size, variant.mask_center)
	SpriteCollision.add_shapes(self, [_shape])
	SpriteCollision.add_shapes(hitbox, [_shape])
	_origin = global_position
	_attack_left = variant.initial_attack
	_jump_left = variant.jump_wait
	if attachment != 0:
		collision_mask = 0
		wings = false
		parachute = false
	_set_sprite(variant.idle_sprite, variant.idle_fps)
	# Fire Draw_0 only draws its body in the pinned SMW source. Saved wings
	# still detach on death; its parachute changes gravity without an overlay.
	if not variant.fire:
		_wings_sprite = SpriteLibrary.make_sprite(variant.flight.wings_sprite)
		_wings_sprite.sprite_frames = SpriteLibrary.get_animations({"flap": [String(variant.flight.wings_sprite), 7.2, true]})
		_wings_sprite.play(&"flap")
		_wings_sprite.name = "Wings"
		$Graphics.add_child(_wings_sprite)
		var rules: EnemyFlightPhysics = preload("res://resources/content/smw_enemy_flight_physics.tres")
		_parachute_sprite = SpriteLibrary.make_sprite(rules.parachute_sprite)
		_parachute_sprite.name = "Parachute"
		_parachute_sprite.pause()
		_parachute_sprite.frame = 2
		$Graphics.add_child(_parachute_sprite)
	_update_visuals()


func _physics_process(delta: float) -> void:
	_age += delta
	var liquid := sub_area.liquid
	swimming = sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP])
	if is_instance_valid(liquid):
		var source_y := global_position.y - 16
		if liquid.is_water():
			swimming = swimming or source_y + (20 if variant.fire else 8) > liquid.global_position.y
		elif source_y + (20 if variant.fire else 8) >= liquid.global_position.y:
			_sink()
			return
	if attachment != 0 and _age >= 5.0 / 60:
		var offset := Vector2(0, -12) if attachment == 1 else Vector2(-16 if attachment == 2 else 16, 0)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = _shape
		query.transform = global_transform.translated(offset)
		query.collision_mask = 1
		if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			kill()
			return
	var grounded := is_on_floor()
	if _start_left > 0:
		_start_left -= delta
		if _start_left < 0.00001 and parachute and not variant.fire and velocity.x == 0:
			velocity.x = (variant.water_sway_speed if swimming else variant.sway_speed) * direction
	if variant.fire:
		_advance_attack(delta)
	else:
		_jump_left -= delta
		if _jump_left <= 0.00001 and attachment == 0 and grounded and is_instance_valid(level.hud.player) \
				and not level.hud.player.is_dead():
			velocity.y = -variant.water_jump_speed if swimming else -variant.jump_speed
			_jump_left = INF
			_set_sprite(variant.jump_sprite, variant.jump_fps)
	if not parachute and (not variant.fire or grounded):
		velocity.x = move_toward(velocity.x, 0, variant.horizontal_drag * delta)
	elif variant.fire and absf(velocity.x) > (18 if swimming else 30):
		velocity.x = move_toward(velocity.x, (18 if swimming else 30) * signf(velocity.x), 288 * delta)
	if attachment == 0:
		var gravity := 0.0
		if not grounded:
			gravity = variant.float_gravity if parachute else variant.water_gravity if swimming else variant.gravity
			var cap := variant.float_fall_speed if parachute else variant.water_fall_speed if swimming else variant.fall_speed
			velocity.y = minf(cap, velocity.y) + gravity * delta
		if parachute and not variant.fire:
			if global_position.x > _origin.x + variant.sway_distance:
				velocity.x = -variant.sway_speed if velocity.x < -variant.sway_speed else velocity.x - variant.sway_acceleration * delta
			elif global_position.x < _origin.x - variant.sway_distance:
				velocity.x = variant.sway_speed if velocity.x > variant.sway_speed else velocity.x + variant.sway_acceleration * delta
			if grounded:
				_detach_parachute()
	var incoming_y := velocity.y
	super(delta)
	if attachment == 0 and is_on_floor() and incoming_y > 0 and not variant.fire:
		_jump_left = variant.jump_wait
		_set_sprite(variant.idle_sprite, variant.idle_fps)
	if variant.fire:
		_update_aim()
	_update_visuals()
	if Utility.get_bounding_box(self).position.y - 16 > 0:
		_drop_wings()
		queue_free()


func apply_source_death() -> void:
	super()
	_jump_left = INF
	if variant.fire and attack == Attack.IDLE:
		_attack_left = INF


func _set_sprite(sprite_name: StringName, fps: float) -> void:
	if _sprite_name == sprite_name:
		return
	_sprite_name = sprite_name
	SpriteLibrary.configure_sprite(%Sprite, sprite_name, &"body", fps)


func _update_aim() -> void:
	var player := level.get_living_player()
	if not is_instance_valid(player):
		direction = -1
		return
	direction = -1 if player.global_position.x < global_position.x else 1
	if attack == Attack.IDLE:
		var separation := player.global_position.y - 32 - (global_position.y - 16 - 21)
		if separation != 0:
			aiming_up = separation < 0
			_set_sprite(variant.aim_up_sprite if aiming_up else variant.idle_sprite, variant.idle_fps)


func _advance_attack(delta: float) -> void:
	_attack_left -= delta
	if _attack_left > 0.00001:
		return
	match attack:
		Attack.IDLE:
			attack = Attack.WINDUP
			_attack_left += variant.attack_windup
			%Sprite.pause()
			%Sprite.frame = 1
		Attack.WINDUP:
			attack = Attack.RECOVERY
			_attack_left += variant.attack_recovery
			%Sprite.frame = 0
			var shot := PlantFireball.new()
			shot.variant = variant
			shot.position = sub_area.get_foreground().to_local(global_position + Vector2(10 * direction, -16 - (11 if aiming_up else 6)))
			var speed := variant.water_projectile_speed if swimming else variant.projectile_speed
			shot.velocity = Vector2(speed.x * direction, -speed.y if aiming_up else speed.y)
			sub_area.add_deferred(shot)
			EnemyEffect.sound_once(sub_area, SoundLibrary.path(variant.shot_sound))
		Attack.RECOVERY:
			attack = Attack.IDLE
			_attack_left += variant.attack_wait
			%Sprite.play(&"body")


func _update_visuals() -> void:
	$Graphics.position.y = SpriteLibrary.contact_draw_y(variant.idle_sprite) if attachment == 0 else -16
	%Sprite.flip_h = variant.fire and direction < 0
	%Sprite.flip_v = false
	%Sprite.scale.y = -1 if attachment == 1 else 1
	%Sprite.position = Vector2.ZERO
	%Sprite.rotation = 0
	match attachment:
		1:
			%Sprite.position.y = 16
		2:
			%Sprite.position = Vector2(8, 8)
			%Sprite.rotation = PI / 2
		3:
			%Sprite.position = Vector2(-8, 8)
			%Sprite.rotation = -PI / 2
	if is_instance_valid(_wings_sprite):
		_wings_sprite.visible = wings
		_parachute_sprite.visible = parachute


func _detach_parachute() -> void:
	parachute = false
	velocity.x = 0
	var rules: EnemyFlightPhysics = preload("res://resources/content/smw_enemy_flight_physics.tres")
	var sprite := SpriteLibrary.make_sprite(rules.parachute_land_sprite)
	sprite.pause()
	sprite.frame = 2
	sprite.position = sub_area.get_foreground().to_local(global_position + Vector2(0, -16))
	sub_area.add_deferred(sprite)
	sprite.ready.connect(func():
		var tween := sprite.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 8.0 / 60)
		tween.tween_callback(sprite.queue_free))


func _drop_wings() -> void:
	if not wings:
		return
	var rules: EnemyFlightPhysics = preload("res://resources/content/smw_enemy_flight_physics.tres")
	for index in variant.flight.wing_loss_offsets.size():
		var wing := DetachedEnemyAttachment.new()
		wing.position = sub_area.get_foreground().to_local(global_position + Vector2(0, -16) + variant.flight.wing_loss_offsets[index])
		wing.turn_direction = 1 if index == 0 else -1
		if sub_area.level_theme == Level.LevelTheme.UNDERWATER \
				or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP]):
			wing.terminal_speed = 48
		var sprite := SpriteLibrary.make_sprite(rules.wing_dead_sprite if index == 0 else rules.other_wing_dead_sprite)
		sprite.pause()
		sprite.frame = 2
		sprite.flip_h = true
		wing.add_child(sprite)
		sub_area.add_deferred(wing)
	wings = false


func _sink() -> void:
	var liquid := sub_area.liquid
	EnemyEffect.play_once(sub_area, variant.poison_splash_sprite if sub_area.level_theme == Level.LevelTheme.FOREST \
			else variant.lava_splash_sprite, Vector2(global_position.x, liquid.global_position.y - 26), 12, false)
	var sink := SinkingEnemy.new()
	sink.mask_size = variant.mask_size
	sink.mask_center = variant.mask_center + Vector2(0, 16)
	sink.sub_area = sub_area
	sink.sprite_name = _sprite_name
	sink.direction = direction
	sink.position = sub_area.get_foreground().to_local(global_position + Vector2(0, -16))
	sub_area.add_deferred(sink)
	_drop_wings()
	queue_free()


func bumped_from_below(_activator: PhysicsBody2D) -> void:
	if velocity.y >= 0 and not is_queued_for_deletion():
		if is_instance_valid(level.hud.player) and not level.hud.player.is_dead():
			level.hud.player.score += 200
		kill()


func kill(launch_direction := 0.0) -> void:
	if is_queued_for_deletion():
		return
	if launch_direction == 0:
		launch_direction = level.hud.player.direction if is_instance_valid(level.hud.player) else -1
	var effect := SwimmingEnemyDefeat.new()
	effect.variant = variant
	effect.sub_area = sub_area
	effect.direction = direction
	effect.velocity.x = 60 * signf(launch_direction)
	effect.position = sub_area.get_foreground().to_local(global_position + variant.dead_offset)
	sub_area.add_deferred(effect)
	_drop_wings()
	queue_free()
