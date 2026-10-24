# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SkidSmoke
extends Node2D
## The supplied SMM2 clip shows a filled puff with a fast attack, followed by
## shrinking separate lobes. Keep white interiors opaque; only edges use AA.

var _age := 0.0
var direction := 1.0
var body_size := 0.18
var lifetime := LIFETIME
var _puff_material: ShaderMaterial
const LIFETIME := 0.30
const PEAK := 0.045


func _ready() -> void:
	_puff_material = ShaderMaterial.new()
	_puff_material.shader = preload("res://shaders/skid_smoke.gdshader")
	material = _puff_material
	_update_envelope()
	queue_redraw()


func _process(delta: float) -> void:
	if WorldDeath.active_for(self):
		return
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_update_envelope()


func _update_envelope() -> void:
	var visual_age := _age * LIFETIME / lifetime
	body_size = lerpf(0.18, 1.0, smoothstep(0, PEAK, visual_age)) * (1.0 - smoothstep(0.07, LIFETIME, visual_age))
	_puff_material.set_shader_parameter(&"body_size", body_size)
	_puff_material.set_shader_parameter(&"age", visual_age)
	_puff_material.set_shader_parameter(&"direction", direction)


func _draw() -> void:
	# Effects do not cast the world's pixel shadow onto themselves.
	draw_rect(Rect2(-9, -8, 18, 10), Color.WHITE)
