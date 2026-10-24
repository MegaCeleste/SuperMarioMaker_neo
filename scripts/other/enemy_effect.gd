# SPDX-License-Identifier: AGPL-3.0-or-later
class_name EnemyEffect
extends RefCounted
## Finite sprite/audio effects use the same area revision ownership as actors.


static func play_once(area: SubArea, sprite_name: StringName, at: Vector2, fps: float, source_smoke := true) -> AnimatedSprite2D:
	var sprite := SpriteLibrary.make_sprite(sprite_name)
	if source_smoke:
		sprite.set_meta(&"source_smoke", true)
	sprite.sprite_frames = SpriteLibrary.get_animations({"effect": [String(sprite_name), fps, false]})
	sprite.position = area.get_foreground().to_local(at)
	sprite.z_index = GameConstants.Layers.Z_PARTICLES
	sprite.play(&"effect")
	sprite.animation_finished.connect(sprite.queue_free)
	area.add_deferred(sprite)
	return sprite


static func sound_once(area: SubArea, path: String) -> void:
	var player := AudioStreamPlayer.new()
	player.add_to_group(&"enemy_effect_audio")
	player.stream = load(path)
	player.finished.connect(player.queue_free)
	player.ready.connect(player.play)
	area.add_deferred(player)


static func sound_if_idle(area: SubArea, path: String) -> void:
	for player in area.get_tree().get_nodes_in_group(&"enemy_effect_audio"):
		if player.stream != null and player.stream.resource_path == path and player.playing:
			return
	for pending in area._pending_spawns.values():
		var player: Node = pending.node
		if player is AudioStreamPlayer and player.stream != null and player.stream.resource_path == path:
			return
	sound_once(area, path)
