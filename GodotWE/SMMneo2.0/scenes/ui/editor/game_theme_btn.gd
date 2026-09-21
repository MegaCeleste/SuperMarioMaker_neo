class_name GameThemeBtn
extends TextureButton

var _level: Level
var _tween: Tween
var _extend_size := 0.0
@onready var _effect = ButtonHoverEffect.new(self, Rect2(0, 0, size.x, size.y - 3))

# Map theme names to background texture previews
var _theme_textures := {
	"Overworld": preload("res://textures/backgrounds/smw/overworld/spr_overworld_anim_0.png"),
	"Underground": null,
	"Underwater": null,
	"Castle": preload("res://textures/backgrounds/smw/castle.png"),
	"Sky": null,
	"Airship": preload("res://textures/backgrounds/smw/airship/spr_airship_anim_0.png"),
	"Desert": preload("res://textures/backgrounds/smw/desert.png"),
	"Snow": null,
	"Mansion": null,
	"Forest": preload("res://textures/backgrounds/smw/forest.png"),
	"Fall": preload("res://textures/backgrounds/smw/fall.png"),
	"Beach": preload("res://textures/backgrounds/smw/beach.png"),
	"Mountain": null,
}

var _theme_names := {
	Level.LevelTheme.OVERWORLD: "Overworld",
	Level.LevelTheme.UNDERGROUND: "Underground",
	Level.LevelTheme.UNDERWATER: "Underwater",
	Level.LevelTheme.CASTLE: "Castle",
	Level.LevelTheme.SKY: "Sky",
	Level.LevelTheme.AIRSHIP: "Airship",
	Level.LevelTheme.DESERT: "Desert",
	Level.LevelTheme.SNOW: "Snow",
	Level.LevelTheme.MANSION: "Ghost House",
	Level.LevelTheme.FOREST: "Forest",
	Level.LevelTheme.FALL: "Fall",
	Level.LevelTheme.BEACH: "Beach",
	Level.LevelTheme.MOUNTAIN: "Mountain",
}


func _ready() -> void:
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)
	%ThemePanel.status_changed.connect(_panel_status_changed)
	await %Editor.loaded
	_level = %Editor.level
	# Theme buttons handle their own pressed signals via theme_button.gd


func _process(_delta: float) -> void:
	_effect.check_redraw()


func _draw() -> void:
	_effect.draw()


func _toggled(toggled_on: bool) -> void:
	if toggled_on:
		mouse_behavior_recursive = MOUSE_BEHAVIOR_ENABLED
		%ThemePanel.open()
	else:
		%ThemePanel.close()
		mouse_behavior_recursive = MOUSE_BEHAVIOR_INHERITED


func _mouse_entered() -> void:
	_effect.start()
	if not DisplayServer.is_touchscreen_available():
		UISoundPlayer.stream = preload("uid://d3lha2xpakko2")
		UISoundPlayer.play()


func _mouse_exited() -> void:
	_effect.stop()


func _panel_status_changed(_old_status: EditorPopout.Status) -> void:
	if %ThemePanel.status == EditorPopout.Status.OPENING:
		set_pressed_no_signal(true)
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_QUAD)
		_tween.set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "_extend_size", 24, 0.1)
	elif %ThemePanel.status == EditorPopout.Status.CLOSING:
		set_pressed_no_signal(false)
		_tween.kill()
		_extend_size = 0


func _on_theme_pressed(theme_name: String) -> void:
	var level = _level
	if level == null:
		level = %Editor.level
	if level == null or level.sub_areas.size() == 0:
		return
	var theme = _theme_name_to_enum(theme_name)
	level.sub_areas[0].level_theme = theme
	level.sub_areas[0]._load_background()
	queue_redraw()
	%ThemePanel.close()
	set_pressed_no_signal(false)


func _on_child_pressed(theme_name: String) -> void:
	_on_theme_pressed(theme_name)


func _theme_name_to_enum(theme_name: String) -> int:
	var theme_map = {
		"Overworld": Level.LevelTheme.OVERWORLD,
		"Underground": Level.LevelTheme.UNDERGROUND,
		"Underwater": Level.LevelTheme.UNDERWATER,
		"Castle": Level.LevelTheme.CASTLE,
		"Sky": Level.LevelTheme.SKY,
		"Airship": Level.LevelTheme.AIRSHIP,
		"Desert": Level.LevelTheme.DESERT,
		"Snow": Level.LevelTheme.SNOW,
		"Mansion": Level.LevelTheme.MANSION,
		"Forest": Level.LevelTheme.FOREST,
		"Fall": Level.LevelTheme.FALL,
		"Beach": Level.LevelTheme.BEACH,
		"Mountain": Level.LevelTheme.MOUNTAIN,
	}
	return theme_map.get(theme_name, Level.LevelTheme.OVERWORLD)
