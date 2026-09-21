class_name Shell
extends Entity

@onready var _sprite: AnimatedSprite2D = $Graphics/Sprite
@onready var pickup_component: PickupComponent = Utility.find_child_by_class(
		self, PickupComponent)

const SPEED = 200.0

var _prev_was_moving := false
var _damage_cooldown := 0.0


func _ready() -> void:
	_sprite.stop()
	_sprite.frame = 0
	pickup_component.dropped.connect(_on_dropped)


func _on_dropped(_release_type: int) -> void:
	# Shell kicks straight horizontally, no upward arc
	velocity.y = 0


func _physics_process(_delta: float) -> void:
	super(_delta)
	if pickup_component.held:
		velocity = Vector2.ZERO
		_sprite.stop()
		_sprite.frame = 0
		_prev_was_moving = false
		return
	if _damage_cooldown > 0:
		_damage_cooldown -= _delta
	move_and_slide()
	# Bounce off walls (always reverse at full speed)
	if is_on_wall():
		var dir = -signf(velocity.x)
		if dir == 0:
			dir = 1 if randf() > 0.5 else -1
		velocity.x = dir * SPEED
	# Maintain constant speed, no decay
	if is_on_floor() and absf(velocity.x) > 0.1:
		velocity.x = signf(velocity.x) * SPEED
	# Detect kick (transition from stationary to moving)
	var is_moving := absf(velocity.x) > 0.1
	if is_moving and not _prev_was_moving:
		_sprite.play(&"kick")
		UISoundPlayer.stream = preload("uid://c345xnns7om3m")
		UISoundPlayer.play()
		_damage_cooldown = 0.3
	elif is_moving and not _sprite.is_playing():
		_sprite.play(&"spin")
	elif not is_moving:
		if _sprite.is_playing():
			_sprite.stop()
			_sprite.frame = 0
	_prev_was_moving = is_moving
	
	# Disable pickup while spinning
	if pickup_component != null:
		pickup_component.can_be_held = not is_moving
	
	# --- Spinning shell interactions ---
	if not is_moving:
		return
	
	var hit_something := false
	
	# 1. Damage/kill anything in HurtArea
	for body in $HurtArea.get_overlapping_bodies():
		if body.is_queued_for_deletion():
			continue
		# Kill enemies (koopa, galoomba, beach_koopa, etc.)
		if body is Enemy:
			body.killed_by_shell = true
			body.kill()
			break
		# Hit another shell
		if body is Shell and body != self:
			var other_moving = absf(body.velocity.x) > 0.1
			if other_moving:
				# Both are spinning → both die
				body.queue_free()
				hit_something = true
				break
			else:
				# Other is stationary → kill it, we keep going
				body.queue_free()
				break
	
	# If we hit something, also destroy this shell
	if hit_something:
		# Spawn a dead entity effect
		var graphics = $Graphics.duplicate() as Node2D
		graphics.global_position = $Graphics.global_position
		graphics.name = "DeadEntity"
		graphics.z_index = GameConstants.Layers.Z_DEAD
		graphics.z_as_relative = false
		graphics.set_script(preload("res://scripts/other/dead_entity.gd"))
		graphics.velocity = Vector2(60 * -sign(velocity.x), -200)
		add_sibling(graphics)
		queue_free()
		return
	
	# 2. Check player overlap (only if shell was already moving, not on initial kick)
	if _prev_was_moving and _damage_cooldown <= 0:
		for body in $CheckArea.get_overlapping_bodies():
			var player = body as Player
			if player == null:
				continue
			# Check if player is stomping from above
			var p_shape = Utility.find_child_by_class(player, CollisionShape2D) as CollisionShape2D
			var s_shape = Utility.find_child_by_class(self, CollisionShape2D) as CollisionShape2D
			if p_shape == null or s_shape == null:
				continue
			var p_rect = p_shape.shape.get_rect()
			p_rect.position += p_shape.global_position
			var s_rect = s_shape.shape.get_rect()
			s_rect.position += s_shape.global_position
			if p_rect.end.y < s_rect.position.y + 12:
				# Player stomped from above → stop shell with full stomp effects
				velocity.x = 0
				player.velocity.y = -player.stomp_bounce_speed
				var spin_thump = preload("uid://clqrm38rakunb").instantiate()
				if player.state_machine.current_state is PlayerJumpingState or player.state_machine.current_state is PlayerFallingState:
					player.state_machine.switch(PlayerJumpingState)
				elif player.state_machine.current_state is PlayerSpinJumpingState:
					player.state_machine.switch(PlayerSpinJumpingState)
				player.sounds.stream = preload("uid://c345xnns7om3m")
				player.sounds.play()
				call_deferred("add_sibling", spin_thump)
				spin_thump.global_position = player.global_position
			else:
				# Player hit from side → damage
				player.damage()
				_damage_cooldown = 0.5
