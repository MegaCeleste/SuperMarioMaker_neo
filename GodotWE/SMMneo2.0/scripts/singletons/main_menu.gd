extends CanvasLayer

enum Status {
	CLOSED,
	OPENING,
	OPEN,
	CLOSING,
}

var menu: Control
var menu_player: AudioStreamPlayer
var status: Status = Status.CLOSED


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	visible = false
	
	menu = preload("uid://b1fhtapnp8h8j").instantiate()
	menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(menu)
	
	get_tree().scene_changed.connect(_scene_changed)
	menu_player = menu.get_node(^"%MenuPlayer")
	menu.get_node(^"%BtnExit").pressed.connect(close)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_action_pressed("pause"):
			if status == Status.CLOSED:
				open()
			elif status == Status.OPEN:
				close()


func open(with_sound := true) -> void:
	if status != Status.CLOSED:
		return
	if SceneManager.fade_in_progress():
		return
	status = Status.OPENING
	
	if with_sound:
		menu_player.stream = preload("uid://c12e0n1f1kvrw")
		menu_player.play()
	
	get_tree().paused = true
	visible = true
	
	# Start positions
	var view_size = get_viewport().get_visible_rect().size
	menu.position = Vector2(view_size.x, 0)
	
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(menu, "position:x", 0.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	tween.finished.connect(func():
		status = Status.OPEN
	, CONNECT_ONE_SHOT)


func close(with_sound := true) -> void:
	if status != Status.OPEN:
		return
	status = Status.CLOSING
	
	if with_sound:
		menu_player.stream = preload("uid://bj4i7k8axfjf5")
		menu_player.play()
	
	var view_size = get_viewport().get_visible_rect().size
	
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	
	# Slide menu out to the right
	tween.tween_property(menu, "position:x", view_size.x, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	tween.finished.connect(func():
		visible = false
		status = Status.CLOSED
		get_tree().paused = false
	, CONNECT_ONE_SHOT)


func _scene_changed() -> void:
	close(false)
