# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerStar
extends Node
## Additive10s invincibility; it does not replace the underlying powerup.

const COLORS := [Color8(255, 255, 72), Color8(254, 138, 139), Color8(102, 245, 157)]
const SCORES := [200, 400, 800, 1000, 2000, 4000, 8000]
var player: Player
var remaining_ticks := 0
var combo := 0
var music: AudioStreamPlayer
var _saved_music: AudioStream
var _saved_playing := false
var _material: ShaderMaterial
var _original_material: Material
var _sparkles: AnimatedSprite2D
var _sensor: Area2D
var _color := 0
var _color_clock := 0
var _flash_alpha := 1.0
var _brightening := false
var _trail_clock := 0
var _warning_ticks := 0


func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	music.stream = SoundLibrary.stream("snd_starman").duplicate()
	music.stream.loop = true
	add_child(music)
	player.level.completed.connect(_completed)
	_sensor = Area2D.new()
	_sensor.name = "StarContact"
	_sensor.collision_layer = 0
	_sensor.collision_mask = 2
	_sensor.monitoring = false
	# obj_invincibility uses the fixed spr_bigmask at Mario's source origin.
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(12, 27)
	shape.position = Vector2(0, -18.5)
	_sensor.add_child(shape)
	_sensor.body_entered.connect(hit)
	player.add_child(_sensor)


func active() -> bool:
	return remaining_ticks > 0


func collect() -> void:
	if active():
		remaining_ticks = 600
		return
	remaining_ticks = 600
	combo = 0
	player.invulnerability_left = 0
	player.sprite.modulate.a = 1
	_warning_ticks = 420
	_saved_music = MusicPlayer.stream
	_saved_playing = MusicPlayer.playing
	MusicPlayer.stop()
	music.play()
	_original_material = player.sprite.material
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/player_star.gdshader")
	player.sprite.material = _material
	_flash_alpha = 1
	_brightening = false
	_color = 0
	_color_clock = 0
	_trail_clock = 0
	_sparkles = SpriteLibrary.make_sprite(&"spr_sparkles")
	_sparkles.name = "StarSparkles"
	_sparkles.position.y = -32
	_sparkles.z_index = GameConstants.Layers.Z_BEFORE_PLAYER - GameConstants.Layers.Z_PLAYER
	_sparkles.sprite_frames = SpriteLibrary.get_animations({"sparkles": ["spr_sparkles", 24, true]})
	_sparkles.play(&"sparkles")
	player.add_child(_sparkles)
	_sensor.set_deferred("monitoring", true)
	_update_material()


func tick() -> void:
	if not active():
		return
	if player.is_dead():
		cancel(false)
		return
	remaining_ticks -= 1
	if remaining_ticks <= 0:
		cancel(true)
		player.invulnerability_left = maxf(player.invulnerability_left, 2.0)
		return
	if _warning_ticks > 0:
		_warning_ticks -= 1
		if _warning_ticks == 0:
			EnemyEffect.sound_once(player.sub_area, SoundLibrary.path("snd_switchalert"))
	_flash_alpha += 0.15 if _brightening else -0.15
	if _flash_alpha < 0.3:
		_brightening = true
		_color = (_color + 1) % 3
	elif _flash_alpha > 0.9:
		_brightening = false
	_color_clock += 1
	if _color_clock == 5:
		_color_clock = 0
		_color = (_color + 1) % 3
	_update_material()
	_trail_clock += 1
	if _trail_clock == 10:
		_trail_clock = 0
		EnemyEffect.play_once(player.sub_area, &"spr_sparkletrail", player.global_position - Vector2(0, 32), 15)
	if player.level.status == Level.Status.PLAYING and _sensor.monitoring:
		for body in _sensor.get_overlapping_bodies():
			hit(body)


func _update_material() -> void:
	_material.set_shader_parameter(&"star_color", COLORS[_color])
	_material.set_shader_parameter(&"flash_alpha", _flash_alpha)


func hit(body: Node2D) -> bool:
	if not active() or player.is_dead() or player.is_frozen() or player.level.status != Level.Status.PLAYING:
		return false
	if not (body is Enemy or body is StompedGaloomba) or body.is_queued_for_deletion() or not body.is_visible_in_tree():
		return false
	var pickup := Utility.find_child_by_class(body, PickupComponent) as PickupComponent
	if pickup != null and pickup.get_holder() == player:
		return false
	# Star bypasses ordinary fire/shell hardness, including Thwomp and Chomp.
	body.kill(player.direction)
	if body is StompedGaloomba:
		EnemyEffect.sound_once(player.sub_area, "uid://c345xnns7om3m")
		return true
	if combo < SCORES.size():
		player.score += SCORES[combo]
	else:
		player.extra_lives += 1
	var suffix := "" if combo == 0 else str(combo + 1) if combo < 7 else "_1up"
	EnemyEffect.sound_once(player.sub_area, SoundLibrary.path("snd_kick" + suffix))
	combo += 1
	return true


func stop_music(restore: bool) -> void:
	if is_instance_valid(music):
		music.stop()
	if restore and _saved_playing and player.level.status == Level.Status.PLAYING \
			and MusicPlayer.stream == _saved_music and not MusicPlayer.playing:
		MusicPlayer.play()
	_saved_playing = false


func _completed(_player: Player) -> void:
	stop_music(false)


func cancel(restore := false) -> void:
	remaining_ticks = 0
	stop_music(restore)
	if is_instance_valid(player.sprite) and player.sprite.material == _material:
		player.sprite.material = _original_material
	if is_instance_valid(_sensor):
		_sensor.set_deferred("monitoring", false)
	if is_instance_valid(_sparkles):
		_sparkles.hide()
		_sparkles.queue_free()


func _exit_tree() -> void:
	cancel(false)
