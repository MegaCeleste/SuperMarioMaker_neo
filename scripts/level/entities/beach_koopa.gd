# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BeachKoopa
extends Enemy
## SMW's ejected Koopa slides, waits, then walks and can hop into its shell.

enum Phase { SLIDING, WAITING, WALKING }

@export var variant: KoopaVariant = preload("res://resources/content/smw_koopa_green.tres")
var physics: ShellPhysics = preload("res://resources/content/smw_shell_physics.tres")
var direction := -1
var phase := Phase.SLIDING
var _age := 0.0
var _wait := 0.0
var _jumping := false


func _ready() -> void:
	super()
	$GravityComponent.set_physics_process(false)
	$GravityComponent.gravity.y = physics.enemy_gravity
	$GravityComponent.max_fall_speed = physics.fall_speed
	$SlideComponent.set_physics_process(false)
	SpriteLibrary.configure_sprite(%Sprite, variant.beach_sprite, &"crawl", 9, Vector2(0, -16))
	%Sprite.position.y = SpriteLibrary.contact_draw_y(variant.beach_sprite)
	%Sprite.stop()
	%Sprite.flip_h = direction < 0


func _physics_process(delta: float) -> void:
	_age += delta
	$GravityComponent._physics_process(delta)
	if phase == Phase.SLIDING:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, physics.eject_deceleration * delta)
		if is_zero_approx(velocity.x):
			phase = Phase.WAITING
			_wait = physics.beach_wait
			%Sprite.play(&"crawl")
	elif phase == Phase.WAITING:
		_wait -= delta
		if _wait <= 0:
			phase = Phase.WALKING
			velocity.y = -physics.beach_hop
			velocity.x = 30 * direction
			$SlideComponent.direction = direction
			$SlideComponent.avoid_ledges = variant.avoid_ledges
			SpriteLibrary.configure_sprite(%Sprite, variant.beach_walk_sprite, &"walk", 9, Vector2(0, -16))
			%Sprite.position.y = SpriteLibrary.contact_draw_y(variant.beach_walk_sprite)
	elif phase == Phase.WALKING:
		$SlideComponent._physics_process(delta)
		direction = $SlideComponent.direction
		_seek_shell()
		if is_queued_for_deletion():
			return
	var old_x := velocity.x
	super(delta)
	if phase == Phase.SLIDING and is_on_wall():
		velocity.x = 0
	elif phase == Phase.WALKING and is_on_wall():
		direction = -int(signf(old_x))
		$SlideComponent.direction = direction
	%Sprite.flip_h = direction < 0
	# Area entry can happen during eject immunity. Check the lingering contact
	# when that immunity expires, as the source collision event does each tick.
	if phase != Phase.WALKING and _age >= physics.eject_invulnerability:
		for body in hitbox.get_overlapping_bodies():
			_body_handling(true, body)


func is_walking() -> bool:
	return phase == Phase.WALKING


func _seek_shell() -> void:
	for node in sub_area.get_foreground().get_children():
		var shell := node as KoopaShell
		if shell == null or shell.is_queued_for_deletion() or shell.variant.id != variant.id \
				or shell.motion != KoopaShell.Motion.STATIONARY:
			continue
		var offset := shell.global_position - global_position
		if not _jumping and is_on_floor() and offset.x * direction > 0 and absf(offset.x) < 20 and absf(offset.y) < 8:
			velocity.y = -physics.reentry_hop
			_jumping = true
		if _jumping and velocity.y > 0 and absf(offset.x) < 12 and absf(offset.y) < 14:
			if shell.begin_entry(variant):
				queue_free()
				return
	if _jumping and is_on_floor() and velocity.y >= 0:
		_jumping = false


func _body_handling(entering: bool, body: Node2D) -> void:
	if body is Player and body.has_star():
		body.star_hit(self)
		return
	if not body is Player or body.is_frozen() or _age < physics.eject_invulnerability or is_queued_for_deletion():
		return
	if phase != Phase.WALKING:
		var previous := Utility.get_bounding_box(body)
		previous.position += body.previous_position - body.global_position
		if previous.end.y > Utility.get_bounding_box(self).position.y + 5:
			body.score += 200
			kill(body.direction)
			return
	super(entering, body)


func _stomped(player: Player) -> void:
	if is_queued_for_deletion():
		return
	super(player)
	player.score += 200
	if is_queued_for_deletion():
		return
	# obj_stomped holds the flattened, colour-specific sprite for 30 ticks.
	var flat := SpriteLibrary.make_sprite(variant.beach_stomp_sprite)
	flat.stop()
	flat.position = sub_area.get_foreground().to_local(global_position - Vector2(0, 16))
	flat.flip_h = direction < 0
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = true
	timer.autostart = true
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	timer.timeout.connect(flat.queue_free)
	flat.add_child(timer)
	sub_area.add_deferred(flat)
	queue_free()


func get_defeat_sprite() -> StringName:
	return variant.beach_walk_dead_sprite if is_walking() else variant.beach_crawl_dead_sprite
