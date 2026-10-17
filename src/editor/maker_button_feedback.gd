@tool
extends Control
## Separate overlay keeps corner/pin feedback above the editable ArtView/CapView.

var _corner: Texture2D = EditorCatalog.load_optional("res://textures/ui/hover.svg")


func _draw() -> void:
	var button: MakerArtButton = get_parent() as MakerArtButton
	if button == null:
		return
	if button.selected_pin and button.button_pressed:
		var point: Vector2 = Vector2(size.x - 5, 10)
		draw_circle(point, 16, Color("df58d3"), true, -1, true)
		draw_line(point + Vector2(-5, 5), point + Vector2(5, -5), Color("79236e"), 4, true)
		draw_line(point + Vector2(0, -7), point + Vector2(7, 0), Color("79236e"), 5, true)
	if button.hover_corners and button.pointer_hovered and _corner != null:
		var bounds: Rect2 = Rect2(Vector2.ONE * -8, size + Vector2.ONE * 16)
		var extent: float = minf(bounds.size.x, bounds.size.y) * 0.18
		var corners: Array[Vector2] = [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]
		for index: int in 4:
			draw_set_transform(corners[index], index * PI * 0.5)
			draw_texture_rect(_corner, Rect2(Vector2.ZERO, Vector2.ONE * extent), false)
		draw_set_transform(Vector2.ZERO)
