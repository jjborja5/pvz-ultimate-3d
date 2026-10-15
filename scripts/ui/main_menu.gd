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
var _currency_labels := {}


func _ready() -> void:
	get_tree().paused = false
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
	_build_ui()
	GameState.god_changed.connect(func(_k): _refresh_currencies())


func _process(delta: float) -> void:
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
			enemies.damage(e, 1e9, false)


# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = UITheme.get_theme()
	layer.add_child(ui)
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
	ui.add_child(shade)
	_show_home()


func _clear_screen() -> void:
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
		["Heroes", "swords", func(): _show_coming("Heroes", ["Archer", "Fire Mage", "Ice Wizard", "Lightning Sorcerer", "Paladin", "Druid", "Necromancer", "Dwarf Engineer", "Dragon Summoner"])],
		["Equipment", "shield", func(): _show_coming("Equipment", ["Weapons, armour and relics per hero", "All items unlocked and max level in God Mode"])],
		["Towers", "archer", _show_towers],
		["Upgrades", "gem", func(): _show_coming("Upgrades", ["Permanent tower and castle upgrades", "Roguelike in-battle upgrade picks", "Skill combinations"])],
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
			var sb: StyleBoxFlat = b.get_theme_stylebox(st).duplicate()
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
	body.add_child(UITheme.label("Planned (Phase 3): magical barriers, spike traps, explosive traps, defensive walls.", 20, Color(0.8, 0.8, 0.8)))


func _show_inventory() -> void:
	var body := _screen_frame("Inventory")
	var names := {"gold": "Gold", "gems": "Gems", "diamonds": "Diamonds", "materials": "Upgrade Materials",
		"energy": "Energy", "skill_points": "Skill Points", "summon_tickets": "Summon Tickets"}
	for k in names:
		var row := HBoxContainer.new()
		var l := UITheme.label(names[k], 30)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UITheme.label(GameState.currency_text(k), 34, UITheme.GOLD))
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UITheme.box(Color(0.12, 0.1, 0.2), UITheme.GOLD_DARK, 16, 2, 0))
		p.add_child(row)
		body.add_child(p)


func _show_settings() -> void:
	var body := _screen_frame("Settings")
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
	for pair in [["particles_quality", "Particle Quality", 0.25, 1.0], ["sfx_volume", "Sound Effects (Phase 4)", 0.0, 1.0], ["music_volume", "Music (Phase 4)", 0.0, 1.0]]:
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
	body.add_child(UITheme.label("Castle Dominion v%s  •  offline, no ads, no purchases" % ProjectSettings.get_setting("application/config/version"), 18, Color(0.7, 0.7, 0.7)))


func _show_coming(title_text: String, lines: Array) -> void:
	var body := _screen_frame(title_text)
	var note := UITheme.label("Arrives in Phase 3. Everything will be unlocked and at max level while God Mode is on.", 22, Color(1, 0.9, 0.6))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	for l in lines:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UITheme.box(Color(0.12, 0.1, 0.2), UITheme.GOLD_DARK, 16, 2, 0))
		var lab := UITheme.label(l, 26)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(lab)
		body.add_child(p)


func _open_god() -> void:
	var gp := GodPanel.new()
	gp.closed.connect(_show_home)
	ui.add_child(gp)
