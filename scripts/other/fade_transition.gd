# SPDX-License-Identifier: AGPL-3.0-or-later
class_name FadeTransition
extends CanvasLayer
## A plain fade to black over a set number of ticks, then holds black until it
## is freed. SMM2 pipes fade out like this before the iris opens elsewhere.

var level: Level
var ticks := 26
var _age := 0
var _cover: ColorRect


static func start(on: Level, duration: int) -> FadeTransition:
	var old := on.get_node_or_null(^"FadeTransition")
	if old != null:
		on.remove_child(old)
		old.queue_free()
	var fade := FadeTransition.new()
	fade.name = "FadeTransition"
	fade.level = on
	fade.ticks = maxi(1, duration)
	on.add_child(fade)
	return fade


func _ready() -> void:
	layer = 89
	_cover = ColorRect.new()
	_cover.name = "Cover"
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.color = Color(0, 0, 0, 0)
	add_child(_cover)
	level.editing.connect(queue_free)


func _physics_process(_delta: float) -> void:
	_age = mini(_age + 1, ticks)
	_cover.color.a = float(_age) / ticks


func is_done() -> bool:
	return _age >= ticks
