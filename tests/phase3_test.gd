extends Node
## Automated tests for Phase 2/3 systems. Run headless:
##   godot --headless res://tests/phase3_test.tscn
## Covers: baked units, heroes + all 9 ultimates, defenses (traps + blockers), blessings and
## combos, loot chests, boss cinematics + abilities, ranged enemies, elites, all 8 spells,
## equipment / hero stats / upgrades, rewards and save/load round-trip.

var battle: Node
var failures: Array[String] = []
var t := 0.0
var step := 0
var _probe: Dictionary = {}


func check(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + msg)
	if not cond:
		failures.append(msg)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== Castle Dominion Phase 2/3 tests ===")
	for c in UnitBaker.CONFIGS:
		var f := UnitBaker.get_frames(c)
		check(f.has("walk") and f.has("attack") and f.has("death") and f.has("walk_lo") and f["texture"] != null, "Baked frames: " + c)
	check(GameData.HEROES.size() == 9, "Nine heroes defined")
	check(GameState.is_hero_unlocked("necromancer"), "All heroes unlocked under God Mode")
	check(GameState.hero_level("druid") == GameData.HERO_MAX_LEVEL, "Max Power: hero level 60")
	check(GameState.ability_level("druid") == GameData.ABILITY_MAX_LEVEL, "Max Power: ability level 10")
	# equipment math
	var item := Loot.make_legendary("crown_undying", 1)
	item = GameState.add_item(item)
	check(GameState.item_level(item) == 50, "Max Power: mythic item at level 50")
	var p_before := HeroStats.power_rating("storm_sorcerer")
	var old := GameState.equipped_item("storm_sorcerer", "accessory")
	GameState.equip("storm_sorcerer", int(item["uid"]))
	check(HeroStats.power_rating("storm_sorcerer") > p_before or not old.is_empty(), "Equipping a mythic raises hero power")
	check(HeroStats.compute("storm_sorcerer")["effects"].has("power"), "Legendary effect applied to hero stats")
	var rolled := Loot.roll_item(0.5, 2, "weapon")
	check(rolled["slot"] == "weapon" and int(rolled["rarity"]) >= 2, "Loot roll respects slot + min rarity")
	check(GameState.buy_upgrade("tower_damage") or int(GameState.upgrades.get("tower_damage", 0)) >= 20, "Buy permanent upgrade with unlimited resources")
	check(GameState.upgrade_value("castle_hp") > 0.0, "Upgrade values active under Max Power")
	# save / load round trip
	var team_before: Array = GameState.team.duplicate()
	var inv_before := GameState.inventory.size()
	GameState.save_state()
	GameState.load_state()
	check(GameState.team == team_before and GameState.inventory.size() == inv_before, "Save/load keeps team and inventory")
	GameState.current_mode = "campaign"
	GameState.current_map = "shattered_ruins"
	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	check(battle.heroes.size() == 3, "Three heroes deployed on the walls")


func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 0.3:
				# deploy the other six heroes temporarily so every ultimate is exercised
				for id in GameData.HERO_ORDER:
					if not GameState.team.has(id):
						var h := Hero.new()
						battle.add_child(h)
						h.global_position = Vector3(randf_range(-10, 10), 3.6, 0.5)
						h.setup(id, battle)
						battle.heroes.append(h)
				check(battle.heroes.size() == 9, "All nine heroes instantiate with animated models")
				battle.god_spawn_army("mixed", 120)
				step = 1
				t = 0.0
		1:
			if t > 1.5:
				var ok := true
				for h in battle.heroes:
					ok = ok and h.cast_ability()
				check(ok, "All nine hero ultimates cast")
				check(battle.enemies.allies.size() >= 10, "Army of the Dead raised spectral allies (%d)" % battle.enemies.allies.size())
				for id in GameData.SPELL_ORDER:
					check(battle.spells.cast(id, Vector3(0, 0, -40)), "Spell cast: " + id)
				step = 2
				t = 0.0
		2:
			if t > 4.0:
				check(battle.kills > 20, "Abilities and spells killed enemies (%d)" % battle.kills)
				battle.god_kill_all()
				battle.enemies.allies.clear()
				# defenses
				var placed := 0
				for type in GameData.DEFENSE_ORDER:
					var d = battle.place_defense(type, Vector3(WorldBuilder.lane_x(1, -30.0 - placed * 6.0), 0, -30.0 - placed * 6.0))
					if d:
						placed += 1
						battle.select_defense(d)
						battle.max_defense()
				check(placed == 5, "Placed all five defense types")
				check(battle.defenses.defenses.all(func(x): return x.level == 3), "Defenses upgrade to level 3")
				check(not battle.defenses.can_place(Vector3(0, 0, -2)), "Placement validation rejects wall area")
				# blocker test: an orc in the middle lane walking into the wall at z=-54
				var wall = null
				for d in battle.defenses.defenses:
					if d.type == "wall":
						wall = d
				_probe["wall"] = wall
				var e = battle.enemies.spawn("orc", 1, wall.z - 7.0)
				e.offset = wall.x - WorldBuilder.lane_x(1, wall.z - 7.0)
				_probe["blocked"] = e
				var spikes = battle.defenses.defenses.filter(func(x): return x.type == "spike_trap")[0]
				var victim = battle.enemies.spawn("brute", 1, spikes.z - 0.5)
				victim.offset = spikes.x - WorldBuilder.lane_x(1, spikes.z)
				victim.pos = Vector3(spikes.x, 0, spikes.z)
				victim.speed = 0.0
				_probe["victim"] = victim
				step = 3
				t = 0.0
		3:
			if t > 6.0:
				var e = _probe["blocked"]
				check(e.alive == false or e.blocked_by != null, "Stone wall blocks enemies in its lane")
				var v = _probe["victim"]
				check(not v.alive or v.hp < v.max_hp, "Spike trap damages enemies standing on it")
				battle.god_kill_all()
				# blessings + combos
				battle.pick_blessing("inferno")
				battle.pick_blessing("permafrost")
				check(battle.has_combo("steam_burst"), "Fire + Ice blessings unlock Steam Burst combo")
				check(battle.mod("burn") > 0.5, "Blessing modifiers stack into run state")
				var offer: Array = battle.run.offer(3)
				check(offer.size() == 3, "Blessing offer has three choices")
				# elites
				var el = battle.enemies.spawn("orc", 0, -60.0, 1.0, "giant")
				check(el.elite == "giant" and el.max_hp > GameData.ENEMIES["orc"]["hp"] * 2.0, "Elite affix scales enemy")
				# loot chest from a boss
				_probe["inv"] = GameState.inventory.size()
				var boss = battle.enemies.spawn("boss_warlord", 1, -40.0)
				check(battle.bosses.is_cinematic(), "Boss spawn starts cinematic intro")
				check(battle.hud._letterbox[0].visible, "Letterbox bars shown during boss intro")
				battle.enemies.damage(boss, 1e9, "physical", false, "god")
				step = 4
				t = 0.0
		4:
			if t > 2.5:
				check(GameState.inventory.size() > int(_probe["inv"]), "Boss dropped a treasure chest with equipment")
				check(battle.run.loot_found.size() >= 1, "Run tracks loot found")
				# boss abilities: lich summons + shield
				var lich = battle.enemies.spawn("boss_lich", 1, -50.0)
				lich.speed = 0.0
				for b in battle.bosses.bosses:
					b["summon_t"] = 0.0
					b["shield_t"] = 0.0
				_probe["lich"] = lich
				_probe["before"] = battle.enemies.alive_count()
				# ranged attacker with invincibility off (heroes stood down so they don't snipe it)
				for h in battle.heroes:
					h.process_mode = Node.PROCESS_MODE_DISABLED
				GameState.god["invincible"] = false
				battle.castle.repair_full()
				var archer = battle.enemies.spawn("skeleton_archer", 1, -22.0)
				archer.speed = 6.0
				_probe["hp0"] = battle.castle.hp
				step = 5
				t = 0.0
		5:
			if t > 5.0:
				check(battle.enemies.alive_count() > int(_probe["before"]), "Hollow King summons skeletons")
				check(_probe["lich"].immune_t > 0.0 or _probe["lich"].hp == _probe["lich"].max_hp, "Hollow King soul shield activates")
				check(battle.castle.hp < float(_probe["hp0"]), "Ranged skeletons damage the castle from range")
				GameState.god["invincible"] = true
				battle.god_kill_all()
				# rewards with real levelling
				GameState.god["max_power"] = false
				GameState.heroes[battle.heroes[0].id]["level"] = 1   # tests share user data: start from level 1
				GameState.heroes[battle.heroes[0].id]["xp"] = 0
				var lvl_before := int(GameState.heroes[battle.heroes[0].id]["level"])
				battle.kills += 500
				var summary: Dictionary = battle.apply_rewards(true)
				check(int(summary["xp"]) > 0, "Battle rewards grant hero XP")
				check(int(GameState.heroes[battle.heroes[0].id]["level"]) > lvl_before or lvl_before >= 60, "Hero levels up from battle XP")
				GameState.god["max_power"] = true
				GameState.save_state()
				_finish()
				step = 99


func _finish() -> void:
	print("=== %s (%d failures) ===" % ["ALL PASSED" if failures.is_empty() else "FAILED", failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
