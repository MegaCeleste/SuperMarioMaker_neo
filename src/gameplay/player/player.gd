class_name Player
extends CharacterBody2D
## REQ-PHYS-109/115: orchestration only; motion and form state are independent.

signal movement_state_changed(previous: PlayerMovementStateMachine.State, current: PlayerMovementStateMachine.State)
signal p_meter_changed(previous: int, current: int)
signal powerup_changed(previous: PowerUpManager.Form, current: PowerUpManager.Form)
signal powerup_phase_changed(previous: PowerUpManager.Phase, current: PowerUpManager.Phase)
signal jump_started(kind: PlayerMotion.JumpKind, horizontal_speed: float, vertical_speed: float)
signal landed(incoming_speed: float)
signal died
signal physics_stepped(snapshot: Dictionary)
signal fireball_spawned(projectile: PlayerFireball)

enum Event { MUSHROOM, FLOWER, COIN, DAMAGE, KILL, BOUNCE, STAR }
const PHYSICS_PRIORITY: int = -10
const STYLE_ABILITIES_PATH: String = "res://data/physics/style_abilities.json"
const PRESENTATION_PATH: String = "res://data/physics/player_presentation.json"

@export var physics_profile: PlayerPhysicsProfile = preload("res://data/physics/base_physics.tres")
@export_enum("smb1", "smb3", "smw") var style_id: String = "smw"
@export var super_sprite_frames: SpriteFrames
@export var fire_sprite_frames: SpriteFrames
@export var show_collision_shapes: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $BodyShape
@onready var hurtbox_area: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var carry_sensor: Area2D = $CarrySensor

var effects: PlayerStatusEffects = PlayerStatusEffects.new()
var motion: PlayerMotion
var powerups: PowerUpManager
var collisions: PlayerCollision
var animator: PlayerAnimator
var carry: PlayerCarry
var input_enabled: bool = true

var movement_state: PlayerMovementStateMachine.State:
	get: return motion.state if motion != null else PlayerMovementStateMachine.State.AIR
	set(_value): push_error("Movement state is owned by PlayerMovementStateMachine.")
var power_form: PowerUpManager.Form:
	get: return powerups.form if powerups != null else PowerUpManager.Form.SMALL
	set(_value): push_error("Power-up form is owned by PowerUpManager.")
var power_phase: PowerUpManager.Phase:
	get: return powerups.phase if powerups != null else PowerUpManager.Phase.ACTIVE
	set(_value): push_error("Power-up phase is owned by PowerUpManager.")
var p_meter: int:
	get: return motion.p_meter if motion != null else 0

var _abilities: Dictionary = {}
var _events: Array[Event] = []
var _enemy_overlaps: Array[Enemy] = []
var _stomp_contacts: Array[Enemy] = []
var _pending_jump: bool = false
var _pending_spin: bool = false
var _pending_jump_release: bool = false
var _pending_spin_release: bool = false
var _pending_run: bool = false
var _pending_run_release: bool = false
var _latest_input: PlayerInputFrame = PlayerInputFrame.new()
var _pre_move_feet_y: float = 0.0
var _pre_move_velocity: Vector2 = Vector2.ZERO
var _death_frame: int = 0
var _death_finished: bool = false
var _fire_cooldown: int = 0
var _fire_shoot_frames: int = 0
var _fireballs: Array[PlayerFireball] = []
var _just_reset: bool = true


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	add_to_group("entity_players")
	_configure_sound_effects()
	physics_profile = physics_profile.duplicate(true) as PlayerPhysicsProfile
	var errors: PackedStringArray = physics_profile.validation_errors()
	if not errors.is_empty():
		push_error("Invalid PlayerPhysicsProfile: " + "; ".join(errors))
		set_physics_process(false)
		return
	motion = PlayerMotion.new(physics_profile)
	powerups = PowerUpManager.new(physics_profile)
	collisions = PlayerCollision.new(self, body_shape, hurtbox_shape, physics_profile)
	carry = PlayerCarry.new(self, physics_profile)
	var presentation: Dictionary = _read_dictionary(PRESENTATION_PATH)
	_fire_shoot_frames = int(presentation.get("fire_shoot_frames", 0))
	var tint: Array = presentation.get("fire_placeholder_tint", [1.0, 1.0, 1.0, 1.0]) as Array
	animator = PlayerAnimator.new(animated_sprite, physics_profile, super_sprite_frames, fire_sprite_frames, Color(float(tint[0]), float(tint[1]), float(tint[2]), float(tint[3])))
	motion.state_changed.connect(_on_movement_state_changed)
	motion.meter_changed.connect(_on_meter_changed)
	motion.jump_started.connect(_on_jump_started)
	powerups.powerup_changed.connect(_on_powerup_changed)
	powerups.phase_changed.connect(_on_powerup_phase_changed)
	powerups.transition_started.connect(_on_transition_started)
	powerups.transition_finished.connect(_on_transition_finished)
	hurtbox_area.collision_layer = CollisionConfig.layer("sensors")
	hurtbox_area.collision_mask = 0
	hurtbox_area.monitoring = false
	carry_sensor.collision_layer = CollisionConfig.layer("sensors")
	carry_sensor.collision_mask = CollisionConfig.mask(["enemies", "pickups"])
	carry_sensor.body_entered.connect(carry.add_candidate)
	carry_sensor.body_exited.connect(carry.remove_candidate)
	set_style(style_id)
	_pre_move_feet_y = feet_y()
	_render(0.0, 0.0)


func _exit_tree() -> void:
	_stop_sound_effects()
	effects.reset()
	if carry != null:
		carry.clear()
	for projectile: PlayerFireball in _fireballs:
		if is_instance_valid(projectile):
			projectile.queue_free()
	_fireballs.clear()
	_events.clear()
	GameManager.clear_gameplay_freeze()

func _unhandled_input(event: InputEvent) -> void:
	record_input_event(event)


func record_input_event(event: InputEvent) -> void:
	if not input_enabled or (event is InputEventKey and (event as InputEventKey).echo):
		return
	_pending_jump = _pending_jump or event.is_action_pressed(&"jump")
	_pending_spin = _pending_spin or event.is_action_pressed(&"spin_jump")
	_pending_jump_release = _pending_jump_release or event.is_action_released(&"jump")
	_pending_spin_release = _pending_spin_release or event.is_action_released(&"spin_jump")
	_pending_run = _pending_run or event.is_action_pressed(&"run")
	_pending_run_release = _pending_run_release or event.is_action_released(&"run")


func _capture_input() -> PlayerInputFrame:
	var input: PlayerInputFrame = PlayerInputFrame.capture() if input_enabled else PlayerInputFrame.new()
	input.jump_pressed = _pending_jump or (input_enabled and InputManager.just_pressed(&"jump"))
	input.spin_pressed = _pending_spin or (input_enabled and InputManager.just_pressed(&"spin_jump"))
	input.jump_released = _pending_jump_release or (input_enabled and InputManager.just_released(&"jump"))
	input.spin_released = _pending_spin_release or (input_enabled and InputManager.just_released(&"spin_jump"))
	input.run_pressed = _pending_run or (input_enabled and InputManager.just_pressed(&"run"))
	input.run_released = _pending_run_release or (input_enabled and InputManager.just_released(&"run"))
	clear_input_edges()
	return input


func clear_input_edges() -> void:
	_pending_jump = false
	_pending_spin = false
	_pending_jump_release = false
	_pending_spin_release = false
	_pending_run = false
	_pending_run_release = false


func _physics_process(delta: float) -> void:
	_latest_input = _capture_input()
	if _events.has(Event.KILL):
		_events.clear()
		powerups.kill()
	if power_form == PowerUpManager.Form.DEAD:
		_advance_death(delta)
		return
	motion.queue_jump(_latest_input, has_ability("spin_jump") and not carry.is_carrying())
	if GameManager.is_gameplay_frozen or powerups.is_transforming():
		powerups.advance_transition()
		_render(0.0, 0.0, true)
		physics_stepped.emit(snapshot(true))
		return
	_process_events()
	_resolve_enemy_contacts()
	if power_form == PowerUpManager.Form.DEAD:
		_advance_death(delta)
		return
	if powerups.is_transforming():
		powerups.advance_transition()
		var frozen: bool = GameManager.is_gameplay_frozen
		_render(0.0, 0.0, frozen)
		physics_stepped.emit(snapshot(frozen))
		return
	var grounded_before: bool = is_on_floor() and velocity.y >= 0.0 and not _just_reset
	_just_reset = false
	collisions.refresh((_latest_input.down and grounded_before) or motion.crouch_jump, powerups.is_large())
	motion.crouched = collisions.crouched
	motion.velocity = velocity
	motion.speed_bonus = effects.speed_bonus()
	motion.begin_tick(_latest_input, grounded_before, has_ability("p_meter"), delta)
	carry.tick(_latest_input, has_ability("carry"), motion.facing, powerups.is_large(), style_id == "smw")
	velocity = motion.velocity
	_pre_move_feet_y = feet_y()
	_pre_move_velocity = velocity
	var start_position: Vector2 = global_position
	collisions.attempt_corner_correction(velocity, delta)
	move_and_slide()
	if is_on_ceiling() and _pre_move_velocity.y < 0.0:
		motion.velocity = velocity
		motion.head_bump()
		velocity = motion.velocity
		var block: InteractableBlock = collisions.head_block()
		if block != null:
			block.hit_by_player(self)
	if is_on_floor() and _pre_move_velocity.y > 0.0 and motion.spin_active:
		var spin_block: InteractableBlock = collisions.floor_block()
		if spin_block != null and spin_block.hit_from_above(self):
			_apply_bounce()
	var grounded_after: bool = is_on_floor() and velocity.y >= 0.0
	if grounded_after:
		collisions.refresh(_latest_input.down, powerups.is_large())
		motion.crouched = collisions.crouched
		if not grounded_before:
			landed.emit(_pre_move_velocity.y)
	motion.finish_tick(velocity, grounded_after, is_on_wall(), _latest_input)
	velocity = motion.velocity
	carry.follow(motion.facing, powerups.is_large())
	_update_fire_ability()
	_render(global_position.x - start_position.x, delta)
	physics_stepped.emit(snapshot(false))
	powerups.finish_active_tick()
	effects.finish_active_tick()
	queue_redraw()


func _process_events() -> void:
	var pending: Array[Event] = _events.duplicate()
	_events.clear()
	# An accepted star pickup protects against damage queued in the same step.
	if pending.has(Event.STAR):
		effects.apply_star()
		pending.erase(Event.STAR)
	for event: Event in pending:
		match event:
			Event.MUSHROOM: powerups.collect_mushroom()
			Event.FLOWER: powerups.collect_fire_flower()
			Event.COIN:
				GameManager.add_coins(1)
				_play_sound("CoinSound")
			Event.STAR: effects.apply_star()
			Event.DAMAGE:
				if effects.star_left == 0:
					powerups.take_damage()
			Event.BOUNCE:
				if powerups.is_transforming():
					_events.append(Event.BOUNCE)
				else:
					_apply_bounce()
			Event.KILL: powerups.kill()


func _resolve_enemy_contacts() -> void:
	if powerups.is_transforming() or power_form == PowerUpManager.Form.DEAD:
		_stomp_contacts.clear()
		return
	var candidates: Array[Enemy] = _enemy_overlaps.duplicate()
	for enemy: Enemy in _stomp_contacts:
		if not candidates.has(enemy):
			candidates.append(enemy)
	_stomp_contacts.clear()
	var stomp_target: Enemy = null
	var stomp_top: float = INF
	for enemy: Enemy in candidates:
		if not is_instance_valid(enemy) or enemy.is_dead:
			_enemy_overlaps.erase(enemy)
			continue
		if effects.star_left > 0 and _enemy_overlaps.has(enemy):
			enemy.receive_hit(EntityHit.new(EntityHit.Kind.STAR, self, self, motion.facing))
			continue
		if not enemy.can_be_stomped(motion.spin_active):
			continue
		var top: float = enemy.stomp_surface_y()
		if _pre_move_velocity.y >= 0.0 and _pre_move_feet_y <= top + physics_profile.stomp_tolerance and feet_y() >= top - physics_profile.stomp_tolerance:
			if top < stomp_top:
				stomp_top = top
				stomp_target = enemy
	if stomp_target != null:
		var response: EntityHitResult = stomp_target.receive_hit(EntityHit.new(EntityHit.Kind.SPIN if motion.spin_active else EntityHit.Kind.STOMP, self, self, motion.facing))
		if response.bounce != EntityHitResult.Bounce.NONE:
			_apply_bounce()
		return
	for enemy: Enemy in candidates:
		if is_instance_valid(enemy) and not enemy.is_dead and _enemy_overlaps.has(enemy):
			if enemy.side_contact(self, _latest_input.run):
				_play_sound("KlockSound")
			elif enemy.can_damage_player():
				if effects.star_left == 0:
					powerups.take_damage()
				return


func register_enemy_overlap(enemy: Enemy) -> void:
	if not _enemy_overlaps.has(enemy):
		_enemy_overlaps.append(enemy)


func unregister_enemy_overlap(enemy: Enemy) -> void:
	_enemy_overlaps.erase(enemy)


func register_stomp_contact(enemy: Enemy) -> void:
	if not _stomp_contacts.has(enemy):
		_stomp_contacts.append(enemy)


func collect_mushroom() -> bool:
	if powerups != null and powerups.phase != PowerUpManager.Phase.ACTIVE:
		return false
	_events.append(Event.MUSHROOM)
	return true


func collect_fire_flower() -> bool:
	if powerups != null and powerups.phase != PowerUpManager.Phase.ACTIVE:
		return false
	_events.append(Event.FLOWER)
	return true


func collect_coin() -> bool:
	if powerups == null or powerups.phase != PowerUpManager.Phase.ACTIVE:
		return false
	_events.append(Event.COIN)
	return true


func collect_star() -> bool:
	if powerups == null or powerups.phase != PowerUpManager.Phase.ACTIVE:
		return false
	_events.append(Event.STAR)
	_play_sound("PowerupSound")
	return true


func collect_reward(amount: int, extra_life: bool = false) -> bool:
	if powerups == null or powerups.phase != PowerUpManager.Phase.ACTIVE:
		return false
	if extra_life:
		GameManager.add_extra_life()
	else:
		GameManager.add_coins(amount)
	_play_sound("PowerupSound" if extra_life else "CoinSound")
	return true


func take_damage() -> void:
	if effects.star_left > 0 or (powerups != null and powerups.is_invulnerable()):
		return
	_events.append(Event.DAMAGE)


func bounce() -> void:
	_events.append(Event.BOUNCE)


func die() -> void:
	_events.append(Event.KILL)


func _apply_bounce() -> void:
	if power_form == PowerUpManager.Form.DEAD:
		return
	motion.velocity = velocity
	motion.bounce(_latest_input)
	velocity = motion.velocity
	_play_sound("KlockSound")


func _on_movement_state_changed(previous: PlayerMovementStateMachine.State, current: PlayerMovementStateMachine.State) -> void:
	movement_state_changed.emit(previous, current)
	if previous == PlayerMovementStateMachine.State.SKID:
		_stop_sound("SkidSound")
	if current == PlayerMovementStateMachine.State.SKID:
		_play_sound("SkidSound")


func _on_meter_changed(previous: int, current: int) -> void:
	p_meter_changed.emit(previous, current)


func _on_jump_started(kind: PlayerMotion.JumpKind, horizontal_speed: float, vertical_speed: float) -> void:
	jump_started.emit(kind, horizontal_speed, vertical_speed)
	if kind != PlayerMotion.JumpKind.BOUNCE:
		_play_sound("SpinJumpSound" if kind == PlayerMotion.JumpKind.SPIN else "JumpSound")


func _on_powerup_changed(previous: PowerUpManager.Form, current: PowerUpManager.Form) -> void:
	if current == PowerUpManager.Form.DEAD:
		$SkidDust.clear()
		effects.reset()
		GameManager.clear_gameplay_freeze()
		_stop_sound_effects()
		carry.drop(velocity)
		motion.enter_dead()
		velocity = Vector2.ZERO
		collisions.set_enabled(false)
		collision_layer = 0
		hurtbox_area.collision_layer = 0
		_death_frame = 0
		_death_finished = false
		_play_sound("DeadSound")
	else:
		collisions.refresh((_latest_input.down and is_on_floor() and velocity.y >= 0.0) or motion.crouch_jump, powerups.is_large())
		motion.crouched = collisions.crouched
	powerup_changed.emit(previous, current)


func _on_powerup_phase_changed(previous: PowerUpManager.Phase, current: PowerUpManager.Phase) -> void:
	powerup_phase_changed.emit(previous, current)


func _on_transition_started(_previous: PowerUpManager.Form, _current: PowerUpManager.Form, frames: int, damage: bool) -> void:
	_stop_sound("SkidSound")
	if damage:
		motion.clear_meter()
		carry.drop(velocity)
	GameManager.freeze_gameplay(frames)
	_play_sound("PowerdownSound" if damage else "PowerupSound")


func _on_transition_finished() -> void:
	collisions.refresh((_latest_input.down and is_on_floor() and velocity.y >= 0.0) or motion.crouch_jump, powerups.is_large())
	motion.crouched = collisions.crouched


func _advance_death(delta: float) -> void:
	if not _death_finished:
		_death_frame += 1
		if _death_frame == physics_profile.death_delay_frames:
			velocity.y = physics_profile.death_initial
		elif _death_frame > physics_profile.death_delay_frames:
			velocity.y += physics_profile.death_gravity * delta
		if _death_frame >= physics_profile.death_delay_frames:
			global_position += velocity * delta
		if _death_frame >= physics_profile.death_duration_frames:
			_death_finished = true
			died.emit()
	motion.velocity = velocity
	_render(0.0, delta)
	physics_stepped.emit(snapshot(false))


func _update_fire_ability() -> void:
	_fire_cooldown = maxi(0, _fire_cooldown - 1)
	if power_form != PowerUpManager.Form.FIRE or not _latest_input.run_pressed or carry.is_carrying() or _fire_cooldown > 0:
		return
	if _fireballs.size() >= physics_profile.fireball_limit:
		return
	var projectile: PlayerFireball = PlayerFireball.new(physics_profile, motion.facing)
	projectile.finished.connect(_on_fireball_finished)
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector2(motion.facing * physics_profile.hold_offset_super.x, physics_profile.feet_y - collisions.terrain_height / 2.0)
	_fireballs.append(projectile)
	_fire_cooldown = physics_profile.fireball_cooldown_frames
	animator.show_shoot(_fire_shoot_frames)
	fireball_spawned.emit(projectile)


func _on_fireball_finished(projectile: PlayerFireball) -> void:
	_fireballs.erase(projectile)


func _render(horizontal_distance: float, delta: float, frozen: bool = false) -> void:
	_sync_skid_sound(frozen)
	animator.render(motion, powerups, horizontal_distance, delta, frozen, carry.is_carrying(), _latest_input.up)
	if effects.star_left > 0:
		animated_sprite.modulate *= effects.tint()
		animated_sprite.visible = true


func get_current_animation_fps() -> float:
	return animator.current_fps


func feet_y() -> float:
	return global_position.y + physics_profile.feet_y


func has_ability(ability: String) -> bool:
	return bool(_abilities.get(ability, false))


func set_style(style: String) -> void:
	var document: Dictionary = _read_dictionary(STYLE_ABILITIES_PATH)
	if not document.has(style):
		push_error("Unknown Player style: " + style)
		return
	style_id = style
	_abilities = document[style] as Dictionary
	if motion != null:
		motion.clear_meter()
		if not has_ability("spin_jump"):
			motion.spin_active = false
			if motion.jump_kind == PlayerMotion.JumpKind.SPIN:
				motion.jump_kind = PlayerMotion.JumpKind.NORMAL
	if carry != null and not has_ability("carry"):
		carry.drop(velocity)


func reset_to(spawn: Vector2, form: PowerUpManager.Form = PowerUpManager.Form.SMALL) -> void:
	if form not in [PowerUpManager.Form.SMALL, PowerUpManager.Form.SUPER, PowerUpManager.Form.FIRE]:
		push_error("Player reset_to() requires a living form.")
		return
	_stop_sound_effects()
	$SkidDust.clear()
	GameManager.clear_gameplay_freeze()
	carry.clear()
	for projectile: PlayerFireball in _fireballs:
		if is_instance_valid(projectile):
			projectile.queue_free()
	_fireballs.clear()
	_fire_cooldown = 0
	_events.clear()
	_enemy_overlaps.clear()
	_stomp_contacts.clear()
	clear_input_edges()
	_latest_input = PlayerInputFrame.new()
	global_position = spawn
	velocity = Vector2.ZERO
	motion.reset()
	effects.reset()
	powerups.reset(form)
	animator.reset()
	collisions.set_enabled(true)
	collision_layer = CollisionConfig.layer("player")
	hurtbox_area.collision_layer = CollisionConfig.layer("sensors")
	collisions.refresh(false, powerups.is_large())
	motion.crouched = collisions.crouched
	_pre_move_feet_y = feet_y()
	_pre_move_velocity = Vector2.ZERO
	_just_reset = true
	_death_finished = false
	_death_frame = 0
	_render(0.0, 0.0)
	reset_physics_interpolation()


func snapshot(frozen: bool) -> Dictionary:
	return {"frame": Engine.get_physics_frames(), "x": global_position.x, "y": global_position.y,
		"vx": velocity.x, "vy": velocity.y, "state": PlayerMovementStateMachine.State.keys()[movement_state],
		"form": PowerUpManager.Form.keys()[power_form], "power_phase": PowerUpManager.Phase.keys()[power_phase],
		"transition_frames": powerups.transition_left, "style": style_id,
		"grounded": power_form != PowerUpManager.Form.DEAD and is_on_floor() and velocity.y >= 0.0, "crouched": collisions.crouched,
		"jump_kind": PlayerMotion.JumpKind.keys()[motion.jump_kind], "coyote": motion.coyote_left,
		"buffer": motion.buffer_left, "p_meter": p_meter, "frozen": frozen,
		"star_frames": effects.star_left, "speed_bonus": effects.speed_bonus(),
		"invulnerability": powerups.invulnerability_left, "animation": String(animated_sprite.animation),
		"animation_frame": animated_sprite.frame, "animation_fps": get_current_animation_fps(),
		"terrain_height": collisions.terrain_height, "hurt_height": collisions.hurt_height,
		"input": _latest_input.as_dictionary()}


func _draw() -> void:
	if show_collision_shapes and collisions != null:
		draw_rect(collisions.terrain_rect(), Color(0.2, 1.0, 0.5), false)
		draw_rect(collisions.hurt_rect().grow(-physics_profile.clearance_epsilon), Color(1.0, 0.4, 0.2), false)


func _configure_sound_effects() -> void:
	var container: Node = get_node_or_null("Sound")
	if container == null:
		return
	for child: Node in container.get_children():
		var sound: AudioStreamPlayer = child as AudioStreamPlayer
		if sound == null or sound.stream == null:
			continue
		sound.stream = SoundEffectStream.copy(sound.stream, sound.name == &"SkidSound")


func _sync_skid_sound(frozen: bool) -> void:
	var sound: AudioStreamPlayer = get_node_or_null("Sound/SkidSound") as AudioStreamPlayer
	if sound == null or sound.stream == null:
		return
	var braking: bool = not frozen and powerups.phase == PowerUpManager.Phase.ACTIVE and movement_state == PlayerMovementStateMachine.State.SKID
	if braking and not sound.playing:
		sound.play()
	elif not braking and sound.playing:
		sound.stop()


func _stop_sound_effects() -> void:
	var container: Node = get_node_or_null("Sound")
	if container == null:
		return
	for child: Node in container.get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()


func _stop_sound(node_name: String) -> void:
	var sound: AudioStreamPlayer = get_node_or_null("Sound/" + node_name) as AudioStreamPlayer
	if sound != null:
		sound.stop()


func _play_sound(node_name: String) -> void:
	var sound: AudioStreamPlayer = get_node_or_null("Sound/" + node_name) as AudioStreamPlayer
	if sound != null and sound.stream != null:
		sound.play()


func _read_dictionary(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing Player configuration: " + path)
		return {}
	var document: Variant = JSON.parse_string(file.get_as_text())
	if document is Dictionary:
		return document as Dictionary
	push_error("Invalid Player configuration: " + path)
	return {}
