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


func open(with_sound := true) -> void:
	if status != Status.CLOSED:
		return
	if SceneManager.fade_in_progress():
		return
	if with_sound:
		menu_player.stream = preload("uid://c12e0n1f1kvrw")
		menu_player.play()
	get_tree().paused = true
	visible = true
	status = Status.OPEN


func close(with_sound := true) -> void:
	if status != Status.OPEN:
		return
	if with_sound:
		menu_player.stream = preload("uid://bj4i7k8axfjf5")
		menu_player.play()
	visible = false
	status = Status.CLOSED
	get_tree().paused = false


func _scene_changed() -> void:
	close(false)
