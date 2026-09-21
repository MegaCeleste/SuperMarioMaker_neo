class_name SpriteExt
extends Sprite2D

## If enabled, a drop shadow child node is created automatically.
@export var cast_shadow := false

var _shadow: Sprite2D
var _last_flip_h: bool
var _last_flip_v: bool


func _ready() -> void:
	if cast_shadow:
		_setup_shadow()


func _process(_delta: float) -> void:
	if _shadow == null:
		return
	if flip_h != _last_flip_h:
		_last_flip_h = flip_h
		_shadow.flip_h = flip_h
	if flip_v != _last_flip_v:
		_last_flip_v = flip_v
		_shadow.flip_v = flip_v


func _setup_shadow() -> void:
	_shadow = Sprite2D.new()
	_shadow.name = "Shadow"
	_shadow.texture = texture
	_shadow.centered = centered
	_shadow.offset = Vector2(2, 2)
	_shadow.modulate = Color(0, 0, 0, 0.5)
	_shadow.z_index = -1
	_shadow.z_as_relative = false
	add_child(_shadow)

	_last_flip_h = flip_h
	_last_flip_v = flip_v
	_shadow.flip_h = flip_h
	_shadow.flip_v = flip_v

	texture_changed.connect(_sync_texture)


func _exit_tree() -> void:
	if _shadow != null:
		_shadow.queue_free()
		_shadow = null


func _sync_texture() -> void:
	if _shadow != null:
		_shadow.texture = texture
