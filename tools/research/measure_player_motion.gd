extends Node
## Numerical measurement of the real PlayerMotion. Synthetic flat floor only.
## This does not exercise PlayerCollision, real input latency, or rendering.

const DT: float = 1.0 / 60.0

func _ready() -> void:
	var profile_path: String = "res://data/physics/base_physics.tres"
	var output_path: String = "res://local_debug_output/smmwe-research/smmneo-native-metrics.json"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size() - 1):
		if args[index] == "--profile":
			profile_path = args[index + 1]
		elif args[index] == "--output":
			output_path = args[index + 1]
	var p: PlayerPhysicsProfile = load(profile_path)
	var output: Dictionary = {}
	var traces: Dictionary = {}
	for running: bool in [false, true]:
		var m: PlayerMotion = PlayerMotion.new(p)
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.axis = 1.0
		f.run = running
		var limit: float = p.run_max if running else p.walk_max
		var frames: int = 0
		var distance: float = 0.0
		while m.velocity.x < limit and frames < 600:
			m.begin_tick(f, true, true, DT)
			distance += m.velocity.x * DT
			m.finish_tick(Vector2(m.velocity.x, 0.0), true, false, f)
			frames += 1
		output["accelerate_run" if running else "accelerate_walk"] = {"frames": frames, "seconds": frames * DT, "distance_px": distance, "last_speed": m.velocity.x}
		f.axis = 0.0
		frames = 0
		distance = 0.0
		while m.velocity.x > p.speed_epsilon and frames < 600:
			m.begin_tick(f, true, true, DT)
			distance += m.velocity.x * DT
			m.finish_tick(Vector2(m.velocity.x, 0.0), true, false, f)
			frames += 1
		output["release_run" if running else "release_walk"] = {"frames": frames, "seconds": frames * DT, "distance_px": distance}
	for speed: float in [0.0, p.walk_max, p.run_max]:
		for hold_frames: int in [1, 6, 12, 600]:
			var m: PlayerMotion = PlayerMotion.new(p)
			m.velocity.x = speed
			var f: PlayerInputFrame = PlayerInputFrame.new()
			f.axis = 1.0 if speed > 0.0 else 0.0
			f.run = speed > p.walk_max
			f.jump = true
			f.jump_pressed = true
			m.queue_jump(f, true)
			var y: float = 0.0
			var apex: float = 0.0
			var apex_frame: int = 0
			var frames: int = 0
			var trace: Array[Dictionary] = [{"frame": 0, "y_px": 0.0, "vx_px_s": speed, "vy_px_s": 0.0}]
			while frames < 600:
				f.jump = frames < hold_frames
				m.begin_tick(f, frames == 0, true, DT)
				y += m.velocity.y * DT
				frames += 1
				trace.append({"frame": frames, "y_px": y, "vx_px_s": m.velocity.x, "vy_px_s": m.velocity.y})
				if y < apex:
					apex = y
					apex_frame = frames
				if y >= 0.0:
					m.finish_tick(Vector2(m.velocity.x, 0.0), true, false, f)
					break
				m.finish_tick(m.velocity, false, false, f)
			output["jump_vx_%s_hold_%s" % [speed, hold_frames]] = {"height_px": -apex, "apex_frames": apex_frame, "air_frames": frames, "air_seconds": frames * DT}
			traces["jump_vx_%s_hold_%s" % [speed, hold_frames]] = trace
	for hold_frames: int in [1, 6, 12, 600]:
		var m: PlayerMotion = PlayerMotion.new(p)
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.spin = true
		f.spin_pressed = true
		m.queue_jump(f, true)
		var y: float = 0.0
		var apex: float = 0.0
		var apex_frame: int = 0
		var frames: int = 0
		while frames < 600:
			f.spin = frames < hold_frames
			m.begin_tick(f, frames == 0, true, DT)
			y += m.velocity.y * DT
			frames += 1
			if y < apex:
				apex = y
				apex_frame = frames
			if y >= 0.0:
				m.finish_tick(Vector2(m.velocity.x, 0.0), true, false, f)
				break
			m.finish_tick(m.velocity, false, false, f)
		output["spin_hold_%s" % hold_frames] = {"height_px": -apex, "apex_frames": apex_frame, "air_frames": frames, "air_seconds": frames * DT}
	var reverse: PlayerMotion = PlayerMotion.new(p)
	reverse.velocity.x = p.run_max
	var r: PlayerInputFrame = PlayerInputFrame.new()
	r.axis = -1.0
	r.run = true
	var frames: int = 0
	var zero_frame: int = 0
	var distance: float = 0.0
	while reverse.velocity.x > -p.run_max and frames < 600:
		reverse.begin_tick(r, true, true, DT)
		frames += 1
		if zero_frame == 0 and reverse.velocity.x <= 0.0:
			zero_frame = frames
		if reverse.velocity.x > 0.0:
			distance += reverse.velocity.x * DT
		reverse.finish_tick(Vector2(reverse.velocity.x, 0.0), true, false, r)
	output["reverse_run"] = {"zero_frame": zero_frame, "opposite_max_frame": frames, "forward_distance_px": distance}
	var coast: PlayerMotion = PlayerMotion.new(p)
	coast.velocity.x = p.run_max
	var walk_input: PlayerInputFrame = PlayerInputFrame.new()
	walk_input.axis = 1.0
	frames = 0
	while coast.velocity.x > p.walk_max and frames < 600:
		coast.begin_tick(walk_input, true, true, DT)
		coast.finish_tick(Vector2(coast.velocity.x, 0.0), true, false, walk_input)
		frames += 1
	output["release_run_key_keep_direction"] = {"frames": frames, "seconds": frames * DT}
	for grounded: bool in [false, true]:
		var m: PlayerMotion = PlayerMotion.new(p)
		m.velocity.x = p.run_max
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.axis = -1.0
		f.run = true
		var trace: Array[Dictionary] = [{"frame": 0, "vx_px_s": p.run_max}]
		var turn_frame: int = 0
		for frame: int in range(1, 181):
			m.begin_tick(f, grounded, true, DT)
			trace.append({"frame": frame, "vx_px_s": m.velocity.x})
			if turn_frame == 0 and m.velocity.x <= 0.0:
				turn_frame = frame
			m.finish_tick(Vector2(m.velocity.x, 0.0), grounded, false, f)
		var key: String = "reverse_ground" if grounded else "reverse_air"
		output[key] = {"sign_change_frame": turn_frame}
		traces[key] = trace
	output["traces"] = traces
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save motion measurement: " + output_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(output, "  "))
	print("PlayerMotion numerical measurement saved; %s metric groups." % (output.size() - 1))
	get_tree().quit()
