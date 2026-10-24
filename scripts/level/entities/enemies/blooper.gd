# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Blooper
extends Enemy
## obj_blooper Step_0, alarms0/1 and its separate underwater contact policy.

enum Phase { WAITING, JETTING, COOLDOWN }

@export var rules: BlooperRules = preload("res://resources/content/smw_blooper.tres")
var phase := Phase.WAITING
var _clock := 0.0
var _gravity_active := false


func _ready() -> void:
	super()
	# Source collisionKind2 is an ellipse, not its enclosing rectangle.
	var polygon := ConvexPolygonShape2D.new()
	var points := PackedVector2Array()
	for index in 32:
		var angle := TAU * index / 32
		points.append(Vector2(cos(angle), sin(angle)) * rules.mask_size / 2)
	polygon.points = points
	for path in ["CollShape", "PlayerArea/CollShape"]:
		get_node(path).shape = polygon
		get_node(path).position = rules.mask_center
	SpriteLibrary.configure_sprite(%Sprite, rules.swim_sprite, &"swim", 0, Vector2(0, -16))
	%Sprite.pause()
	%Sprite.frame = 1
	if sub_area.level_theme == Level.LevelTheme.UNDERWATER:
		stomp_behavior = Stompability.NONE


func _physics_process(delta: float) -> void:
	if phase != Phase.WAITING:
		_clock -= delta
		if _clock <= 0.00001:
			if phase == Phase.JETTING:
				phase = Phase.COOLDOWN
				_clock += rules.cooldown_time
				_gravity_active = true
				velocity = Vector2.ZERO
			else:
				phase = Phase.WAITING
	if phase == Phase.WAITING:
		var player := level.hud.player
		if is_instance_valid(player) and not player.is_dead():
			# GM origins: this instance16px above native feet; Mario32px above.
			var separation := global_position.y - 16 - (player.global_position.y - 32)
			if separation > 0 or (not _gravity_active and separation < 0):
				phase = Phase.JETTING
				_clock = rules.jet_time
				_gravity_active = false
				velocity = Vector2(1 if player.global_position.x > global_position.x else -1, -1).normalized() * rules.jet_speed
		if phase == Phase.WAITING:
			_gravity_active = true
	if _gravity_active:
		velocity.y = minf(rules.sink_speed, velocity.y + rules.sink_gravity * delta)
	super(delta)
	%Sprite.frame = 0 if velocity.y < 0 else 1


func _stomped(player: Player) -> void:
	if is_queued_for_deletion() or player.is_dead():
		return
	if stomp_behavior == Stompability.NONE:
		player.damage()
		return
	super(player)
	player.score += 200
	if not is_queued_for_deletion():
		kill(player.direction)


func bumped_from_below(_activator: PhysicsBody2D) -> void:
	if velocity.y < 0 or is_queued_for_deletion():
		return
	var player := level.hud.player
	if is_instance_valid(player) and not player.is_dead() and level.status == Level.Status.PLAYING:
		player.score += 200
	kill()


func kill(_launch_direction := 0.0) -> void:
	if is_queued_for_deletion():
		return
	var defeat := FloatingEnemyDefeat.new()
	defeat.rules = rules
	defeat.underwater = sub_area.level_theme == Level.LevelTheme.UNDERWATER
	defeat.position = sub_area.get_foreground().to_local(global_position)
	sub_area.add_deferred(defeat)
	queue_free()
