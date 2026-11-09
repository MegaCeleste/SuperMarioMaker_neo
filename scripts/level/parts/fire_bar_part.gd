# SPDX-License-Identifier: AGPL-3.0-or-later
class_name FireBarPart
extends Part
## Editor Fire Bar (source obj_firebar_res): one base cell. Dragging the end
## ball (source spr_firebar_move) sets the start angle and grows or shrinks
## the bar by 2 fireballs between 4 and 20 (source size_x); the Part window
## also offers 4 to 10 and the clockwise toggle (source direct_t). Saved in
## PLATAFORMAS with the start angle in color; builds a [FireBar].

const LENGTHS = [&"four", &"six", &"eight", &"ten"]
## Source size_x starts at 4 and grows while below size_limit_x + 1 (19).
const MIN_LENGTH := 4
const MAX_LENGTH := 20

var length := 4
var dragging := false
var _drag_before: Dictionary
var clockwise := false
## Source color: the start angle in degrees.
var start_angle := 0.0


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_gizmos.tres")


static func get_part_name(_environment: SubArea) -> String:
	return "Fire Bar"


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return icon_for(4)


static func icon_for(balls: int) -> Texture2D:
	var icon := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	if SpriteLibrary.has_sprite(&"spr_firebar"):
		var base := SpriteLibrary.get_frames(&"spr_firebar_base").get_frame_texture(&"default", 2).get_image()
		var ball := SpriteLibrary.get_frames(&"spr_firebar").get_frame_texture(&"default", 2).get_image()
		base.convert(Image.FORMAT_RGBA8)
		ball.convert(Image.FORMAT_RGBA8)
		var step := 40 / maxi(1, balls - 1)
		icon.blend_rect(base, Rect2i(0, 0, 16, 16), Vector2i(2, 22))
		for i in balls:
			icon.blend_rect(ball, Rect2i(0, 0, 10, 10), Vector2i(5 + i * step, 25))
	return ImageTexture.create_from_image(icon)


static func create() -> FireBarPart:
	return load("res://scenes/level/parts/fire_bar_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_firebar_base").get_frame_texture(&"default", 2)
	queue_redraw()


func _draw() -> void:
	super()
	# Editor preview of the bar at its start angle, like obj_firebar_res Draw.
	if level != null and level.status == Level.Status.EDITING and SpriteLibrary.has_sprite(&"spr_firebar"):
		var ball := SpriteLibrary.get_frames(&"spr_firebar").get_frame_texture(&"default", 2)
		var step := Vector2(cos(deg_to_rad(start_angle)), -sin(deg_to_rad(start_angle))) * 8
		for i in range(1, length):
			draw_texture(ball, Vector2(8, 8) + step * i - Vector2(5, 5), Color(1, 1, 1, 0.7))
		# obj_firebar_res/Draw: the turn button on the base, the move handle
		# on the last ball.
		if not dragging and SpriteLibrary.has_sprite(&"spr_button_change_firebar"):
			var button := _frame(&"spr_button_change_firebar", int(clockwise))
			draw_texture(button, Vector2(8, 8) - button.get_size() / 2)
		if SpriteLibrary.has_sprite(&"spr_firebar_move"):
			var handle := _frame(&"spr_firebar_move", 1 if dragging else 0)
			draw_texture(handle, _handle_offset() - handle.get_size() / 2)
		else:
			draw_arc(_handle_offset(), 6, 0, TAU, 16, Color.WHITE, 1.5)


static func _frame(sprite: StringName, index: int) -> Texture2D:
	var frames := SpriteLibrary.get_frames(sprite)
	return frames.get_frame_texture(&"default", mini(index, frames.get_frame_count(&"default") - 1))


## The last ball's centre relative to the Part's top-left (source xExtra2).
func _handle_offset() -> Vector2:
	return Vector2(8, 8) + Vector2(cos(deg_to_rad(start_angle)), -sin(deg_to_rad(start_angle))) * (length - 1) * 8


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not dragging and _can_drag() \
				and Rect2(_handle_offset() - Vector2(8, 8), Vector2(16, 16)).has_point(get_local_mouse_position()):
			begin_drag()
			get_viewport().set_input_as_handled()
			return
		if not event.pressed and dragging:
			end_drag()
			return
	super(event)


## obj_firebar_res/Mouse_4: a click inside the base's middle 8px flips direct_t.
func _input_event(viewport: Viewport, event: InputEvent, shape_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _can_drag():
		if Rect2(4, 4, 8, 8).has_point(get_local_mouse_position()):
			var state := get_variant_state()
			state.modifiers[&"clockwise"] = not clockwise
			level.editor.history.set_part_state(self, state, "Change direction")
			UISoundPlayer.stream = SoundLibrary.stream("snd_change_arrow")
			UISoundPlayer.play()
			viewport.set_input_as_handled()
			return
	super(viewport, event, shape_index)


func _can_drag() -> bool:
	return is_instance_valid(level) and level.status == Level.Status.EDITING and is_instance_valid(level.editor) \
			and level.editor.part_interact and level.editor.held_part == null and not held \
			and level.editor.erasing == Editor.EraseMode.NONE


func begin_drag() -> void:
	dragging = true
	_drag_before = get_variant_state()
	level.editor.held_part = self
	level.editor.part_interact = false
	Cursor.down = true
	queue_redraw()


func end_drag() -> void:
	dragging = false
	level.editor.held_part = null
	level.editor.part_interact = true
	level.editor.history.record_geometry(self, _drag_before, get_variant_state())
	Cursor.down = false
	queue_redraw()


func _process(delta: float) -> void:
	super(delta)
	if dragging:
		drag_to(get_local_mouse_position())


## obj_firebar_res/Step_2 while move_bar: aim at the mouse, then grow or shrink
## by 2 when the mouse is 16px past the handle along the bar's main axis.
## Measured from the base centre, where the handle is drawn.
func drag_to(mouse: Vector2) -> void:
	var center := Vector2(8, 8)
	var aim := mouse - center
	if aim.length_squared() > 0:
		start_angle = fposmod(rad_to_deg(atan2(-aim.y, aim.x)), 360)
	var tip := _handle_offset()
	var grow := 0
	if start_angle < 45 or start_angle > 315:
		grow = -1 if mouse.x < tip.x - 16 else 1 if mouse.x > tip.x + 16 else 0
	elif start_angle > 135 and start_angle < 225:
		grow = 1 if mouse.x < tip.x - 16 else -1 if mouse.x > tip.x + 16 else 0
	elif start_angle > 45 and start_angle < 135:
		grow = 1 if mouse.y < tip.y - 16 else -1 if mouse.y > tip.y + 16 else 0
	elif start_angle > 225 and start_angle < 315:
		grow = -1 if mouse.y < tip.y - 16 else 1 if mouse.y > tip.y + 16 else 0
	if (grow > 0 and length < MAX_LENGTH - 1) or (grow < 0 and length > MIN_LENGTH):
		length += grow * 2
		# obj_firebar_res/Other_15 (user event 5).
		UISoundPlayer.stream = SoundLibrary.stream("snd_rieles")
		UISoundPlayer.play()
	queue_redraw()


func get_variant_state() -> Dictionary:
	var state := super()
	state.length = length
	state.angle = start_angle
	return state


func restore_variant_state(state: Dictionary) -> void:
	super(state)
	length = state.get("length", length)
	start_angle = state.get("angle", start_angle)
	queue_redraw()


func get_variants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in LENGTHS.size():
		result.append({"id": LENGTHS[i], "label": "", "icon": icon_for(4 + i * 2)})
	return result


func get_variant() -> StringName:
	return LENGTHS[clampi(roundi((length - 4) / 2.0), 0, LENGTHS.size() - 1)]


func set_variant(id: StringName) -> void:
	if id in LENGTHS:
		length = 4 + LENGTHS.find(id) * 2
		queue_redraw()


func get_modifiers() -> Array[Dictionary]:
	return [{"id": &"clockwise", "label": "EDITOR_CLOCKWISE", "icon": load("res://textures/ui/editor/btn_clockwise.svg")}]


func has_modifier(id: StringName) -> bool:
	return id == &"clockwise" and clockwise


func set_modifier(id: StringName, enabled: bool) -> void:
	if id == &"clockwise":
		clockwise = enabled
		queue_redraw()


## Source PLATAFORMAS row: x_pos/y_pos is the base centre, width the ball
## count, color the start angle and direct_t 1 for clockwise.
func read_platform(entry: Dictionary, _id: String) -> void:
	position = Level.snap(Vector2(float(entry.get("x_pos", 8)) - 8, float(entry.get("y_pos", 440)) - 432 - 8))
	var balls: Variant = entry.get("width", 4)
	length = clampi(int(balls), 1, MAX_LENGTH) if (balls is int or balls is float) else 4
	var angle: Variant = entry.get("color", 0)
	start_angle = float(angle) if (angle is int or angle is float) else 0.0
	clockwise = int(entry.get("direct_t", 0)) == 1


func write_platform(entry: Dictionary) -> void:
	entry.object = "obj_firebar_res"
	entry.x_pos = position.x + 8
	entry.y_pos = position.y + 432 + 8
	entry.width = length
	entry.height = 1
	entry.color = start_angle
	entry.direct_t = int(clockwise)
	entry.sprite = "spr_firebar_editor"


func build() -> void:
	var bar := FireBar.new()
	bar.setup(sub_area, length, clockwise, start_angle)
	bar.position = position + Vector2(8, 8)
	sub_area.add(bar)
