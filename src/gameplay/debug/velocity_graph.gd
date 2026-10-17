extends Control

const SAMPLE_COUNT: int = 300
const HORIZONTAL_COLOR: Color = Color(0.28, 0.85, 0.95)
const VERTICAL_COLOR: Color = Color(1.0, 0.65, 0.3)
const AXIS_COLOR: Color = Color(0.42, 0.47, 0.53)

var speed_limit: float = 1.0
var show_second_curve: bool = true
var _first: PackedFloat32Array = PackedFloat32Array()
var _second: PackedFloat32Array = PackedFloat32Array()


func push_sample(first: float, second: float = 0.0) -> void:
	_first.append(first)
	_second.append(second)
	if _first.size() > SAMPLE_COUNT:
		_first.remove_at(0)
		_second.remove_at(0)
	queue_redraw()


func clear() -> void:
	_first.clear()
	_second.clear()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.09, 0.13), true)
	var middle: float = size.y / 2.0
	draw_line(Vector2(0.0, middle), Vector2(size.x, middle), AXIS_COLOR)
	_draw_curve(_first, HORIZONTAL_COLOR)
	if show_second_curve:
		_draw_curve(_second, VERTICAL_COLOR)


func _draw_curve(samples: PackedFloat32Array, color: Color) -> void:
	if samples.size() < 2:
		return
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in samples.size():
		var x: float = float(index) / float(SAMPLE_COUNT - 1) * size.x
		var y: float = size.y / 2.0 - clampf(samples[index] / maxf(speed_limit, 1.0), -1.0, 1.0) * (size.y / 2.0 - 4.0)
		points.append(Vector2(x, y))
	draw_polyline(points, color, 2.0)
