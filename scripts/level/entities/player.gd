# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Player
extends Entity
## Represents a controllable player.

## Emitted when the [member held_item] is dropped.
signal item_dropped(item: Entity)
## Emitted when an item is given to the player.
signal item_given

@export var physics: PlayerPhysics = preload("res://resources/content/smw_player_physics.tres")
@export var animation_rules: PlayerAnimationRules = preload("res://resources/content/smw_player_animation.tres")

## The player's sprite.
@onready var sprite: AnimatedSprite2D = %Sprite
## The player's sound player.
@onready var sounds: AudioStreamPlayer = %Sounds
## The player's state machine.
@onready var state_machine: StateMachine = %StateMachine

## The powerup the player will start with.
@export var starting_powerup: Powerup = SmallPowerup.new():
	set(v):
		v.player = self
		starting_powerup = v

#region Physics values

@export_group("Maximum Speed")
## The maximum horizontal speed when walking.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var max_walk_speed := 78.0
## The maximum horizontal speed when running.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var max_run_speed := 180.0
## The maximum vertical speed when falling.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var max_fall_speed := 258.0

@export_group("Acceleration")
## The usual horizontal acceleration speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²")
var acceleration := 216.0
## Acceleration speed used when the player is on a slippery surface.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²")
var ice_acceleration := 180.0

@export_group("Deceleration")
## The usual horizontal deceleration speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²")
var deceleration := 180.0
## Deceleration speed used when the player is on a slippery surface.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²")
var ice_deceleration := 18.0
## Deceleration speed used when the player is skidding. The player does not
## accelerate using this value.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²")
var skid_deceleration := 468.0

@export_group("Jump Speed")
## Jump speed used when the horizontal speed is equal to or above
## [member Player.max_run_speed].
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var fast_jump_speed := 258.0
## Jump speed used when the horizontal speed is equal to or above
## [member Player.max_walk_speed] when walking, below
## [member Player.max_run_speed] when running.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var slow_jump_speed := 243.0
## Jump speed used when the horizontal speed is below
## [member Player.max_walk_speed].
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var idle_jump_speed := 237.0
## The vertical speed at which the player will start applying
## [member Player.gravity] instead of [member Player.long_jump_gravity].
## Includes spin jumps.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var long_jump_stop_speed := 60.0
## The regular spin jump speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var spin_jump_speed := 198.0
## The spin jump speed used when the level has low gravity.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var night_spin_jump_speed := 138.0
## The bounce speed used when an enemy is stomped.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var stomp_bounce_speed := 253.5

@export_group("Gravity")
## The default gravity.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²")
var gravity := 1080.0
## The gravity used for variable jump height.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²")
var long_jump_gravity := 360.0

@export_group("Enhancements")
## The amount of body corner overlap to push the player to the side. Only
## applied on the Y axis.
@export_custom(PROPERTY_HINT_NONE, "suffix:px")
var corner_correction := 3
## The maximum amount of time the player will allow when it has jumped
## too [i]early[/i].
@export_custom(PROPERTY_HINT_NONE, "suffix:s")
var jump_buffer_time := 2.0/60
## The maximum amount of time the player will allow when it has jumped too
## [i]late[/i].
@export_custom(PROPERTY_HINT_NONE, "suffix:s")
var coyote_time := 4.0/60

#endregion

## The player's collected coin count.
var coins := 0
var score := 0
var invulnerability_left := 0.0
## The player's P-Meter value, from 0 to 7.
var p_meter := 0
## The direction the player is facing. This value is either -1 or 1, and
## represents which side of the X axis is the player facing.
var direction := 1
## Used in processing coyote time.
var just_fell := false
## The player's [b]global[/b] position before the [method move_and_slide] call.
## Used in scenarios where
## [url=https://github.com/godotengine/godot/issues/38983]Godot's area detection
## is late[/url].
var previous_position: Vector2
## The tween used to move the held item side to side when moving and turning.
var held_item_tween: Tween
## The [EditorPlayer] that created this [Player].
var editor_player: EditorPlayer

var _powerup: Powerup
var _held_item: Entity
var _helmet: PlayerHelmet
var _star: PlayerStar
var held_item: Entity:
	get:
		return _held_item if is_instance_valid(_held_item) else null
	set(item):
		give_item(item)
## 1UP rewards earned this play session; profile/life UI is a later system.
var extra_lives := 0
var _p_timer := 0.0
var _can_move_camera_up := false
var _held_z := 0
var _gravity: GravityComponent
var _sprite_mapping: Dictionary = {}
## A mushroom cannot expand the body into a ceiling; stand when it clears.
var growth_crouched := false
## Voluntary crouching also applies to small SMW Mario and crouch jumps.
var crouching := false


## The hitbox size used when the player is on a small powerup.
const SMALL_HITBOX_SIZE = Rect2(Vector2(0, -7.5), Vector2(12, 15))
const SMALL_DUCK_HITBOX_SIZE = Rect2(Vector2(0, -6.5), Vector2(12, 13))
## The hitbox size used when the player is on a big powerup.
const BIG_HITBOX_SIZE = Rect2(Vector2(0, -13.5), Vector2(12, 27))
const HELD_ITEM_OFFSET = Vector2(11, -1.5)
## The y height at which the player will be killed.
const VOID_LEVEL = 64


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(editor_player) \
			and is_instance_valid(level) and level.editor != null:
		editor_player.global_position = global_position - Vector2(8, 16)


func _ready() -> void:
	if not level.is_node_ready():
		await level.ready
	level.hud.player = self
	max_walk_speed = physics.walk_speed
	max_run_speed = physics.run_speed
	max_fall_speed = physics.fall_speed
	acceleration = physics.acceleration
	deceleration = physics.deceleration
	ice_acceleration = physics.ice_acceleration
	ice_deceleration = physics.ice_deceleration
	skid_deceleration = physics.skid_deceleration
	idle_jump_speed = physics.idle_jump_speed
	slow_jump_speed = physics.slow_jump_speed
	fast_jump_speed = physics.fast_jump_speed
	spin_jump_speed = physics.spin_jump_speed
	gravity = physics.gravity
	long_jump_gravity = physics.long_jump_gravity
	_gravity = Utility.find_child_by_class(self, GravityComponent)
	_gravity.gravity = Vector2(0, gravity)
	_gravity.max_fall_speed = max_fall_speed
	# Evaluate state, gravity, then motion in one fixed tick, independent of
	# scene-child processing order (also used by physics trace regressions).
	state_machine.set_physics_process(false)
	_gravity.set_physics_process(false)
	
	# trigger setter
	$CollShape.shape = $CollShape.shape.duplicate()
	sprite.animation_changed.connect(_update_sprite_origin)
	starting_powerup = starting_powerup
	_powerup = starting_powerup
	_powerup.start()
	_helmet = PlayerHelmet.new()
	_helmet.name = "BuzzyHelmet"
	add_child(_helmet)
	_star = PlayerStar.new()
	_star.player = self
	add_child(_star)
	
	var f = func():
		var query = PhysicsShapeQueryParameters2D.new()
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.collision_mask = 1
		query.shape = WorldBoundaryShape2D.new()
		query.shape.normal = Vector2.DOWN
		query.transform.origin = Vector2(0, -14 * Level.GRID_SIZE.y)
		_can_move_camera_up = not get_world_2d().direct_space_state.intersect_shape(
				query, 1).is_empty()
	f.call_deferred()


func _physics_process(delta: float) -> void:
	previous_position = global_position
	_update_swimming()
	_update_crouch()
	_p_timer += delta
	if is_swimming():
		p_meter = 0
	elif is_on_floor():
		if absf(velocity.x) > max_walk_speed:
			if _p_timer >= 0.133:
				p_meter = mini(7, p_meter + 1)
				_p_timer = 0
		else:
			p_meter = mini(p_meter, 5)
			if _p_timer >= 0.4:
				p_meter = maxi(0, p_meter - 1)
				_p_timer = 0
	invulnerability_left = maxf(0, invulnerability_left - delta)
	_star.tick()
	sprite.modulate.a = 0.4 if invulnerability_left > 0 \
			and int(invulnerability_left * 15) % 2 == 0 else 1.0
	state_machine._physics_process(delta)
	if is_ducking() and not is_dead() and not is_frozen() and not is_traveling() \
			and not state_machine.current_state is PlayerStunnedState and not state_machine.current_state is PlayerSlopeSlideState \
			and level.status == Level.Status.PLAYING:
		sprite.speed_scale = 1
		sprite.play(&"hold_duck" if held_item != null else &"duck")
		sprite.flip_h = direction < 0
	if not is_frozen() and not is_traveling():
		_gravity._physics_process(delta)
		_powerup.physics_process(delta)
		_attempt_correction(delta, 2)
		move_and_slide()
		if is_swimming() and sub_area.level_theme == Level.LevelTheme.UNDERWATER:
			# Source room top is y=-16 at a top-origin32px Mario. Native feet
			# are32px lower; this also leaves the usual headroom above the room.
			position.y = maxf(position.y, -Level.LEVEL_HEIGHT * Level.GRID_SIZE.y + 16)
		super(delta)
	
	if global_position.y >= VOID_LEVEL and not is_dead():
		kill()
	_update_camera(delta)


## Query only the supporting foot strip. A cloud above ice must not inherit
## its friction, and jumping off the surface restores ordinary air control.
func is_on_ice() -> bool:
	if not is_on_floor() or velocity.y < 0:
		return false
	var bounds := Utility.get_bounding_box(self)
	var query := PhysicsShapeQueryParameters2D.new()
	var strip := RectangleShape2D.new()
	strip.size = Vector2(bounds.size.x, 1)
	query.shape = strip
	query.transform.origin = Vector2(bounds.get_center().x, bounds.end.y + 0.5)
	query.collision_mask = 1
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		if hit.collider is IceBlock:
			return true
	return false


func _process(delta: float) -> void:
	_powerup.process(delta)
	_update_sprite_origin()


## Follow the completed body step on the same clock. Updating the camera on
## render frames moves a stationary-between-ticks sprite backwards at >60fps.
func _update_camera(delta: float) -> void:
	# avoid moving the camera during pauses
	if level.can_process() and not is_dead():
		var size = get_viewport().get_visible_rect().size / Utility.camera_scale
		var center = global_position - (size / 2)
		var target = Vector2(center.x, Utility.camera_position.y)
		if _can_move_camera_up or Utility.camera_position.y < center.y:
			if Utility.camera_position.y - center.y <= -32:
				target.y = center.y - 32
			if center.y - Utility.camera_position.y <= -32:
				target.y = center.y + 32
		# uncomment to smooth when camera hits edges
		#target = target.clamp(
				#Vector2(0, -Level.LEVEL_HEIGHT * Level.GRID_SIZE.y),
				#Vector2(INF, -get_viewport().get_visible_rect().size.y \
				#/ Utility.camera_scale.y))
		Utility.camera_position = Utility.camera_position.lerp(target, 6 * delta)
		# Physics-side projectile culling must see the same bounded camera
		# that rendering uses, rather than waiting for Level's deferred clamp.
		level._camera_clamp()


## Makes the player bounce (e.g. off an enemy).
func bounce() -> void:
	if is_frozen():
		return
	if is_swimming():
		velocity.y = -get_node("StateMachine/Swimming").rules.bounce_speed
		sounds.stop()
		return
	if state_machine.current_state is PlayerSpinJumpingState:
		state_machine.switch(PlayerSpinJumpingState, true)
	else:
		state_machine.switch(PlayerJumpingState, true)
	sounds.stop()
	velocity.y = -stomp_bounce_speed
	if state_machine.current_state is PlayerSpinJumpingState and _powerup is FirePowerup:
		_powerup.begin_spin(5)


## Downgrades the player into a lower-tier powerup.
func damage() -> void:
	if is_queued_for_deletion() or is_dead() or is_frozen() or has_star() or invulnerability_left > 0 \
			or level.status != Level.Status.PLAYING:
		return
	if has_helmet():
		_helmet.break_off()
		invulnerability_left = physics.damage_invulnerability
		return
	if _powerup is SmallPowerup:
		kill()
	else:
		set_powerup(SuperPowerup.new() if _powerup is FirePowerup else SmallPowerup.new(), true)
		invulnerability_left = physics.damage_invulnerability
		sounds.stream = preload("uid://0nbemimuo3b6")
		sounds.play()


## Forcibly kills the player, regardless of any powerups.
func kill() -> void:
	if not is_dead() and level.status == Level.Status.PLAYING:
		state_machine.switch(PlayerDeathState)


func is_dead() -> bool:
	return state_machine.current_state is PlayerDeathState


func is_frozen() -> bool:
	return state_machine.current_state is PlayerFrozenState


func is_swimming() -> bool:
	return state_machine.current_state is PlayerSwimmingState


## Whether a door currently moves Mario instead of physics.
func is_traveling() -> bool:
	return state_machine.current_state is PlayerDoorState


## Starts the scripted trip through [param entry] to its partner door.
func enter_door(entry: WarpDoor) -> void:
	var state: PlayerDoorState = Utility.find_child_by_class(state_machine, PlayerDoorState)
	state.entry = entry
	state_machine.switch(PlayerDoorState, true)


## Centres the camera on Mario at once, as after going through a door.
func snap_camera() -> void:
	var size = get_viewport().get_visible_rect().size / Utility.camera_scale
	Utility.camera_position = global_position - size / 2
	level._camera_clamp()


## Full underwater themes are water everywhere. The existing surface supports
## source entry/exit hysteresis too; lava/poison must never enable swimming.
func _update_swimming() -> void:
	var state := state_machine.current_state
	if not (state is PlayerIdleState or state is PlayerMovingState or state is PlayerFallingState \
			or state is PlayerJumpingState or state is PlayerSpinJumpingState \
			or state is PlayerSwimmingState or state is PlayerSlopeSlideState):
		return
	var full := sub_area.level_theme == Level.LevelTheme.UNDERWATER
	var liquid := sub_area.liquid
	var surface := is_instance_valid(liquid) and liquid.is_water()
	var submerged := full or (surface and global_position.y - 14 >= liquid.global_position.y)
	if is_swimming():
		if full or (surface and global_position.y > liquid.global_position.y + 12):
			return
		var speed := velocity.y
		if surface and Input.is_action_pressed("player_jump"):
			speed = -get_node("StateMachine/Swimming").rules.surface_jump_speed
			var jump := get_node("StateMachine/Jumping") as PlayerJumpingState
			jump.external_launch_speed = -speed
			state_machine.switch(PlayerJumpingState)
			EnemyEffect.play_once(sub_area, liquid.rules.water_splash_sprite,
					Vector2(global_position.x, liquid.global_position.y - 26), liquid.rules.splash_fps, false)
		else:
			state_machine.switch(PlayerFallingState)
		velocity.y = speed
	elif submerged:
		if surface:
			EnemyEffect.play_once(sub_area, liquid.rules.water_splash_sprite,
					Vector2(global_position.x, liquid.global_position.y - 26), liquid.rules.splash_fps, false)
		state_machine.switch(PlayerSwimmingState)


func freeze_in_ice() -> bool:
	if is_dead() or is_frozen() or has_star() or invulnerability_left > 0 or level.status != Level.Status.PLAYING:
		return false
	state_machine.switch(PlayerFrozenState, true)
	return true


func stun_from_landing() -> bool:
	if is_dead() or is_frozen() or not is_on_floor() or level.status != Level.Status.PLAYING:
		return false
	if state_machine.current_state is PlayerStunnedState:
		state_machine.current_state.refresh()
		return true
	state_machine.switch(PlayerStunnedState, true)
	return true


## Collects a coin once; loose coins and block coins share scoring/audio.
func collect_coin() -> void:
	coins += 1
	score += 200
	%Coin.play()


## Updates both sizes through the same sprite node, preserving animations.
func set_powerup_sprites(big: bool, animate: bool, skin: StringName = &"") -> void:
	var growing := big and _powerup is SmallPowerup
	var moving := Utility.find_child_by_class(state_machine, PlayerMovingState) as PlayerMovingState
	if moving != null:
		moving.stop_skid()
	Powerup.cancel_animation(sprite)
	var old_sprite: Sprite2D
	if animate:
		# Freeze exactly the displayed pixels. Duplicating AnimatedSprite2D
		# re-runs its idle autoplay when added, but retains the walking origin
		# (16px vs 32px canvases), shifting the outgoing image by 8px.
		old_sprite = Sprite2D.new()
		old_sprite.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		old_sprite.centered = sprite.centered
		old_sprite.offset = sprite.offset
		old_sprite.transform = sprite.transform
		old_sprite.flip_h = sprite.flip_h
		old_sprite.flip_v = sprite.flip_v
		old_sprite.modulate = sprite.modulate
		old_sprite.self_modulate = sprite.self_modulate
		old_sprite.texture_filter = sprite.texture_filter
		old_sprite.material = sprite.material
		sprite.add_sibling(old_sprite)
	var animation := sprite.animation
	if crouching or (big and growth_crouched):
		animation = &"hold_duck" if held_item != null else &"duck"
	var old_frame := sprite.frame
	var old_progress := sprite.frame_progress
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://resources/content/smw_player_sprites.json"))
	_sprite_mapping = catalog[String(skin) if not skin.is_empty() else "super" if big else "small"]
	var frames := SpriteLibrary.get_animations(_sprite_mapping)
	if frames == null:
		_sprite_mapping = {}
		sprite.sprite_frames = load("res://textures/styles/smw/entities/player/mario/%s.tres" % ("super" if big else "small"))
		sprite.centered = true
		sprite.offset = Vector2.ZERO
		sprite.position = Vector2(0, -15)
	else:
		sprite.sprite_frames = frames
		sprite.centered = false
		sprite.position = Vector2.ZERO
	sprite.play(animation if sprite.sprite_frames.has_animation(animation) else &"idle")
	sprite.set_frame_and_progress(mini(old_frame, sprite.sprite_frames.get_frame_count(sprite.animation) - 1), old_progress)
	_update_sprite_origin()
	if animate:
		Powerup.default_animate(get_tree(), old_sprite, sprite, growing)


## Shares one distance-based cadence across acceleration, running and coasting.
func play_ground_animation(animation: StringName) -> void:
	sprite.play(animation)
	var fps := minf(absf(velocity.x) / animation_rules.pixels_per_frame, animation_rules.max_locomotion_fps)
	sprite.speed_scale = fps / sprite.sprite_frames.get_animation_speed(animation)


## Grow upward from the same feet, retaining the small mask until there is room.
func set_powerup_hitbox(big: bool) -> void:
	growth_crouched = big and not crouching and not _can_expand_hitbox()
	var box := SMALL_DUCK_HITBOX_SIZE if not big and crouching \
			else SMALL_HITBOX_SIZE if crouching or growth_crouched or not big else BIG_HITBOX_SIZE
	var collider: CollisionShape2D = $CollShape
	if collider.position != box.position or collider.shape.size != box.size:
		collider.position = box.position
		collider.shape.size = box.size


func _can_expand_hitbox() -> bool:
	return _has_hitbox_room(BIG_HITBOX_SIZE)


func _has_hitbox_room(box: Rect2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var rectangle := RectangleShape2D.new()
	# Exclude the floor contact and safe margin from the standing-room query.
	rectangle.size = box.size - Vector2(0.2, 0.2)
	query.shape = rectangle
	query.transform = global_transform.translated_local(box.position)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body: CollisionObject2D = hit.collider
		var owner_id := body.shape_find_owner(hit.shape)
		var shape_owner := body.shape_owner_get_owner(owner_id) as CollisionShape2D
		# Growing upward passes through the underside of native one-way platforms.
		if shape_owner == null or not shape_owner.one_way_collision:
			return false
	return true


## Both voluntary ducking and forced low-ceiling growth use crouching art.
func is_ducking() -> bool:
	return crouching or growth_crouched


func slope_direction() -> float:
	if not is_on_floor():
		return 0
	var normal := get_floor_normal()
	return signf(normal.x) if absf(normal.x) > 0.1 else 0.0


func slope_slide_check() -> bool:
	return slope_direction() != 0 and Input.is_action_pressed("player_down") and not Input.is_action_pressed("player_up") \
			and held_item == null and not growth_crouched


func _update_crouch() -> void:
	if is_dead() or is_frozen() or state_machine.current_state is PlayerStunnedState \
			or level.status != Level.Status.PLAYING:
		return
	var before := crouching
	if is_on_floor() and Input.is_action_pressed("player_down"):
		crouching = true
	elif crouching and not Input.is_action_pressed("player_down") \
			and (is_on_floor() or velocity.y > 0):
		# Release during a crouch jump takes effect while descending. A solid
		# ceiling retains the smaller mask until Mario can actually stand.
		crouching = not _has_hitbox_room(SMALL_HITBOX_SIZE if _powerup is SmallPowerup else BIG_HITBOX_SIZE)
	if crouching or before or growth_crouched:
		set_powerup_hitbox(not _powerup is SmallPowerup)


func _update_sprite_origin() -> void:
	if _sprite_mapping.has(String(sprite.animation)):
		var sprite_name: String = _sprite_mapping[String(sprite.animation)][0]
		# GameMaker draws Mario at y + 1, including the SMW goal sequence.
		# Convert its 32px top-origin canvas to feet, retaining that 1px
		# overlap with the floor. Frozen/dead Mario's separate Draw omits +1.
		# Do not trim the source's walking poses.
		sprite.offset = -SpriteLibrary.get_origin(sprite_name) - Vector2(0, 32 if is_frozen() or is_dead() else 31)


## Sets the player's current [Powerup]. If [param animate] is [code]false[/code],
## the powering up animation will not be played.
func set_powerup(powerup: Powerup, animate := true) -> void:
	_powerup.end()
	powerup.player = self
	powerup.start(animate)
	_powerup = powerup


## Gets the player's current [Powerup].
func get_powerup() -> Powerup:
	return _powerup


func has_helmet() -> bool:
	return is_instance_valid(_helmet) and _helmet.active


func has_star() -> bool:
	return is_instance_valid(_star) and _star.active()


func collect_star() -> void:
	_star.collect()


func star_hit(body: Node2D) -> bool:
	return _star.hit(body) if has_star() else false


func equip_buzzy_helmet() -> bool:
	return equip_shell_helmet()


func equip_shell_helmet(rules: HelmetRules = null) -> bool:
	if has_helmet() or is_dead() or is_frozen() or level.status != Level.Status.PLAYING:
		return false
	if not is_instance_valid(_helmet):
		return false
	_helmet.activate(rules if rules != null else preload("res://resources/content/smw_helmet_rules.tres"))
	return true


func get_helmet_goal_animation() -> StringName:
	return _helmet.rules.goal_animation if has_helmet() else &"goal"


func helmet_deflects(enemy: Entity, previous_bottom := INF) -> bool:
	return has_helmet() and _helmet.deflect(enemy, previous_bottom)


func helmet_shields(enemy: Entity, previous_bottom := INF) -> bool:
	return has_helmet() and _helmet.shields(enemy, previous_bottom)


## Gives the player an item to hold. This is equivalent to setting [member
## held_item] to [param item].
func give_item(item: Entity) -> void:
	if item != null and (is_dead() or is_frozen() or state_machine.current_state is PlayerStunnedState):
		return
	if held_item == item:
		return
	var pickup: PickupComponent
	if held_item != null:
		stop_held_item_turn()
		pickup = Utility.find_child_by_class(held_item, PickupComponent)
		if pickup != null:
			held_item.reparent.call_deferred(get_parent())
			var release_type
			if Input.is_action_pressed("player_down"):
				release_type = PickupComponent.ReleaseType.DROPPED
			elif Input.is_action_pressed("player_up"):
				release_type = PickupComponent.ReleaseType.THROWN_UP
			else:
				release_type = PickupComponent.ReleaseType.KICKED
			var old_item = held_item
			held_item.z_index = _held_z
			_held_item = null
			pickup.dropped.emit.call_deferred(self, release_type)
			item_dropped.emit.call_deferred(old_item)
		if item == null:
			return
	pickup = Utility.find_child_by_class(item, PickupComponent)
	if pickup == null:
		push_warning("Given item does not have PickupComponent, cannot give.")
		return
	if not pickup.can_be_held:
		push_warning("Can't hold this item.")
		return
	if pickup.pickup_immunity_left > 0:
		return
	_held_item = item
	if item.get_parent() == null:
		add_child(item)
	else:
		item.reparent.call_deferred(self)
	# Align after deferred reparenting too. A continuous state such as swimming
	# has no new start() call to place an item picked up during that state.
	item.set_deferred("position", Vector2(HELD_ITEM_OFFSET.x * direction, HELD_ITEM_OFFSET.y))
	_held_z = held_item.z_index
	held_item.z_index = GameConstants.Layers.Z_AFTER_PLAYER
	pickup.picked_up.emit.call_deferred(self)
	item_given.emit.call_deferred()


## Drops whatever item the player is currently holding. This is different from
## setting [member held_item] to [code]null[/code] as it returns the dropped
## item. The release type ([enum PickupComponent.ReleaseType]) depends on what
## actions the player is currently executing.
func drop_item() -> Entity:
	var item = held_item
	held_item = null
	return item


## obj_holdparent/Step_2 and obj_enemyparent_held/Step_2 release their item
## on freezing or stun. No normal throw event or kick animation is invoked.
func detach_held_item(release_type := PickupComponent.ReleaseType.DETACHED) -> Entity:
	var item := held_item
	if item == null:
		return null
	stop_held_item_turn()
	_held_item = null
	item.z_index = _held_z
	_finish_held_item_detach.call_deferred(item, sub_area._runtime_revision, release_type)
	return item


func _finish_held_item_detach(item: Entity, revision: int, release_type: PickupComponent.ReleaseType) -> void:
	if not is_instance_valid(item):
		return
	# A retry can remove this player before collision callbacks are flushed.
	# Reparenting then would rescue its old item into the new runtime.
	if not is_inside_tree() or is_queued_for_deletion() or revision != sub_area._runtime_revision:
		item.queue_free()
		return
	item.reparent(sub_area.get_foreground())
	# Collision events can freeze Mario in the same step as a Sledge impact.
	# The source hold parent sees the replacement and takes its no-Mario branch.
	if is_frozen() or is_dead():
		release_type = PickupComponent.ReleaseType.DETACHED
	elif release_type == PickupComponent.ReleaseType.STUNNED:
		item.position.y -= 1
	var pickup: PickupComponent = Utility.find_child_by_class(item, PickupComponent)
	if pickup != null:
		pickup.dropped.emit(self, release_type)


func stop_held_item_turn() -> void:
	if held_item_tween != null:
		held_item_tween.kill()
		held_item_tween = null


## A carried shield can be consumed without running its normal throw action.
func forget_held_item(item: Entity) -> void:
	if _held_item == item:
		_held_item = null


## Spawns the spin thump effect at [param position] in global coordinates, at
## the player's feet by default.
func spawn_spin_thump(pos := global_position) -> void:
	var spin_thump = preload("uid://clqrm38rakunb").instantiate()
	spin_thump.position = sub_area.get_foreground().to_local(pos)
	sub_area.add_deferred(spin_thump)


## Used in the state machine to determine whether it can change to another
## animation.
func can_change_sprite() -> bool:
	return not (sprite.animation == &"kick" and sprite.is_playing())


func _just_collided(collision: KinematicCollision2D) -> void:
	var coll = collision.get_collider()
	if collision.get_normal().y == 1 and \
			(coll is CollisionObject2D and coll.collision_layer == 1):
		sounds.stream = preload("uid://7ec5u6l30bgt")
		sounds.play()


func _attempt_correction(delta: float, amount: int) -> void:
	if velocity.y < 0 and test_move(
			global_transform, Vector2(0, velocity.y * delta)):
		for i in range(1, amount * 2 + 1):
			for j in [-1.0, 1.0]:
				if not test_move(global_transform.translated(
						Vector2(i * j / 2, 0)), Vector2(0, velocity.y * delta)):
					position += Vector2(i * j / 2, 0)
					if velocity.x * j / 2 < 0:
						velocity.x = 0
					return
