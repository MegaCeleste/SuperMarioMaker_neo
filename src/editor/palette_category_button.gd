@tool
class_name PaletteCategoryButton
extends MakerArtButton
## The selected category grows into a pill; the HBoxContainer moves its peers.

@export var category_color: Color = Color("cf47de")
@export var label_key: String = "MAKER_ITEMS"


func _ready() -> void:
	hover_corners = false
	super._ready()
	toggled.connect(_update_width)
	_update_width(button_pressed)


func _update_width(selected: bool) -> void:
	custom_minimum_size = Vector2(600 if selected else 108, 108)
	queue_redraw()


func _draw() -> void:
	var backing: StyleBoxFlat = StyleBoxFlat.new()
	backing.bg_color = category_color
	backing.set_corner_radius_all(54)
	draw_style_box(backing, Rect2(Vector2.ZERO, size))
	if button_pressed:
		draw_string(get_theme_font("font", "MakerPaletteTitle"), Vector2(130, 74), tr(label_key), HORIZONTAL_ALIGNMENT_CENTER, size.x - 190, 50, Color("5d1c1c"))
