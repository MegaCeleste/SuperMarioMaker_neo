# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Bridge
extends StaticBody2D
## SMW bridge (source obj_puente_res -> obj_modelsizable type 2): a row of
## left, middle and right pieces drawn around a one-way surface at the
## sprite origin line (source obj_solidtop at y).

## Width in 16px cells; source size_x.
var width := 3
var sprite := &"spr_puente"


func setup(cells: int, art: StringName) -> void:
	width = cells
	sprite = art


func _ready() -> void:
	z_as_relative = false
	z_index = GameConstants.Layers.Z_BRIDGES
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(width * 16, 6)
	shape.position = Vector2(width * 8, 3)
	shape.one_way_collision = true
	shape.one_way_collision_margin = 2
	add_child(shape)
	var frames := SpriteLibrary.get_frames(sprite)
	for cell in width:
		var piece := Sprite2D.new()
		piece.centered = false
		piece.texture = frames.get_frame_texture(&"default", 0 if cell == 0 else 2 if cell == width - 1 else 1)
		# Source origin (0, 16): the art straddles the surface line.
		piece.position = Vector2(cell * 16, -16)
		add_child(piece)
