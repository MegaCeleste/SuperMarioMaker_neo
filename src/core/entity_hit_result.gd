class_name EntityHitResult
extends RefCounted
enum Bounce { NONE, NORMAL, SAFE_SPIN }
var affected: bool
var consume_attack: bool
var bounce: Bounce

func _init(applied: bool = false, consumed: bool = false, rebound: Bounce = Bounce.NONE) -> void:
	affected = applied
	consume_attack = consumed
	bounce = rebound
