# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PSwitchTimer
extends Node
## Source obj_levelmanager P-switch state (Other_11, Alarm_10, Step_2): 600
## ticks of snd_switchsong, snd_switchalert once 100-120 ticks before the end,
## and coins and plain turn blocks trading places while it runs (source
## obj_coin/obj_flipblock Step, convertirse). Pressing again restarts the clock.

const DURATION_TICKS := 600
const COIN = preload("uid://dt15xtlk2twqj")
const TURN_BLOCK = preload("uid://d1pyovyuwelpw")

var level: Level
## Ticks left; zero when no P-switch is running.
var ticks := 0
var _warned := false


## Starts or restarts the P-switch effect in [param on].
static func activate(on: Level) -> void:
	var timer: PSwitchTimer = on.get_node_or_null(^"PSwitchTimer")
	if timer == null:
		timer = PSwitchTimer.new()
		timer.name = "PSwitchTimer"
		timer.level = on
		on.add_child(timer)
	timer._start()


static func is_active(on: Level) -> bool:
	var timer: PSwitchTimer = on.get_node_or_null(^"PSwitchTimer")
	return timer != null and timer.ticks > 0


func _ready() -> void:
	level.editing.connect(_reset)


func _start() -> void:
	var running := ticks > 0
	ticks = DURATION_TICKS
	_warned = false
	if level.music:
		var song := SoundLibrary.stream("snd_switchsong")
		if song != null:
			# Like SMWTheme.music_for(): the switch song always loops.
			song.loop = true
			MusicPlayer.stream = song
			MusicPlayer.play()
	if not running:
		_swap(true)


func _physics_process(_delta: float) -> void:
	if ticks <= 0 or level.status != Level.Status.PLAYING:
		return
	ticks -= 1
	if not _warned and ticks > 100 and ticks < 120:
		_warned = true
		EnemyEffect.sound_once(level.current_sub_area, SoundLibrary.path("snd_switchalert"))
	if ticks == 0:
		_swap(false)
		if level.music:
			MusicPlayer.stream = SMWTheme.music_for(level.current_sub_area, false)
			MusicPlayer.play()


# Editing rebuilds every object, so only the clock needs clearing.
func _reset() -> void:
	ticks = 0


## Coins become turn blocks and plain turn blocks become coins; ending the
## effect turns back exactly the objects it changed.
func _swap(active: bool) -> void:
	var area := level.current_sub_area
	for node in area.get_foreground().get_children():
		if node.is_queued_for_deletion():
			continue
		var changed: bool = node.has_meta(&"pswitch")
		if node is Coin and (active != changed):
			_replace(node, TURN_BLOCK.instantiate(), area, active)
		elif node is TurnBlockTile and (active != changed) and node.is_plain():
			_replace(node, COIN.instantiate(), area, active)


func _replace(old: Node2D, replacement: Node2D, area: SubArea, active: bool) -> void:
	replacement.global_position = old.global_position
	if active:
		replacement.set_meta(&"pswitch", true)
	old.queue_free()
	area.add_deferred(replacement)
