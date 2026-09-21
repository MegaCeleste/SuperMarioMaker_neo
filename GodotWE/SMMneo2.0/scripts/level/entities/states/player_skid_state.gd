class_name PlayerSkidState
extends State
## Provides skidding/braking behavior to the player.

var skid_timer := 0.0
var vfx_timer := 0.0
var _smoke_scene: PackedScene

const VFX_COOLDOWN := 0.1


func _init() -> void:
	intended_class = Player


func start(entity: Node2D) -> Variant:
	var player = entity as Player
	player.kick_anim_timer = 0
	if player._held_item != null and player.sprite.sprite_frames.has_animation("walk_hold"):
		player.sprite.play("walk_hold")
	else:
		player.sprite.play("skid")
	player.sprite.speed_scale = 1.0
	player.sprite.flip_h = player.velocity.x > 0
	
	player.sounds.stream = preload("uid://vxfegf1r2emq")
	player.sounds.play()
	
	skid_timer = 0.0
	vfx_timer = VFX_COOLDOWN  # 立即生成一个特效
	_smoke_scene = preload("uid://bde0tltjb5047")
	return


func end(entity: Node2D) -> void:
	var player = entity as Player
	player.sounds.stop()
	player.sprite.speed_scale = 1.0


func physics_process(entity: Node2D, delta: float) -> Variant:
	var player = entity as Player
	
	if player.global_position.y > player.VOID_LEVEL:
		return PlayerDeathState
	
	# 刹车减速（两倍于普通减速度）
	player.velocity.x = move_toward(
		player.velocity.x, 0.0, player.skid_deceleration
	)
	skid_timer += delta
	
	# 刹车烟雾特效
	vfx_timer += delta
	if vfx_timer >= VFX_COOLDOWN:
		vfx_timer = 0.0
		var dust = _smoke_scene.instantiate()
		dust.position = player.position + Vector2(0, 2)
		player.get_tree().current_scene.add_child(dust)
	
	var dir := Input.get_axis("player_left", "player_right")
	
	# 如果玩家输入的方向与当前滑行方向相同 → 结束刹车
	if dir != 0 and sign(dir) == sign(player.velocity.x):
		return PlayerMovingState
	
	if not player.is_on_floor():
		return PlayerFallingState
	
	if Input.is_action_just_pressed("player_jump"):
		player.velocity.y = -player.idle_jump_speed
		return PlayerJumpingState
	
	# 刹车结束条件（时间到或速度归零）
	if skid_timer >= 0.5 or abs(player.velocity.x) == 0:
		if Input.is_action_pressed("player_duck"):
			return PlayerDuckState
		elif dir != 0:
			return PlayerMovingState
		else:
			return PlayerIdleState
	
	return
