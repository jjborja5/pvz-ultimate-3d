extends Node3D
## Main menu over a live 3D diorama of the castle and battlefield.

var world: WorldBuilder
var castle: Castle
var fx: FX
var enemies: EnemyManager
var camera: Camera3D
var ui: Control
var _t := 0.0
var _spawn_t := 0.0
var _screen: Control
var _on_home := false
var _currency_labels := {}


func _ready() -> void:
	get_tree().paused = false
	await _bake_with_progress()
	fx = FX.new()
	add_child(fx)
	world = WorldBuilder.new()
	add_child(world)
	world.build(GameState.current_map)
	castle = Castle.new()
	add_child(castle)
	castle.build(fx)
	castle.ground_pads(world.height_at)
	enemies = EnemyManager.new()
	add_child(enemies)
	enemies.setup(world, fx)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 70
	camera.far = 400
	add_child(camera)
	camera.make_current()
	fx.camera = camera
	await HeroPortraits.generate_missing(self)
	_build_ui()
	if GameState.boot_ms == 0:
		GameState.boot_ms = Time.get_ticks_msec()
		print("BOOT OK: menu ready in %d ms (%s, %s)" % [GameState.boot_ms, OS.get_name(), RenderingServer.get_video_adapter_name()])
		if OS.get_cmdline_user_args().has("--demo-battle"):
			GameState.current_mode = "sandbox"
			get_tree().change_scene_to_file.call_deferred("res://scenes/battle.tscn")
			return
	Audio.play_music("menu")
	GameState.god_changed.connect(func(_k): _refresh_currencies())


func _bake_with_progress() -> void:
	## First launch: bake character animation frames with a progress screen (later launches
	## load them from the user:// cache in a fraction of a second).
	var pending: Array = UnitBaker.CONFIGS.keys().filter(func(c): return not UnitBaker.is_baked(c))
	if pending.is_empty():
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var title := UITheme.title("CASTLE\nDOMINION", 84)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.offset_left = -360
	title.offset_right = 360
	title.offset_top = -260
	title.offset_bottom = -60
	layer.add_child(title)
	var lbl := UITheme.label("Forging the armies...", 26, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl.offset_left = -300
	lbl.offset_right = 300
	lbl.offset_top = 20
	lbl.offset_bottom = 60
	layer.add_child(lbl)
	var bar := ProgressBar.new()
	bar.theme = UITheme.get_theme()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bar.offset_left = -260
	bar.offset_right = 260
	bar.offset_top = 80
	bar.offset_bottom = 110
	bar.max_value = pending.size()
	bar.show_percentage = false
	layer.add_child(bar)
	for i in pending.size():
		await get_tree().process_frame
		UnitBaker.get_frames(pending[i])
		bar.value = i + 1
	layer.queue_free()


func _process(delta: float) -> void:
	if camera == null:
		return
	_t += delta
	var a := sin(_t * 0.08) * 0.5
	var target := Vector3(0, 4, -12)
	camera.global_position = target + Vector3(sin(a) * 40.0, 18.0 + sin(_t * 0.15) * 2.0, cos(a) * 40.0 - 50.0 + 50.0)
	camera.look_at(target + Vector3(0, 0, -20), Vector3.UP)
	_spawn_t -= delta
	if _spawn_t <= 0.0 and enemies.alive_count() < 60:
		_spawn_t = 0.4
		enemies.spawn(GameData.REGULAR_TYPES[randi() % GameData.REGULAR_TYPES.size()], -1, -70.0)
	# keep the diorama alive: enemies at the wall are struck down by lightning
	for e in enemies.enemies:
		if e.alive and e.attacking and randf() < 0.01:
			fx.lightning([e.pos + Vector3(0, 25, 0), enemies.enemy_center(e)], Color(0.6, 0.8, 1.0), 0.4)
			enemies.damage(e, 1e9, "lightning", false, "god")


# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = UITheme.get_theme()
	layer.add_child(ui)
	UITheme.apply_safe_area(ui)
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.65, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.1), Color(0.03, 0.01, 0.06, 0.85)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)   # full screen, behind the safe-area-inset UI
	layer.move_child(shade, 0)
	_show_home()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and ui != null:
		# Android back: sub-screens return home; from home, save and leave
		if _on_home:
			GameState.save_state()
			get_tree().quit()
		else:
			Audio.sfx("ui_back", -8.0)
			_show_home()


func _clear_screen() -> void:
	_on_home = false
	if _screen:
		_screen.queue_free()
	_screen = Control.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_screen)
	_screen.modulate.a = 0.0
	create_tween().tween_property(_screen, "modulate:a", 1.0, 0.2)


func _currency_bar(parent: Control) -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 12
	bar.offset_right = -12
	bar.offset_top = 12
	bar.add_theme_stylebox_override("panel", UITheme.box(Color(0.05, 0.04, 0.1, 0.8), UITheme.GOLD_DARK, 16, 2, 4))
	parent.add_child(bar)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	bar.add_child(h)
	_currency_labels.clear()
	for pair in [["gold", "gold"], ["gems", "gem"], ["diamonds", "diamond"], ["energy", "speed"]]:
		var box := HBoxContainer.new()
		box.add_child(IconArt.new(pair[1], 34))
		var l := UITheme.label("", 26, Color(1, 0.92, 0.6))
		box.add_child(l)
		_currency_labels[pair[0]] = l
		h.add_child(box)
	_refresh_currencies()


func _refresh_currencies() -> void:
	for k in _currency_labels:
		if is_instance_valid(_currency_labels[k]):
			(_currency_labels[k] as Label).text = GameState.currency_text(k)


func _show_home() -> void:
	_clear_screen()
	_on_home = true
	_currency_bar(_screen)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 30
	v.offset_right = -30
	v.offset_top = 110
	v.offset_bottom = -30
	v.add_theme_constant_override("separation", 14)
	_screen.add_child(v)
	var title := UITheme.title("CASTLE\nDOMINION", 84)
	title.add_theme_constant_override("line_spacing", -18)
	v.add_child(title)
	var badge := UITheme.label("GOD MODE ACTIVE  •  EVERYTHING UNLOCKED" if GameState.god["enabled"] else "GOD MODE OFF", 22,
		Color(0.6, 1.0, 0.6) if GameState.god["enabled"] else Color(1, 0.6, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(badge)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var start := UITheme.button("START BATTLE", Color(0.7, 0.2, 0.1), Vector2(0, 110))
	start.add_theme_font_size_override("font_size", 40)
	start.pressed.connect(_show_start)
	v.add_child(start)
	# idle pulse on the main call to action
	var tw := start.create_tween().set_loops()
	tw.tween_property(start, "modulate", Color(1.15, 1.1, 1.0), 0.8)
	tw.tween_property(start, "modulate", Color.WHITE, 0.8)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var items := [
		["Heroes", "swords", _show_heroes],
		["Equipment", "shield", _show_equipment],
		["Towers", "archer", _show_towers],
		["Upgrades", "gem", _show_upgrades],
		["Inventory", "gold", _show_inventory],
		["World Map", "meteor", _show_world_map],
		["God Mode", "crown", _open_god],
		["Settings", "ice", _show_settings],
	]
	for it in items:
		var b := UITheme.button(it[0], UITheme.PURPLE, Vector2(0, 84))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for st in ["normal", "hover", "pressed"]:
			var sb: StyleBox = b.get_theme_stylebox(st).duplicate()
			sb.content_margin_left = 78
			b.add_theme_stylebox_override(st, sb)
		var ic := IconArt.new(it[1], 50)
		ic.position = Vector2(14, 17)
		b.add_child(ic)
		b.pressed.connect(it[2])
		grid.add_child(b)


func _screen_frame(title_text: String) -> VBoxContainer:
	_clear_screen()
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 18
	p.offset_right = -18
	p.offset_top = 40
	p.offset_bottom = -30
	_screen.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var head := HBoxContainer.new()
	var back := UITheme.button("<", UITheme.BLUE, Vector2(72, 72))
	back.pressed.connect(_show_home)
	head.add_child(back)
	var t := UITheme.title(title_text, 42)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(72, 0)
	head.add_child(pad)
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	return body


func _choice_card(parent: Control, title_text: String, desc: String, selected: bool, cb: Callable, locked := false) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 110)
	b.toggle_mode = true
	b.button_pressed = selected
	var col := Color(0.35, 0.22, 0.08) if selected else Color(0.13, 0.1, 0.22)
	b.add_theme_stylebox_override("normal", UITheme.box(col, UITheme.GOLD if selected else UITheme.GOLD_DARK, 18))
	b.add_theme_stylebox_override("pressed", UITheme.box(Color(0.35, 0.22, 0.08), UITheme.GOLD, 18, 4))
	b.add_theme_stylebox_override("hover", UITheme.box(col.lightened(0.1), UITheme.GOLD, 18))
	UITheme.juice(b)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 20
	v.offset_top = 12
	v.offset_right = -20
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UITheme.label(title_text + ("  (locked)" if locked else ""), 30, UITheme.GOLD)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var d := UITheme.label(desc, 20, Color(0.88, 0.85, 0.8))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	b.add_child(v)
	b.disabled = locked
	b.pressed.connect(cb)
	parent.add_child(b)


func _show_start() -> void:
	var body := _screen_frame("Start Battle")
	body.add_child(UITheme.label("GAME MODE", 24, UITheme.GOLD))
	for id in GameData.MODE_ORDER:
		var md: Dictionary = GameData.MODES[id]
		var best := int(GameState.best_wave.get(id, 0))
		var desc: String = md["desc"] + ("   Best: wave %d" % best if best > 0 else "")
		_choice_card(body, md["name"], desc, GameState.current_mode == id, func():
			GameState.current_mode = id
			GameState.save_state()
			_show_start())
	body.add_child(UITheme.label("BATTLEFIELD", 24, UITheme.GOLD))
	for id in GameData.MAP_ORDER:
		var m: Dictionary = GameData.MAPS[id]
		_choice_card(body, m["name"], m["desc"], GameState.current_map == id, func(): _select_map(id, _show_start), not GameState.is_map_unlocked(id))
	var diff := OptionButton.new()
	diff.custom_minimum_size = Vector2(0, 72)
	for i in GameData.DIFFICULTIES.size():
		diff.add_item("Difficulty: " + String(GameData.DIFFICULTIES[i]["name"]), i)
	diff.selected = GameState.difficulty
	diff.item_selected.connect(func(i):
		GameState.difficulty = i
		GameState.save_state())
	body.add_child(diff)
	var go := UITheme.button("TO BATTLE!", Color(0.7, 0.2, 0.1), Vector2(0, 110))
	go.add_theme_font_size_override("font_size", 40)
	go.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/battle.tscn"))
	body.add_child(go)


func _select_map(id: String, then: Callable) -> void:
	var changed := GameState.current_map != id
	GameState.current_map = id
	GameState.save_state()
	if changed:
		get_tree().reload_current_scene()
	else:
		then.call()


func _show_world_map() -> void:
	var body := _screen_frame("World Map")
	for id in GameData.MAP_ORDER:
		var m: Dictionary = GameData.MAPS[id]
		_choice_card(body, m["name"], m["desc"], GameState.current_map == id, func(): _select_map(id, _show_world_map), not GameState.is_map_unlocked(id))
	body.add_child(UITheme.label("Selecting a map rebuilds the diorama behind this menu.", 20, Color(0.8, 0.8, 0.8)))


func _show_towers() -> void:
	var body := _screen_frame("Towers")
	for type in GameData.TOWER_ORDER:
		var d: Dictionary = GameData.TOWERS[type]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.add_child(IconArt.new(type, 90))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UITheme.label(d["name"] + "   ★★★★★ MAX", 28, UITheme.GOLD))
		var desc := UITheme.label(d["desc"], 20, Color(0.88, 0.85, 0.8))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(desc)
		v.add_child(UITheme.label("Lv5: dmg %d  •  %.1f/s  •  range %d" % [d["damage"][4], d["rate"][4], d["range"][4]], 20, Color(0.75, 0.9, 1.0)))
		row.add_child(v)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UITheme.box(Color(0.12, 0.1, 0.2), UITheme.GOLD_DARK, 16, 2, 0))
		p.add_child(row)
		body.add_child(p)
	body.add_child(UITheme.label("BATTLEFIELD DEFENSES (built with the BUILD button in battle)", 22, UITheme.GOLD))
	for type in GameData.DEFENSE_ORDER:
		var dd: Dictionary = GameData.DEFENSES[type]
		var lab := UITheme.label("%s — %s" % [dd["name"], dd["desc"]], 20, Color(0.88, 0.85, 0.8))
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(lab)


func _show_settings() -> void:
	var body := _screen_frame("Settings")
	var qopt := OptionButton.new()
	qopt.custom_minimum_size = Vector2(0, 72)
	for i in GameState.QUALITY_PRESETS.size():
		qopt.add_item("Graphics Quality: " + String(GameState.QUALITY_PRESETS[i]["name"]), i)
	qopt.selected = int(GameState.settings.get("quality", 2))
	qopt.item_selected.connect(func(i):
		GameState.set_quality(i)
		_show_settings())
	body.add_child(qopt)
	var rec := GameState.recommended_quality()
	var qd := UITheme.label(("Recommended for this device: %s.\n" % GameState.QUALITY_PRESETS[rec]["name"])
		+ "Low (entry-level Android, e.g. Galaxy A21): reduced resolution, no dynamic shadows or bloom, fewer particles and lights, simpler distant enemies, 30 FPS cap.\n"
		+ "Medium: shadows, bloom, weather, 60 FPS.\n"
		+ "High (e.g. iPhone 11 Pro Max): full detail, MSAA, unit shadows, 60 FPS.", 17, Color(0.8, 0.8, 0.8))
	qd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(qd)
	var cap := CheckButton.new()
	cap.text = "60 FPS (off = 30 FPS, cooler and steadier)"
	cap.custom_minimum_size = Vector2(0, 72)
	cap.button_pressed = int(GameState.settings.get("fps_cap", 60)) >= 60
	cap.toggled.connect(func(on):
		GameState.set_setting("fps_cap", 60 if on else 30)
		GameState.apply_frame_cap())
	body.add_child(cap)
	var fpsb := CheckButton.new()
	fpsb.text = "Show FPS / Performance Overlay"
	fpsb.custom_minimum_size = Vector2(0, 72)
	fpsb.button_pressed = GameState.settings.get("show_fps", false)
	fpsb.toggled.connect(func(on): GameState.set_setting("show_fps", on))
	body.add_child(fpsb)
	var sh := CheckButton.new()
	sh.text = "Dynamic Shadows"
	sh.custom_minimum_size = Vector2(0, 72)
	sh.button_pressed = GameState.settings["shadows"]
	sh.toggled.connect(func(on): GameState.set_setting("shadows", on))
	body.add_child(sh)
	var dn := CheckButton.new()
	dn.text = "Damage Numbers"
	dn.custom_minimum_size = Vector2(0, 72)
	dn.button_pressed = GameState.settings["show_damage_numbers"]
	dn.toggled.connect(func(on): GameState.set_setting("show_damage_numbers", on))
	body.add_child(dn)
	for pair in [["particles_quality", "Particle Quality", 0.25, 1.0], ["sfx_volume", "Sound Effects Volume", 0.0, 1.0], ["music_volume", "Music Volume", 0.0, 1.0]]:
		var l := UITheme.label(pair[1], 24)
		body.add_child(l)
		var s := HSlider.new()
		s.min_value = pair[2]
		s.max_value = pair[3]
		s.step = 0.05
		s.value = GameState.settings[pair[0]]
		s.custom_minimum_size = Vector2(0, 48)
		var key: String = pair[0]
		s.value_changed.connect(func(v): GameState.set_setting(key, v))
		body.add_child(s)
	var save_btn := UITheme.button("Save Game Now", UITheme.BLUE)
	save_btn.custom_minimum_size = Vector2(0, 72)
	save_btn.pressed.connect(func():
		GameState.save_state()
		save_btn.text = "Saved (progress also saves automatically)")
	body.add_child(save_btn)
	var bench := UITheme.button("Run Performance Benchmark", Color(0.45, 0.3, 0.6))
	bench.custom_minimum_size = Vector2(0, 72)
	bench.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/benchmark.tscn"))
	body.add_child(bench)
	var info := UITheme.label("Castle Dominion v%s  •  offline, no ads, no purchases\n%s  •  %s  •  %s" % [
		ProjectSettings.get_setting("application/config/version"), OS.get_name(), OS.get_model_name(),
		RenderingServer.get_video_adapter_name()], 18, Color(0.7, 0.7, 0.7))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)


func _open_god() -> void:
	var gp := GodPanel.new()
	gp.closed.connect(_show_home)
	ui.add_child(gp)


# ------------------------------------------------------------------ shared widgets

var _sel_hero := "fire_mage"
var _inv_filter := ""
var _selected_uid := -1


func _panel(parent: Control, bg := Color(0.12, 0.1, 0.2), border := UITheme.GOLD_DARK) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(bg, border, 16, 2, 0))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v


func _wrap(text: String, size: int, color: Color) -> Label:
	var l := UITheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _god_note(parent: Control) -> void:
	if GameState.is_god("enabled"):
		var n := UITheme.label("GOD MODE: everything unlocked" + (", all levels at maximum" if GameState.is_god("max_power") else "") +
			(", all costs free" if GameState.has_unlimited_resources() else ""), 18, Color(0.6, 1.0, 0.6))
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(n)


func _item_card(parent: Control, it: Dictionary, on_tap: Callable, selected := false) -> void:
	var col := Loot.rarity_color(it)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 112)
	b.add_theme_stylebox_override("normal", UITheme.box(Color(col.r * 0.16, col.g * 0.16, col.b * 0.2, 0.95), col if selected else col.darkened(0.3), 16, 3 if selected else 2, 0))
	b.add_theme_stylebox_override("hover", UITheme.box(Color(col.r * 0.24, col.g * 0.24, col.b * 0.28, 0.95), col, 16, 3, 0))
	b.add_theme_stylebox_override("pressed", UITheme.box(Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.95), Color.WHITE, 16, 3, 0))
	var icons := {"weapon": "swords", "armor": "shield", "accessory": "gem"}
	var ic := IconArt.new(icons.get(it["slot"], "gem"), 64)
	ic.position = Vector2(12, 24)
	b.add_child(ic)
	var max_lv := int(GameData.RARITIES[int(it["rarity"])]["max_level"])
	var t := UITheme.label("%s   Lv %d/%d" % [it["name"], GameState.item_level(it), max_lv], 22, col.lightened(0.25))
	t.position = Vector2(88, 8)
	b.add_child(t)
	var st := UITheme.label(Loot.rarity_name(it) + " " + String(it["slot"]).capitalize() + "   " + Loot.stats_text(it), 16, UITheme.TEXT)
	st.position = Vector2(88, 40)
	b.add_child(st)
	var eff := Loot.effect_desc(it)
	var owner := GameState.item_owner(int(it["uid"]))
	var extra := ("★ " + eff) if eff != "" else ""
	if owner != "":
		extra += ("   " if extra != "" else "") + "Equipped: " + String(GameData.HEROES[owner]["class"])
	if extra != "":
		var el := UITheme.label(extra, 16, Color(1.0, 0.85, 0.5))
		el.position = Vector2(88, 66)
		el.size = Vector2(520, 40)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(el)
	b.pressed.connect(on_tap)
	parent.add_child(b)


# ------------------------------------------------------------------ heroes

func _show_heroes() -> void:
	var body := _screen_frame("Heroes")
	_god_note(body)
	var id := _sel_hero
	var def: Dictionary = GameData.HEROES[id]
	var st := HeroStats.compute(id)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	body.add_child(top)
	var preview := HeroPreview.new(Vector2(300, 400))
	top.add_child(preview)
	preview.show_hero(id)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	info.add_child(_wrap(def["name"], 30, def["color"]))
	info.add_child(_wrap(def["title"], 18, Color(0.85, 0.8, 0.7)))
	info.add_child(UITheme.label(String(def["class"]).to_upper(), 20, UITheme.GOLD))
	var lvl := int(st["level"])
	info.add_child(UITheme.label("Level %d / %d" % [lvl, GameData.HERO_MAX_LEVEL], 22, UITheme.TEXT))
	var xpb := ProgressBar.new()
	xpb.custom_minimum_size = Vector2(0, 18)
	xpb.show_percentage = false
	xpb.max_value = 1.0
	xpb.value = 1.0 if lvl >= GameData.HERO_MAX_LEVEL else float(GameState.heroes[id]["xp"]) / GameData.hero_xp_to_next(lvl)
	xpb.add_theme_stylebox_override("fill", UITheme.box(Color(0.4, 0.75, 1.0), Color(0, 0, 0, 0), 8, 0, 0))
	info.add_child(xpb)
	info.add_child(UITheme.label("Power  %d" % HeroStats.power_rating(id), 24, Color(1, 0.75, 0.3)))
	info.add_child(_wrap("Damage %d  •  %.1f/s  •  Range %d\nCrit %d%%  •  %s" % [st["damage"], st["rate"], st["range"], int(st["crit"] * 100), String(def["attack"]["element"]).capitalize()], 18, Color(0.8, 0.92, 1.0)))
	var lvl_btn := UITheme.button("LEVEL UP" + ("" if GameState.has_unlimited_resources() else "  (%d gold)" % (GameData.hero_xp_to_next(int(GameState.heroes[id]["level"])) * 2)), UITheme.GREEN, Vector2(0, 64))
	lvl_btn.disabled = int(GameState.heroes[id]["level"]) >= GameData.HERO_MAX_LEVEL
	lvl_btn.pressed.connect(func():
		GameState.level_up_hero(id)
		_show_heroes())
	info.add_child(lvl_btn)
	# ability
	var ab := _panel(body, Color(0.16, 0.1, 0.22), def["color"])
	ab.add_child(UITheme.label("ULTIMATE: %s   (Lv %d/%d)" % [def["ability"]["name"], st["ability_level"], GameData.ABILITY_MAX_LEVEL], 22, def["color"].lightened(0.3)))
	ab.add_child(_wrap(def["ability"]["desc"], 18, UITheme.TEXT))
	ab.add_child(UITheme.label("Ability damage %d  •  Cooldown %.1fs" % [st["ability_damage"], st["cooldown"]], 18, Color(0.85, 0.9, 1.0)))
	var ab_btn := UITheme.button("UPGRADE ABILITY" + ("" if GameState.has_unlimited_resources() else "  (1 skill point)"), UITheme.PURPLE, Vector2(0, 60))
	ab_btn.disabled = int(GameState.heroes[id]["ability_level"]) >= GameData.ABILITY_MAX_LEVEL
	ab_btn.pressed.connect(func():
		GameState.upgrade_ability(id)
		_show_heroes())
	ab.add_child(ab_btn)
	# skins
	body.add_child(UITheme.label("SKINS", 22, UITheme.GOLD))
	var skins := HBoxContainer.new()
	skins.add_theme_constant_override("separation", 8)
	body.add_child(skins)
	for i in GameData.SKINS.size():
		var sk: Dictionary = GameData.SKINS[i]
		var sel: bool = int(GameState.heroes[id]["skin"]) == i
		var c: Color = def["color"] if float(sk["amount"]) < 0.0 else sk["tint"]
		var sb := UITheme.button(sk["name"], Color(c.r * 0.4, c.g * 0.4, c.b * 0.45), Vector2(0, 64))
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.add_theme_font_size_override("font_size", 17)
		if sel:
			sb.add_theme_stylebox_override("normal", UITheme.box(Color(c.r * 0.5, c.g * 0.5, c.b * 0.5), Color.WHITE, 16, 4))
		var si: int = i
		sb.pressed.connect(func():
			GameState.set_skin(id, si)
			await HeroPortraits.generate_missing(self)
			_show_heroes())
		skins.add_child(sb)
	# team
	body.add_child(UITheme.label("BATTLE TEAM (heroes deployed on the castle walls)", 20, UITheme.GOLD))
	var team := HBoxContainer.new()
	team.add_theme_constant_override("separation", 8)
	body.add_child(team)
	for slot in GameData.TEAM_SIZE:
		var tid: String = GameState.team[slot]
		var tb := UITheme.button("Slot %d\n%s" % [slot + 1, GameData.HEROES[tid]["class"]], GameData.HEROES[tid]["color"].darkened(0.55), Vector2(0, 80))
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 18)
		var sl: int = slot
		tb.pressed.connect(func():
			GameState.set_team_slot(sl, id)
			_show_heroes())
		team.add_child(tb)
	body.add_child(UITheme.label("Tap a slot to place %s there." % def["class"], 16, Color(0.8, 0.8, 0.8)))
	# roster
	body.add_child(UITheme.label("ROSTER", 22, UITheme.GOLD))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for hid in GameData.HERO_ORDER:
		var hd: Dictionary = GameData.HEROES[hid]
		var unlocked := GameState.is_hero_unlocked(hid)
		var hb := Button.new()
		hb.custom_minimum_size = Vector2(0, 118)
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hc: Color = hd["color"]
		hb.add_theme_stylebox_override("normal", UITheme.box(Color(hc.r * 0.2, hc.g * 0.2, hc.b * 0.25), Color.WHITE if hid == id else hc.darkened(0.3), 16, 4 if hid == id else 2))
		hb.add_theme_stylebox_override("hover", UITheme.box(Color(hc.r * 0.3, hc.g * 0.3, hc.b * 0.35), hc, 16, 3))
		UITheme.juice(hb)
		var ic := UITheme.portrait(hid, 56)
		ic.position = Vector2(8, 6)
		hb.add_child(ic)
		var nl := UITheme.label(hd["class"], 17, hc.lightened(0.3))
		nl.position = Vector2(8, 64)
		hb.add_child(nl)
		var ll := UITheme.label(("Lv %d" % GameState.hero_level(hid)) if unlocked else "LOCKED", 16, UITheme.GOLD if unlocked else Color(1, 0.5, 0.4))
		ll.position = Vector2(8, 88)
		hb.add_child(ll)
		if GameState.team.has(hid):
			var tl := UITheme.label("TEAM", 14, Color(0.5, 1.0, 0.5))
			tl.position = Vector2(70, 12)
			hb.add_child(tl)
		hb.pressed.connect(func():
			if not GameState.is_hero_unlocked(hid):
				GameState.unlock_hero(hid)
			_sel_hero = hid
			_show_heroes())
		grid.add_child(hb)


# ------------------------------------------------------------------ equipment

func _show_equipment() -> void:
	var body := _screen_frame("Equipment")
	_god_note(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 92)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(row)
	body.add_child(scroll)
	for hid in GameData.HERO_ORDER:
		var hc: Color = GameData.HEROES[hid]["color"]
		var hb := UITheme.button(String(GameData.HEROES[hid]["class"]).get_slice(" ", 0), hc.darkened(0.6 if hid != _sel_hero else 0.25), Vector2(176, 84))
		hb.add_theme_font_size_override("font_size", 17)
		hb.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var pt := UITheme.portrait(hid, 62, false)
		pt.position = Vector2(8, 11)
		hb.add_child(pt)
		hb.pressed.connect(func():
			_sel_hero = hid
			_show_equipment())
		row.add_child(hb)
	var id := _sel_hero
	var def: Dictionary = GameData.HEROES[id]
	body.add_child(UITheme.label("%s  —  %s" % [def["name"], def["class"]], 26, def["color"]))
	var st := HeroStats.compute(id)
	body.add_child(_wrap("Power %d   •   Damage %d   •   Ability %d   •   Cooldown %.1fs" % [HeroStats.power_rating(id), st["damage"], st["ability_damage"], st["cooldown"]], 18, Color(0.85, 0.92, 1.0)))
	for slot in GameData.SLOTS:
		body.add_child(UITheme.label(String(slot).to_upper(), 22, UITheme.GOLD))
		var it := GameState.equipped_item(id, slot)
		if it.is_empty():
			body.add_child(UITheme.label("  (empty) — choose an item below", 18, Color(0.7, 0.7, 0.7)))
		else:
			var uid := int(it["uid"])
			var sl: String = slot
			_item_card(body, it, func():
				GameState.unequip(id, sl)
				_show_equipment(), true)
		# candidate items for this slot
		var cands: Array = GameState.inventory.filter(func(x): return x["slot"] == slot and int(x["uid"]) != int(it.get("uid", -1)))
		cands.sort_custom(func(a, b): return int(a["rarity"]) * 1000 + GameState.item_level(a) > int(b["rarity"]) * 1000 + GameState.item_level(b))
		for c in cands.slice(0, 4):
			var cuid := int(c["uid"])
			_item_card(body, c, func():
				GameState.equip(id, cuid)
				_show_equipment())
		if cands.size() > 4:
			body.add_child(UITheme.label("  +%d more in Inventory" % (cands.size() - 4), 16, Color(0.7, 0.7, 0.7)))
	body.add_child(UITheme.label("Tap an item to equip it. Tap an equipped item to remove it.", 16, Color(0.8, 0.8, 0.8)))


# ------------------------------------------------------------------ inventory

func _show_inventory() -> void:
	var body := _screen_frame("Inventory")
	_god_note(body)
	var names := {"gold": "Gold", "gems": "Gems", "diamonds": "Diamonds", "materials": "Materials",
		"energy": "Energy", "skill_points": "Skill Pts", "summon_tickets": "Tickets"}
	var cg := GridContainer.new()
	cg.columns = 4
	cg.add_theme_constant_override("h_separation", 6)
	cg.add_theme_constant_override("v_separation", 6)
	body.add_child(cg)
	for k in names:
		var v := _panel(cg)
		v.add_child(UITheme.label(names[k], 16, Color(0.85, 0.8, 0.7)))
		v.add_child(UITheme.label(GameState.currency_text(k), 24, UITheme.GOLD))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	for f in ["", "weapon", "armor", "accessory"]:
		var tb := UITheme.button("All" if f == "" else String(f).capitalize(), UITheme.BLUE if _inv_filter == f else UITheme.PURPLE, Vector2(0, 60))
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ff: String = f
		tb.pressed.connect(func():
			_inv_filter = ff
			_show_inventory())
		tabs.add_child(tb)
	if GameState.is_god("enabled"):
		var gb := UITheme.button("GOD: Grant every legendary & mythic (max level)", Color(0.55, 0.38, 0.05), Vector2(0, 64))
		gb.pressed.connect(func():
			GameState.grant_all_legendaries()
			_show_inventory())
		body.add_child(gb)
	var items: Array = GameState.inventory.filter(func(x): return _inv_filter == "" or x["slot"] == _inv_filter)
	items.sort_custom(func(a, b): return int(a["rarity"]) * 1000 + GameState.item_level(a) > int(b["rarity"]) * 1000 + GameState.item_level(b))
	body.add_child(UITheme.label("%d items" % items.size(), 18, Color(0.8, 0.8, 0.8)))
	for it in items:
		var uid := int(it["uid"])
		_item_card(body, it, func():
			_selected_uid = uid if _selected_uid != uid else -1
			_show_inventory(), uid == _selected_uid)
		if uid == _selected_uid:
			_item_actions(body, it)


func _item_actions(body: Control, it: Dictionary) -> void:
	var uid := int(it["uid"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)
	var max_lv := int(GameData.RARITIES[int(it["rarity"])]["max_level"])
	var cost := GameState.item_upgrade_cost(it)
	var free := GameState.has_unlimited_resources()
	var up := UITheme.button("UPGRADE" + ("" if free else "\n%dg %dm" % [cost["gold"], cost["materials"]]), UITheme.GREEN, Vector2(0, 72))
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.add_theme_font_size_override("font_size", 18)
	up.disabled = int(it["level"]) >= max_lv
	up.pressed.connect(func():
		GameState.upgrade_item(uid)
		_show_inventory())
	row.add_child(up)
	if GameState.is_god("enabled"):
		var mx := UITheme.button("MAX", Color(0.6, 0.42, 0.05), Vector2(90, 72))
		mx.pressed.connect(func():
			GameState.max_item(uid)
			_show_inventory())
		row.add_child(mx)
	var eq := UITheme.button("EQUIP\n" + String(GameData.HEROES[_sel_hero]["class"]).get_slice(" ", 0), UITheme.BLUE, Vector2(120, 72))
	eq.add_theme_font_size_override("font_size", 17)
	eq.pressed.connect(func():
		GameState.equip(_sel_hero, uid)
		_show_inventory())
	row.add_child(eq)
	var sv := UITheme.button("SALVAGE", UITheme.RED, Vector2(120, 72))
	sv.add_theme_font_size_override("font_size", 18)
	sv.pressed.connect(func():
		GameState.salvage_item(uid)
		_selected_uid = -1
		_show_inventory())
	row.add_child(sv)


# ------------------------------------------------------------------ upgrades

func _show_upgrades() -> void:
	var body := _screen_frame("Upgrades")
	_god_note(body)
	body.add_child(_wrap("Permanent upgrades apply to every battle. In-battle roguelike Blessings are chosen every %d waves." % GameData.BLESSING_EVERY, 18, Color(0.85, 0.82, 0.78)))
	if GameState.is_god("enabled"):
		var mb := UITheme.button("GOD: Max every upgrade, hero and item", Color(0.55, 0.38, 0.05), Vector2(0, 64))
		mb.pressed.connect(func():
			GameState.max_all_meta()
			_show_upgrades())
		body.add_child(mb)
	var group := ""
	for uid in GameData.UPGRADE_ORDER:
		var u: Dictionary = GameData.UPGRADES[uid]
		if u["group"] != group:
			group = u["group"]
			body.add_child(UITheme.label(group.to_upper(), 22, UITheme.GOLD))
		var lv := GameState.upgrade_level(uid)
		var mx := int(u["max"])
		var v := _panel(body)
		var head := HBoxContainer.new()
		v.add_child(head)
		var t := UITheme.label("%s   %d/%d" % [u["name"], lv, mx], 22, UITheme.TEXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		var raw := int(GameState.upgrades.get(uid, 0))
		var free := GameState.has_unlimited_resources()
		var bb := UITheme.button("MAX" if raw >= mx else ("BUY" if free else "%d g" % GameData.upgrade_cost(uid, raw)), UITheme.GREEN, Vector2(130, 56))
		bb.add_theme_font_size_override("font_size", 18)
		bb.disabled = raw >= mx
		var key: String = uid
		bb.pressed.connect(func():
			GameState.buy_upgrade(key)
			_show_upgrades())
		head.add_child(bb)
		v.add_child(UITheme.label(u["desc"], 17, Color(0.85, 0.82, 0.78)))
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(0, 14)
		pb.show_percentage = false
		pb.max_value = mx
		pb.value = lv
		pb.add_theme_stylebox_override("fill", UITheme.box(UITheme.GOLD, Color(0, 0, 0, 0), 6, 0, 0))
		v.add_child(pb)
