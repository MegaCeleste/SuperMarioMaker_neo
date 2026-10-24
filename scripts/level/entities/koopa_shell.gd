# SPDX-License-Identifier: AGPL-3.0-or-later
class_name KoopaShell
extends Enemy
## SMW's stationary, moving and carried shell states share one native body.

enum Motion { STATIONARY, MOVING, CARRIED, CEILING_DROP }

@export var variant: ShellVariant = preload("res://resources/content/smw_koopa_green.tres")
@export var inverted := false
var physics: ShellPhysics = preload("res://resources/content/smw_shell_physics.tres")
var motion := Motion.STATIONARY
var _target_velocity := 0.0
var _grace := 0.25
var _entry_left := -1.0
var _throw_up := false
var _combo := 0
var _credit: Player
var _sprite_name: StringName
var _consumed := false
var _recovery_left := -1.0
var _shake_angle := 0.0
var _shake_direction := -1.0
var _warning_left := 0.0
var _recoiling_player_id := 0
var facing_direction := -1


func _ready() -> void:
	super()
	fireproof = variant.fireproof
	var shape := RectangleShape2D.new()
	shape.size = Vector2(variant.mask_width, variant.mask_height)
	for path in ["CollShape", "PlayerArea/CollShape", "EnemyArea/CollShape"]:
		get_node(path).shape = shape
		get_node(path).position.y = -variant.mask_height / 2
	if variant.recovery_time > 0 and motion == Motion.STATIONARY:
		_recovery_left = variant.recovery_time
		_warning_left = variant.recovery_time - variant.warning_time
	$GravityComponent.set_physics_process(false)
	$GravityComponent.max_fall_speed = physics.fall_speed
	%PickupComponent.use_default_behavior = false
	%PickupComponent.picked_up.connect(_picked_up)
	%PickupComponent.dropped.connect(_dropped)
	$EnemyArea.body_entered.connect(_hit_enemy)
	_update_sprite()
	_update_pickup()


func _physics_process(delta: float) -> void:
	if _consumed:
		return
	_grace = maxf(0, _grace - delta)
	_update_pickup()
	if _recovery_left >= 0 and motion in [Motion.STATIONARY, Motion.CARRIED]:
		_recovery_left -= delta
		if _recovery_left <= _warning_left:
			_shake_angle += _shake_direction * 300 * delta
			if absf(_shake_angle) >= 10:
				_shake_angle = clampf(_shake_angle, -10, 10)
				_shake_direction *= -1
			%Sprite.rotation_degrees = _shake_angle
		if _recovery_left <= 0:
			_restore_koopa()
			return
	if _entry_left >= 0:
		_entry_left -= delta
		%Sprite.frame = 1 if _entry_left > variant.reentry_time - 11.0 / 60 else 0
		%Sprite.rotation = deg_to_rad(10 * sin(_entry_left * 60))
		if _entry_left <= 0:
			_restore_koopa()
			return
	if source_death_stopped():
		super(delta)
	if motion != Motion.CARRIED and not source_death_stopped():
		# obj_holdparent uses .15/frame; obj_shell_held inherits .2/frame.
		$GravityComponent.gravity.y = physics.enemy_gravity if motion in [Motion.MOVING, Motion.CEILING_DROP] else physics.idle_shell_gravity
		$GravityComponent._physics_process(delta)
		# The reference stores a signed spd. Its left launches keep their
		# initial speed; retain that behavior rather than normalizing the sign.
		if motion == Motion.MOVING:
			if velocity.x > 0 and velocity.x < _target_velocity:
				velocity.x = minf(_target_velocity, velocity.x + physics.acceleration * delta)
			elif velocity.x < 0 and velocity.x > -_target_velocity:
				velocity.x = maxf(-_target_velocity, velocity.x - physics.acceleration * delta)
		var before_x := velocity.x
		super(delta)
		if is_queued_for_deletion():
			return
		for index in get_slide_collision_count():
			var hit := get_slide_collision(index)
			if hit.get_normal().x != 0 and motion == Motion.MOVING:
				velocity.x = -before_x
				_bump_block(hit.get_collider())
			elif hit.get_normal().y > 0 and _throw_up:
				_bump_block(hit.get_collider())
		if is_on_floor():
			if motion == Motion.CEILING_DROP:
				motion = Motion.MOVING
				velocity.x = -150 if level.hud.player.global_position.x < global_position.x else 150
				_target_velocity = 150
				_grace = 0
				_update_sprite()
			_throw_up = false
			if motion == Motion.STATIONARY:
				velocity.x = move_toward(velocity.x, 0, physics.eject_deceleration * delta)
	elif motion == Motion.CARRIED:
		velocity = Vector2.ZERO
		var holder: Player = %PickupComponent.get_holder()
		if variant.wearable and holder != null and holder.is_on_floor() \
				and Input.is_action_pressed("player_down") and _wear(holder):
			return
	for body in $EnemyArea.get_overlapping_bodies():
		_hit_enemy(body)
		if _consumed:
			return
	for body in hitbox.get_overlapping_bodies():
		if body is Player:
			_touch_player(body)


func _body_handling(entering: bool, body: Node2D) -> void:
	if entering and body is Player:
		_touch_player(body)


func _touch_player(player: Player) -> void:
	if _consumed or _grace > 0 or player.is_dead() or player.is_frozen() or level.status != Level.Status.PLAYING \
			or player.held_item == self or %PickupComponent.get_holder() != null:
		return
	if player.has_star():
		player.star_hit(self)
		return
	if player.get_instance_id() == _recoiling_player_id:
		# Physics overlap lists can retain the departing player for another tick.
		if player.velocity.y < 0:
			return
		_recoiling_player_id = 0
	if motion == Motion.STATIONARY and Input.is_action_pressed("player_run") and player.held_item == null:
		player.give_item(self)
		return
	var player_bounds := Utility.get_bounding_box(player)
	player_bounds.position += player.previous_position - player.global_position
	if variant.wearable and velocity.y >= 0 and motion == Motion.STATIONARY \
			and Utility.get_bounding_box(self).end.y < player_bounds.position.y + 5 and _wear(player):
		return
	if player.helmet_deflects(self):
		return
	var previous := Utility.get_bounding_box(player)
	previous.position += player.previous_position - player.global_position
	var top := Utility.get_bounding_box(self).position.y
	var above := player.velocity.y > 0 and previous.end.y <= top + 15
	if above and variant.spiked_top and not inverted:
		if player.state_machine.current_state is PlayerSpinJumpingState:
			player.bounce()
			player.spawn_spin_thump()
			_recoiling_player_id = player.get_instance_id()
		else:
			player.damage()
		return
	if above and player.state_machine.current_state is PlayerSpinJumpingState:
		player.bounce()
		player.score += 200
		_spin_stomp()
		return
	if motion == Motion.MOVING and above:
		player.bounce()
		motion = Motion.STATIONARY
		velocity.x = 0
		_target_velocity = 0
		_grace = 0.2
		if variant.recovery_time > 0:
			_recovery_left = variant.stopped_recovery_time
			_warning_left = variant.stopped_recovery_time - variant.warning_time
		_update_sprite()
		return
	if motion == Motion.STATIONARY:
		if above:
			player.bounce()
		launch(player, false)
	elif motion == Motion.CEILING_DROP and above:
		player.bounce()
	elif motion in [Motion.MOVING, Motion.CEILING_DROP]:
		var shield := player.held_item as KoopaShell
		if shield != null and Utility.get_bounding_box(shield).intersects(Utility.get_bounding_box(self)):
			shield.kill(signf(velocity.x))
			kill(-signf(velocity.x))
		else:
			player.damage()


## obj_shell collision and release events choose different starting speeds.
func launch(player: Player, from_hand := false) -> void:
	var direction := player.direction if from_hand else (1 if player.global_position.x < global_position.x else -1)
	var moving := not is_zero_approx(player.velocity.x)
	var initial := physics.kick_idle_speed
	var target := physics.kick_idle_target
	if moving:
		initial = physics.release_base_speed + absf(player.velocity.x) / 2 if from_hand \
				else physics.kick_base_speed + (player.velocity.x / 2 if direction > 0 else absf(player.velocity.x) / 2)
		target = minf(physics.target_limit, physics.release_base_speed + absf(player.velocity.x) / 2)
	motion = Motion.MOVING
	facing_direction = direction
	_credit = player
	_combo = 0
	_target_velocity = target * direction
	velocity.x = initial * direction
	velocity.y = 6 if from_hand else velocity.y
	_grace = physics.launch_immunity if from_hand else 0.2
	_entry_left = -1
	_throw_up = false
	_recovery_left = -1
	_shake_angle = 0
	_shake_direction = -1
	%Sprite.rotation = 0
	_update_sprite()
	_update_pickup()


func _picked_up(player: Player) -> void:
	motion = Motion.CARRIED
	_credit = player
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	_update_sprite()


func _dropped(player: Player, release_type: PickupComponent.ReleaseType) -> void:
	if _consumed:
		return
	set_deferred("collision_layer", 2)
	if release_type == PickupComponent.ReleaseType.DETACHED:
		motion = Motion.STATIONARY
		_grace = 0
		_throw_up = false
		velocity = Vector2.ZERO
		_update_sprite()
	elif release_type == PickupComponent.ReleaseType.STUNNED:
		motion = Motion.STATIONARY
		_grace = physics.launch_immunity
		_throw_up = false
		velocity = Vector2(60 * player.direction, 0)
		_update_sprite()
	elif release_type == PickupComponent.ReleaseType.KICKED:
		launch(player, true)
	else:
		motion = Motion.STATIONARY
		_credit = player
		_grace = physics.launch_immunity
		_throw_up = release_type == PickupComponent.ReleaseType.THROWN_UP
		velocity = Vector2(physics.throw_horizontal_speed * player.direction if not is_zero_approx(player.velocity.x) else 0,
			-physics.throw_up_speed) if _throw_up else Vector2(physics.dropped_speed * player.direction, 0)
		_update_sprite()


func _hit_enemy(body: Node2D) -> void:
	if body is StompedGaloomba and not body.is_queued_for_deletion() and not _consumed \
			and not is_queued_for_deletion() and not source_death_stopped():
		var holder: Player = %PickupComponent.get_holder()
		if motion == Motion.MOVING or holder != null or (_throw_up and velocity.y < 0):
			body.kill(holder.direction if holder != null else signf(velocity.x))
			if holder != null: kill(-holder.direction)
		return
	if body == self or _consumed or is_queued_for_deletion() or not body is Enemy or body.is_queued_for_deletion():
		return
	# obj_shell_held requires hspeed != 0 for ordinary enemy hits. Its separate
	# shell-pair collision remains valid even after the central death stop.
	if source_death_stopped() and not body is KoopaShell:
		return
	if body is BeachKoopa and not body.is_walking():
		return
	var holder: Player = %PickupComponent.get_holder()
	if motion != Motion.MOVING and holder == null and not (_throw_up and velocity.y < 0):
		return
	var direction := holder.direction if holder != null else int(signf(velocity.x))
	if body is KoopaShell:
		var destroy_self: bool = holder != null or body.motion == Motion.MOVING
		body.kill(direction)
		if destroy_self:
			kill(-direction)
		return
	if body.hit_by_actor(&"shell", self, direction):
		_award_combo()
	if holder != null:
		kill(-direction)


func _award_combo() -> void:
	var player := _credit if is_instance_valid(_credit) else level.hud.player
	if not is_instance_valid(player) or player.is_dead() or level.status != Level.Status.PLAYING:
		return
	if _combo < physics.combo_scores.size():
		player.score += physics.combo_scores[_combo]
	else:
		player.extra_lives += 1
	_combo += 1


func _bump_block(body: Object) -> void:
	var block: BlockComponent = Utility.find_child_by_class(body, BlockComponent)
	if block != null:
		block.activate(self, Vector2.UP)


func begin_entry(entering: KoopaVariant) -> bool:
	if not variant is KoopaVariant or _consumed or motion != Motion.STATIONARY or _entry_left >= 0 or entering.id != variant.id:
		return false
	_entry_left = variant.reentry_time
	velocity = Vector2.ZERO
	_update_sprite()
	return true


func _restore_koopa() -> void:
	_consumed = true
	_forget_holder()
	if variant.restore_scene.is_empty():
		queue_free()
		return
	var koopa: Enemy = load(variant.restore_scene).instantiate()
	koopa.variant = variant
	koopa.get_node("SlideComponent").direction = facing_direction
	koopa.position = sub_area.get_foreground().to_local(global_position)
	sub_area.add_deferred(koopa)
	queue_free()


func kill(launch_direction := 0.0) -> void:
	if _consumed:
		return
	_consumed = true
	_forget_holder()
	super(launch_direction)


func _forget_holder() -> void:
	var holder: Player = %PickupComponent.get_holder()
	if holder != null:
		holder.forget_held_item(self)


func _wear(player: Player) -> bool:
	if not player.equip_shell_helmet(variant.helmet_rules):
		return false
	_consumed = true
	_forget_holder()
	queue_free()
	return true


func get_defeat_sprite() -> StringName:
	return variant.dead_sprite


func _update_pickup() -> void:
	%PickupComponent.can_be_held = motion == Motion.STATIONARY and _grace == 0 and not _consumed


func _update_sprite() -> void:
	if not is_node_ready():
		return
	var name: StringName = variant.inside_sprite if _entry_left >= 0 else variant.shell_sprite
	if name != _sprite_name:
		_sprite_name = name
		SpriteLibrary.configure_sprite(%Sprite, name, &"shell", 12, Vector2(0, -16))
		if SpriteLibrary.has_sprite(name):
			%Sprite.material = SpriteLibrary.ROTATION_MATERIAL
	%Sprite.flip_v = inverted
	%Sprite.position.y = SpriteLibrary.contact_draw_y(name, 0, false, inverted)
	if motion == Motion.MOVING:
		%Sprite.play("shell")
	else:
		%Sprite.stop()
		%Sprite.frame = 0
