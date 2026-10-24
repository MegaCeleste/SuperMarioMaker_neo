# SPDX-License-Identifier: AGPL-3.0-or-later
extends EditorPopout
## Native popout lifecycle, landscape cards and the existing hover-corner effect.

var choices: Dictionary[int, Button] = {}

const CARD_SIZE := Vector2(126, 78)

func _ready() -> void:
	super()
	var group := ButtonGroup.new()
	for i in SMWTheme.CHOICES.size():
		var theme: Level.LevelTheme = SMWTheme.CHOICES[i]
		var data := SMWTheme.info(theme)
		var button := ThemeChoice.new()
		button.name = Level.LevelTheme.find_key(theme)
		button.position = Vector2(35 + (i % 2) * 159, 98 + (i / 2) * 108)
		button.size = CARD_SIZE
		button.toggle_mode = true
		button.button_group = group
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var border := StyleBoxFlat.new()
			border.bg_color = Color("eeeee6")
			border.set_corner_radius_all(6)
			border.shadow_color = Color(0, 0, 0, 0.18)
			border.shadow_size = 2
			border.shadow_offset = Vector2(0, 3)
			button.add_theme_stylebox_override(state, border)
		button.pressed.connect(choose.bind(theme))
		button.card = load("res://textures/ui/editor/left_panel/theme_cards/wide/%s.svg" % ("mansion" if theme == Level.LevelTheme.MANSION else data.key))
		add_child(button)
		choices[theme] = button
	status_changed.connect(_sync)
	%Editor.loaded.connect(_sync.bind(Status.CLOSED))

func choose(theme: Level.LevelTheme) -> bool:
	var editor: Editor = %Editor
	if not is_instance_valid(editor.level) or editor.level.status != Level.Status.EDITING \
			or editor.held_part != null or editor._saving or editor.level.game_style != Level.GameStyle.SMW:
		return false
	if theme not in SMWTheme.CHOICES:
		return false
	editor.history.set_theme(editor.level.current_sub_area, theme)
	_sync(Status.OPEN)
	close()
	return true

func _sync(_old: Status) -> void:
	var editor: Editor = %Editor
	if not is_instance_valid(editor.level):
		return
	for theme in choices:
		choices[theme].disabled = editor.level.game_style != Level.GameStyle.SMW
		choices[theme].set_pressed_no_signal(editor.level.current_sub_area.level_theme == theme)
		(choices[theme] as ThemeChoice).refresh_effect()

class ThemeChoice extends Button:
	var card: Texture2D
	var effect: ButtonHoverEffect

	func _ready() -> void:
		effect = ButtonHoverEffect.new(self)
		for changed in [mouse_entered, mouse_exited, focus_entered, focus_exited, visibility_changed]:
			changed.connect(refresh_effect)

	func refresh_effect() -> void:
		if effect == null:
			return
		var highlighted := is_visible_in_tree() and not disabled and (button_pressed or is_hovered() or has_focus())
		if highlighted and not effect.enabled:
			effect.start()
		elif not highlighted:
			effect.stop()
		queue_redraw()

	func _process(_delta: float) -> void:
		effect.check_redraw()

	func _draw() -> void:
		if card != null:
			draw_texture_rect(card, Rect2(Vector2(5, 5), size - Vector2(10, 10)), false)
		if effect != null:
			effect.draw()
