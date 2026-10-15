extends Node
## Persistent player state + permanent God Mode.
## God Mode is ON by default and never requires payment, ads or grinding.

signal god_changed(key: String)
signal settings_changed
signal unlocks_changed

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

var difficulty := 1
var current_map := "verdant_pass"
var current_mode := "campaign"
var best_wave := {}


func _ready() -> void:
	load_state()
	apply_game_speed()


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
	unlocks_changed.emit()
	save_state()


func max_all_meta() -> void:
	for t in GameData.TOWER_ORDER:
		tower_meta_level[t] = GameData.TOWER_MAX_LEVEL
	unlock_everything()


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
	if not GameData.MAPS.has(current_map):
		current_map = "verdant_pass"
	if not GameData.MODES.has(current_mode):
		current_mode = "campaign"


func set_setting(key: String, value) -> void:
	settings[key] = value
	settings_changed.emit()
	save_state()
