# SPDX-License-Identifier: AGPL-3.0-or-later
class_name CurtainTransition
extends CanvasLayer
## Source obj_curtainin: the screen stays black for 15 ticks, then a circle
## centred on the arrival point grows 6px per tick until it passes 300px.
## Drawn as black geometry around the circle, so it needs no shader.

const BLACK_TICKS := 15
const GROWTH := 6.0
const END_RADIUS := 300.0
const ARC_POINTS := 24

var level: Level
## Arrival point in area coordinates.
var target := Vector2.ZERO
var radius := 0.0
var _ticks := 0
var _cover: Control


## Starts a curtain for [param on], replacing one that is still opening.
static func open(on: Level, at: Vector2) -> CurtainTransition:
	var old := on.get_node_or_null(^"CurtainTransition")
	if old != null:
		on.remove_child(old)
		old.queue_free()
	var curtain := CurtainTransition.new()
	curtain.name = "CurtainTransition"
	curtain.level = on
	curtain.target = at
	on.add_child(curtain)
	return curtain


func _ready() -> void:
	layer = 90
	_cover = Control.new()
	_cover.name = "Cover"
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.draw.connect(_draw_cover)
	add_child(_cover)
	level.editing.connect(queue_free)


func _physics_process(_delta: float) -> void:
	_ticks += 1
	if _ticks > BLACK_TICKS:
		radius += GROWTH
	if radius > END_RADIUS:
		queue_free()


func _process(_delta: float) -> void:
	_cover.queue_redraw()


func _draw_cover() -> void:
	var view := _cover.size
	var r := radius * Utility.camera_scale.x
	if r <= 0:
		_cover.draw_rect(Rect2(Vector2.ZERO, view), Color.BLACK)
		return
	var c := level.get_global_transform_with_canvas() * target
	# Everything outside the circle's square, then the square's four corners.
	_cover.draw_rect(Rect2(0, 0, view.x, maxf(0, c.y - r)), Color.BLACK)
	_cover.draw_rect(Rect2(0, c.y + r, view.x, maxf(0, view.y - c.y - r)), Color.BLACK)
	_cover.draw_rect(Rect2(0, c.y - r, maxf(0, c.x - r), r * 2), Color.BLACK)
	_cover.draw_rect(Rect2(c.x + r, c.y - r, maxf(0, view.x - c.x - r), r * 2), Color.BLACK)
	for quarter in 4:
		var start := quarter * PI / 2
		var corner := c + Vector2(cos(start), sin(start)) * r + Vector2(cos(start + PI / 2), sin(start + PI / 2)) * r
		var points := PackedVector2Array([corner])
		for i in ARC_POINTS + 1:
			var angle := start + PI / 2 * i / ARC_POINTS
			points.append(c + Vector2(cos(angle), sin(angle)) * r)
		_cover.draw_colored_polygon(points, Color.BLACK)
