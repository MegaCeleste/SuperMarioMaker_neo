# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SMWTheme
extends RefCounted
## SMM2's ten SMW themes, day and night. Atlas layout/topology remain native GodotWE.

const CHOICES = [Level.LevelTheme.OVERWORLD, Level.LevelTheme.UNDERGROUND,
	Level.LevelTheme.UNDERWATER, Level.LevelTheme.DESERT, Level.LevelTheme.SNOW, Level.LevelTheme.SKY,
	Level.LevelTheme.FOREST, Level.LevelTheme.MANSION, Level.LevelTheme.AIRSHIP, Level.LevelTheme.CASTLE]
const GROUND = preload("res://textures/styles/smw/tiles/ground/overworld.png")
static var _data: Dictionary = {}
static var _atlases: Dictionary = {}
static var _music: Dictionary = {}

static func info(theme: Level.LevelTheme) -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://resources/content/smw_themes.json"))
	return _data.get(Level.LevelTheme.find_key(theme), {})

static func supports(area: SubArea) -> bool:
	return is_instance_valid(area) and is_instance_valid(area.level) and area.level.game_style == Level.GameStyle.SMW and area.level_theme in CHOICES

static func music_for(area: SubArea, editing: bool) -> AudioStream:
	var data := info(area.level_theme) if supports(area) else info(Level.LevelTheme.OVERWORLD)
	var mode := "edit" if editing else "play"
	var path: String = data.get(mode, "res://assets/openwe/sounds/snd_%s_%s.ogg" % ["editor" if editing else "music", data.key])
	if not editing and supports(area) and area.night_mode:
		# scr_snd_<theme>: night swaps play music only; scr_snd_editor_<theme> has no night branch.
		path = "res://assets/openwe/sounds/snd_music_%s_night.ogg" % data.get("music", data.key)
	if not _music.has(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		_music[path] = stream
	return _music[path]

## The source ground sprite; scr_tiles_ground swaps it at night for underwater and snow only.
static func ground_sprite(area: SubArea) -> String:
	var data := info(area.level_theme)
	return data.get("night_ground", data.ground) if area.night_mode else data.ground

## Repack existing source frames; never replace the native53-rule chooser.
static func atlas(area: SubArea) -> Texture2D:
	if not supports(area) or area.level_theme == Level.LevelTheme.OVERWORLD:
		return GROUND
	var theme := area.level_theme
	var sprite := ground_sprite(area)
	if _atlases.has(sprite):
		return _atlases[sprite]
	if not SpriteLibrary.has_sprite(sprite):
		return GROUND # Cold editor icon reads must not cache missing metadata.
	var frames := SpriteLibrary.get_frames(sprite)
	var image := Image.create(96, 224, false, Image.FORMAT_RGBA8)
	# Raw sprite roles diverge from SWE's saved-frame order at43. Extra frames
	# in underground are slopes, not the native atlas's decorative variants.
	var mapping: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/content/smw_ground_frames.json"))
	for row in mapping.rows.size():
		for column in mapping.rows[row].size():
			var frame: int = mapping.rows[row][column]
			image.blit_rect(frames.get_frame_texture(&"default", frame).get_image(), Rect2i(0, 0, 16, 16), Vector2i(column, row) * 16)
	# Full paired ribbon assets are still incomplete outside overworld. Keep a
	# theme-colored fallback until the optional artist-supplied PNGs are present.
	var top := frames.get_frame_texture(&"default", 21).get_image()
	var body := frames.get_frame_texture(&"default", 43).get_image()
	var bottom := frames.get_frame_texture(&"default", 27).get_image()
	for right in [true, false]:
		for filled in [true, false]:
			for x in 16:
				for y in 32:
					var depth := y - (15 - x if right else x)
					var color := Color.TRANSPARENT
					if depth >= 0 and (filled or depth < 16):
						color = top.get_pixel(x, depth) if depth < 4 else body.get_pixel(x, y % 16)
						if not filled and depth >= 12:
							color = bottom.get_pixel(x, depth)
					image.set_pixel((0 if right else 16) + (0 if filled else 64) + x, 192 + y, color)
	var result := ImageTexture.create_from_image(image)
	result.set_meta(&"course_theme", info(theme).key)
	_atlases[sprite] = result
	return result

static func create_background(area: SubArea) -> Node:
	if not supports(area) or (area.level_theme == Level.LevelTheme.OVERWORLD and not area.night_mode):
		return null
	var layer := CanvasLayer.new()
	layer.layer = -1
	layer.follow_viewport_enabled = true
	var backdrop := ThemeBackground.new()
	backdrop.name = "Background"
	backdrop.area = area
	# scr_create_bg_anim: night uses its own four-frame loop (airship borrows the
	# cloudy sky set, ghost house a single still) in place of scr_bg_<theme>.
	for name: String in info(area.level_theme)["night_backgrounds" if area.night_mode else "backgrounds"]:
		backdrop.frames.append(SpriteLibrary.get_frames(name).get_frame_texture(&"default", 0))
	backdrop.texture = backdrop.frames[0]
	backdrop.follow_scale = Vector2(0.5, 1)
	layer.add_child(backdrop)
	return layer

class ThemeBackground extends Background:
	var area: SubArea
	var frames: Array[Texture2D] = []
	func _process(delta: float) -> void:
		# obj_bganimator/Alarm_0:10 ticks per background frame; editor freezes0.
		texture = frames[int(area.level.animation_time * 6) % frames.size() if area.level.status == Level.Status.PLAYING else 0]
		super(delta)
