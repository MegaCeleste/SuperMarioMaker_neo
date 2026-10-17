class_name PlayerStatusEffects
extends RefCounted
## Temporary effects do not modify the permanent physics profile or power form.
var star_left: int = 0
var star_age: int = 0
const COLORS: Array[Color] = [Color(1, 1, 0.28), Color(1, 0.54, 0.55), Color(0.4, 0.96, 0.62)]

func apply_star() -> void:
	star_left = int(PrototypeEntityConfig.section("star")["duration_frames"])
	star_age = 0

func finish_active_tick() -> void:
	if star_left > 0:
		star_left -= 1
		star_age += 1

func speed_bonus() -> float:
	return float(PrototypeEntityConfig.section("star")["speed_bonus"]) if star_left > 0 else 0.0

func tint() -> Color:
	return COLORS[(star_age / 4) % COLORS.size()]

func reset() -> void:
	star_left = 0
	star_age = 0
