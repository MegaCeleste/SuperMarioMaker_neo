# SPDX-License-Identifier: AGPL-3.0-or-later
class_name WarpDoor
extends Node2D
## The play-time door built from a [DoorPart] (source obj_door/obj_door_exit):
## drawn behind Mario, opened by pressing up while standing in it, and closed
## again after Mario comes out of it.

## Source image_speed 0.12 frames per tick.
const ANIMATION_FPS := 7.2
## Source alarm[3]: a door just used refuses Mario for 40 ticks.
const COOLDOWN_TICKS := 40

var part: DoorPart
var cooldown := 0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	z_as_relative = false
	z_index = GameConstants.Layers.Z_DECORATIONS
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = false
	_sprite.sprite_frames = SpriteLibrary.get_animations({
		"open": ["spr_door", ANIMATION_FPS, false],
		"close": ["spr_door_close", ANIMATION_FPS, false],
	})
	_sprite.animation = &"open"
	_sprite.frame = 0
	_sprite.animation_finished.connect(_animation_finished)
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	cooldown = maxi(0, cooldown - 1)
	if part.get_exit() == null or not is_instance_valid(part.get_exit().runtime) or not is_instance_valid(part.level):
		return
	var player := part.level.get_living_player()
	if player != null and player.sub_area == part.sub_area and can_enter(player):
		player.enter_door(self)


## Source obj_door Step: pressing up while standing on the ground inside the
## door, feet within the door's bottom cell.
func can_enter(player: Player) -> bool:
	var bottom := position.y + 32
	return cooldown == 0 and part.get_exit().runtime.cooldown == 0 and not player.is_traveling() \
			and Input.is_action_pressed(&"player_up") and player.is_on_floor() \
			and player.global_position.y >= bottom - 1 and player.global_position.y <= bottom + 6 \
			and player.global_position.x >= position.x and player.global_position.x <= position.x + 16


## The exit door, where Mario appears.
func get_exit() -> WarpDoor:
	return part.get_exit().runtime


func open() -> void:
	_sprite.play(&"open")
	part.level.get_node(^"%LevelTimer").paused = true
	EnemyEffect.sound_once(part.sub_area, SoundLibrary.path("snd_door"))


## Source obj_door Alarm_0: the entrance shuts at once when Mario leaves it.
func reset() -> void:
	_sprite.stop()
	_sprite.animation = &"open"
	_sprite.frame = 0
	cooldown = COOLDOWN_TICKS


func close() -> void:
	cooldown = COOLDOWN_TICKS
	_sprite.play(&"close")


func _animation_finished() -> void:
	if _sprite.animation == &"close":
		_sprite.animation = &"open"
		_sprite.frame = 0
		EnemyEffect.sound_once(part.sub_area, SoundLibrary.path("snd_door_close"))
