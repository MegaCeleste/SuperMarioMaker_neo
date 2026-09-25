extends State

const DUST_VFX = preload("res://src/vfx/skid_smoke.tscn")

var skid_timer: float = 0.0
var vfx_timer := 0.0
const VFX_COOLDOWN := 0.1

func enter() -> void:
	player.animated_sprite.play("skid")
	player.animated_sprite.flip_h = player.velocity.x > 0
	player.animated_sprite.speed_scale = 1.0
	player.skid_sound.play()
	skid_timer = 0.0

	vfx_timer = VFX_COOLDOWN # 立即生成一个特效


func exit() -> void:
	player.skid_sound.stop()



func physics_update(delta: float) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.ground_acceleration * delta * 2.0)
	skid_timer += delta

	vfx_timer += delta # 特效计时

	if vfx_timer >= VFX_COOLDOWN:
		vfx_timer = 0.0
		var dust = DUST_VFX.instantiate()
		dust.position = player.position + Vector2(0, 15)
		dust.animation_finished.connect(dust.queue_free)

		player.get_tree().current_scene.add_child(dust)

	var dir := Input.get_axis("move_left", "move_right")

	if dir != 0 and sign(dir) == sign(player.velocity.x): # 如果玩家输入的方向与当前滑行方向相同，提前结束滑行状态
		state_machine.change_state(state_machine.run)
		return

	if not player.is_on_floor():
		state_machine.change_state(state_machine.air)
		return

	if Input.is_action_just_pressed("jump"):
		player.velocity.y = player.JUMP_VELOCITY
		player.jump_sound.play()
		state_machine.change_state(state_machine.air)
		return

	if skid_timer >= 0.5 or abs(player.velocity.x) == 0:
		if Input.is_action_just_pressed("move_down"):
			state_machine.change_state(state_machine.duck)
		elif dir != 0:
			state_machine.change_state(state_machine.run)
		else:
			state_machine.change_state(state_machine.idle)
		return
