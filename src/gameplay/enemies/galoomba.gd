class_name Galoomba
extends Enemy
## REQ-PWR-015.

var _carryable: ICarryable
var _attack_area: Area2D
var _recovery_left: int = 0
var _contacts: Array[Enemy] = []
var _carried_by: Player


func _config_section() -> String:
	return "galoomba"


func _visual_group() -> String:
	return "galoomba"


func _render(delta: float) -> void:
	super._render(delta)
	# The owner-selected SMW pose uses the original walking art upside down.
	sprite.flip_v = state in [State.STUNNED, State.HELD, State.THROWN, State.DEAD]


func _ready() -> void:
	super._ready()
	_carryable = ICarryable.new()
	_carryable.name = "Carryable"
	_carryable.pickup_enabled = false
	_carryable.picked_up.connect(_on_picked_up)
	_carryable.thrown.connect(_on_thrown)
	_carryable.dropped.connect(_on_dropped)
	add_child(_carryable)
	_attack_area = Area2D.new()
	_attack_area.name = "AttackArea"
	_attack_area.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	_attack_area.collision_layer = CollisionConfig.layer("sensors")
	_attack_area.collision_mask = CollisionConfig.mask(["enemies", "projectiles"])
	_attack_area.monitoring = false
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = physics_shape.shape.duplicate()
	_attack_area.add_child(shape)
	_attack_area.body_entered.connect(_on_attack_contact)
	add_child(_attack_area)


func stomp(spinning: bool) -> void:
	if is_dead or state == State.HELD:
		return
	if spinning:
		spin_defeat()
		return
	_stun()


func bumped() -> void:
	if not is_dead and state != State.HELD:
		_stun()
		velocity.y = float(_config["bump_initial"])


func _stun() -> void:
	_transition(State.STUNNED)
	_recovery_left = int(_config["recovery_frames"])
	velocity.x = 0.0
	collision_layer = CollisionConfig.layer("enemies")
	_carryable.pickup_enabled = true
	_attack_area.monitoring = false
	_render(0.0)


func side_contact(player: Player, wants_carry: bool) -> bool:
	if state != State.STUNNED or (wants_carry and player.has_ability("carry")):
		return false
	_on_thrown(Vector2(player.motion.facing * (float(_config["throw_speed"]) + absf(player.velocity.x)), float(_config["throw_lift"])))
	return true


func _on_picked_up(by: Node2D) -> void:
	_carried_by = by as Player
	_transition(State.HELD)
	_carryable.pickup_enabled = false
	_render(0.0)


func _on_thrown(launch: Vector2) -> void:
	var from_hand: bool = state == State.HELD
	_transition(State.THROWN)
	_carryable.pickup_enabled = false
	velocity = launch
	if from_hand:
		if is_zero_approx(launch.x):
			velocity.y = float(_config["throw_up_initial"])
		else:
			var inherited: float = absf(_carried_by.velocity.x) if is_instance_valid(_carried_by) else 0.0
			velocity = Vector2(signf(launch.x) * (float(_config["throw_speed"]) + inherited), float(_config["throw_lift"]))
	if not is_zero_approx(launch.x):
		dir = signf(launch.x)
	collision_layer = CollisionConfig.layer("projectiles")
	_attack_area.monitoring = true
	_render(0.0)


func _on_dropped() -> void:
	_transition(State.STUNNED)
	_carryable.pickup_enabled = true
	collision_layer = CollisionConfig.layer("enemies")
	_attack_area.monitoring = false
	_render(0.0)


func _on_attack_contact(body: Node2D) -> void:
	if body is Enemy and body != self:
		_contacts.append(body as Enemy)


func _process_state(delta: float) -> void:
	if state == State.THROWN:
		for target: Enemy in _contacts:
			if is_instance_valid(target) and not target.is_dead:
				var response: EntityHitResult = target.receive_hit(EntityHit.new(EntityHit.Kind.THROWN, self, null, dir))
				if response.affected:
					die()
					break
	_contacts.clear()
	if state not in [State.STUNNED, State.THROWN]:
		return
	_recovery_left = maxi(0, _recovery_left - 1)
	if state == State.THROWN and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, float(_config.get("friction", _profile.friction_normal)) * delta)
		if absf(velocity.x) <= _profile.speed_epsilon:
			_on_dropped()
	if _recovery_left == 0:
		_transition(State.WALKING)
		_carryable.pickup_enabled = false
		collision_layer = CollisionConfig.layer("enemies")
		_attack_area.monitoring = false


func die() -> void:
	if is_dead:
		return
	if _carryable != null:
		_carryable.pickup_enabled = false
	if _attack_area != null:
		_attack_area.set_deferred("monitoring", false)
	super.die()
