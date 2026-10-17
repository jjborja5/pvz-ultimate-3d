extends Node
## Performance benchmark: for each quality preset and horde size, measures frame time,
## horde simulation / render-prep time, draw calls, triangles and video memory.
## Writes a markdown table to <out_file> (arg 0).
##   Real renderer:  xvfb-run ... godot --rendering-method mobile res://tests/benchmark.tscn -- out.md
var configs: Array = []
var cur := -1
var battle: Node
var t := 0.0
var samples: Array = []
var results: Array = []
var _last_us := 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for q in [0, 1, 2]:
		for n in [100, 300, 600]:
			configs.append([q, n])
	_next()

func _next():
	if battle:
		battle.queue_free()
		battle = null
	cur += 1
	if cur >= configs.size():
		_write()
		get_tree().quit()
		return
	GameState.set_quality(configs[cur][0])
	GameState.current_mode = "sandbox"
	GameState.current_map = "verdant_pass"
	GameState.settings["show_damage_numbers"] = true
	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	t = 0.0
	samples.clear()
	await get_tree().process_frame
	battle.god_fill_pads()
	battle.god_build_defenses()
	for i in configs[cur][1]:
		var e = battle.enemies.spawn(GameData.REGULAR_TYPES[i % GameData.REGULAR_TYPES.size()], i % 3, -20.0 - (i % 60) * 1.2)
		if e:
			e.speed = 0.15
			e.max_hp *= 50.0
			e.hp = e.max_hp
	_last_us = Time.get_ticks_usec()

func _process(_d):
	if battle == null:
		return
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last_us) / 1000.0
	_last_us = now
	t += _d
	if t > 1.0 and t < 4.0:
		samples.append([frame_ms, battle.enemies.stats["sim_us"], battle.enemies.stats["render_us"],
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)])
	elif t >= 4.0 and not samples.is_empty():
		var avg := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		for s in samples:
			for k in 6:
				avg[k] += s[k] / samples.size()
		results.append([GameState.QUALITY_PRESETS[configs[cur][0]]["name"], configs[cur][1], battle.enemies.alive_count(), avg])
		print("bench ", results[-1])
		samples.clear()
		_next()

func _write():
	var lines := ["| Quality | Enemies | Frame ms | Sim ms | Render-prep ms | Draw calls | Triangles | VRAM MB |", "|---|---|---|---|---|---|---|---|"]
	for r in results:
		var a: Array = r[3]
		lines.append("| %s | %d | %.1f | %.2f | %.2f | %d | %dk | %.0f |" % [r[0], r[2], a[0], a[1] / 1000.0, a[2] / 1000.0, a[3], a[4] / 1000, a[5] / 1048576.0])
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://benchmark.md"
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	print("\n".join(lines))
	GameState.set_quality(2)
