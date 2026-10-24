# SPDX-License-Identifier: AGPL-3.0-or-later
class_name EnemyFlightComponent
extends Component
## Shared native motion for independent wings/parachute flags.
## Sources: obj_galoomba/Step_0 + Alarm_0, obj_koopa[_red]/Step_0,
## obj_physicsparent/Other_14 and the detached attachment objects.

@export var wings := false
@export var parachute := false
var rules: EnemyFlightPhysics = preload("res://resources/content/smw_enemy_flight_physics.tres")
var profile: EnemyFlightProfile
var _body: Enemy
var _gravity: GravityComponent
var _slide: SlideComponent
var _graphics: Node2D
var _sprite: AnimatedSprite2D
var _wing_sprite: AnimatedSprite2D
var _parachute_sprite: AnimatedSprite2D
var _walk_sprite: StringName
var _walk_fps := 9.0
var _origin := Vector2.ZERO
var _age := 0.0
var _burst_pause := 2.0
var _hop_count := 0
var _airborne_hop := false
var _resume_left := 0.0
var _avoid_ledges := false
var _visual_state := Vector2i(-1, -1)
var _incoming_x := 0.0
var _ride_platform: AnimatableBody2D
var _ride_loaded := false


func setup(data: EnemyFlightProfile, walk_sprite: StringName, walk_fps: float, ceiling := false) -> void:
	profile = data
	_body = get_parent()
	_gravity = _body.get_node("GravityComponent")
	_slide = _body.get_node("SlideComponent")
	_graphics = _body.get_node("Graphics")
	_sprite = _body.get_node("Graphics/Sprite")
	_walk_sprite = walk_sprite
	_walk_fps = walk_fps
	_origin = _body.global_position
	_burst_pause = rules.burst_pause
	_avoid_ledges = _slide.avoid_ledges
	_gravity.set_physics_process(false)
	_slide.set_physics_process(false)
	# Keep a stable rest-animation pivot; ceiling crawlers overlap upward.
	_graphics.position = Vector2(0, SpriteLibrary.contact_draw_y(walk_sprite,
			-16 if ceiling else 0, ceiling, ceiling))
	if wings and profile.motion == EnemyFlightProfile.WingMotion.CRUISE:
		_body.velocity.x = _slide.speed * _slide.direction
	elif wings and profile.motion == EnemyFlightProfile.WingMotion.RIDE:
		_resume_left = 2.0 / 60
		_create_ride_platform()
	elif parachute:
		_body.velocity.x = -rules.sway_speed
	elif wings and profile.motion == EnemyFlightProfile.WingMotion.VERTICAL:
		_body.velocity.y = rules.sway_speed
	_update_visuals()


## Called once before the enemy's move_and_slide; no second body move.
func before_move(delta: float) -> void:
	_age += delta
	var resuming := _resume_left > 0
	_resume_left = maxf(0, _resume_left - delta)
	if _body.source_death_stopped():
		return
	_slide.avoid_ledges = _avoid_ledges and not wings
	if wings and profile.motion == EnemyFlightProfile.WingMotion.CRUISE:
		_body.velocity.x = _slide.speed * _slide.direction
		var offset := _body.global_position.y - _origin.y
		if offset > profile.hover_distance:
			_body.velocity.y = -profile.hover_speed if _body.velocity.y < -profile.hover_speed \
					else _body.velocity.y - profile.hover_acceleration * delta
		elif offset < -profile.hover_distance:
			_body.velocity.y = profile.hover_speed if _body.velocity.y > profile.hover_speed \
					else _body.velocity.y + profile.hover_acceleration * delta
	elif wings and profile.motion == EnemyFlightProfile.WingMotion.RIDE:
		# Buzzy's source wing branch bypasses gravity; its parachute consequently
		# detaches immediately even when both flags were saved in midair.
		if parachute:
			_land_parachute()
		_ride(delta)
	elif parachute:
		if wings and profile.motion == EnemyFlightProfile.WingMotion.HOP_BURST:
			_burst_pause -= delta
			if _burst_pause <= 0:
				_burst_pause = 10.0 / 60
		_gravity.gravity.y = rules.parachute_gravity
		_gravity.max_fall_speed = rules.parachute_fall_speed
		_gravity._physics_process(delta)
		_body.velocity.x = _sway(_body.global_position.x - _origin.x, _body.velocity.x, rules.sway_distance, delta)
		_slide.direction = -1
	elif wings and profile.motion == EnemyFlightProfile.WingMotion.VERTICAL:
		_body.velocity.x = 0
		if resuming and _resume_left == 0:
			_body.velocity.y = rules.sway_speed
		if _resume_left == 0:
			_body.velocity.y = _sway(_body.global_position.y - _origin.y, _body.velocity.y, rules.vertical_distance, delta)
		var player := _body.level.hud.player
		_slide.direction = -1 if not is_instance_valid(player) or player.global_position.x < _body.global_position.x else 1
	else:
		_gravity.gravity.y = rules.gravity
		_gravity.max_fall_speed = rules.fall_speed
		_gravity._physics_process(delta)
		if _resume_left == 0 and not profile.manual_walk:
			_slide._physics_process(delta)
		if wings:
			if profile.motion == EnemyFlightProfile.WingMotion.BOUNCE and _body.is_on_floor():
				_body.velocity.y = -(profile.wing_hop_speed if profile.wing_hop_speed > 0.0 \
						else rules.koopa_hop)
			elif profile.motion == EnemyFlightProfile.WingMotion.HOP_BURST:
				_burst(delta)
	_incoming_x = _body.velocity.x
	_update_visuals()


func after_move() -> void:
	if _body.source_death_stopped():
		return
	if _body.is_queued_for_deletion():
		return
	if is_instance_valid(_ride_platform):
		_ride_platform.global_position = _body.global_position + Vector2(0, -16)
	if parachute and _body.is_on_wall():
		_body.velocity.x = -_incoming_x
	if parachute and _body.is_on_floor():
		_land_parachute()
	elif wings and profile.motion == EnemyFlightProfile.WingMotion.VERTICAL:
		if _body.is_on_floor() and _resume_left == 0:
			_body.velocity.y = -rules.collision_recoil
		elif _body.is_on_ceiling():
			_body.velocity.y = rules.collision_recoil
	_update_visuals()


func _create_ride_platform() -> void:
	_ride_platform = AnimatableBody2D.new()
	_ride_platform.name = "BuzzyRidePlatform"
	_ride_platform.collision_layer = 1
	_ride_platform.collision_mask = 0
	_ride_platform.sync_to_physics = false
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 2)
	shape.shape = rectangle
	shape.position.y = 1
	shape.one_way_collision = true
	_ride_platform.add_child(shape)
	_ride_platform.position = _body.sub_area.get_foreground().to_local(_body.global_position + Vector2(0, -16))
	_ride_platform.ready.connect(func(): _body.add_collision_exception_with(_ride_platform))
	_body.sub_area.add_deferred(_ride_platform)


func _ride(delta: float) -> void:
	var player := _body.level.hud.player
	var passenger := is_instance_valid(player) and not player.is_dead() \
			and absf(player.global_position.x - _body.global_position.x) < 14 \
			and player.global_position.y >= _body.global_position.y - 21 \
			and player.global_position.y <= _body.global_position.y - 15
	if passenger:
		if not _ride_loaded:
			_body.velocity.y = rules.ride_sink_speed
		_body.velocity.y = maxf(-rules.ride_rise_speed, _body.velocity.y - rules.ride_acceleration * delta)
	else:
		_body.velocity.y = 0
	_ride_loaded = passenger
	if _body.is_on_wall():
		_slide.direction *= -1
	_body.velocity.x = _slide.speed * _slide.direction if _resume_left == 0 else 0


func _exit_tree() -> void:
	if is_instance_valid(_ride_platform):
		if _ride_platform.get_parent() != null:
			_ride_platform.queue_free()
		else:
			_ride_platform.free()


func _sway(offset: float, speed: float, distance: float, delta: float) -> float:
	if offset > distance:
		return -rules.sway_speed if speed < -rules.sway_speed else speed - rules.sway_acceleration * delta
	if offset < -distance:
		return rules.sway_speed if speed > rules.sway_speed else speed + rules.sway_acceleration * delta
	return speed


func _burst(delta: float) -> void:
	if _airborne_hop:
		if not _body.is_on_floor():
			return
		_airborne_hop = false
		if _hop_count == 4:
			_hop_count = 0
			_burst_pause = rules.burst_pause
			if profile.turn_after_burst:
				_slide.direction *= -1
			return
	_burst_pause = maxf(0, _burst_pause - delta)
	if _burst_pause == 0 and _body.is_on_floor():
		_hop_count += 1
		_body.velocity.y = -rules.burst_large_hop if _hop_count == 4 else -rules.burst_small_hop
		_airborne_hop = true


## A normal stomp strips wings first, retaining type and any parachute.
func strip_wings() -> bool:
	if not wings:
		return false
	var direction := _slide.direction
	for index in profile.wing_loss_offsets.size():
		var effect := DetachedEnemyAttachment.new()
		var offset := profile.wing_loss_offsets[index]
		if profile.mirror_wings_offset:
			offset.x *= direction
		effect.position = _body.sub_area.get_foreground().to_local(_body.global_position + Vector2(0, -16) + offset)
		effect.turn_direction = -1 if index == 0 else 1
		var sprite := SpriteLibrary.make_sprite(rules.wing_dead_sprite if index == 0 else rules.other_wing_dead_sprite)
		sprite.stop()
		sprite.frame = 2
		sprite.flip_h = direction < 0 if profile.mirror_wings_offset else true
		effect.add_child(sprite)
		_body.sub_area.add_deferred(effect)
	wings = false
	_body.velocity.x = 0
	if profile.wing_loss_drop:
		_body.velocity.y = 30
	_resume_left = rules.wing_loss_delay
	_update_visuals()
	return true


func _land_parachute() -> void:
	parachute = false
	_body.velocity.x = 0
	_resume_left = rules.land_delay
	if wings and profile.motion == EnemyFlightProfile.WingMotion.VERTICAL:
		_origin.y = _body.global_position.y - rules.vertical_distance
		_body.velocity.y = 0
	var sprite := SpriteLibrary.make_sprite(rules.parachute_land_sprite)
	sprite.stop()
	sprite.frame = 2
	sprite.position = _body.sub_area.get_foreground().to_local(_body.global_position + Vector2(
		profile.parachute_offset.x * _slide.direction, -16 + profile.parachute_offset.y))
	# Insert first, then start the short source shrinking animation.
	_body.sub_area.add_deferred(sprite)
	sprite.ready.connect(func():
		var shrink := sprite.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		shrink.tween_property(sprite, "scale", Vector2(0.2, 0.2), 8.0 / 60)
		shrink.tween_callback(sprite.queue_free))
	_update_visuals()


func _update_visuals() -> void:
	if profile == null:
		return
	var state := Vector2i(int(wings), int(parachute))
	if state != _visual_state:
		_visual_state = state
		var sprite_name := profile.float_sprite if parachute and profile.float_sprite != &"" else _walk_sprite
		if wings and profile.wing_body_sprite != &"":
			sprite_name = profile.wing_body_sprite
		SpriteLibrary.configure_sprite(_sprite, sprite_name, &"walk", profile.parachute_fps if parachute else _walk_fps)
		if wings and profile.wing_body_frame >= 0:
			_sprite.pause()
			_sprite.frame = profile.wing_body_frame
		if wings:
			if not is_instance_valid(_wing_sprite):
				_wing_sprite = AnimatedSprite2D.new()
				_wing_sprite.name = "Wings"
				_graphics.add_child(_wing_sprite)
			SpriteLibrary.configure_sprite(_wing_sprite, profile.wings_sprite, &"wings", 9 if parachute and profile.wings_fps == 0 else profile.wings_fps)
			if profile.wings_fps == 0 and not parachute:
				_wing_sprite.stop()
		if parachute and not is_instance_valid(_parachute_sprite):
			_parachute_sprite = SpriteLibrary.make_sprite(rules.parachute_sprite)
			_parachute_sprite.name = "Parachute"
			_parachute_sprite.stop()
			_parachute_sprite.frame = 2
			_parachute_sprite.z_index = -1
			_graphics.add_child(_parachute_sprite)
	_sprite.flip_h = _slide.direction < 0
	_graphics.rotation_degrees = sin(-rules.swing_frequency * _age) * rules.swing_degrees if parachute and profile.parachute_swing else 0
	if is_instance_valid(_wing_sprite):
		_wing_sprite.visible = wings
		_wing_sprite.position = profile.wings_offset
		if profile.mirror_wings_offset:
			_wing_sprite.position.x *= _slide.direction
		# Source draw calls rotate each sprite at its own fixed anchor.
		# Counter-rotate the offset, keeping the shared graphics rotation.
		_wing_sprite.position = _wing_sprite.position.rotated(-_graphics.rotation)
		_wing_sprite.flip_h = _slide.direction < 0
		if profile.motion == EnemyFlightProfile.WingMotion.RIDE:
			_wing_sprite.speed_scale = profile.loaded_wings_fps / profile.wings_fps if _ride_loaded else 1
	if is_instance_valid(_parachute_sprite):
		_parachute_sprite.visible = parachute
		_parachute_sprite.position = profile.parachute_offset.rotated(-_graphics.rotation)
