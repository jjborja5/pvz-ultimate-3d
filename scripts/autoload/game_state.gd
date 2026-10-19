extends Node
## Persistent player state + permanent God Mode.
## God Mode is ON by default and never requires payment, ads or grinding.

signal god_changed(key: String)
signal settings_changed
signal safe_area_changed
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
	"quality": 2,              # 0 Low, 1 Medium, 2 High
	"shadow_distance": 80.0,
	"show_fps": false,
	"fps_cap": 60,
	"ui_top_margin": 0.0,      # extra clearance under browser / Claude viewer toolbars (canvas units)
	"ui_bottom_margin": 0.0,             # 30 or 60; Low defaults to 30 for steady frame pacing on weak phones
}

## Graphics presets. Low targets entry-level Android phones (e.g. Galaxy A21), High targets
## recent iPhones (e.g. iPhone 11 Pro Max). Nothing here removes gameplay: only rendering cost.
##   scale / max_pixels  3D render resolution (fraction of screen, capped to a pixel budget)
##   particles           particle multiplier + FX budget     glow / fill_light / omni   lighting extras
##   height_fog / cloud_shadows / weather                    environmental effects
##   lod_offset / hi_units                                   distance where enemies switch to low-poly frames
const QUALITY_PRESETS := [
	{"name": "Low", "scale": 0.75, "max_pixels": 650000, "msaa": 0, "shadows": false, "shadow_size": 1024,
		"particles": 0.35, "shadow_distance": 50.0, "unit_shadows": false, "lod_offset": -8.0, "hi_units": 40,
		"weather": false, "glow": false, "fill_light": false, "omni": false, "height_fog": false,
		"cloud_shadows": false, "fps_cap": 30},
	{"name": "Medium", "scale": 0.85, "max_pixels": 1300000, "msaa": 0, "shadows": true, "shadow_size": 1024,
		"particles": 0.7, "shadow_distance": 60.0, "unit_shadows": false, "lod_offset": -16.0, "hi_units": 90,
		"weather": true, "glow": true, "fill_light": true, "omni": true, "height_fog": true,
		"cloud_shadows": true, "fps_cap": 60},
	{"name": "High", "scale": 1.0, "max_pixels": 2300000, "msaa": 2, "shadows": true, "shadow_size": 2048,
		"particles": 1.0, "shadow_distance": 80.0, "unit_shadows": true, "lod_offset": -20.0, "hi_units": 140,
		"weather": true, "glow": true, "fill_light": true, "omni": true, "height_fog": true,
		"cloud_shadows": true, "fps_cap": 60},
]


func quality_profile() -> Dictionary:
	return QUALITY_PRESETS[clampi(int(settings.get("quality", 2)), 0, QUALITY_PRESETS.size() - 1)]


func q(key: String):
	## Shortcut for a value of the active graphics preset.
	return quality_profile()[key]


static func recommended_quality() -> int:
	## Device-based default: iPhones get High, Android phones Low unless they have lots of RAM
	## (a proxy for a flagship GPU), desktops High.
	if OS.has_feature("web"):
		return 0   # browser build: single-threaded WebAssembly + WebGL 2, so start light
	if OS.has_feature("ios"):
		return 2
	if OS.has_feature("android"):
		var ram := int(OS.get_memory_info().get("physical", 0))
		return 1 if ram >= 7 * 1024 * 1024 * 1024 else 0
	return 2


func set_quality(level: int) -> void:
	## Applies a preset to the individual graphics settings.
	settings["quality"] = clampi(level, 0, QUALITY_PRESETS.size() - 1)
	var p := quality_profile()
	settings["shadows"] = p["shadows"]
	settings["particles_quality"] = p["particles"]
	settings["shadow_distance"] = p["shadow_distance"]
	settings["fps_cap"] = p["fps_cap"]
	apply_frame_cap()
	settings_changed.emit()
	save_state()


func apply_frame_cap() -> void:
	Engine.max_fps = int(settings.get("fps_cap", 60))


func render_scale_for(vp: Viewport) -> float:
	## Preset scale, reduced further so the 3D pass never exceeds the preset's pixel budget
	## (a 1242x2688 iPhone screen at scale 1.0 would be 3.3 MP).
	var p := quality_profile()
	var px := float(vp.get_visible_rect().size.x * vp.get_visible_rect().size.y)
	if vp == get_tree().root:
		var ws := DisplayServer.window_get_size()
		px = float(ws.x * ws.y)
	var sc: float = p["scale"]
	if px > 0.0:
		sc = minf(sc, sqrt(float(p["max_pixels"]) / px))
	return clampf(sc, 0.4, 1.0)


func apply_viewport_quality(vp: Viewport) -> void:
	var p := quality_profile()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = render_scale_for(vp)
	vp.msaa_3d = Viewport.MSAA_2X if int(p["msaa"]) == 2 else Viewport.MSAA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(int(p["shadow_size"]), true)

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
var boot_ms := 0        # process start -> main menu ready (measured once per launch)
var current_map := "verdant_pass"
var current_mode := "campaign"
var best_wave := {}


func _ready() -> void:
	var first_run := not FileAccess.file_exists(SAVE_PATH)
	load_state()
	_ensure_heroes()
	if first_run:
		set_quality(recommended_quality())   # e.g. High on iPhone 11 Pro Max, Low on Galaxy A21
	if inventory.is_empty():
		_starter_items()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):   # testing: force a preset, e.g. -- --quality=0
			set_quality(int(arg.get_slice("=", 1)))
	apply_frame_cap()
	apply_game_speed()
	get_tree().root.size_changed.connect(func(): safe_area_changed.emit())


func _notification(what: int) -> void:
	# Phones can kill a backgrounded app at any time: persist everything when we lose focus.
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			save_state()


# ---------------------------------------------------------------- mobile screen

func safe_insets(canvas_size: Vector2) -> Dictionary:
	## Notch / home-indicator insets in canvas units {top, bottom, left, right}.
	var ws := DisplayServer.window_get_size()
	var out := _device_insets(canvas_size, ws)
	out["top"] += float(settings.get("ui_top_margin", 0.0))
	out["bottom"] += float(settings.get("ui_bottom_margin", 0.0))
	return out


func _device_insets(canvas_size: Vector2, ws: Vector2i) -> Dictionary:
	var out := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--safe-area=") and ws.y > 0:   # testing: simulate a notch, "top,bottom" in window px
			var parts := arg.get_slice("=", 1).split(",")
			out["top"] = float(parts[0]) * canvas_size.y / float(ws.y)
			out["bottom"] = float(parts[1]) * canvas_size.y / float(ws.y)
			return out
	if ws.x <= 0 or ws.y <= 0 or not OS.has_feature("mobile"):
		return out
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return out
	var k := canvas_size.y / float(ws.y)
	out["top"] = maxf(0.0, safe.position.y) * k
	out["bottom"] = maxf(0.0, screen.y - safe.end.y) * k
	out["left"] = maxf(0.0, safe.position.x) * k
	out["right"] = maxf(0.0, screen.x - safe.end.x) * k
	return out


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
	# write-then-rename so a phone killing the app mid-save never corrupts the save file
	var tmp := SAVE_PATH + ".tmp"
	if cfg.save(tmp) == OK:
		DirAccess.rename_absolute(tmp, SAVE_PATH)


func load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK and cfg.load(SAVE_PATH + ".tmp") != OK:
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
	if key.begins_with("ui_") and key.ends_with("_margin"):
		safe_area_changed.emit()
	save_state()
