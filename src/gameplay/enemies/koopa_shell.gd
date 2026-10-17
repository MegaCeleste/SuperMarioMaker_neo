class_name KoopaShell
extends Enemy
@export_enum("green", "red", "buzzy", "spiny") var shell_kind: String = "green"
var occupant: String = ""
var recovery_left: int = 0
var protection_left: int = 0
var carried_by: Player
var carryable: ICarryable
var _entered_targets: Dictionary = {}
var _slide_target: float = 132.0
var flipped: bool = false
var eject_on_recovery: bool = false
var _high_throw: bool = false

func _config_section() -> String:
	return "shell"

func _visual_group() -> String:
	return "shell_" + shell_kind

func _movement_animation() -> StringName:
	return &"slide"

func _ready() -> void:
	super._ready()
	add_to_group("entity_shells")
	_transition(State.STUNNED)
	carryable = ICarryable.new()
	carryable.name = "Carryable"
	carryable.picked_up.connect(_picked_up)
	carryable.thrown.connect(_thrown)
	carryable.dropped.connect(_dropped)
	add_child(carryable)

func is_empty_stationary() -> bool:
	return occupant.is_empty() and state == State.STUNNED and absf(velocity.x) < 1.0

func enter_koopa(kind: String) -> bool:
	if not is_empty_stationary() or shell_kind != kind:
		return false
	occupant = kind
	recovery_left = int(_config["enter_red_frames"] if kind == "red" else _config["enter_green_frames"])
	return true

func _picked_up(by: Node2D) -> void:
	carried_by = by as Player
	_transition(State.HELD)
	carryable.pickup_enabled = false
	_render(0.0)

func _thrown(launch: Vector2) -> void:
	var from_hand: bool = state == State.HELD
	_transition(State.THROWN)
	carryable.pickup_enabled = false
	velocity = launch
	_high_throw = is_zero_approx(launch.x)
	if _high_throw and from_hand:
		velocity.y = float(_config["throw_up_initial"])
	if not is_zero_approx(launch.x):
		dir = signf(launch.x)
		var inherited: float = absf(carried_by.velocity.x) / 2.0 if is_instance_valid(carried_by) else 0.0
		_slide_target = minf(float(_config["held_slide_cap"]), float(_config["held_slide_speed"]) if from_hand and is_zero_approx(inherited) else float(_config["slide_speed"]) + inherited)
		velocity.x = dir * ((float(_config["slide_speed"]) if from_hand and inherited > 0.0 else float(_config["kick_initial"])) + inherited)
	protection_left = int(_config["kick_protection_frames"])
	collision_layer = CollisionConfig.layer("projectiles")
	_entered_targets.clear()

func _dropped() -> void:
	_transition(State.STUNNED)
	carryable.pickup_enabled = true
	collision_layer = CollisionConfig.layer("enemies")
	_entered_targets.clear()

func side_contact(player: Player, wants_carry: bool) -> bool:
	if state != State.STUNNED or (wants_carry and player.has_ability("carry")):
		return false
	carried_by = player
	_thrown(Vector2(player.motion.facing * float(_config["slide_speed"]), 0.0))
	return true

func can_damage_player() -> bool:
	return state == State.THROWN and protection_left == 0

func receive_hit(request: EntityHit) -> EntityHitResult:
	if is_dead or state == State.HELD:
		return EntityHitResult.new()
	if request.kind == EntityHit.Kind.FIREBALL and shell_kind == "buzzy":
		return EntityHitResult.new(false, true)
	if request.kind in [EntityHit.Kind.EXPLOSION, EntityHit.Kind.THROWN] and shell_kind == "buzzy" and not occupant.is_empty():
		return EntityHitResult.new()
	if request.kind == EntityHit.Kind.STOMP:
		if state == State.THROWN:
			velocity.x = 0.0
			_dropped()
		else:
			carried_by = request.player
			_thrown(Vector2(request.direction * float(_config["slide_speed"]), 0.0))
		return EntityHitResult.new(true, false, EntityHitResult.Bounce.NORMAL)
	if request.kind == EntityHit.Kind.BUMP:
		velocity.y = float(_config["bump_initial"])
		return EntityHitResult.new(true)
	return super.receive_hit(request)

func _physics_process(delta: float) -> void:
	var previous: Vector2 = global_position
	super._physics_process(delta)
	if state != State.THROWN or is_queued_for_deletion():
		return
	if is_on_wall():
		dir *= -1.0
		velocity.x = dir * _slide_target
		for index: int in get_slide_collision_count():
			var collision: KinematicCollision2D = get_slide_collision(index)
			if absf(collision.get_normal().x) > 0.5 and collision.get_collider() is InteractableBlock:
				(collision.get_collider() as InteractableBlock).hit_by_attack(EntityHit.new(EntityHit.Kind.SHELL, self, carried_by, dir))
	var touching: Dictionary = {}
	for target: Enemy in EntitySpawn.swept_enemies(self, previous):
		var id: int = target.get_instance_id()
		touching[id] = true
		if not _entered_targets.has(id):
			target.receive_hit(EntityHit.new(EntityHit.Kind.SHELL, self, carried_by, dir))
			if target is KoopaShell:
				die()
				break
	_entered_targets = touching

func _process_state(_delta: float) -> void:
	protection_left = maxi(0, protection_left - 1)
	if state == State.THROWN:
		if _high_throw and is_on_floor() and velocity.y >= 0.0:
			velocity.x = 0.0
			_dropped()
		elif not _high_throw and not is_zero_approx(velocity.x):
			velocity.x = move_toward(velocity.x, dir * _slide_target, float(_config["slide_accel"]) * _delta)
		elif is_on_floor():
			_dropped()
	# Source moving shells use obj_shell_held without the stationary wake alarms.
	if state != State.STUNNED or occupant.is_empty():
		return
	recovery_left = maxi(0, recovery_left - 1)
	if recovery_left == 0 and EntitySpawn.fits(self, 26.0 if occupant in ["green", "red"] and not eject_on_recovery else 14.0):
		var path: String = "res://src/gameplay/enemies/koopa.tscn"
		if occupant in ["buzzy", "spiny"]:
			path = "res://src/gameplay/enemies/%s.tscn" % ("buzzy_beetle" if occupant == "buzzy" else "spiny")
		elif eject_on_recovery:
			path = "res://src/gameplay/enemies/naked_koopa.tscn"
		EntitySpawn.enemy(path, get_parent(), feet_position(), {"start_direction":int(dir)} if occupant in ["buzzy", "spiny"] else {"color": occupant, "start_direction": int(dir)})
		if eject_on_recovery:
			occupant = ""
			flipped = false
			eject_on_recovery = false
			return
		retire()

func _render(delta: float) -> void:
	super._render(delta)
	if not is_dead:
		sprite.flip_v = flipped
	if not is_dead and not occupant.is_empty() and sprite.sprite_frames.has_animation(&"inside"):
		sprite.animation = &"inside"
		sprite.frame = (_state_frames / 10) % sprite.sprite_frames.get_frame_count(&"inside")

func die() -> void:
	if carryable != null:
		carryable.pickup_enabled = false
	super.die()
