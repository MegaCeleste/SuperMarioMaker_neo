# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SpinThump
extends Node2D
## Continuous contact flash, centered on the impact rather than on a moving foot.

const TEXTURE = preload("res://textures/spin_thump.png")
const LIFETIME := 4.0 / 21
var _age := 0.0
var pulse_size := 0.2


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	_update_size()


func _update_size() -> void:
	pulse_size = lerpf(0.2, 1.0, smoothstep(0, 0.05, _age)) * (1.0 - smoothstep(0.065, LIFETIME, _age))
	queue_redraw()


func _draw() -> void:
	# Use the full-size white frame; an envelope replaces the four abrupt sizes.
	var size := Vector2(19, 19) * pulse_size
	draw_texture_rect_region(TEXTURE, Rect2(-size / 2, size), Rect2(38, 0, 19, 19))
