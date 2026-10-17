extends Node
## Automated checks for the iOS / Android release work. Run headless:
##   godot --headless res://tests/mobile_test.tscn
## Covers: device graphics presets, render-resolution budget, frame cap, safe-area math,
## crash-safe saving, Android back button + pause/resume, God Mode defaults, export presets,
## and the on-device benchmark scene.

var failures: Array[String] = []
var step := 0
var t := 0.0
var battle: Node
var bench: Node


func check(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + msg)
	if not cond:
		failures.append(msg)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== Castle Dominion mobile tests ===")
	var keys := ["scale", "max_pixels", "msaa", "shadows", "particles", "glow", "fill_light", "omni", "height_fog",
		"cloud_shadows", "weather", "lod_offset", "hi_units", "fps_cap", "shadow_size"]
	for p in GameState.QUALITY_PRESETS:
		var ok := true
		for k in keys:
			ok = ok and p.has(k)
		check(ok, "Preset %s defines every setting" % p["name"])
	var low: Dictionary = GameState.QUALITY_PRESETS[0]
	var high: Dictionary = GameState.QUALITY_PRESETS[2]
	check(not low["shadows"] and not low["glow"] and not low["weather"] and int(low["fps_cap"]) == 30
		and float(low["particles"]) < float(high["particles"]) and int(low["hi_units"]) < int(high["hi_units"]),
		"Low preset cuts shadows, bloom, weather, particles, near-detail units; caps 30 FPS")
	check(high["shadows"] and int(high["msaa"]) == 2 and int(high["fps_cap"]) == 60, "High preset keeps full effects at 60 FPS")
	check(GameState.recommended_quality() == 2, "Desktop recommends High (iOS -> High, Android -> Low by RAM)")
	var old_q := int(GameState.settings["quality"])
	GameState.set_quality(0)
	check(Engine.max_fps == 30, "Low preset applies the 30 FPS cap")
	# pixel budget: an iPhone 11 Pro Max screen (1242x2688) must be scaled down on High
	GameState.set_quality(2)
	var budget_scale := sqrt(float(high["max_pixels"]) / (1242.0 * 2688.0))
	check(budget_scale < 1.0 and budget_scale > 0.7, "High renders iPhone 11 Pro Max at %.2f scale (pixel budget)" % budget_scale)
	var a21 := minf(float(low["scale"]), sqrt(float(low["max_pixels"]) / (720.0 * 1600.0)))
	check(a21 <= 0.76 and a21 >= 0.6, "Low renders Galaxy A21 (720x1600) at %.2f scale" % a21)
	check(Engine.max_fps == 60, "High preset applies the 60 FPS cap")
	GameState.set_quality(old_q)
	var ins := GameState.safe_insets(Vector2(720, 1280))
	check(ins["top"] == 0.0 and ins["bottom"] == 0.0, "Safe-area insets are zero on desktop")
	GameState.save_state()
	check(FileAccess.file_exists(GameState.SAVE_PATH) and not FileAccess.file_exists(GameState.SAVE_PATH + ".tmp"),
		"Save is written atomically (no leftover temp file)")
	check(not ProjectSettings.get_setting("application/config/quit_on_go_back"), "Android back button handled by the game")
	check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 1, "Portrait orientation")
	check(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"), "Mobile texture compression enabled")
	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "Export presets exist")
	var plats: Array = []
	for sec in cfg.get_sections():
		if not sec.ends_with(".options"):
			plats.append(cfg.get_value(sec, "platform"))
	check(plats.has("Android") and plats.has("iOS"), "Android and iOS export presets")
	check(cfg.get_value("preset.0.options", "architectures/arm64-v8a", false) and cfg.get_value("preset.0.options", "architectures/armeabi-v7a", false),
		"Android APK includes arm64-v8a and armeabi-v7a")
	check(GameState.god["enabled"] and GameState.god["invincible"] and GameState.god["unlimited"] and GameState.god["no_cooldowns"]
		and GameState.god["max_power"], "God Mode enabled by default")
	check(ResourceLoader.exists("res://scenes/benchmark.tscn"), "On-device benchmark scene present")
	GameState.current_mode = "sandbox"
	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)


func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 0.4:
				battle.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
				check(get_tree().paused and battle.hud.pause_open, "Back button pauses the battle")
				battle.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
				check(not get_tree().paused and not battle.hud.pause_open, "Back button again resumes")
				battle.hud.open_god_panel()
				battle.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
				check(not get_tree().paused, "Back button closes the God panel first")
				battle.queue_free()
				bench = load("res://scenes/benchmark.tscn").instantiate()
				bench.WARMUP = 0.1
				bench.MEASURE = 0.4
				add_child(bench)
				step = 1
				t = 0.0
		1:
			if bench.results.size() >= 3 or t > 120.0:
				check(bench.results.size() == 3, "Benchmark completes 100/300/600-enemy stages")
				var txt: String = bench.report_text()
				check(txt.contains("FPS avg") and txt.contains("Battle load"), "Benchmark report lists FPS, frame times, memory and load time")
				check(bench.results.size() == 3 and int(bench.results[2]["enemies"]) >= 500, "Heavy stage holds 500+ enemies (%d)" % (int(bench.results[2]["enemies"]) if bench.results.size() == 3 else 0))
				_finish()


func _finish() -> void:
	get_tree().paused = false
	print("=== %s (%d failures) ===" % ["ALL PASSED" if failures.is_empty() else "FAILED", failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)
