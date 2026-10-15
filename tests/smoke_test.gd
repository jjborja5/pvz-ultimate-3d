extends Node
## Automated gameplay smoke test. Run headless:
##   godot --headless res://tests/smoke_test.tscn
## Exercises: battle setup, waves, towers, spells, god mode actions, map switching data.

var battle: Node
var failures: Array[String] = []
var t := 0.0
var step := 0


func check(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + msg)
	if not cond:
		failures.append(msg)


func _ready() -> void:
	print("=== Castle Dominion smoke test ===")
	check(GameState.god["enabled"], "God Mode enabled by default")
	check(GameState.has_unlimited_resources(), "Unlimited resources active")
	check(GameState.currency_text("gold") == GameState.INFINITE_DISPLAY, "Gold displays as infinite")
	check(GameState.spend("gems", 999999), "Spending with unlimited resources always succeeds")
	for id in GameData.MAP_ORDER:
		check(GameState.is_map_unlocked(id), "Map unlocked: " + id)
	for type in GameData.ENEMIES:
		var m: ArrayMesh = Models.get_enemy(type)
		check(m != null and m.get_surface_count() == 1, "Enemy model builds: " + type)
	for type in GameData.TOWER_ORDER:
		for lv in range(1, 6):
			check(Models.tower(type, lv) != null and Models.tower_head(type, lv) != null, "Tower model %s L%d" % [type, lv])
	GameState.current_mode = "campaign"
	GameState.current_map = "verdant_pass"
	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	check(battle.castle.pads.size() == 12, "Castle has 12 build pads")


func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 0.5:
				battle.call_next_wave()
				check(battle.waves.wave == 1, "Wave 1 started")
				var tw = battle.build_tower(0, "archer")
				check(tw != null, "Built archer tower")
				battle.build_tower(4, "cannon")
				battle.build_tower(5, "lightning")
				battle.build_tower(8, "fire")
				battle.build_tower(9, "ice")
				battle.select_pad(0)
				battle.upgrade_selected()
				check(tw.level == 2, "Upgrade archer to level 2 (free)")
				battle.max_selected()
				check(tw.level == 5, "Max archer to level 5")
				battle.god_spawn_army("mixed", 100)
				step = 1
				t = 0.0
		1:
			if t > 2.0:
				check(battle.enemies.alive_count() > 50, "Army spawned (%d alive)" % battle.enemies.alive_count())
				var p: Vector3 = battle.enemies.enemies[0].pos
				check(battle.spells.cast("fireball", p), "Cast fireball")
				check(battle.spells.cast("fireball", p), "Re-cast immediately (no cooldowns)")
				check(battle.spells.cast("lightning", p), "Cast chain storm")
				check(battle.spells.cast("ice_storm", p), "Cast ice storm")
				check(battle.spells.cast("meteor", p), "Cast meteor")
				battle.god_spawn_boss()
				step = 2
				t = 0.0
		2:
			if t > 3.0:
				check(battle.kills > 0, "Enemies killed by towers/spells (%d)" % battle.kills)
				check(battle.current_boss != null, "Boss spawned and tracked")
				battle.god_fill_pads()
				var filled := 0
				for pad in battle.castle.pads:
					if pad["tower"] != null:
						filled += 1
				check(filled == 12, "Fill all pads")
				battle.god_kill_all()
				check(battle.enemies.alive_count() == 0, "Kill all enemies")
				# invincibility vs damage
				var hp0: float = battle.castle.hp
				battle.castle.take_damage(500.0, Vector3.ZERO)
				check(battle.castle.hp == hp0, "Invincible castle ignores damage")
				GameState.god["invincible"] = false
				battle.castle.take_damage(500.0, Vector3.ZERO)
				check(battle.castle.hp < hp0, "Castle takes damage when invincibility is off")
				GameState.god["invincible"] = true
				battle.castle.repair_full()
				# one hit kill
				GameState.god["one_hit_kill"] = true
				var e = battle.enemies.spawn("brute", 1, -30.0)
				battle.enemies.damage(e, 1.0)
				check(not e.alive, "One-hit kill")
				GameState.god["one_hit_kill"] = false
				# stress
				GameState.god["spawn_mult"] = 1.0
				battle.god_spawn_army("mixed", 500)
				step = 3
				t = 0.0
		3:
			if t > 4.0:
				print("  INFO  enemies alive under stress: %d, fps(headless) %.0f" % [battle.enemies.alive_count(), Engine.get_frames_per_second()])
				check(battle.enemies.alive_count() > 200, "Stress horde > 200 alive")
				battle.god_complete_wave()
				check(battle.enemies.alive_count() == 0, "Complete wave clears field")
				_finish()
				step = 99


func _finish() -> void:
	print("=== %s (%d failures) ===" % ["ALL PASSED" if failures.is_empty() else "FAILED", failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
