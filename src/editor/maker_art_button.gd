@tool
class_name MakerArtButton
extends Button
## 原图负责外观，Button 负责焦点、信号和命中；尺寸仍在场景中调整。

@export var art: Texture2D:
	set(value):
		art = value
		_sync_art_view()
@export_file("*.png", "*.svg") var art_path: String = "":
	set(value):
		art_path = value
		art = EditorCatalog.load_optional(value)
@export var plate: Texture2D
@export var pressed_plate: Texture2D
@export var selected_pin: bool = false
@export var hover_corners: bool = true
var pointer_hovered: bool = false


func _ready() -> void:
	_sync_art_view()
	resized.connect(_redraw)
	toggled.connect(func(_value: bool) -> void: _redraw())
	mouse_entered.connect(func() -> void: pointer_hovered = true; _redraw())
	mouse_exited.connect(func() -> void: pointer_hovered = false; _redraw())


func artwork_rect() -> Rect2:
	var view: TextureRect = get_node_or_null("ArtView") as TextureRect
	return view.get_rect() if view != null else Rect2()


func _sync_art_view() -> void:
	var view: TextureRect = get_node_or_null("ArtView") as TextureRect
	if view != null:
		view.texture = art
	# Layout and material belong to the saved child; never overwrite them here.
	_redraw()


func _redraw() -> void:
	queue_redraw()
	var feedback: Control = get_node_or_null("Feedback") as Control
	if feedback != null:
		feedback.queue_redraw()


func _draw() -> void:
	var backing: Texture2D = pressed_plate if button_pressed and pressed_plate != null else plate
	if backing != null:
		draw_texture_rect(backing, Rect2(Vector2.ZERO, size), false)
