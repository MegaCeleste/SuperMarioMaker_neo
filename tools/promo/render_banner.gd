# SPDX-License-Identifier: AGPL-3.0-or-later
extends Node
## Renders the README banner in the layout of GodotWE's own banner, with SMM2's
## yellow. Only art tracked in this repository is drawn; converted OpenWE assets
## are not used (see docs/porting/LICENSING.md). The tag font (SMM2's MARIOMAKER
## by default) is read from a gitignored local file and never committed.
## Run: Godot --path . res://tools/promo/render_banner.tscn [-- --font=path]

const SIZE := Vector2i(1152, 384)
const OUTPUT := "res://docs/images/banner.png"
const FONTS := ["assets/fonts/MARIOMAKER.otf", "../openwe-ref/datafiles/fontcjk.ttf"]
const YELLOW := Color("#facd00")
const ORANGE := Color("#f7a600")
const DARK := Color("#5d1c1c")
const RED := Color("#e60012")
const MARIO = preload("res://textures/styles/smw/entities/player/mario/super/jump.png")
const QUESTION = preload("res://textures/styles/smw/tiles/question_block.png")
const GALOOMBA = preload("res://textures/styles/smw/entities/galoomba.png")
const COIN = preload("res://textures/styles/smw/tiles/coin.png")
const TWO_TONE := """
shader_type canvas_item;
uniform vec3 lower : source_color;
void fragment() {
	if (UV.y > 0.56) {
		COLOR.rgb *= lower;
	}
}
"""

var _font: Font = preload("res://resources/ui/text.ttf")
var _world: Node2D


func _ready() -> void:
	_load_font()
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.msaa_2d = Viewport.MSAA_4X
	add_child(viewport)
	_world = Node2D.new()
	viewport.add_child(_world)
	_world.add_child(Backdrop.new())
	_sprites()
	_title(Vector2(276, 48), 0.92)
	for i in 4:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	viewport.get_texture().get_image().save_png(OUTPUT)
	print("BANNER ", OUTPUT)
	get_tree().quit()


func _load_font() -> void:
	var paths: Array = FONTS.map(func(path): return ProjectSettings.globalize_path("res://").path_join(path))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--font="):
			paths = [arg.trim_prefix("--font=")]
	for path: String in paths:
		var font := FontFile.new()
		if FileAccess.file_exists(path) and font.load_dynamic_font(path) == OK:
			_font = font
			print("BANNER_FONT ", path)
			return
	push_warning("No tag font found; using the bundled UI font")


func _sprites() -> void:
	_shadowed(_frame(MARIO, 1, 0, Vector2(32, 32)), Vector2(70, 120), 6.0)
	_shadowed(_frame(QUESTION, 4, 0), Vector2(1000, 64), 5.0)
	_shadowed(_frame(COIN, 4, 0), Vector2(926, 74), 4.0)
	_shadowed(_frame(GALOOMBA, 2, 0), Vector2(986, 266), 5.0, true)


# Draws the game's own title letters with GodotWE's banner treatment: a two-tone
# fill, a thick dark outline and a solid drop shadow.
func _title(at: Vector2, size: float) -> void:
	var outline := 9.0
	for layer in 2:
		var offset := Vector2(0, 12) if layer == 0 else Vector2.ZERO
		for angle in 24:
			var logo := _make_logo(at + offset + Vector2.from_angle(angle * TAU / 24) * outline, size)
			logo.modulate = DARK.darkened(0.45) if layer == 0 else DARK
	var fill := _make_logo(at, size)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = TWO_TONE
	material.set_shader_parameter(&"lower", Color("#ffe9a8"))
	fill.material = material
	_tag("neo", at + Vector2(430, 196) * size, -6.0)


# An SMM2-style rounded label, as on course tags and editor buttons.
func _tag(text: String, at: Vector2, angle: float) -> void:
	var holder := Node2D.new()
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	holder.position = at
	holder.rotation_degrees = angle
	_world.add_child(holder)
	var font_size := 88
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var panel := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = RED
	box.set_corner_radius_all(30)
	box.border_color = DARK
	box.set_border_width_all(8)
	box.shadow_color = DARK.darkened(0.45)
	box.shadow_offset = Vector2(0, 10)
	box.shadow_size = 1
	panel.add_theme_stylebox_override(&"panel", box)
	panel.size = Vector2(width + 56, 96)
	holder.add_child(panel)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", _font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.size = Vector2(panel.size.x, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Centre the lowercase x-height, not the line box: fonts reserve very different
	# space above Latin glyphs. Godot draws the baseline at the font's ascent.
	var x_height := _x_height(font_size)
	label.position = Vector2(0, panel.size.y / 2 - _font.get_ascent(font_size) + x_height / 2)
	panel.add_child(label)


# Measures the drawn height of "x" by rendering it into a throwaway image.
func _x_height(font_size: int) -> float:
	var text_server := TextServerManager.get_primary_interface()
	var rid := _font.get_rids()[0]
	var glyph := text_server.font_get_glyph_index(rid, font_size, "x".unicode_at(0), 0)
	var size := text_server.font_get_glyph_size(rid, Vector2i(font_size, 0), glyph)
	return size.y if size.y > 0 else font_size * 0.5


func _make_logo(at: Vector2, size: float) -> Logo:
	var logo := Logo.new()
	# Vector letters and fonts scale smoothly; only the pixel sprites stay nearest.
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	logo.world_engine = false
	logo.white = true
	logo.position = at
	logo.scale = Vector2(size, size)
	_world.add_child(logo)
	return logo


func _frame(sheet: Texture2D, frames: int, index: int, size := Vector2(16, 16)) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = Rect2(Vector2(index * sheet.get_width() / frames, 0), size)
	return texture


# A pixel sprite over a soft dark copy, so it reads on yellow.
func _shadowed(texture: Texture2D, at: Vector2, scale: float, flip := false) -> void:
	for shadow in [true, false]:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.flip_h = flip
		sprite.position = at + (Vector2(0, 8) if shadow else Vector2.ZERO)
		sprite.scale = Vector2(scale, scale)
		if shadow:
			sprite.modulate = Color(DARK, 0.35)
		_world.add_child(sprite)


# SMM2 yellow with GodotWE's banner motif: diagonal bands and large tilted squares.
class Backdrop extends Node2D:
	func _draw() -> void:
		var size := Vector2(SIZE)
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([YELLOW, YELLOW, ORANGE, ORANGE])
		)
		for i in 14:
			var x := -200.0 + i * 110
			var band := PackedVector2Array([
				Vector2(x, size.y), Vector2(x + 60, size.y), Vector2(x + 200, 0), Vector2(x + 140, 0)
			])
			draw_colored_polygon(band, Color(1, 1, 1, 0.09))
		var square := StyleBoxFlat.new()
		square.set_corner_radius_all(26)
		for spec in [[Vector2(580, 190), 330.0, 14.0, 0.10], [Vector2(560, 200), 230.0, -9.0, 0.08],
				[Vector2(120, 330), 220.0, 20.0, 0.07], [Vector2(1060, 70), 200.0, -16.0, 0.08]]:
			square.bg_color = Color(DARK, spec[3])
			draw_set_transform(spec[0], deg_to_rad(spec[2]))
			draw_style_box(square, Rect2(-Vector2.ONE * spec[1] / 2, Vector2.ONE * spec[1]))
		draw_set_transform(Vector2.ZERO)
		# SMM2's caution stripes along the bottom edge.
		draw_rect(Rect2(0, size.y - 22, size.x, 22), DARK)
		for i in 60:
			var x := i * 28.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, size.y), Vector2(x + 14, size.y), Vector2(x + 30, size.y - 16), Vector2(x + 16, size.y - 16)
			]), YELLOW)
