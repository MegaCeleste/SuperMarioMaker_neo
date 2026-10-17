@tool
extends MakerArtButton

@export var direction: int = 1


func _ready() -> void:
	hover_corners = false
	super._ready()


func _draw() -> void:
	var points: PackedVector2Array = PackedVector2Array([Vector2(5, 5), Vector2(size.x - 5, size.y * 0.5), Vector2(5, size.y - 5)])
	if direction < 0:
		for index: int in points.size():
			points[index].x = size.x - points[index].x
	draw_colored_polygon(points, Color("5d1c1c"))
