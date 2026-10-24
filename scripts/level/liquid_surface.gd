# SPDX-License-Identifier: AGPL-3.0-or-later
class_name LiquidSurface
extends Node2D
## Native source surface position/animation for water-dependent actors.
## obj_lava_water Step_2 + Alarm_0: 12px origin offset and two-second holds.

enum Phase { START, RISING, HOLD_TOP, DESCEND, FALLING, HOLD_BOTTOM }

var rules: LiquidRules = preload("res://resources/content/smw_liquids.tres")
var sub_area: SubArea
var velocity := 0.0
var phase := Phase.START
var _hold := 0.0
var _age := 0.0
var _surface: SpriteFrames
var _fill: Texture2D


static func supports(theme: Level.LevelTheme, night: bool) -> bool:
	return theme in [Level.LevelTheme.FOREST, Level.LevelTheme.BEACH, Level.LevelTheme.CASTLE] \
			or (theme == Level.LevelTheme.MOUNTAIN and night)


func is_water() -> bool:
	return sub_area.level_theme == Level.LevelTheme.BEACH \
			or (sub_area.level_theme == Level.LevelTheme.FOREST and not sub_area.night_mode)


func source_contact_bounds() -> Rect2:
	var size := _surface.get_frame_texture(&"default", 0).get_size() * rules.contact_scale
	return Rect2(Vector2(Utility.get_visible_rect().position.x, global_position.y), size)


func reset() -> void:
	position.y = sub_area.water_start_y + 12
	velocity = 0
	phase = Phase.START
	_hold = 0
	_age = 0
	queue_redraw()


func _ready() -> void:
	reset()
	var sprite_name := rules.water_sprite
	var fill_name := rules.water_fill_sprite
	match sub_area.level_theme:
		Level.LevelTheme.BEACH:
			sprite_name = rules.beach_sprite
			fill_name = rules.beach_fill_sprite
		Level.LevelTheme.CASTLE, Level.LevelTheme.MOUNTAIN:
			sprite_name = rules.lava_sprite
			fill_name = rules.lava_fill_sprite
		Level.LevelTheme.FOREST:
			if sub_area.night_mode:
				sprite_name = rules.poison_sprite
				fill_name = rules.poison_fill_sprite
	_surface = SpriteLibrary.get_frames(sprite_name)
	_fill = SpriteLibrary.get_frames(fill_name).get_frame_texture(&"default", 2)


func _physics_process(delta: float) -> void:
	var level := sub_area.level
	z_index = GameConstants.Layers.Z_LIQUID if level.status != Level.Status.EDITING else GameConstants.Layers.Z_EDITOR_LIQUID
	if level.status == Level.Status.EDITING:
		reset()
		modulate.a = 1.0 if is_water() else 0.4
		return
	modulate.a = 1
	var player := level.hud.player
	if is_instance_valid(player) and player.is_dead():
		velocity = 0
		# Alarm0 keeps counting even though not_move stops motion/animation.
		if _hold > 0:
			_hold = maxf(0, _hold - delta)
			if _hold <= 0.00001:
				_hold = 0
				phase = Phase.DESCEND if phase == Phase.HOLD_TOP else Phase.START
		return
	_age += delta
	# Source movement occurs before its end-step state changes.
	position.y += velocity * delta
	if level.is_completed:
		velocity = 0
		if not is_water():
			for part in sub_area.get_parts().get_children():
				if part is GoalPolePart and position.y < part.position.y + 137 + 12:
					velocity = 60
		queue_redraw()
		return
	if _hold > 0:
		_hold = maxf(0, _hold - delta)
		if _hold <= 0.00001:
			_hold = 0
			phase = Phase.DESCEND if phase == Phase.HOLD_TOP else Phase.START
	if sub_area.water_start_y != sub_area.water_limit_y:
		var speed := rules.speeds[sub_area.water_speed]
		if phase == Phase.START and sub_area.water_limit_y < position.y - 12:
			velocity = -speed
			phase = Phase.RISING
		elif phase == Phase.RISING and sub_area.water_limit_y >= position.y - 12:
			velocity = 0
			phase = Phase.HOLD_TOP
			_hold = rules.hold_time
		elif phase == Phase.DESCEND and sub_area.water_limit_y >= position.y - 12:
			velocity = speed
			phase = Phase.FALLING
		elif phase == Phase.FALLING and position.y >= sub_area.water_start_y:
			velocity = 0
			phase = Phase.HOLD_BOTTOM
			_hold = rules.hold_time
	queue_redraw()


func _draw() -> void:
	if _surface == null or _surface.get_frame_count(&"default") == 0:
		return
	var visible_rect := get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	var texture := _surface.get_frame_texture(&"default", int(_age * rules.fps) % _surface.get_frame_count(&"default"))
	var width := texture.get_width()
	var left := floorf(visible_rect.position.x / width) * width
	draw_texture_rect(_fill, Rect2(Vector2(left, maxf(4, visible_rect.position.y)),
			Vector2(visible_rect.size.x + width, maxf(0, visible_rect.end.y - maxf(4, visible_rect.position.y)))), false)
	for x in range(int(left), ceili(visible_rect.end.x) + width, width):
		draw_texture(texture, Vector2(x, -12))
