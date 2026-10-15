extends Node
## Persistent player state + permanent God Mode.
## God Mode is ON by default and never requires payment, ads or grinding.

signal god_changed(key: String)
signal settings_changed
signal unlocks_changed
signal inventory_changed
signal heroes_changed

const SAVE_PATH := "user://castle_dominion.cfg"
const INFINITE_DISPLAY := "∞"

## God Mode flags. Persisted between sessions.
var god := {
	"enabled": true,
	"invincible": true,
	"unlimited": true,
	"no_cooldowns": true,
	"free_upgrades": true,
	"one_hit_kill": false,
	"auto_complete_waves": false,
	"game_speed": 1.0,
	"attack_speed": 1.0,
	"spawn_mult": 1.0,
	"max_power": true,        # heroes, abilities, equipment and permanent upgrades at maximum
}

## Meta currencies (used fully in Phase 3). With unlimited resources they read as infinite.
var currencies := {
	"gold": 2500, "gems": 100, "diamonds": 20, "materials": 50,
	"energy": 30, "skill_points": 5, "summon_tickets": 3,
}

var unlocked_all := true
var unlocked_maps: Array = ["verdant_pass"]
var tower_meta_level := {}  # permanent per-tower bonus levels (Phase 3)

var settings := {
	"shadows": true,
	"particles_quality": 1.0,  # 0.25..1.0
	"show_damage_numbers": true,
	"sfx_volume": 0.8,
	"music_volume": 0.6,
}

## Hero progression: id -> {level, xp, ability_level, skin, equipped: {slot: item uid or -1}}
var heroes := {}
var unlocked_heroes: Array = ["archer", "fire_mage", "paladin"]
var team: Array = ["fire_mage", "paladin", "archer"]
## Equipment inventory: Array of item dictionaries (see Loot).
var inventory: Array = []
var next_uid := 1
## Permanent upgrades: id -> level
var upgrades := {}

var difficulty := 1
var current_map := "verdant_pass"
var current_mode := "campaign"
var best_wave := {}


func _ready() -> void:
	load_state()
	_ensure_heroes()
	if inventory.is_empty():
		_starter_items()
	apply_game_speed()


func _ensure_heroes() -> void:
	for id in GameData.HERO_ORDER:
		if not heroes.has(id):
			heroes[id] = {"level": 1, "xp": 0, "ability_level": 1, "skin": 0,
				"equipped": {"weapon": -1, "armor": -1, "accessory": -1}}
	team = team.filter(func(h): return GameData.HEROES.has(h))
	while team.size() < GameData.TEAM_SIZE:
		for id in GameData.HERO_ORDER:
			if not team.has(id) and team.size() < GameData.TEAM_SIZE:
				team.append(id)


func _starter_items() -> void:
	for slot in GameData.SLOTS:
		add_item(Loot.roll_item(0.0, 0, slot), false)
	add_item(Loot.make_legendary("emberfang", 1), false)
	save_state()


# ---------------------------------------------------------------- god mode

func is_god(key: String) -> bool:
	return bool(god.get("enabled", false)) and bool(god.get(key, false))


func set_god(key: String, value) -> void:
	god[key] = value
	if key == "game_speed" or key == "enabled":
		apply_game_speed()
	god_changed.emit(key)
	save_state()


func god_value(key: String, fallback: float = 1.0) -> float:
	if not god.get("enabled", false):
		return fallback
	return float(god.get(key, fallback))


func apply_game_speed() -> void:
	Engine.time_scale = clampf(god_value("game_speed", 1.0), 0.1, 8.0)


func has_unlimited_resources() -> bool:
	return is_god("unlimited")


func currency_text(key: String) -> String:
	if has_unlimited_resources():
		return INFINITE_DISPLAY
	return str(currencies.get(key, 0))


func can_afford(key: String, amount: int) -> bool:
	return has_unlimited_resources() or int(currencies.get(key, 0)) >= amount


func spend(key: String, amount: int) -> bool:
	if has_unlimited_resources():
		return true
	if int(currencies.get(key, 0)) < amount:
		return false
	currencies[key] = int(currencies[key]) - amount
	save_state()
	return true


func is_map_unlocked(map_id: String) -> bool:
	return unlocked_all or is_god("enabled") or unlocked_maps.has(map_id)


func unlock_everything() -> void:
	unlocked_all = true
	unlocked_maps = GameData.MAP_ORDER.duplicate()
	unlocked_heroes = GameData.HERO_ORDER.duplicate()
	grant_all_legendaries()
	unlocks_changed.emit()
	save_state()


func max_all_meta() -> void:
	for t in GameData.TOWER_ORDER:
		tower_meta_level[t] = GameData.TOWER_MAX_LEVEL
	max_all_upgrades()
	max_all_heroes()
	for it in inventory:
		it["level"] = int(GameData.RARITIES[int(it["rarity"])]["max_level"])
	inventory_changed.emit()
	unlock_everything()


# ---------------------------------------------------------------- heroes

func is_hero_unlocked(id: String) -> bool:
	return unlocked_all or is_god("enabled") or unlocked_heroes.has(id)


func unlock_hero(id: String) -> bool:
	if is_hero_unlocked(id):
		return true
	if not spend("gems", 300):
		return false
	unlocked_heroes.append(id)
	heroes_changed.emit()
	save_state()
	return true


func hero_level(id: String) -> int:
	if is_god("max_power"):
		return GameData.HERO_MAX_LEVEL
	return int(heroes[id]["level"])


func ability_level(id: String) -> int:
	if is_god("max_power"):
		return GameData.ABILITY_MAX_LEVEL
	return int(heroes[id]["ability_level"])


func add_hero_xp(id: String, xp: int) -> int:
	## Returns the number of levels gained.
	var h: Dictionary = heroes[id]
	var gained := 0
	h["xp"] = int(h["xp"]) + xp
	while int(h["level"]) < GameData.HERO_MAX_LEVEL and int(h["xp"]) >= GameData.hero_xp_to_next(int(h["level"])):
		h["xp"] = int(h["xp"]) - GameData.hero_xp_to_next(int(h["level"]))
		h["level"] = int(h["level"]) + 1
		gained += 1
	return gained


func upgrade_ability(id: String) -> bool:
	var h: Dictionary = heroes[id]
	if int(h["ability_level"]) >= GameData.ABILITY_MAX_LEVEL:
		return false
	if not spend("skill_points", 1):
		return false
	h["ability_level"] = int(h["ability_level"]) + 1
	heroes_changed.emit()
	save_state()
	return true


func level_up_hero(id: String) -> bool:
	## Buy a level with gold (instant, free under unlimited resources).
	var h: Dictionary = heroes[id]
	if int(h["level"]) >= GameData.HERO_MAX_LEVEL:
		return false
	if not spend("gold", GameData.hero_xp_to_next(int(h["level"])) * 2):
		return false
	h["level"] = int(h["level"]) + 1
	h["xp"] = 0
	heroes_changed.emit()
	save_state()
	return true


func set_skin(id: String, skin: int) -> void:
	heroes[id]["skin"] = clampi(skin, 0, GameData.SKINS.size() - 1)
	heroes_changed.emit()
	save_state()


func set_team_slot(slot: int, id: String) -> void:
	var existing := team.find(id)
	if existing >= 0:
		team[existing] = team[slot]
	team[slot] = id
	heroes_changed.emit()
	save_state()


func max_all_heroes() -> void:
	for id in heroes:
		heroes[id]["level"] = GameData.HERO_MAX_LEVEL
		heroes[id]["ability_level"] = GameData.ABILITY_MAX_LEVEL
	unlocked_heroes = GameData.HERO_ORDER.duplicate()
	heroes_changed.emit()
	save_state()


# ---------------------------------------------------------------- equipment

func add_item(item: Dictionary, save := true) -> Dictionary:
	item["uid"] = next_uid
	next_uid += 1
	inventory.append(item)
	inventory_changed.emit()
	if save:
		save_state()
	return item


func find_item(uid: int) -> Dictionary:
	for it in inventory:
		if int(it["uid"]) == uid:
			return it
	return {}


func item_level(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	if is_god("max_power"):
		return int(GameData.RARITIES[int(item["rarity"])]["max_level"])
	return int(item["level"])


func equipped_item(hero_id: String, slot: String) -> Dictionary:
	var uid := int(heroes[hero_id]["equipped"].get(slot, -1))
	return find_item(uid) if uid >= 0 else {}


func item_owner(uid: int) -> String:
	for id in heroes:
		for slot in heroes[id]["equipped"]:
			if int(heroes[id]["equipped"][slot]) == uid:
				return id
	return ""


func equip(hero_id: String, uid: int) -> void:
	var it := find_item(uid)
	if it.is_empty():
		return
	var prev := item_owner(uid)
	if prev != "":
		heroes[prev]["equipped"][it["slot"]] = -1
	heroes[hero_id]["equipped"][it["slot"]] = uid
	heroes_changed.emit()
	save_state()


func unequip(hero_id: String, slot: String) -> void:
	heroes[hero_id]["equipped"][slot] = -1
	heroes_changed.emit()
	save_state()


func item_upgrade_cost(item: Dictionary) -> Dictionary:
	var lv := int(item["level"])
	return {"gold": int(60 * pow(lv, 1.35) * (1 + int(item["rarity"]))), "materials": 1 + lv / 5 + int(item["rarity"])}


func upgrade_item(uid: int) -> bool:
	var it := find_item(uid)
	if it.is_empty():
		return false
	var max_lv := int(GameData.RARITIES[int(it["rarity"])]["max_level"])
	if int(it["level"]) >= max_lv:
		return false
	var cost := item_upgrade_cost(it)
	if not (can_afford("gold", cost["gold"]) and can_afford("materials", cost["materials"])):
		return false
	spend("gold", cost["gold"])
	spend("materials", cost["materials"])
	it["level"] = int(it["level"]) + 1
	inventory_changed.emit()
	save_state()
	return true


func max_item(uid: int) -> void:
	var it := find_item(uid)
	if it.is_empty():
		return
	it["level"] = int(GameData.RARITIES[int(it["rarity"])]["max_level"])
	inventory_changed.emit()
	save_state()


func salvage_item(uid: int) -> int:
	var it := find_item(uid)
	if it.is_empty():
		return 0
	var owner := item_owner(uid)
	if owner != "":
		unequip(owner, it["slot"])
	inventory.erase(it)
	var mats := (1 + int(it["rarity"])) * (2 + int(it["level"]) / 4)
	currencies["materials"] = int(currencies["materials"]) + mats
	inventory_changed.emit()
	save_state()
	return mats


func grant_all_legendaries() -> void:
	## God Mode: one of every legendary / mythic at max level (skips ones already owned).
	var owned := {}
	for it in inventory:
		if it.has("legendary"):
			owned[it["legendary"]] = true
	for id in GameData.LEGENDARIES:
		if not owned.has(id):
			var item := Loot.make_legendary(id, 1)
			item["level"] = int(GameData.RARITIES[int(item["rarity"])]["max_level"])
			add_item(item, false)
	inventory_changed.emit()
	save_state()


# ---------------------------------------------------------------- permanent upgrades

func upgrade_level(id: String) -> int:
	if is_god("max_power"):
		return int(GameData.UPGRADES[id]["max"])
	return int(upgrades.get(id, 0))


func upgrade_value(id: String) -> float:
	return upgrade_level(id) * float(GameData.UPGRADES[id]["per"])


func buy_upgrade(id: String) -> bool:
	var lv := int(upgrades.get(id, 0))
	if lv >= int(GameData.UPGRADES[id]["max"]):
		return false
	if not spend("gold", GameData.upgrade_cost(id, lv)):
		return false
	upgrades[id] = lv + 1
	save_state()
	return true


func max_all_upgrades() -> void:
	for id in GameData.UPGRADES:
		upgrades[id] = int(GameData.UPGRADES[id]["max"])
	save_state()


func add_currency(key: String, amount: int) -> void:
	currencies[key] = int(currencies.get(key, 0)) + amount


func record_wave(mode: String, wave: int) -> void:
	if wave > int(best_wave.get(mode, 0)):
		best_wave[mode] = wave
		save_state()


# ---------------------------------------------------------------- persistence

func save_state() -> void:
	var cfg := ConfigFile.new()
	for k in god:
		cfg.set_value("god", k, god[k])
	for k in currencies:
		cfg.set_value("currencies", k, currencies[k])
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.set_value("progress", "unlocked_all", unlocked_all)
	cfg.set_value("progress", "unlocked_maps", unlocked_maps)
	cfg.set_value("progress", "tower_meta_level", tower_meta_level)
	cfg.set_value("progress", "best_wave", best_wave)
	cfg.set_value("progress", "difficulty", difficulty)
	cfg.set_value("progress", "current_map", current_map)
	cfg.set_value("progress", "current_mode", current_mode)
	cfg.set_value("heroes", "data", heroes)
	cfg.set_value("heroes", "unlocked", unlocked_heroes)
	cfg.set_value("heroes", "team", team)
	cfg.set_value("inventory", "items", inventory)
	cfg.set_value("inventory", "next_uid", next_uid)
	cfg.set_value("upgrades", "levels", upgrades)
	cfg.set_value("meta", "save_version", 2)
	cfg.save(SAVE_PATH)


func load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in god:
		god[k] = cfg.get_value("god", k, god[k])
	for k in currencies:
		currencies[k] = cfg.get_value("currencies", k, currencies[k])
	for k in settings:
		settings[k] = cfg.get_value("settings", k, settings[k])
	unlocked_all = cfg.get_value("progress", "unlocked_all", unlocked_all)
	unlocked_maps = cfg.get_value("progress", "unlocked_maps", unlocked_maps)
	tower_meta_level = cfg.get_value("progress", "tower_meta_level", tower_meta_level)
	best_wave = cfg.get_value("progress", "best_wave", best_wave)
	difficulty = cfg.get_value("progress", "difficulty", difficulty)
	current_map = cfg.get_value("progress", "current_map", current_map)
	current_mode = cfg.get_value("progress", "current_mode", current_mode)
	heroes = cfg.get_value("heroes", "data", heroes)
	unlocked_heroes = cfg.get_value("heroes", "unlocked", unlocked_heroes)
	team = cfg.get_value("heroes", "team", team)
	inventory = cfg.get_value("inventory", "items", inventory)
	next_uid = cfg.get_value("inventory", "next_uid", next_uid)
	upgrades = cfg.get_value("upgrades", "levels", upgrades)
	if not GameData.MAPS.has(current_map):
		current_map = "verdant_pass"
	if not GameData.MODES.has(current_mode):
		current_mode = "campaign"


func set_setting(key: String, value) -> void:
	settings[key] = value
	settings_changed.emit()
	save_state()
