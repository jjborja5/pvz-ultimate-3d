extends Node
## On-device performance benchmark (Settings > Run Performance Benchmark).
## Loads a fully built battle with the current graphics preset, then holds 100, 300 and 600
## enemies on the field and records frame times, 1% lows, memory, draw calls and load time.
## Results are shown on screen, saved to user://benchmark_<preset>.txt and can be copied.

const STAGES := [100, 300, 600]
var WARMUP := 2.0
var MEASURE := 8.0

var battle: Node
var stage := -1
var t := 0.0
var frames: PackedFloat32Array = []
var results: Array = []
var load_ms := 0
var _last_us := 0
var _saved_mode := ""
var _saved_map := ""
var _saved_cap := 60
var _layer: CanvasLayer
var _status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_saved_mode = GameState.current_mode
	_saved_map = GameState.current_map
	_saved_cap = int(GameState.settings.get("fps_cap", 60))
	Engine.max_fps = 0   # measure headroom; the display's v-sync still limits mobile to 60
	GameState.current_mode = "sandbox"
	GameState.current_map = "verdant_pass"
	var t0 := Time.get_ticks_msec()
	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	load_ms = Time.get_ticks_msec() - t0
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	_status = UITheme.label("Benchmark starting...", 26, UITheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status.offset_left = -340
	_status.offset_right = 340
	_status.offset_top = 260
	_status.add_theme_constant_override("outline_size", 8)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_layer.add_child(_status)
	await get_tree().process_frame
	battle.god_fill_pads()
	battle.god_build_defenses()
	_next_stage()


func _next_stage() -> void:
	stage += 1
	if stage >= STAGES.size():
		_finish()
		return
	var target: int = STAGES[stage]
	var need: int = target - battle.enemies.alive_count()
	for i in need:
		var e = battle.enemies.spawn(GameData.REGULAR_TYPES[i % GameData.REGULAR_TYPES.size()], i % 3, -24.0 - (i % 70) * 1.1)
		if e:
			e.speed = 0.12
			e.max_hp *= 400.0
			e.hp = e.max_hp
	t = 0.0
	frames.clear()
	_last_us = Time.get_ticks_usec()


func _process(delta: float) -> void:
	if stage < 0 or stage >= STAGES.size():
		return
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	t += delta / maxf(Engine.time_scale, 0.01)
	_status.text = "Benchmark: %d enemies  (%d/%d)\n%s preset  •  %.0f FPS" % [STAGES[stage], stage + 1, STAGES.size(),
		GameState.quality_profile()["name"], Engine.get_frames_per_second()]
	if t < WARMUP:
		return
	frames.append(ms)
	if t >= WARMUP + MEASURE:
		results.append(_summarize())
		_next_stage()


func _summarize() -> Dictionary:
	var sorted := frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f in frames:
		total += f
	var avg := total / maxf(1.0, frames.size())
	var p99: float = sorted[int(sorted.size() * 0.99)] if sorted.size() > 0 else 0.0
	return {
		"enemies": battle.enemies.alive_count(),
		"avg_fps": 1000.0 / maxf(avg, 0.001),
		"low1_fps": 1000.0 / maxf(p99, 0.001),
		"avg_ms": avg,
		"worst_ms": sorted[-1] if sorted.size() > 0 else 0.0,
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"tris": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"ram_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"vram_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"sim_ms": battle.enemies.stats["sim_us"] / 1000.0,
	}


func report_text() -> String:
	var lines: Array[String] = []
	lines.append("Castle Dominion benchmark  v%s" % ProjectSettings.get_setting("application/config/version"))
	lines.append("Device: %s %s  •  GPU: %s" % [OS.get_name(), OS.get_model_name(), RenderingServer.get_video_adapter_name()])
	lines.append("Renderer: %s  •  Preset: %s  •  3D scale %.2f  •  Screen %s" % [
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), GameState.quality_profile()["name"],
		get_viewport().scaling_3d_scale, str(DisplayServer.window_get_size())])
	lines.append("Startup to menu: %d ms  •  Battle load: %d ms" % [GameState.boot_ms, load_ms])
	for r in results:
		lines.append("%d enemies: %.0f FPS avg, %.0f FPS 1%% low, %.1f ms avg, %.0f ms worst, %d draws, %dk tris, sim %.1f ms, RAM %d MB, VRAM %d MB" % [
			r["enemies"], r["avg_fps"], r["low1_fps"], r["avg_ms"], r["worst_ms"], r["draws"], int(r["tris"] / 1000),
			r["sim_ms"], r["ram_mb"], r["vram_mb"]])
	return "\n".join(lines)


func _finish() -> void:
	GameState.settings["fps_cap"] = _saved_cap
	GameState.apply_frame_cap()
	var text := report_text()
	print(text)
	var f := FileAccess.open("user://benchmark_%s.txt" % String(GameState.quality_profile()["name"]).to_lower(), FileAccess.WRITE)
	if f:
		f.store_string(text + "\n")
	battle.enemies.clear_all()
	get_tree().paused = true
	_status.text = ""
	var panel := PanelContainer.new()
	panel.theme = UITheme.get_theme()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.06, 0.04, 0.12, 0.95), UITheme.GOLD, 20, 3, 8))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -420
	panel.offset_bottom = 420
	_layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(UITheme.title("BENCHMARK", 48))
	var body := UITheme.label(text, 19, UITheme.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var copy := UITheme.button("Copy Results", UITheme.BLUE)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(text)
		copy.text = "Copied")
	v.add_child(copy)
	var back := UITheme.button("Back to Menu", UITheme.GREEN)
	back.pressed.connect(_exit)
	v.add_child(back)


func _exit() -> void:
	GameState.current_mode = _saved_mode
	GameState.current_map = _saved_map
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_exit()
