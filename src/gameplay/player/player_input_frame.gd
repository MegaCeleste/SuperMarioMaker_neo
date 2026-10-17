class_name PlayerInputFrame
extends RefCounted
## REQ-INP-001, REQ-PHYS-115.

var axis: float = 0.0
var down: bool = false
var up: bool = false
var run: bool = false
var run_pressed: bool = false
var run_released: bool = false
var jump: bool = false
var spin: bool = false
var jump_pressed: bool = false
var spin_pressed: bool = false
var jump_released: bool = false
var spin_released: bool = false


static func capture() -> PlayerInputFrame:
	var frame: PlayerInputFrame = PlayerInputFrame.new()
	frame.axis = InputManager.axis(&"move_left", &"move_right")
	frame.down = InputManager.pressed(&"move_down")
	frame.up = InputManager.pressed(&"move_up")
	frame.run = InputManager.pressed(&"run")
	frame.jump = InputManager.pressed(&"jump")
	frame.spin = InputManager.pressed(&"spin_jump")
	return frame


func jump_held(from_spin: bool) -> bool:
	return spin if from_spin else jump


func as_dictionary() -> Dictionary:
	return {"axis": axis, "down": down, "up": up, "run": run, "jump": jump, "spin": spin,
		"jump_pressed": jump_pressed, "spin_pressed": spin_pressed, "run_pressed": run_pressed,
		"jump_released": jump_released, "spin_released": spin_released, "run_released": run_released}
