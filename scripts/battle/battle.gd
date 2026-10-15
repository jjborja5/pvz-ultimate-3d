extends Node3D
## Battle scene root. Wires together world, castle, horde, towers, spells, waves,
## camera, touch input and the HUD, and exposes God Mode actions.

const CAM_MIN_Z := -62.0
const CAM_MAX_Z := -16.0
const START_GOLD := 450

var map_id := "verdant_pass"
var mode := "campaign"

var fx: FX
var world: WorldBuilder
var castle: Castle
var enemies: EnemyManager
var projectiles: ProjectileSystem
var spells: SpellSystem
var waves: WaveManager
var hud: BattleHUD
var camera: Camera3D

var gold := START_GOLD
var kills := 0
var focus_target: EnemyManager.Enemy = null
var current_boss: EnemyManager.Enemy = null
var selected_pad := -1
var armed_spell := ""
var game_over := false

var _cam_look_z := -24.0
var _cam_zoom := 1.0
var _shake := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _touches := {}
var _pinch_dist := 0.0
var _focus_marker: MeshInstance3D


func _ready() -> void:
	map_id = GameState.current_map
	mode = GameState.current_mode
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()


func _build() -> void:
	fx = FX.new()
	fx.name = "FX"
	add_child(fx)
	world = WorldBuilder.new()
	world.name = "World"
	add_child(world)
	world.build(map_id)
	castle = Castle.new()
	castle.name = "Castle"
	add_child(castle)
	castle.build(fx)
	castle.ground_pads(world.height_at)
	enemies = EnemyManager.new()
	enemies.name = "Enemies"
	add_child(enemies)
	enemies.setup(world, fx)
	projectiles = ProjectileSystem.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	projectiles.setup(enemies, fx)
	spells = SpellSystem.new()
	spells.name = "Spells"
	add_child(spells)
	spells.setup(self)
	waves = WaveManager.new()
	waves.name = "Waves"
	add_child(waves)
	waves.setup(enemies, mode)

	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 52.0
	camera.far = 400.0
	add_child(camera)
	camera.make_current()
	fx.camera = camera
	_update_camera(0.0)

	_focus_marker = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.5
	cone.bottom_radius = 0.0
	cone.height = 1.0
	_focus_marker.mesh = cone
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.2, 0.15)
	fm.emission_enabled = true
	_focus_marker.material_override = fm
	_focus_marker.visible = false
	add_child(_focus_marker)

	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	hud = BattleHUD.new()
	hud.battle = self
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(hud)

	enemies.enemy_killed.connect(_on_enemy_killed)
	enemies.castle_hit.connect(_on_castle_hit)
	enemies.boss_spawned.connect(_on_boss_spawned)
	castle.destroyed.connect(_on_castle_destroyed)
	waves.wave_started.connect(_on_wave_started)
	waves.wave_cleared.connect(_on_wave_cleared)
	waves.all_waves_cleared.connect(_on_victory)

	if mode == "playground":
		god_fill_pads()
	elif mode == "sandbox":
		hud.show_hint("Sandbox: open the crown panel to spawn armies")


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	_update_camera(delta)
	if focus_target != null:
		if focus_target.alive:
			_focus_marker.visible = true
			_focus_marker.global_position = focus_target.pos + Vector3(0, 2.8 * focus_target.scale + 0.6 + sin(Time.get_ticks_msec() * 0.008) * 0.2, 0)
		else:
			focus_target = null
			_focus_marker.visible = false
	if current_boss != null and not current_boss.alive:
		current_boss = null


func _update_camera(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 2.5)
	var look := Vector3(0, 0, _cam_look_z)
	var offset := Vector3(0, 36.0, 34.0) * _cam_zoom
	var pos := look + offset
	if _shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.6
	camera.global_position = pos
	camera.look_at(look, Vector3.UP)


func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.2)


func castle_cast_point() -> Vector3:
	return Vector3(0, 9.0, 0.5)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() == 2:
			var p: Array = _touches.values()
			_pinch_dist = (p[0] as Vector2).distance_to(p[1])
			_dragging = true
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 2:
			var p: Array = _touches.values()
			var d := (p[0] as Vector2).distance_to(p[1])
			if _pinch_dist > 0.0:
				_cam_zoom = clampf(_cam_zoom * _pinch_dist / d, 0.55, 1.5)
			_pinch_dist = d
	elif event is InputEventMagnifyGesture:
		_cam_zoom = clampf(_cam_zoom / event.factor, 0.55, 1.5)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressing = true
				_dragging = false
				_press_pos = event.position
			else:
				if _pressing and not _dragging and _touches.size() <= 1:
					_tap(event.position)
				_pressing = false
				_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_zoom = clampf(_cam_zoom * 0.92, 0.55, 1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_zoom = clampf(_cam_zoom * 1.08, 0.55, 1.5)
	elif event is InputEventMouseMotion and _pressing:
		if _press_pos.distance_to(event.position) > 14.0:
			_dragging = true
		if _dragging and _touches.size() < 2:
			_cam_look_z = clampf(_cam_look_z - event.relative.y * 0.09 * _cam_zoom, CAM_MIN_Z, CAM_MAX_Z)


func ground_point(screen: Vector2) -> Vector3:
	var o := camera.project_ray_origin(screen)
	var d := camera.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector3.INF
	# intersect y = 0 then refine once against terrain height
	var t := -o.y / d.y
	var p := o + d * t
	var h := world.height_at(p.x, p.z)
	t = (h - o.y) / d.y
	return o + d * t


func _tap(screen: Vector2) -> void:
	if armed_spell != "":
		var p := ground_point(screen)
		if p != Vector3.INF:
			spells.cast(armed_spell, p)
			if not GameState.is_god("no_cooldowns"):
				arm_spell("")
		return
	# pads/towers are picked in screen space (they sit at different heights)
	var best := -1
	var best_d := 70.0
	for i in castle.pads.size():
		var wp: Vector3 = castle.pads[i]["pos"] + Vector3(0, 1.5, 0)
		if camera.is_position_behind(wp):
			continue
		var sp := camera.unproject_position(wp)
		var d := sp.distance_to(screen)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		select_pad(best)
		return
	# manual targeting: tap an enemy to focus fire
	var gp := ground_point(screen)
	if gp != Vector3.INF:
		var e := enemies.find_nearest(gp, 3.0)
		if e != null:
			focus_target = e
			hud.show_hint("Towers focusing fire on " + String(GameData.ENEMIES[e.type]["name"]))
			fx.hit_spark(enemies.enemy_center(e), Color(1, 0.3, 0.2))
			return
	deselect()


func arm_spell(id: String) -> void:
	armed_spell = id
	if id != "":
		deselect()
	hud.set_armed_spell(id)


# ------------------------------------------------------------------ towers

func select_pad(i: int) -> void:
	deselect()
	selected_pad = i
	var pad: Dictionary = castle.pads[i]
	if pad["tower"] != null:
		(pad["tower"] as Tower).show_range(true)
		hud.show_tower_sheet(pad["tower"])
	else:
		hud.show_build_sheet(i)


func deselect() -> void:
	if selected_pad >= 0 and selected_pad < castle.pads.size():
		var t = castle.pads[selected_pad]["tower"]
		if t != null:
			(t as Tower).show_range(false)
	selected_pad = -1
	hud.close_sheet()


func _pay(cost: int) -> bool:
	if GameState.has_unlimited_resources():
		return true
	if gold < cost:
		hud.show_hint("Not enough gold")
		return false
	gold -= cost
	return true


func build_tower(pad_index: int, type: String, level := 1, reselect := true) -> Tower:
	var pad: Dictionary = castle.pads[pad_index]
	if pad["tower"] != null:
		return pad["tower"]
	var cost: int = GameData.TOWERS[type]["cost"][0]
	if not _pay(cost):
		return null
	var t := Tower.new()
	add_child(t)
	t.global_position = pad["pos"] + Vector3(0, 0.2, 0)
	t.setup(type, level, self)
	t.total_spent = cost
	pad["tower"] = t
	(pad["node"] as Node3D).visible = false
	fx.shockwave(t.global_position, 2.5, Color(1, 0.85, 0.4, 0.8))
	fx.hit_spark(t.global_position + Vector3(0, 2, 0), Color(1, 0.9, 0.5))
	t.scale = Vector3(1, 0.2, 1)
	create_tween().tween_property(t, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if reselect:
		select_pad(pad_index)
	return t


func _selected_tower() -> Tower:
	if selected_pad < 0:
		return null
	return castle.pads[selected_pad]["tower"]


func upgrade_selected() -> void:
	var t := _selected_tower()
	if t == null or not t.can_upgrade():
		return
	var free := GameState.is_god("free_upgrades")
	var cost := t.upgrade_cost()
	if not free and not _pay(cost):
		return
	t.total_spent += 0 if free else cost
	t.set_level(t.level + 1)
	select_pad(selected_pad)


func max_selected() -> void:
	var t := _selected_tower()
	if t == null:
		return
	t.set_level(GameData.TOWER_MAX_LEVEL)
	select_pad(selected_pad)


func sell_selected() -> void:
	var t := _selected_tower()
	if t == null:
		return
	if not GameState.has_unlimited_resources():
		gold += int(t.total_spent * 0.6)
	var pad: Dictionary = castle.pads[selected_pad]
	pad["tower"] = null
	(pad["node"] as Node3D).visible = true
	fx.explosion(t.global_position + Vector3(0, 1, 0), 1.5, Color(0.8, 0.7, 0.5))
	t.queue_free()
	deselect()


# ------------------------------------------------------------------ waves / events

func call_next_wave() -> void:
	if not waves.active:
		waves.start_next_wave()


func _on_wave_started(w: int, is_boss: bool) -> void:
	hud.banner("WAVE %d" % w if not is_boss else "BOSS WAVE %d" % w, UITheme.GOLD if not is_boss else Color(1, 0.4, 0.3))


func _on_wave_cleared(w: int) -> void:
	if not game_over:
		var bonus := 25 + w * 5
		if not GameState.has_unlimited_resources():
			gold += bonus
		hud.show_hint("Wave %d cleared!  +%d gold" % [w, bonus])


func _on_enemy_killed(e: EnemyManager.Enemy) -> void:
	kills += 1
	if not GameState.has_unlimited_resources():
		gold += e.reward
	if e == focus_target:
		focus_target = null
		_focus_marker.visible = false
	if e.boss:
		shake(1.0)
		hud.banner("TYRANT SLAIN!", Color(1, 0.85, 0.3))
		hud.show_hint("Loot: +%d gold, +3 gems, +1 legendary material" % e.reward)
		if not GameState.has_unlimited_resources():
			GameState.currencies["gems"] = int(GameState.currencies["gems"]) + 3
			GameState.currencies["materials"] = int(GameState.currencies["materials"]) + 1
			GameState.save_state()


func _on_castle_hit(dmg: float, pos: Vector3) -> void:
	castle.take_damage(dmg, pos)
	if dmg >= 50.0:
		shake(0.4)


func _on_boss_spawned(e: EnemyManager.Enemy) -> void:
	current_boss = e
	shake(0.5)
	hud.banner(String(GameData.ENEMIES[e.type]["name"]).get_slice(",", 0).to_upper() + " APPROACHES", Color(1, 0.35, 0.25))
	fx.flash_light(Vector3(0, 10, -60), Models.enemy_glow(e.type), 8.0, 50.0, 1.5)


func _on_castle_destroyed() -> void:
	if game_over:
		return
	game_over = true
	GameState.record_wave(mode, waves.wave)
	fx.explosion(Vector3(0, 4, 0), 8.0, Color(1, 0.5, 0.2), true)
	hud.show_result(false, waves.wave - 1)


func _on_victory() -> void:
	game_over = true
	hud.show_result(true, waves.wave)


func toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	if p:
		hud.show_pause()
	else:
		hud.hide_modal()


func exit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ------------------------------------------------------------------ God Mode actions

func god_kill_all() -> void:
	var n := 0
	for e in enemies.enemies:
		if n < 12 and e.alive:
			fx.lightning([enemies.enemy_center(e) + Vector3(0, 30, 0), enemies.enemy_center(e)], Color(1.0, 0.9, 0.5), 0.5)
			n += 1
	enemies.kill_all()
	shake(0.6)


func god_complete_wave() -> void:
	waves.complete_wave_now()
	shake(0.4)


func god_spawn_army(type: String, count: int) -> void:
	if type == "mixed":
		for i in count:
			waves.spawn_army(GameData.REGULAR_TYPES[i % GameData.REGULAR_TYPES.size()], 1)
	else:
		waves.spawn_army(type, count)


func god_spawn_boss() -> void:
	var b: String = GameData.BOSS_TYPES[randi() % GameData.BOSS_TYPES.size()]
	enemies.spawn(b, 1)


func god_max_towers() -> void:
	for p in castle.pads:
		if p["tower"] != null and (p["tower"] as Tower).level < GameData.TOWER_MAX_LEVEL:
			(p["tower"] as Tower).set_level(GameData.TOWER_MAX_LEVEL)
	if selected_pad >= 0:
		select_pad(selected_pad)


func god_fill_pads() -> void:
	var i := 0
	for idx in castle.pads.size():
		if castle.pads[idx]["tower"] == null:
			var type: String = GameData.TOWER_ORDER[i % GameData.TOWER_ORDER.size()]
			var prev_unlimited: bool = GameState.god["unlimited"]
			var t := build_tower(idx, type, GameData.TOWER_MAX_LEVEL, false)
			if t == null and not prev_unlimited:
				break
			i += 1


func god_reset() -> void:
	## Restart the battle; unlocks, God Mode settings and progression are kept.
	get_tree().paused = false
	get_tree().reload_current_scene()


func god_change_map(id: String) -> void:
	GameState.current_map = id
	GameState.save_state()
	god_reset()
