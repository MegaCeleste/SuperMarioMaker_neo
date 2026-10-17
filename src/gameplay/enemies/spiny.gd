class_name Spiny
extends Enemy

func _config_section() -> String:
	return "spiny"

func _visual_group() -> String:
	return "spiny"

func can_be_stomped(spinning: bool = false) -> bool:
	return spinning and not is_dead

func receive_hit(request: EntityHit) -> EntityHitResult:
	if request.kind == EntityHit.Kind.SPIN and not is_dead:
		return EntityHitResult.new(false, false, EntityHitResult.Bounce.SAFE_SPIN)
	if request.kind == EntityHit.Kind.STOMP:
		return EntityHitResult.new()
	return super.receive_hit(request)

func bumped() -> void:
	if is_dead:
		return
	var shell: KoopaShell = EntitySpawn.enemy("res://src/gameplay/enemies/koopa_shell.tscn", get_parent(), feet_position(), {"shell_kind":"spiny"}) as KoopaShell
	shell.occupant = "spiny"
	shell.flipped = true
	shell.recovery_left = int(_config["recovery_frames"])
	shell.velocity = Vector2(dir * 15.0, -90.0)
	retire()
