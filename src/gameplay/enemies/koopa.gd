class_name Koopa
extends Enemy
@export_enum("green", "red") var color: String = "green"
var _eject_direction: float = -1.0

func _config_section() -> String:
	return "koopa"

func _visual_group() -> String:
	return "koopa_" + color

func _process_state(_delta: float) -> void:
	if color == "red" and state == State.WALKING and is_on_floor() and not has_floor_ahead():
		dir *= -1.0

func stomp(spinning: bool) -> void:
	if is_dead:
		return
	if spinning:
		spin_defeat()
		return
	var feet: Vector2 = feet_position()
	EntitySpawn.enemy("res://src/gameplay/enemies/koopa_shell.tscn", get_parent(), feet, {"shell_kind": color})
	var naked: NakedKoopa = EntitySpawn.enemy("res://src/gameplay/enemies/naked_koopa.tscn", get_parent(), feet, {"color": color}) as NakedKoopa
	naked.eject(_eject_direction)
	retire()

func receive_hit(request: EntityHit) -> EntityHitResult:
	_eject_direction = request.direction
	if is_instance_valid(request.player) and not is_equal_approx(request.player.global_position.x, global_position.x):
		_eject_direction = signf(global_position.x - request.player.global_position.x)
	return super.receive_hit(request)

func bumped() -> void:
	if is_dead:
		return
	var shell: KoopaShell = EntitySpawn.enemy("res://src/gameplay/enemies/koopa_shell.tscn", get_parent(), feet_position(), {"shell_kind":color}) as KoopaShell
	shell.occupant = color
	shell.flipped = true
	shell.eject_on_recovery = true
	shell.recovery_left = int(shell._config["bump_recovery_frames"])
	shell.velocity = Vector2(_eject_direction * 30.0, float(shell._config["bump_initial"]))
	retire()
