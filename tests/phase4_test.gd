extends Node
## Automated tests for Phase 4 systems. Run headless:
##   godot --headless res://tests/phase4_test.tscn
## Covers: every referenced SFX / music file exists and loads, audio buses + independent
## volumes, SFX cooldown limiting, quality presets, spatial grid queries, FX particle budget,
## boss identity (aura, enrage, cinematic, death sequence), all spells + ultimates under
## God Mode, and that God Mode flags are untouched.

var battle: Node
var failures: Array[String] = []
var t := 0.0
var step := 0
var _boss: EnemyManager.Enemy


func check(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + msg)
	if not cond:
		failures.append(msg)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== Castle Dominion Phase 4 tests ===")
	_test_audio()
	_test_quality()
	check(GameState.god["enabled"] and GameState.god["invincible"] and GameState.god["unlimited"] \
		and GameState.god["no_cooldowns"] and GameState.god["max_power"], "God Mode flags all active")
	GameState.current_mode = "sandbox"
	GameState.current_map = "molten_abyss"
	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)


func _scan(dir: String, re: RegEx, out: Dictionary) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			for m in re.search_all(FileAccess.get_file_as_string(dir.path_join(f))):
				out[m.get_string(1)] = true
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), re, out)


func _test_audio() -> void:
	var sfx := {}
	var re := RegEx.create_from_string("Audio\\.sfx\\(\"([a-z0-9_]+)\"")
	_scan("res://scripts", re, sfx)
	var missing: Array = []
	for n in sfx:
		if not ResourceLoader.exists(Audio.SFX_DIR + n + ".ogg"):
			missing.append(n)
	check(sfx.size() >= 25, "Code references %d distinct sound effects" % sfx.size())
	check(missing.is_empty(), "Every referenced SFX file exists %s" % str(missing))
	for m in ["menu", "battle", "boss", "victory", "defeat"]:
		var s = load(Audio.MUSIC_DIR + m + ".ogg")
		check(s is AudioStreamOggVorbis and s.get_length() > 3.0, "Music track loads: " + m)
	check(AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0, "Music and SFX buses exist")
	var old_m: float = GameState.settings.get("music_volume", 0.6)
	var old_s: float = GameState.settings.get("sfx_volume", 0.8)
	GameState.settings["music_volume"] = 0.0
	GameState.settings["sfx_volume"] = 1.0
	Audio.apply_volumes()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),
		"Music and SFX volumes are independent")
	GameState.settings["music_volume"] = old_m
	GameState.settings["sfx_volume"] = old_s
	Audio.apply_volumes()
	var before := Audio.plays
	Audio.sfx("coin")
	Audio.sfx("coin")   # within cooldown: dropped
	check(Audio.plays == before + 1, "SFX cooldown prevents mixer flooding")
	Audio.play_music("battle", 0.1)
	check(Audio.current_music() == "battle", "Battle music plays")


func _test_quality() -> void:
	var old := int(GameState.settings.get("quality", 2))
	GameState.set_quality(0)
	check(not GameState.settings["shadows"] and float(GameState.settings["particles_quality"]) < 0.5, "Low preset disables shadows, cuts particles")
	GameState.set_quality(2)
	check(GameState.settings["shadows"] and float(GameState.settings["particles_quality"]) == 1.0, "High preset enables shadows, full particles")
	GameState.set_quality(old)
	check(GameState.QUALITY_PRESETS.size() == 3, "Three graphics quality presets")


func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 0.5:
				_test_grid()
				_test_fx_budget()
				battle.god_spawn_boss("boss_lich")
				_boss = battle.current_boss
				step = 1
				t = 0.0
		1:
			if t > 0.3:
				check(_boss != null and _boss.alive, "Boss spawned via God panel")
				check(battle.bosses.is_cinematic(), "Boss intro cinematic active")
				check(battle.bosses.bosses.size() > 0 and is_instance_valid(battle.bosses.bosses[0]["aura"]), "Boss aura created")
				battle.enemies.damage(_boss, _boss.max_hp * 0.6, "physical", false)
				step = 2
				t = 0.0
		2:
			if t > 0.4:
				check(battle.bosses.bosses.size() > 0 and battle.bosses.bosses[0]["enraged"], "Boss enrages below 50% HP")
				var before := Audio.plays
				for id in GameData.SPELL_ORDER:
					battle.spells.force_cast(id, _boss.pos + Vector3(0, 0, 4))
				check(Audio.plays > before, "Spells play sound effects")
				for i in battle.heroes.size():
					battle.cast_hero(i)
				step = 3
				t = 0.0
		3:
			if t > 1.0:
				battle.enemies.damage(_boss, _boss.max_hp * 10.0, "physical", false)
				step = 4
				t = 0.0
		4:
			if t > 0.3:
				check(not _boss.alive, "Boss can be killed")
				check(battle.bosses.is_cinematic(), "Boss death slow-motion sequence plays")
				step = 5
				t = 0.0
		5:
			if t > 3.0:
				check(not battle.bosses.is_cinematic() and Engine.time_scale > 0.3, "Time scale restored after boss death")
				_finish()


func _test_grid() -> void:
	var em: EnemyManager = battle.enemies
	for i in 60:
		em.spawn("skeleton_warrior", -1, -10.0 - i * 0.7)
	em._rebuild_grid()
	var center: Vector3 = em.enemies[0].pos
	var brute := 0
	for e in em.enemies:
		var rr := 3.0 + e.radius
		if e.alive and Vector2(e.pos.x - center.x, e.pos.z - center.z).length_squared() <= rr * rr:
			brute += 1
	check(em.enemies_in_radius(center, 3.0).size() == brute, "Spatial grid query matches brute force (%d)" % brute)


func _test_fx_budget() -> void:
	var fx: FX = battle.fx
	check(fx.budget() > 0 and fx.budget() <= 70, "FX particle budget bounded (%d)" % fx.budget())


func _finish() -> void:
	print("=== %s (%d failures) ===" % ["ALL PASSED" if failures.is_empty() else "FAILED", failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)
