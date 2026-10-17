class_name Enemy
extends CharacterBody2D
## REQ-PHYS-121/123. Contacts are queued and states advance in physics.

signal state_changed(previous: State, current: State)
signal defeated(enemy: Enemy)

enum State { WALKING, STUNNED, HELD, THROWN, SQUASHED, DEAD }

@export_enum("Left:-1", "Right:1") var start_direction: int = -1
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var physics_shape: CollisionShape2D = $PhysicsShape
@onready var stomp_area: Area2D = $StompArea
@onready var hurt_area: Area2D = $HurtArea

var state: State:
	get: return _state
	set(_value): push_error("Enemy state is owned by transition methods.")
var is_dead: bool:
	get: return _state == State.SQUASHED or _state == State.DEAD
var dir: float = -1.0
var speed: float = 0.0
var _state: State = State.WALKING
var _config: Dictionary = {}
var _profile: PlayerPhysicsProfile = preload("res://data/physics/base_physics.tres")
var _state_frames: int = 0
var _animation_phase: float = 0.0


func _ready() -> void:
	_config = PrototypeEntityConfig.actor(_config_section())
	speed = float(_config["speed"])
	dir = float(start_direction)
	collision_layer = CollisionConfig.layer("enemies")
	collision_mask = CollisionConfig.mask(["solids", "semisolids"])
	_set_shape(physics_shape, _config["body_size"] as Array)
	var offset: Array = _config["body_offset"] as Array
	physics_shape.position = Vector2(float(offset[0]), float(offset[1]))
	_set_shape(stomp_area.get_node("CollisionShape2D") as CollisionShape2D, _config["stomp_size"] as Array)
	stomp_area.position.y = float(_config["stomp_y"])
	_set_shape(hurt_area.get_node("CollisionShape2D") as CollisionShape2D, _config["hurt_size"] as Array)
	stomp_area.collision_layer = CollisionConfig.layer("sensors")
	stomp_area.collision_mask = CollisionConfig.layer("player")
	hurt_area.collision_layer = CollisionConfig.layer("sensors")
	hurt_area.collision_mask = CollisionConfig.layer("sensors")
	stomp_area.body_entered.connect(_on_stomp_area_entered)
	hurt_area.area_entered.connect(_on_hurt_area_entered)
	hurt_area.area_exited.connect(_on_hurt_area_exited)
	BasicSpriteLibrary.apply(sprite, _visual_group())
	add_child(GameplayFreezeGate.new())
	_render(0.0)


func _config_section() -> String:
	return "enemy"


func receive_hit(request: EntityHit) -> EntityHitResult:
	if is_dead or state == State.HELD:
		return EntityHitResult.new()
	match request.kind:
		EntityHit.Kind.STOMP, EntityHit.Kind.SPIN:
			stomp(request.kind == EntityHit.Kind.SPIN)
			return EntityHitResult.new(true, false, EntityHitResult.Bounce.NORMAL)
		EntityHit.Kind.BUMP:
			bumped()
		_:
			die()
	return EntityHitResult.new(true, request.kind == EntityHit.Kind.FIREBALL)


func feet_position() -> Vector2:
	var rectangle: RectangleShape2D = physics_shape.shape as RectangleShape2D
	return physics_shape.global_position + Vector2(0.0, rectangle.size.y / 2.0)


func retire() -> void:
	_state = State.DEAD
	_disable_interactions()
	queue_free()


func has_floor_ahead() -> bool:
	var feet: Vector2 = feet_position()
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(feet + Vector2(dir * 9.0, -2.0), feet + Vector2(dir * 9.0, 5.0), CollisionConfig.mask(["solids", "semisolids"]), [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _visual_group() -> String:
	return "goomba"


func _movement_animation() -> StringName:
	return &"walk"


func _set_shape(node: CollisionShape2D, dimensions: Array) -> void:
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(float(dimensions[0]), float(dimensions[1]))
	node.shape = rectangle


func _physics_process(delta: float) -> void:
	_state_frames += 1
	_process_state(delta)
	if is_queued_for_deletion():
		return
	if state == State.HELD:
		return
	if state == State.SQUASHED:
		if _state_frames >= int(_config["squash_frames"]):
			queue_free()
	else:
		velocity.y = minf(velocity.y, float(_config.get("max_fall", 240.0))) + float(_config["gravity"]) * delta
		if state == State.WALKING:
			velocity.x = dir * speed
		elif state == State.STUNNED:
			velocity.x = move_toward(velocity.x, 0.0, float(_config.get("friction", _profile.friction_normal)) * delta)
		move_and_slide()
		if is_on_wall() and state == State.WALKING:
			dir *= -1.0
	_render(delta)
	if global_position.y > float(_config["cleanup_y"]):
		queue_free()


func _process_state(_delta: float) -> void:
	pass


func _render(delta: float) -> void:
	var animation: StringName = _movement_animation()
	if state in [State.STUNNED, State.HELD, State.THROWN]:
		animation = &"stunned"
	elif state == State.SQUASHED:
		animation = &"squashed"
	elif state == State.DEAD:
		animation = &"dead"
	if not sprite.sprite_frames.has_animation(animation):
		animation = _movement_animation()
	sprite.animation = animation
	sprite.pause()
	sprite.flip_h = dir < 0.0
	sprite.flip_v = state == State.DEAD
	sprite.scale = Vector2.ONE
	_animation_phase += sprite.sprite_frames.get_animation_speed(animation) * delta
	var count: int = sprite.sprite_frames.get_frame_count(animation)
	if count > 0:
		sprite.frame = floori(_animation_phase) % count
	sprite.position.y = 0.0
	if state == State.SQUASHED and count > 0:
		var texture: Texture2D = sprite.sprite_frames.get_frame_texture(animation, sprite.frame)
		var rectangle: RectangleShape2D = physics_shape.shape as RectangleShape2D
		var feet: float = physics_shape.position.y + rectangle.size.y / 2.0
		sprite.position.y = feet - (texture.get_height() / 2.0 + sprite.offset.y) * sprite.scale.y


func _transition(next: State) -> void:
	if is_dead or next == _state:
		return
	var previous: State = _state
	_state = next
	_state_frames = 0
	_animation_phase = 0.0
	state_changed.emit(previous, next)


func can_damage_player() -> bool:
	return state == State.WALKING


func can_be_stomped(_spinning: bool = false) -> bool:
	return state in [State.WALKING, State.STUNNED, State.THROWN]


func side_contact(_player: Player, _wants_carry: bool) -> bool:
	return false


func _on_stomp_area_entered(body: Node2D) -> void:
	if not is_dead and body is Player:
		(body as Player).register_stomp_contact(self)


func _on_hurt_area_entered(area: Area2D) -> void:
	var player: Player = area.get_parent() as Player
	if not is_dead and player != null and area == player.hurtbox_area:
		player.register_enemy_overlap(self)


func _on_hurt_area_exited(area: Area2D) -> void:
	var player: Player = area.get_parent() as Player
	if player != null and area == player.hurtbox_area:
		player.unregister_enemy_overlap(self)


func stomp_surface_y() -> float:
	var rectangle: RectangleShape2D = physics_shape.shape as RectangleShape2D
	return physics_shape.global_position.y - rectangle.size.y / 2.0


func stomp(spinning: bool) -> void:
	if spinning:
		spin_defeat()
	else:
		die()


func spin_defeat() -> void:
	if is_dead:
		return
	# Reuse subclass cleanup and the defeated signal, then replace the corpse.
	die()
	velocity = Vector2.ZERO
	visible = false
	set_physics_process(false)
	var effect: Node2D = preload("res://src/gameplay/effects/spin_defeat_effect.gd").new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	queue_free()


func bumped() -> void:
	die()


func _disable_interactions() -> void:
	collision_layer = 0
	collision_mask = 0
	stomp_area.set_deferred("monitoring", false)
	hurt_area.set_deferred("monitoring", false)
	physics_shape.set_deferred("disabled", true)


func die() -> void:
	if is_dead:
		return
	_transition(State.DEAD)
	_disable_interactions()
	velocity = Vector2(0.0, float(_config["death_initial"]))
	defeated.emit(self)
	_render(0.0)
