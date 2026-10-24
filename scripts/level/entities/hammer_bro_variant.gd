# SPDX-License-Identifier: AGPL-3.0-or-later
class_name HammerBroVariant
extends EnemyDefeatStyle
## One of obj_hammerbro/firebro/icebro/boomerangbro. Movement and jumps are
## shared; the variant supplies art, projectile and throw timings.

enum Projectile { HAMMER, FIRE, ICE, BOOMERANG }

@export var id: StringName = &"hammer"
@export var object_id := "obj_hammerbro_res"
@export var label: StringName = &"EDITOR_ENEMY_HAMMERBRO"
@export var idle_sprite: StringName = &"spr_hammerbro"
@export var jump_sprite: StringName = &"spr_hammerbro_jump"
@export var throw_sprite: StringName = &"spr_hammerbro_throw"
@export var editor_sprite: StringName = &"spr_hammerbro_res"
@export var editor_frame := 2
@export var editor_origin := Vector2(8, 16)
@export var projectile: Projectile = Projectile.HAMMER
@export var min_throws := 1
@export var max_throws := 3
@export var throw_delay := 20
@export var burst_cooldown := 80
@export var walk_speed := 24.0
@export var jump_big := -371.4
@export var jump_small := -150.0
@export var wing_jump_big := -420.0
@export var wing_jump_small := -270.0
@export var water_jump_big := -191.4
@export var water_jump_small := -90.0
@export var water_wing_jump_big := -180.0
@export var water_wing_jump_small := -90.0
@export var gravity := 720.0
@export var water_gravity := 72.0
@export var fall_speed := 240.0
@export var water_fall_speed := 60.0
@export var pass_gravity := 900.0
@export var water_pass_gravity := 540.0
@export var water_walk_speed := 12.0
@export var water_initial_walk_speed := 18.0
@export var source_to_feet := 16.0
@export var upper_block_probe := 40.0
@export var lower_block_probe := 8.0
@export var jump_room_below := 64.0
@export var lower_support_probes := PackedFloat32Array([32, 48, 64, 80, 112, 128])
## Sledge Bro (obj_sledgebro) uses fixed 8s jumps, an 80-tick throw cadence
## and a bigger mask/art anchor.
@export var sledge := false
@export var mask_size := Vector2(10, 16)
@export var graphics_y := -16.0
@export var jump_interval := 6.0
@export var jump_speed := -360.0
@export var throw_interval := 17
@export var hammer_offset := Vector2(-5, -24)

var _icon: Texture2D
var icon: Texture2D:
	get:
		return get_icon()


func get_icon() -> Texture2D:
	# Resources can be inspected while the autoload list is still loading.
	if not is_instance_valid(SpriteLibrary) or not SpriteLibrary.is_node_ready():
		return null
	if _icon == null:
		# Normalize an independent crop; retain the source pixels unchanged.
		var frames := SpriteLibrary.get_frames(editor_sprite)
		if frames.get_frame_count(&"default") <= editor_frame:
			return null
		var source := frames.get_frame_texture(&"default", editor_frame).get_image()
		var cropped := source.get_region(source.get_used_rect())
		var factor := 48.0 / maxf(cropped.get_width(), cropped.get_height())
		cropped.resize(roundi(cropped.get_width() * factor), roundi(cropped.get_height() * factor), Image.INTERPOLATE_NEAREST)
		var canvas := Image.create(60, 60, false, Image.FORMAT_RGBA8)
		canvas.blit_rect(cropped, Rect2i(Vector2i.ZERO, cropped.get_size()), (Vector2i(60, 60) - cropped.get_size()) / 2)
		_icon = ImageTexture.create_from_image(canvas)
	return _icon
