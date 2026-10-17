class_name PiranhaPlant
extends Enemy
@export_enum("up", "down", "left", "right") var orientation: String = "up"
enum Phase { HIDDEN, EXTENDING, EXPOSED, RETRACTING }
var phase: Phase = Phase.HIDDEN
var phase_left: int = 1
var extension: float = 0.0
var anchor: Vector2
var _out: Vector2 = Vector2.UP

func _config_section() -> String:
	return "piranha"

func _visual_group() -> String:
	return "piranha"

func _movement_animation() -> StringName:
	return &"idle"

func _ready() -> void:
	super._ready()
	anchor = global_position
	_out = {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}[orientation]
	physics_shape.disabled = true
	collision_mask = 0
	_update_exposure()

func can_damage_player() -> bool:
	return extension > 0.0 and not is_dead

func can_be_stomped(spinning: bool = false) -> bool:
	return spinning and can_damage_player()

func receive_hit(request: EntityHit) -> EntityHitResult:
	if is_dead or extension <= 0.0:
		return EntityHitResult.new()
	if request.kind == EntityHit.Kind.SPIN:
		return EntityHitResult.new(false, false, EntityHitResult.Bounce.SAFE_SPIN)
	if request.kind == EntityHit.Kind.STOMP:
		return EntityHitResult.new()
	# Alarm_5 changes source hardness halfway through either travel phase.
	if request.kind in [EntityHit.Kind.FIREBALL, EntityHit.Kind.SHELL, EntityHit.Kind.THROWN, EntityHit.Kind.EXPLOSION] and extension < float(_config["damage_threshold"]):
		return EntityHitResult.new(false, request.kind == EntityHit.Kind.FIREBALL)
	return super.receive_hit(request)

func _player_near_mouth() -> bool:
	# Rotate the source's upward proximity region to other pipe orientations.
	for node: Node in get_tree().get_nodes_in_group("entity_players"):
		var player: Player = node as Player
		if not is_instance_valid(player) or player.get_world_2d() != get_world_2d() or player.power_form == PowerUpManager.Form.DEAD:
			continue
		var offset: Vector2 = Vector2(player.global_position.x, player.feet_y()) - anchor
		var outward: float = offset.dot(_out)
		var lateral: float = absf(offset.dot(Vector2(-_out.y, _out.x)))
		if lateral <= float(_config["avoid_lateral"]) and outward >= -2.0 and outward <= float(_config["avoid_outward"]):
			return true
	return false

func _physics_process(delta: float) -> void:
	if is_dead:
		super._physics_process(delta)
		return
	if phase == Phase.HIDDEN and phase_left <= 1 and _player_near_mouth():
		return
	phase_left -= 1
	if phase == Phase.EXTENDING:
		extension = minf(16.0, extension + float(_config["speed"]) * delta)
	elif phase == Phase.RETRACTING:
		extension = maxf(0.0, extension - float(_config["speed"]) * delta)
	if phase_left <= 0:
		match phase:
			Phase.HIDDEN:
				phase = Phase.EXTENDING
				phase_left = int(_config["travel_frames"])
			Phase.EXTENDING:
				extension = 16.0
				phase = Phase.EXPOSED
				phase_left = int(_config["wait_frames"])
			Phase.EXPOSED:
				phase = Phase.RETRACTING
				phase_left = int(_config["travel_frames"])
			Phase.RETRACTING:
				extension = 0.0
				phase = Phase.HIDDEN
				phase_left = int(_config["wait_frames"])
	_update_exposure()
	_render(delta)

func _update_exposure() -> void:
	# Root remains the pipe-mouth anchor; hurt geometry covers only exposed length.
	var size: Vector2 = Vector2(12.0, maxf(0.1, extension)) if _out.x == 0.0 else Vector2(maxf(0.1, extension), 12.0)
	(hurt_area.get_node("CollisionShape2D") as CollisionShape2D).shape.set("size", size)
	hurt_area.position = _out * extension / 2.0
	stomp_area.position = _out * extension
	collision_layer = CollisionConfig.layer("enemies") if extension > 0.0 else 0
	# A queryable body is needed for fireballs, shells and explosions; no motion mask.
	physics_shape.disabled = extension <= 0.0
	(physics_shape.shape as RectangleShape2D).size = size
	physics_shape.position = hurt_area.position
	stomp_area.monitoring = extension > 0.0
	hurt_area.monitoring = extension > 0.0

func _render(delta: float) -> void:
	super._render(delta)
	if is_dead:
		$Exposed.visible = false
		sprite.visible = true
		return
	sprite.visible = extension > 0.0
	sprite.rotation = _out.angle() + PI / 2.0
	# Atlas crop prevents hidden parts being painted over the pipe.
	if sprite.visible:
		var base: AtlasTexture = sprite.sprite_frames.get_frame_texture(&"idle", sprite.frame) as AtlasTexture
		var cropped: AtlasTexture = AtlasTexture.new()
		cropped.atlas = base.atlas
		cropped.region = Rect2(base.region.position, Vector2(base.region.size.x, minf(extension, base.region.size.y)))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# AnimatedSprite keeps canonical frames; clip via a child region sprite below.
		$Exposed.texture = cropped
		$Exposed.rotation = sprite.rotation
		$Exposed.position = _out * extension / 2.0
		$Exposed.visible = true
	else:
		$Exposed.visible = false
	sprite.visible = false
