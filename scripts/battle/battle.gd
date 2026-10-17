extends Node3D
## Battle scene root. Wires together world, castle, horde, towers, heroes, defenses,
## spells, waves, roguelike run state, loot, boss director, camera, touch input and HUD,
## and exposes God Mode actions.

const CAM_MIN_Z := -62.0
const CAM_MAX_Z := -10.0
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
var defenses: DefenseSystem
var loot: LootDrops
var bosses: BossDirector
var run := RunState.new()
var heroes: Array[Hero] = []
var hud: BattleHUD
var camera: Camera3D

var gold := START_GOLD
var kills := 0
var focus_target: EnemyManager.Enemy = null
var current_boss: EnemyManager.Enemy = null
var selected_pad := -1
var selected_defense: DefenseSystem.Defense = null
var armed_spell := ""
var placing_defense := ""
var game_over := false
var rewards_applied := false

var _cam_look_z := -15.0
var _cam_zoom := 1.0
var _shake := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _touches := {}
var _pinch_dist := 0.0
var _focus_marker: MeshInstance3D
var _elem_bonus := {}
var _hero_effects: Array = []
var _auto_meteor_t := 18.0
var _auto_thunder_t := 10.0
var _cine_blend := 0.0


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
	enemies.damage_modifier = _damage_mod
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
	defenses = DefenseSystem.new()
	defenses.name = "Defenses"
	add_child(defenses)
	defenses.setup(self)
	loot = LootDrops.new()
	loot.name = "Loot"
	add_child(loot)
	loot.setup(self)
	bosses = BossDirector.new()
	bosses.name = "Bosses"
	add_child(bosses)
	bosses.setup(self)

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
	_focus_marker.material_override = fm
	_focus_marker.visible = false
	add_child(_focus_marker)

	_deploy_heroes()
	_apply_castle_stats()
	gold = START_GOLD + int(GameState.upgrade_value("start_gold"))

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
	enemies.ranged_attack.connect(_on_ranged_attack)
	enemies.blocker_hit.connect(func(b, dmg, _e): b.take_damage(dmg))
	castle.destroyed.connect(_on_castle_destroyed)
	waves.wave_started.connect(_on_wave_started)
	waves.wave_cleared.connect(_on_wave_cleared)
	waves.all_waves_cleared.connect(_on_victory)
	loot.item_found.connect(func(item): hud.loot_toast(item))

	Audio.play_music("battle")
	if mode == "playground":
		god_fill_pads()
	elif mode == "sandbox":
		hud.show_hint("Sandbox: open the crown panel to spawn armies")


func _deploy_heroes() -> void:
	var posts := castle.hero_posts
	for i in mini(GameState.team.size(), posts.size()):
		var id: String = GameState.team[i]
		if not GameData.HEROES.has(id):
			continue
		var h := Hero.new()
		add_child(h)
		h.global_position = posts[i]
		h.setup(id, self)
		heroes.append(h)
	# legendary bonuses that apply battle-wide
	for h in heroes:
		_hero_effects.append_array(h.stats["effects"])
	_elem_bonus = {
		"fire": (0.25 if _hero_effects.has("ignite") else 0.0) + (0.5 if _hero_effects.has("dragon") else 0.0),
		"ice": 0.25 if _hero_effects.has("chill") else 0.0,
		"holy": 0.4 if _hero_effects.has("holy_boost") else 0.0,
		"nature": 0.35 if _hero_effects.has("nature_boost") else 0.0,
		"shadow": 0.35 if _hero_effects.has("nature_boost") else 0.0,
	}


func _apply_castle_stats() -> void:
	var hp_bonus := GameState.upgrade_value("castle_hp") + mod("fortify")
	for h in heroes:
		hp_bonus += float(h.stats["castle_hp"])
	castle.set_max_hp(Castle.BASE_HP * (1.0 + hp_bonus))
	castle.armor = GameState.upgrade_value("castle_armor") + (0.25 if _hero_effects.has("fortress") else 0.0)


# ------------------------------------------------------------------ run modifiers

func mod(key: String) -> float:
	return run.mod(key)


func has_combo(id: String) -> bool:
	return run.has_combo(id)


func _damage_mod(e: EnemyManager.Enemy, amount: float, element: String, source: String) -> float:
	var a := amount * (1.0 + mod("el_" + element) + float(_elem_bonus.get(element, 0.0)))
	if source == "tower":
		a *= 1.0 + GameState.upgrade_value("tower_damage")
	if e.boss or e.elite != "":
		a *= 1.0 + mod("boss_dmg")
	if mod("crit") > 0.0 and randf() < mod("crit"):
		a *= 2.5
	var slowed := e.slow > 0.0 or e.frozen_t > 0.0
	if element == "lightning":
		if has_combo("superconductor") and slowed:
			a *= 2.0
		if has_combo("wildfire"):
			enemies.apply_burn(e, a * 0.2, 3.0)
	if element == "physical" and has_combo("shatter") and e.frozen_t > 0.0:
		a *= 3.0
	if element == "fire" and has_combo("steam_burst") and slowed and source != "steam":
		fx.frost_burst(e.pos, 2.0)
		for o in enemies.enemies_in_radius(e.pos, 2.2):
			if o != e:
				enemies.damage(o, a * 0.4, "fire", false, "steam")
	if mod("execute") > 0.0 and not e.boss and e.hp - a < e.max_hp * mod("execute"):
		a = e.hp + 1.0
	return a


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
	# slow motion during boss intros
	var speed := GameState.god_value("game_speed", 1.0)
	Engine.time_scale = clampf(speed * (0.35 if bosses.is_cinematic() else 1.0), 0.05, 8.0)
	enemies.lod_z = _cam_look_z - 20.0
	_run_auto_blessings(delta)


func _run_auto_blessings(delta: float) -> void:
	if mod("auto_meteor") > 0.0:
		_auto_meteor_t -= delta
		if _auto_meteor_t <= 0.0:
			_auto_meteor_t = 18.0 / mod("auto_meteor")
			var p := enemies.densest_point()
			if p != Vector3.INF:
				spells.force_cast("meteor", p)
	if mod("auto_thunder") > 0.0:
		_auto_thunder_t -= delta
		if _auto_thunder_t <= 0.0:
			_auto_thunder_t = 10.0 / mod("auto_thunder")
			for e in enemies.random_enemies(6):
				fx.lightning([e.pos + Vector3(0, 26, 0), enemies.enemy_center(e)], Color(0.7, 0.8, 1.0), 0.6)
				enemies.damage(e, 150.0 * spells.power(), "lightning", true, "blessing")
	if mod("wall_slow") > 0.0:
		for e in enemies.enemies:
			if e.alive and e.pos.z > -9.0:
				enemies.apply_slow(e, mod("wall_slow"), 0.5)


func _update_camera(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 2.5)
	var look := Vector3(0, 0, _cam_look_z)
	var offset := Vector3(0, 38.0, 31.0) * _cam_zoom
	var cine := bosses != null and bosses.is_cinematic()
	_cine_blend = move_toward(_cine_blend, 1.0 if cine else 0.0, delta / maxf(Engine.time_scale, 0.05) * 1.8)
	if _cine_blend > 0.0 and bosses.cinematic_target != null:
		var bp: Vector3 = bosses.cinematic_target.pos
		var t := smoothstep(0.0, 1.0, _cine_blend)
		look = look.lerp(bp + Vector3(0, 3.0, 0), t)
		offset = offset.lerp(Vector3(6.0, 9.0, 16.0), t)
	var pos := look + offset
	if _shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.6
	camera.global_position = pos
	camera.look_at(look, Vector3.UP)


func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.2)


func flash_screen(color: Color, duration: float) -> void:
	hud.flash(color, duration)


func banner_world(text: String, color: Color) -> void:
	fx.banner_text(text, color)


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
	if placing_defense != "":
		var gp0 := ground_point(screen)
		if gp0 != Vector3.INF:
			place_defense(placing_defense, gp0)
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
	var gp := ground_point(screen)
	if gp != Vector3.INF:
		var def := defenses.defense_at(gp)
		if def != null:
			select_defense(def)
			return
		# manual targeting: tap an enemy to focus fire
		var e := enemies.find_nearest(gp, 3.0)
		if e != null:
			focus_target = e
			hud.show_hint("All towers and heroes focus " + String(GameData.ENEMIES[e.type]["name"]))
			fx.hit_spark(enemies.enemy_center(e), Color(1, 0.3, 0.2))
			return
	deselect()


func arm_spell(id: String) -> void:
	armed_spell = id
	if id != "":
		deselect()
		placing_defense = ""
	hud.set_armed_spell(id)


func cast_hero(i: int) -> void:
	if i >= 0 and i < heroes.size():
		heroes[i].cast_ability()


# ------------------------------------------------------------------ defenses

func begin_placing(type: String) -> void:
	deselect()
	arm_spell("")
	placing_defense = type
	hud.show_hint("Tap the battlefield to place " + String(GameData.DEFENSES[type]["name"]) + "  (tap Build again to stop)")


func stop_placing() -> void:
	placing_defense = ""
	hud.show_hint("")


func place_defense(type: String, p: Vector3) -> DefenseSystem.Defense:
	if not defenses.can_place(p):
		hud.show_hint("Can't build there")
		return null
	if not _pay(defenses.cost(type)):
		return null
	Audio.sfx("build", -3.0, 0.05, 0.0)
	return defenses.place(type, p)


func select_defense(d: DefenseSystem.Defense) -> void:
	deselect()
	selected_defense = d
	hud.show_defense_sheet(d)


func upgrade_defense() -> void:
	var d := selected_defense
	if d == null or d.level >= GameData.DEFENSE_MAX_LEVEL:
		return
	if not GameState.is_god("free_upgrades") and not _pay(defenses.cost(d.type, d.level + 1)):
		return
	defenses.upgrade(d)
	select_defense(d)


func max_defense() -> void:
	var d := selected_defense
	if d == null:
		return
	while d.level < GameData.DEFENSE_MAX_LEVEL:
		defenses.upgrade(d)
	select_defense(d)


func sell_defense() -> void:
	var d := selected_defense
	if d == null:
		return
	if not GameState.has_unlimited_resources():
		gold += int(d.spent * 0.6)
	defenses.remove(d, true)
	deselect()


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
	selected_defense = null
	hud.close_sheet()


func _pay(cost: int) -> bool:
	if GameState.has_unlimited_resources() or cost <= 0:
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
	t.global_position = pad["pos"] + Vector3(0, 0.15, 0)
	t.setup(type, level, self)
	t.total_spent = cost
	pad["tower"] = t
	Audio.sfx("build", -3.0, 0.05, 0.0)
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
	Audio.sfx("upgrade", -2.0, 0.0, 0.0)
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
	Audio.sfx("sell", -3.0, 0.0, 0.0)
	t.queue_free()
	deselect()


# ------------------------------------------------------------------ waves / events

func call_next_wave() -> void:
	if not waves.active:
		waves.start_next_wave()


func _on_wave_started(w: int, is_boss: bool) -> void:
	Audio.sfx("wave_start", -2.0, 0.0, 0.0)
	hud.banner("WAVE %d" % w if not is_boss else "BOSS WAVE %d" % w, UITheme.GOLD if not is_boss else Color(1, 0.4, 0.3))


func _on_wave_cleared(w: int) -> void:
	if game_over:
		return
	Audio.sfx("wave_clear", -3.0, 0.0, 0.0)
	var bonus := 25 + w * 5
	if not GameState.has_unlimited_resources():
		gold += bonus
	run.gold_earned += bonus
	hud.show_hint("Wave %d cleared!  +%d gold" % [w, bonus])
	for h in heroes:
		h.celebrate(1.8)
	var every := 1 if mode == "playground" else GameData.BLESSING_EVERY
	if w % every == 0 and not GameState.is_god("auto_complete_waves"):
		offer_blessing()


func offer_blessing() -> void:
	get_tree().paused = true
	hud.show_blessing_picker(run.offer(3))


func pick_blessing(id: String) -> void:
	var new_combos := run.add_blessing(id)
	Audio.sfx("combo" if not new_combos.is_empty() else "blessing", 0.0, 0.0, 0.0)
	if id == "fortify":
		_apply_castle_stats()
		castle.repair_full()
		for d in defenses.defenses:
			if d.max_hp > 1.0:
				d.max_hp = defenses.max_hp_for(d.type, d.level)
				d.hp = d.max_hp
	get_tree().paused = false
	hud.hide_modal()
	hud.banner(String(GameData.BLESSINGS[id]["name"]).to_upper(), Color(0.7, 1.0, 0.7))
	for c in new_combos:
		hud.combo_toast(c)
		fx.banner_text("COMBO: " + String(GameData.COMBOS[c]["name"]), Color(1.0, 0.8, 0.3))


func _on_enemy_killed(e: EnemyManager.Enemy) -> void:
	kills += 1
	var reward := int(e.reward * (1.0 + GameState.upgrade_value("kill_gold") + mod("gold") + (0.5 if _hero_effects.has("midas") else 0.0)))
	if not GameState.has_unlimited_resources():
		gold += reward
	run.gold_earned += reward
	if e == focus_target:
		focus_target = null
		_focus_marker.visible = false
	loot.on_kill(e)
	if _hero_effects.has("reap") and randf() < 0.2 and enemies.allies.size() < 30:
		enemies.spawn_ally(e.pos, 40.0, 8.0)
	if has_combo("divine_storm") and e.burn_t <= 0.0 and randf() < 0.3:
		castle.heal(castle.max_hp * 0.002)
	if e.boss:
		if not enemies.enemies.any(func(o): return o.alive and o.boss and o != e):
			get_tree().create_timer(3.0, false).timeout.connect(func():
				if not game_over:
					Audio.play_music("battle", 2.0))
		shake(1.0)
		run.gems_earned += 5
		run.materials_earned += 3
		hud.banner("TYRANT SLAIN!", Color(1, 0.85, 0.3))
		flash_screen(Color(1, 0.9, 0.6), 0.4)
	elif e.elite != "":
		run.materials_earned += 1


func _on_castle_hit(dmg: float, pos: Vector3) -> void:
	castle.take_damage(dmg, pos)
	Audio.sfx("castle_hit", -8.0)
	if dmg >= 50.0:
		shake(0.4)


func _on_ranged_attack(e: EnemyManager.Enemy) -> void:
	var kind: String = GameData.ENEMIES[e.type].get("projectile", "enemy_arrow")
	if kind == "arrow":
		kind = "enemy_arrow"
	var target := Vector3(clampf(e.pos.x, -14, 14), randf_range(1.5, 3.2), -1.4)
	var dmg := e.damage
	projectiles.fire(kind, enemies.enemy_center(e), null, 30.0, 2.5 if kind == "enemy_arrow" else 1.0, func(p: Vector3, _t):
		castle.take_damage(dmg, p)
		fx.hit_spark(p, Color(0.8, 0.4, 1.0) if kind == "hex" else Color(0.9, 0.8, 0.6)), target)


func _on_boss_spawned(e: EnemyManager.Enemy) -> void:
	current_boss = e
	bosses.on_boss(e)


func _on_castle_destroyed() -> void:
	if game_over:
		return
	game_over = true
	GameState.record_wave(mode, waves.wave)
	fx.explosion(Vector3(0, 4, 0), 8.0, Color(1, 0.5, 0.2), true)
	_finish(false)


func _on_victory() -> void:
	game_over = true
	_finish(true)


func _finish(victory: bool) -> void:
	Audio.play_music("victory" if victory else "defeat", 0.5)
	if victory:
		for h in heroes:
			h.celebrate()
	var summary := apply_rewards(victory)
	if summary.get("levels", {}).values().any(func(v): return int(v) > 0):
		Audio.sfx("level_up", 0.0, 0.0, 0.0)
	hud.show_result(victory, waves.wave if victory else maxi(waves.wave - 1, 0), summary)


func apply_rewards(victory: bool) -> Dictionary:
	## Converts the run into permanent progression (gold, gems, materials, hero XP).
	if rewards_applied:
		return {}
	rewards_applied = true
	var waves_done := maxi(waves.wave - (0 if victory else 1), 0)
	var xp := int((kills * 2 + waves_done * 25) * (1.0 + GameState.upgrade_value("hero_xp")))
	var levels := {}
	for h in heroes:
		levels[h.id] = GameState.add_hero_xp(h.id, xp)
	GameState.add_currency("gold", run.gold_earned)
	GameState.add_currency("gems", run.gems_earned + (10 if victory else 0))
	GameState.add_currency("materials", run.materials_earned)
	GameState.save_state()
	return {"gold": run.gold_earned, "gems": run.gems_earned + (10 if victory else 0), "materials": run.materials_earned,
		"xp": xp, "levels": levels, "items": run.loot_found, "kills": kills}


func toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	if p:
		hud.show_pause()
	else:
		hud.hide_modal()


func exit_to_menu() -> void:
	apply_rewards(false)
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


func god_spawn_boss(type := "") -> void:
	var b: String = type if type != "" else GameData.BOSS_TYPES[randi() % GameData.BOSS_TYPES.size()]
	enemies.spawn(b, 1)


func god_max_towers() -> void:
	for p in castle.pads:
		if p["tower"] != null and (p["tower"] as Tower).level < GameData.TOWER_MAX_LEVEL:
			(p["tower"] as Tower).set_level(GameData.TOWER_MAX_LEVEL)
	for d in defenses.defenses:
		while d.level < GameData.DEFENSE_MAX_LEVEL:
			defenses.upgrade(d)
	if selected_pad >= 0:
		select_pad(selected_pad)


func god_fill_pads() -> void:
	var i := 0
	for idx in castle.pads.size():
		if castle.pads[idx]["tower"] == null:
			var type: String = GameData.TOWER_ORDER[i % GameData.TOWER_ORDER.size()]
			var t := build_tower(idx, type, GameData.TOWER_MAX_LEVEL, false)
			if t == null:
				break
			i += 1


func god_build_defenses() -> void:
	## Lines the lanes with max-level traps and barriers.
	var spots := [
		["barrier", Vector3(-8, 0, -30)], ["barrier", Vector3(8, 0, -30)], ["wall", Vector3(0, 0, -34)],
		["spike_trap", Vector3(-8, 0, -40)], ["spike_trap", Vector3(8, 0, -40)], ["spike_trap", Vector3(0, 0, -44)],
		["barrel_trap", Vector3(-4, 0, -50)], ["barrel_trap", Vector3(4, 0, -50)],
		["frost_rune", Vector3(-8, 0, -20)], ["frost_rune", Vector3(8, 0, -20)], ["frost_rune", Vector3(0, 0, -24)],
	]
	for s in spots:
		var p: Vector3 = s[1]
		p.x = WorldBuilder.lane_x(int(round((p.x + 8.0) / 8.0)), p.z)
		if defenses.can_place(p):
			var d := defenses.place(s[0], p, 1)
			while d.level < GameData.DEFENSE_MAX_LEVEL:
				defenses.upgrade(d)


func god_blessing() -> void:
	offer_blessing()


func god_all_blessings() -> void:
	for id in GameData.BLESSINGS:
		if not run.picks.has(id):
			for c in run.add_blessing(id):
				hud.combo_toast(c)
	_apply_castle_stats()
	castle.repair_full()
	hud.banner("ALL BLESSINGS", Color(0.7, 1.0, 0.7))


func god_reset() -> void:
	## Restart the battle; unlocks, God Mode settings and progression are kept.
	get_tree().paused = false
	get_tree().reload_current_scene()


func god_change_map(id: String) -> void:
	GameState.current_map = id
	GameState.save_state()
	god_reset()
