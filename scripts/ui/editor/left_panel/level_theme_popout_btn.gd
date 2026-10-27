class_name LevelThemePopoutBtn
extends TextureButton

const HOVER = preload("uid://bbc6fa1b5njqq")
const CHANGE_STYLE = preload("uid://dnblg2whmhj7t")

@export var level_theme: Level.LevelTheme:
	set = _set_level_theme

@onready var effect := ButtonHoverEffect.new(self)


func _ready() -> void:
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)


func _process(_delta: float) -> void:
	effect.check_redraw()


func _draw() -> void:
	if %Editor.level != null:
		draw_texture(get_card(), Vector2(0, 0))
	effect.draw()


func get_card() -> Texture2D:
	# TODO
	match level_theme:
		Level.LevelTheme.OVERWORLD:
			return preload("uid://c5e3og8cn1tkk")
		Level.LevelTheme.UNDERGROUND:
			return preload("uid://cuo4hsgaoju5i")
		Level.LevelTheme.UNDERWATER:
			return preload("uid://n3vx3ek5mphg")
		Level.LevelTheme.CASTLE:
			return preload("uid://j7xvgsa1ajj")
		Level.LevelTheme.SKY:
			return preload("uid://7k7sobkw3k8n")
		Level.LevelTheme.AIRSHIP:
			return preload("uid://dewin56yhpwyf")
		Level.LevelTheme.DESERT:
			return preload("uid://cgvt0mbyvw75f")
		Level.LevelTheme.SNOW:
			return preload("uid://rkq0n8tfavyi")
		Level.LevelTheme.MANSION:
			return preload("uid://dy08efwgaeoow")
		Level.LevelTheme.FOREST:
			return preload("uid://35yvo2wixaty")
		Level.LevelTheme.FALL:
			return preload("uid://4875c0hqr8q0")
		Level.LevelTheme.BEACH:
			return preload("uid://dvtkgixtpt7uw")
		Level.LevelTheme.MOUNTAIN:
			if %Editor.level.current_sub_area.night_mode:
				return preload("uid://oorntut1b3lj")
			else:
				return preload("uid://bnypmawt40h3f")
		_:
			return preload("uid://c5e3og8cn1tkk")


func _pressed() -> void:
	%Editor.level.current_sub_area.level_theme = level_theme
	%LevelThemePanel.close_sound = CHANGE_STYLE
	%LevelThemePanel.close()


func _mouse_entered() -> void:
	UISoundPlayer.stream = HOVER
	UISoundPlayer.play()
	effect.start()


func _mouse_exited() -> void:
	effect.stop()


func _set_level_theme(v: Level.LevelTheme) -> void:
	level_theme = v
	queue_redraw()
