class_name WaveManager
extends Node
## Generates and runs enemy waves for each game mode.

signal wave_started(wave: int, is_boss: bool)
signal wave_cleared(wave: int)
signal all_waves_cleared

const INTERMISSION := 4.0

var enemies: EnemyManager
var mode := "campaign"
var wave := 0
var max_waves := 30
var auto_waves := true
var active := false
var _queue: Array = []   # [{t, type, lane}]
var _clock := 0.0
var _intermission := 2.5
var _finished := false


func setup(p_enemies: EnemyManager, p_mode: String) -> void:
	enemies = p_enemies
	mode = p_mode
	var md: Dictionary = GameData.MODES[mode]
	max_waves = md["waves"]
	auto_waves = md["auto_waves"]


func difficulty() -> Dictionary:
	return GameData.DIFFICULTIES[clampi(GameState.difficulty, 0, GameData.DIFFICULTIES.size() - 1)]


func is_boss_wave(w: int) -> bool:
	if mode == "boss_rush":
		return true
	return w % 5 == 0


func start_next_wave() -> void:
	if _finished:
		return
	wave += 1
	active = true
	_clock = 0.0
	_queue = _compose(wave)
	enemies.hp_mult = (1.0 + 0.11 * (wave - 1) + pow(maxf(0.0, wave - 15.0), 1.5) * 0.02) * float(difficulty()["hp"])
	wave_started.emit(wave, is_boss_wave(wave))
	if GameState.is_god("auto_complete_waves"):
		complete_wave_now()


func _compose(w: int) -> Array:
	var q: Array = []
	var count_mult: float = float(difficulty()["count"]) * GameState.god_value("spawn_mult", 1.0)
	if mode == "playground":
		count_mult *= 2.0
	var base := int((10 + w * 4.5) * count_mult)
	if mode == "boss_rush":
		base = int((6 + w * 2) * count_mult)
	var t := 0.0
	var interval := clampf(1.1 - w * 0.03, 0.18, 1.1) / maxf(1.0, count_mult * 0.6)
	var pool: Array = ["goblin"]
	if w >= 2: pool.append("skeleton")
	if w >= 4: pool.append("orc")
	if w >= 7: pool.append("demon")
	if w >= 10: pool.append("brute")
	if mode == "playground" or mode == "boss_rush":
		pool = GameData.REGULAR_TYPES.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = w * 7919 + hash(mode)
	var squad_lane := 0
	for i in base:
		if i % 6 == 0:
			squad_lane = rng.randi_range(0, WorldBuilder.LANE_COUNT - 1)
		var type: String = pool[rng.randi_range(0, pool.size() - 1)]
		if type == "brute" and rng.randf() < 0.6:
			type = "orc"
		q.append({"t": t, "type": type, "lane": squad_lane})
		t += interval * rng.randf_range(0.4, 1.4)
	if is_boss_wave(w):
		var boss: String = GameData.BOSS_TYPES[(w / 5) % GameData.BOSS_TYPES.size()] if mode != "boss_rush" else GameData.BOSS_TYPES[w % 2]
		q.append({"t": t * 0.5, "type": boss, "lane": 1})
	q.sort_custom(func(a, b): return a["t"] < b["t"])
	return q


func remaining_to_spawn() -> int:
	return _queue.size()


func complete_wave_now() -> void:
	_queue.clear()
	enemies.kill_all()


func spawn_army(type: String, count: int) -> void:
	for i in count:
		_queue.append({"t": _clock + i * 0.04, "type": type, "lane": i % WorldBuilder.LANE_COUNT})
	_queue.sort_custom(func(a, b): return a["t"] < b["t"])


func _process(delta: float) -> void:
	if _finished:
		return
	if not active:
		if auto_waves:
			_intermission -= delta
			if _intermission <= 0.0:
				start_next_wave()
		_drain_queue(delta)
		return
	_clock += delta
	_drain_queue(0.0)
	if _queue.is_empty() and enemies.alive_count() == 0:
		active = false
		_intermission = INTERMISSION
		GameState.record_wave(mode, wave)
		wave_cleared.emit(wave)
		if max_waves > 0 and wave >= max_waves:
			_finished = true
			all_waves_cleared.emit()


func _drain_queue(extra_delta: float) -> void:
	if not active:
		_clock += extra_delta
	var spawned := 0
	while not _queue.is_empty() and _queue[0]["t"] <= _clock and spawned < 40:
		var item: Dictionary = _queue.pop_front()
		var boss_scale := 1.0
		if GameData.ENEMIES[item["type"]].get("boss", false) and mode == "boss_rush":
			boss_scale = 0.5 + wave * 0.15
		enemies.spawn(item["type"], item["lane"], WorldBuilder.SPAWN_Z, boss_scale)
		spawned += 1


func reset() -> void:
	wave = 0
	active = false
	_finished = false
	_queue.clear()
	_clock = 0.0
	_intermission = 2.5
