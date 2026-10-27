# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SpinSmoke
extends AnimatedSprite2D

const _LENGTH = 4/15.0
const _STAR = preload("uid://dhfplan3lkxas")

var _progress := 0.0
var _tween: Tween
var star_size: float:
	get:
		var age := _progress * _LENGTH
		return lerpf(0.2, 1.0, smoothstep(0, 0.055, age)) * (1.0 - smoothstep(0.075, _LENGTH, age))
var _smoke_finished := false


static func create() -> SpinSmoke:
	return preload("uid://i6qiojuqmpnm").instantiate()


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	z_index = GameConstants.Layers.Z_PARTICLES
	animation_finished.connect(func(): _smoke_finished = true)
	_tween = create_tween()
	_tween.tween_property(self, "_progress", 1, _LENGTH)


func _process(_delta: float) -> void:
	if not _tween.is_running() and not %Sound.playing and _smoke_finished:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if _progress >= 1:
		return
	var size := _STAR.get_size() * star_size
	for x in range(-32, 33, 64):
		for y in range(-16, 17, 32):
			var center := Vector2(x, y) * _progress
			draw_texture_rect(_STAR, Rect2(center - size / 2, size), false)
