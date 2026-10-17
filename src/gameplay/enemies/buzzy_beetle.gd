class_name BuzzyBeetle
extends Enemy

func _config_section() -> String:
	return "buzzy"

func _visual_group() -> String:
	return "buzzy"

func receive_hit(request: EntityHit) -> EntityHitResult:
	if request.kind == EntityHit.Kind.FIREBALL:
		return EntityHitResult.new(false, true)
	return super.receive_hit(request)

func stomp(spinning: bool) -> void:
	if spinning:
		spin_defeat()
		return
	var shell: KoopaShell = EntitySpawn.enemy("res://src/gameplay/enemies/koopa_shell.tscn", get_parent(), feet_position(), {"shell_kind": "buzzy"}) as KoopaShell
	shell.occupant = "buzzy"
	shell.recovery_left = int(_config["recovery_frames"])
	retire()

func bumped() -> void:
	if is_dead:
		return
	var shell: KoopaShell = EntitySpawn.enemy("res://src/gameplay/enemies/koopa_shell.tscn", get_parent(), feet_position(), {"shell_kind":"buzzy"}) as KoopaShell
	shell.occupant = "buzzy"
	shell.flipped = true
	shell.recovery_left = int(shell._config["bump_recovery_frames"])
	shell.velocity = Vector2(dir * 15.0, -90.0)
	retire()
