# SPDX-License-Identifier: AGPL-3.0-or-later
extends EditorPopout
## Native popout lifecycle, landscape cards and the existing hover-corner effect.

const CARD_SIZE := Vector2(106, 66)
const CHANGE_NIGHT_DAY = preload("uid://wujt66l1ojvt")

var choices: Dictionary[int, Button] = {}
var night_toggle: NightToggle

func _ready() -> void:
	super()
	var group := ButtonGroup.new()
	for i in SMWTheme.CHOICES.size():
		var theme: Level.LevelTheme = SMWTheme.CHOICES[i]
		var data := SMWTheme.info(theme)
		var button := ThemeChoice.new()
		button.name = Level.LevelTheme.find_key(theme)
		button.position = Vector2(26 + (i % 2) * 120, 66 + (i / 2) * 73)
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
	# Upstream GodotWE's NightModeBtn placement: the lamp hangs from the title bar.
	night_toggle = NightToggle.new()
	night_toggle.name = "NightToggle"
	night_toggle.position = Vector2(298, 120)
	night_toggle.size = Vector2(63, 66)
	night_toggle.flat = true
	night_toggle.pressed.connect(toggle_night)
	add_child(night_toggle)
	status_changed.connect(_sync)
	%Editor.loaded.connect(_sync.bind(Status.CLOSED))

func choose(theme: Level.LevelTheme) -> bool:
	if not _editable() or theme not in SMWTheme.CHOICES:
		return false
	var editor: Editor = %Editor
	editor.history.set_theme(editor.level.current_sub_area, theme)
	_sync(Status.OPEN)
	close()
	return true

func toggle_night() -> bool:
	if not _editable():
		return false
	var editor: Editor = %Editor
	var area := editor.level.current_sub_area
	editor.history.set_night_mode(area, not area.night_mode)
	close_sound = CHANGE_NIGHT_DAY
	_sync(Status.OPEN)
	close()
	return true

func _editable() -> bool:
	var editor: Editor = %Editor
	return is_instance_valid(editor.level) and editor.level.status == Level.Status.EDITING \
			and editor.held_part == null and not editor._saving and editor.level.game_style == Level.GameStyle.SMW

func _sync(_old: Status) -> void:
	var editor: Editor = %Editor
	if not is_instance_valid(editor.level):
		return
	for theme in choices:
		choices[theme].disabled = editor.level.game_style != Level.GameStyle.SMW
		choices[theme].set_pressed_no_signal(editor.level.current_sub_area.level_theme == theme)
		(choices[theme] as ThemeChoice).refresh_effect()
	night_toggle.disabled = editor.level.game_style != Level.GameStyle.SMW
	night_toggle.night = editor.level.current_sub_area.night_mode
	night_toggle.refresh_effect()

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

class NightToggle extends ThemeChoice:
	const DAY = preload("uid://dv6oae3myu24m")
	const NIGHT = preload("uid://kba5wv1bfgwf")
	var night := false

	func _draw() -> void:
		draw_texture(NIGHT if night else DAY, Vector2(-18, -66), Color(1, 1, 1, 0.5 if disabled else 1.0))
		if effect != null:
			effect.draw()
