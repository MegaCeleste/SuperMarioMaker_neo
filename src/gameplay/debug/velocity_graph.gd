extends Control

const SAMPLE_COUNT := 300  # Five seconds at REQ-ARC-003's 60 Hz.
const GRAPH_COLOR := Color(0.28, 0.85, 0.95)
const AXIS_COLOR := Color(0.42, 0.47, 0.53)

var speed_limit: float = 216.0
var _samples: PackedFloat32Array = PackedFloat32Array()


func push_sample(speed: float) -> void:
	_samples.append(speed)
	if _samples.size() > SAMPLE_COUNT:
		_samples.remove_at(0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.09, 0.13), true)
	var midpoint: float = size.y / 2.0
	draw_line(Vector2(0.0, midpoint), Vector2(size.x, midpoint), AXIS_COLOR)
	if _samples.size() < 2:
		return
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in _samples.size():
		var x: float = float(index) / float(SAMPLE_COUNT - 1) * size.x
		var y: float = midpoint - clampf(_samples[index] / speed_limit, -1.0, 1.0) * (midpoint - 4.0)
		points.append(Vector2(x, y))
	draw_polyline(points, GRAPH_COLOR, 2.0)
