class_name BobOmb
extends Enemy
var fuse: BombFuse
var carryable: ICarryable
var primed: bool = false
var carried_by: Player

func _config_section() -> String:
	return "bob_omb"

func _visual_group() -> String:
	return "bob_omb"

func _ready() -> void:
	super._ready()
	carryable = ICarryable.new()
	carryable.name = "Carryable"
	carryable.pickup_enabled = false
	carryable.picked_up.connect(_picked_up)
	carryable.thrown.connect(_thrown)
	carryable.dropped.connect(_dropped)
	add_child(carryable)
	fuse = BombFuse.new()
	fuse.expired.connect(_explode)
	fuse.ticked.connect(_fuse_tick)
	add_child(fuse)

func ignite() -> void:
	if primed or is_dead:
		return
	primed = true
	fuse.ignite(int(_config["fuse_frames"]))
	_transition(State.STUNNED)
	velocity.x = 0.0
	carryable.pickup_enabled = true
	_render(0.0)

func _fuse_tick(remaining: int) -> void:
	if is_dead:
		return
	sprite.modulate = Color(1.0, 0.5, 0.3) if remaining < 60 and (remaining / 4) % 2 == 0 else Color.WHITE

func _picked_up(by: Node2D) -> void:
	carried_by = by as Player
	_transition(State.HELD)
	carryable.pickup_enabled = false
	_render(0.0)

func _thrown(launch: Vector2) -> void:
	var from_hand: bool = state == State.HELD
	_transition(State.THROWN)
	velocity = launch
	if from_hand:
		if is_zero_approx(launch.x):
			velocity.y = float(_config["throw_up_initial"])
		else:
			var inherited: float = absf(carried_by.velocity.x) if is_instance_valid(carried_by) else 0.0
			velocity = Vector2(signf(launch.x) * (float(_config["throw_speed"]) + inherited), float(_config["throw_lift"]))
	carryable.pickup_enabled = false
	if not is_zero_approx(launch.x):
		dir = signf(launch.x)

func _dropped() -> void:
	_transition(State.STUNNED)
	carryable.pickup_enabled = true

func side_contact(player: Player, wants_carry: bool) -> bool:
	if state != State.STUNNED or (wants_carry and player.has_ability("carry")):
		return false
	carried_by = player
	_thrown(Vector2(player.motion.facing * float(_config["kick_speed"]), 0.0))
	return true

func can_damage_player() -> bool:
	return not primed and state == State.WALKING

func receive_hit(request: EntityHit) -> EntityHitResult:
	if is_dead:
		return EntityHitResult.new()
	if request.kind in [EntityHit.Kind.STOMP, EntityHit.Kind.SPIN, EntityHit.Kind.FIREBALL, EntityHit.Kind.BUMP]:
		if state == State.HELD:
			return EntityHitResult.new()
		var was_primed: bool = primed
		ignite()
		if request.kind == EntityHit.Kind.FIREBALL and was_primed:
			dir = request.direction
			velocity = Vector2(dir * float(_config["fireball_push"]), float(_config["fireball_lift"]))
		elif request.kind == EntityHit.Kind.BUMP:
			velocity.y = float(_config["bump_initial"])
		if request.kind in [EntityHit.Kind.STOMP, EntityHit.Kind.SPIN] and state == State.THROWN:
			_dropped()
			velocity.x = 0.0
		return EntityHitResult.new(true, request.kind == EntityHit.Kind.FIREBALL, EntityHitResult.Bounce.NORMAL if request.kind in [EntityHit.Kind.STOMP, EntityHit.Kind.SPIN] else EntityHitResult.Bounce.NONE)
	return super.receive_hit(request)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.THROWN and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, float(_config["friction"]) * delta)
		if absf(velocity.x) < 1.0:
			_dropped()

func _render(delta: float) -> void:
	super._render(delta)
	if primed and not is_dead:
		sprite.animation = &"primed"
		sprite.frame = floori(_animation_phase) % sprite.sprite_frames.get_frame_count(&"primed")

func _explode() -> void:
	if is_dead or is_queued_for_deletion():
		return
	var held_player: Player = carried_by if is_instance_valid(carried_by) and carryable.is_carried else null
	if held_player != null and held_player.carry.is_carrying():
		carried_by.carry.drop(Vector2.ZERO)
	var explosion: EntityExplosion = EntityExplosion.new()
	explosion.attacker = carried_by
	explosion.held_player = held_player
	explosion.position = position
	get_parent().add_child(explosion)
	retire()

func die() -> void:
	if fuse != null:
		fuse.remaining = 0
	if carryable != null:
		carryable.pickup_enabled = false
	super.die()
