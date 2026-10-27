# SPDX-License-Identifier: AGPL-3.0-or-later
extends Node
## Renders the README banner from art already tracked in this repository.
## Converted OpenWE assets are deliberately not used; see docs/porting/LICENSING.md.
## Run: Godot --path . res://tools/promo/render_banner.tscn

const SIZE := Vector2i(1280, 640)
const SCALE := 3.0
const TILE := 16 * SCALE
const OUTPUT := "res://docs/images/banner.png"
const BACKGROUND = preload("res://textures/styles/smw/backgrounds/overworld/background.png")
const GROUND = preload("res://textures/styles/smw/tiles/ground/overworld.png")
const QUESTION = preload("res://textures/styles/smw/tiles/question_block.png")
const TURN = preload("res://textures/styles/smw/tiles/turn_block.png")
const COIN = preload("res://textures/styles/smw/tiles/coin.png")
const MUSHROOM = preload("res://textures/styles/smw/entities/mushroom.png")
const GALOOMBA = preload("res://textures/styles/smw/entities/galoomba.png")
const KOOPA = preload("res://textures/styles/smw/entities/green_koopa.png")
const SHELL = preload("res://textures/styles/smw/entities/green_koopa_shell.png")
const MARIO_JUMP = preload("res://textures/styles/smw/entities/player/mario/super/jump.png")
const FONT = preload("res://resources/ui/text.ttf")
# Native ground atlas cells (column, row), as checked by theme_switch_test.
const TOP_LEFT := Vector2i(0, 0)
const TOP := Vector2i(1, 0)
const TOP_RIGHT := Vector2i(5, 0)
const LEFT := Vector2i(0, 1)
const FILL := Vector2i(1, 1)
const RIGHT := Vector2i(5, 1)
const BOTTOM_LEFT := Vector2i(0, 5)
const BOTTOM := Vector2i(1, 5)
const BOTTOM_RIGHT := Vector2i(5, 5)

var _world: Node2D


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	_world = Node2D.new()
	viewport.add_child(_world)
	_build()
	for i in 4:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	viewport.get_texture().get_image().save_png(OUTPUT)
	print("BANNER ", OUTPUT)
	get_tree().quit()


func _build() -> void:
	for x in [0, 1024]:
		_sprite(BACKGROUND, Vector2(x, SIZE.y - 864 + 48), 2.0)
	var floor_y := SIZE.y - 2 * TILE
	for column in ceili(SIZE.x / TILE):
		_ground(TOP, Vector2(column * TILE, floor_y))
		_ground(FILL, Vector2(column * TILE, floor_y + TILE))
	_platform(Vector2(48, 400), Vector2i(4, 2))
	_platform(Vector2(864, 400), Vector2i(6, 2))
	for i in 4:
		_frame(TURN if i % 2 else QUESTION, 4, 0, Vector2(384 + i * TILE, 336))
	for i in 3:
		_frame(COIN, 4, i, Vector2(72 + i * 56, 320 - (24 if i == 1 else 0)))
	_frame(MUSHROOM, 1, 0, Vector2(384, 288))
	_frame(MARIO_JUMP, 1, 0, Vector2(360, 386), Vector2(32, 32))
	_frame(SHELL, 2, 0, Vector2(640, floor_y - TILE), Vector2(16, 16))
	_frame(GALOOMBA, 2, 0, Vector2(744, floor_y - TILE), Vector2(16, 16), true)
	_frame(KOOPA, 2, 0, Vector2(1010, 400 - 2 * TILE), Vector2(16, 32), true)
	_themes(Vector2(0, floor_y + 18))
	_logo()


func _logo() -> void:
	var origin := Vector2((SIZE.x - 627) / 2.0, 34)
	# A black copy offset in eight directions outlines the white letters.
	for angle in 8:
		var outline := _make_logo(false)
		outline.position = origin + Vector2.from_angle(angle * TAU / 8) * 6
		outline.modulate = Color(0, 0, 0, 0.85)
	var logo := _make_logo(true)
	logo.position = origin
	var neo := Label.new()
	neo.text = "neo"
	neo.add_theme_font_override(&"font", FONT)
	neo.add_theme_font_size_override(&"font_size", 104)
	neo.add_theme_color_override(&"font_color", Utility.COLOR_YELLOW)
	neo.add_theme_color_override(&"font_outline_color", Color.BLACK)
	neo.add_theme_constant_override(&"outline_size", 22)
	neo.position = origin + Vector2(470, 138)
	neo.rotation_degrees = -8
	_world.add_child(neo)


# The ten course theme cards from the editor, on a dark strip over the floor.
func _themes(at: Vector2) -> void:
	const KEYS = ["overworld", "underground", "underwater", "desert", "snow", "sky", "forest",
			"mansion", "airship", "castle"]
	const CARD := Vector2(76, 45)
	const GAP := 10.0
	var width := KEYS.size() * (CARD.x + GAP) - GAP
	var strip := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.55)
	box.set_corner_radius_all(14)
	strip.add_theme_stylebox_override(&"panel", box)
	strip.size = Vector2(width + 28, CARD.y + 20)
	strip.position = at + Vector2((SIZE.x - strip.size.x) / 2, 0)
	_world.add_child(strip)
	for i in KEYS.size():
		var card := TextureRect.new()
		card.texture = load("res://textures/ui/editor/left_panel/theme_cards/wide/%s.svg" % KEYS[i])
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.size = CARD
		card.position = strip.position + Vector2(14 + i * (CARD.x + GAP), 10)
		_world.add_child(card)


func _make_logo(white: bool) -> Logo:
	var logo := Logo.new()
	logo.world_engine = false
	logo.white = white
	_world.add_child(logo)
	return logo


func _platform(at: Vector2, size: Vector2i) -> void:
	for y in size.y:
		for x in size.x:
			var row := 0 if y == 0 else 2 if y == size.y - 1 else 1
			var column := 0 if x == 0 else 2 if x == size.x - 1 else 1
			var role: Vector2i = [
				[TOP_LEFT, TOP, TOP_RIGHT], [LEFT, FILL, RIGHT], [BOTTOM_LEFT, BOTTOM, BOTTOM_RIGHT]
			][row][column]
			_ground(role, at + Vector2(x, y) * TILE)


func _ground(role: Vector2i, at: Vector2) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = GROUND
	texture.region = Rect2(Vector2(role) * 16, Vector2(16, 16))
	_sprite(texture, at, SCALE)


func _frame(sheet: Texture2D, frames: int, index: int, at: Vector2, size := Vector2(16, 16),
		flip := false) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = Rect2(Vector2(index * sheet.get_width() / frames, 0), size)
	var sprite := _sprite(texture, at, SCALE)
	sprite.flip_h = flip


func _sprite(texture: Texture2D, at: Vector2, scale: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = at
	sprite.scale = Vector2(scale, scale)
	_world.add_child(sprite)
	return sprite
