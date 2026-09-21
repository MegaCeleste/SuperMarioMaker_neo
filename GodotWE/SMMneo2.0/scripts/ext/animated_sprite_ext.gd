class_name AnimatedSpriteExt
extends AnimatedSprite2D
## @deprecated:

## If enabled, a drop shadow child node is created automatically.
@export var cast_shadow := false

var _shadow: AnimatedSprite2D
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
	_shadow = AnimatedSprite2D.new()
	_shadow.name = "Shadow"
	_shadow.sprite_frames = sprite_frames
	_shadow.animation = animation
	_shadow.frame = frame
	_shadow.centered = centered
	_shadow.offset = Vector2(2, 2)
	_shadow.modulate = Color(0, 0, 0, 0.5)
	_shadow.z_index = -1
	_shadow.z_as_relative = false
	_shadow.stop()  # Don't animate independently; follow parent via signals
	add_child(_shadow)

	_last_flip_h = flip_h
	_last_flip_v = flip_v
	_shadow.flip_h = flip_h
	_shadow.flip_v = flip_v

	animation_changed.connect(_on_anim_changed)
	frame_changed.connect(_on_frame_changed)


func _exit_tree() -> void:
	if _shadow != null:
		_shadow.queue_free()
		_shadow = null


func _on_anim_changed() -> void:
	if _shadow != null:
		_shadow.animation = animation
		_shadow.frame = frame  # Sync frame immediately to avoid frame-0 glitch


func _on_frame_changed() -> void:
	if _shadow != null:
		_shadow.frame = frame
