class_name GodPanel
extends Control
## Touch-friendly God Mode control panel. Works from the main menu and in battle.
## In battle, `battle` is set and the action buttons (spawn, kill, reset...) are enabled.

signal closed

var battle: Node = null
var _switches := {}
var _sliders := {}
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 18
	panel.offset_right = -18
	panel.offset_top = 60
	panel.offset_bottom = -40
	var sb := UITheme.box(Color(0.07, 0.05, 0.13, 0.97), UITheme.GOLD, 24, 4, 12)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	# header
	var header := HBoxContainer.new()
	header.add_child(IconArt.new("crown", 60))
	var t := UITheme.title("GOD MODE", 46)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	var close := UITheme.button("X", UITheme.RED, Vector2(72, 72))
	close.pressed.connect(_close)
	header.add_child(close)
	outer.add_child(header)
	_status = UITheme.label("", 20, Color(0.7, 1.0, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	outer.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	_section(list, "POWERS")
	_switch(list, "enabled", "God Mode (master switch)")
	_switch(list, "invincible", "Invincible Castle")
	_switch(list, "unlimited", "Unlimited Resources")
	_switch(list, "no_cooldowns", "No Spell Cooldowns")
	_switch(list, "free_upgrades", "Free Instant Upgrades")
	_switch(list, "one_hit_kill", "One-Hit Kills")
	_switch(list, "auto_complete_waves", "Instant Wave Completion")
	_switch(list, "max_power", "Max Power (heroes, items, upgrades at max)")

	_section(list, "TUNING")
	_slider(list, "game_speed", "Game Speed", 0.25, 5.0, 0.25)
	_slider(list, "attack_speed", "Tower Attack Speed", 0.5, 10.0, 0.5)
	_slider(list, "spawn_mult", "Enemy Spawn Count", 0.5, 10.0, 0.5)

	_section(list, "BATTLE ACTIONS")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	list.add_child(grid)
	_action(grid, "Kill All Enemies", UITheme.RED, func(): battle.god_kill_all())
	_action(grid, "Complete Wave", UITheme.RED, func(): battle.god_complete_wave())
	_action(grid, "Spawn Army x100", UITheme.PURPLE, func(): battle.god_spawn_army("mixed", 100))
	_action(grid, "Spawn Random Boss", UITheme.PURPLE, func(): battle.god_spawn_boss())
	for bt in GameData.BOSS_TYPES:
		_action(grid, "Boss: " + String(GameData.ENEMIES[bt]["name"]).get_slice(",", 0), Color(0.5, 0.12, 0.2), func(): battle.god_spawn_boss(bt))
	_action(grid, "Cast All Ultimates", Color(0.55, 0.38, 0.05), func():
		for i in battle.heroes.size():
			battle.heroes[i].ability_cd = 0.0
			battle.cast_hero(i))
	_action(grid, "Build All Defenses", UITheme.GREEN, func(): battle.god_build_defenses())
	_action(grid, "Pick a Blessing", UITheme.PURPLE, func():
		_close()
		battle.god_blessing())
	_action(grid, "All Blessings + Combos", UITheme.PURPLE, func(): battle.god_all_blessings())
	for type in GameData.REGULAR_TYPES:
		_action(grid, "+25 " + String(GameData.ENEMIES[type]["name"]).get_slice(" ", 1 if type != "goblin" else 0), UITheme.BLUE, func(): battle.god_spawn_army(type, 25))
	_action(grid, "Max All Towers", UITheme.GREEN, func(): battle.god_max_towers())
	_action(grid, "Fill All Pads", UITheme.GREEN, func(): battle.god_fill_pads())
	_action(grid, "Reset Battle", UITheme.BLUE, func(): battle.god_reset())
	_action(grid, "Repair Castle", UITheme.GREEN, func(): battle.castle.repair_full())

	_section(list, "WORLD")
	var map_opt := OptionButton.new()
	map_opt.custom_minimum_size = Vector2(0, 72)
	for i in GameData.MAP_ORDER.size():
		map_opt.add_item("Map: " + String(GameData.MAPS[GameData.MAP_ORDER[i]]["name"]), i)
	map_opt.selected = GameData.MAP_ORDER.find(GameState.current_map)
	map_opt.item_selected.connect(func(i):
		GameState.current_map = GameData.MAP_ORDER[i]
		GameState.save_state()
		if battle:
			battle.god_change_map(GameState.current_map)
		else:
			_flash("Map set: " + String(GameData.MAPS[GameState.current_map]["name"])))
	list.add_child(map_opt)
	var diff_opt := OptionButton.new()
	diff_opt.custom_minimum_size = Vector2(0, 72)
	for i in GameData.DIFFICULTIES.size():
		diff_opt.add_item("Difficulty: " + String(GameData.DIFFICULTIES[i]["name"]), i)
	diff_opt.selected = GameState.difficulty
	diff_opt.item_selected.connect(func(i):
		GameState.difficulty = i
		GameState.save_state()
		_flash("Difficulty: " + String(GameData.DIFFICULTIES[i]["name"]) + " (applies to new waves)"))
	list.add_child(diff_opt)

	_section(list, "PROGRESSION")
	var g2 := GridContainer.new()
	g2.columns = 2
	g2.add_theme_constant_override("h_separation", 10)
	g2.add_theme_constant_override("v_separation", 10)
	list.add_child(g2)
	var unlock_all := func():
		GameState.unlock_everything()
		_flash("Everything unlocked")
	_action(g2, "Unlock Everything", UITheme.GREEN, unlock_all, false)
	var max_all := func():
		GameState.max_all_meta()
		if battle:
			battle.god_max_towers()
		_flash("All upgrades maximised")
	_action(g2, "Max All Upgrades", UITheme.GREEN, max_all, false)
	var unlock_heroes := func():
		GameState.max_all_heroes()
		_flash("All heroes unlocked at max level")
	_action(g2, "Unlock + Max Heroes", UITheme.GREEN, unlock_heroes, false)
	var all_items := func():
		GameState.grant_all_legendaries()
		_flash("Every legendary and mythic granted")
	_action(g2, "Grant All Legendaries", UITheme.GREEN, all_items, false)
	var cash := func():
		for k in GameState.currencies:
			GameState.currencies[k] = 999999
		GameState.save_state()
		_flash("Stored currencies set to 999,999")
	_action(g2, "Fill Currency Stores", UITheme.GREEN, cash, false)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	list.add_child(spacer)
	_refresh()
	# pop-in animation
	panel.pivot_offset = Vector2(340, 600)
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)


func _section(parent: Control, text: String) -> void:
	var l := UITheme.label(text, 24, UITheme.GOLD)
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	var line := ColorRect.new()
	line.color = Color(UITheme.GOLD, 0.4)
	line.custom_minimum_size = Vector2(0, 2)
	parent.add_child(line)


func _switch(parent: Control, key: String, text: String) -> void:
	var cb := CheckButton.new()
	cb.text = text
	cb.custom_minimum_size = Vector2(0, 70)
	cb.button_pressed = bool(GameState.god.get(key, false))
	cb.toggled.connect(func(on):
		GameState.set_god(key, on)
		_flash(text + (" ON" if on else " OFF"))
		_refresh())
	parent.add_child(cb)
	_switches[key] = cb


func _slider(parent: Control, key: String, text: String, lo: float, hi: float, step: float) -> void:
	var row := VBoxContainer.new()
	var l := UITheme.label("", 22)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(GameState.god.get(key, 1.0))
	s.custom_minimum_size = Vector2(0, 48)
	var update_label := func(v): l.text = "%s:  x%.2f" % [text, v]
	update_label.call(s.value)
	s.value_changed.connect(func(v):
		update_label.call(v)
		GameState.set_god(key, v))
	row.add_child(s)
	parent.add_child(row)
	_sliders[key] = s


func _action(parent: Control, text: String, color: Color, cb: Callable, needs_battle := true) -> void:
	var b := UITheme.button(text, color, Vector2(0, 76))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	b.clip_text = true
	if needs_battle and battle == null:
		b.disabled = true
		b.tooltip_text = "Available during a battle"
	b.pressed.connect(func():
		cb.call()
		if needs_battle:
			_flash(text))
	parent.add_child(b)


func _refresh() -> void:
	var master_on := bool(GameState.god["enabled"])
	for k in _switches:
		if k != "enabled":
			(_switches[k] as CheckButton).modulate = Color.WHITE if master_on else Color(1, 1, 1, 0.45)
	for k in _sliders:
		(_sliders[k] as HSlider).modulate = Color.WHITE if master_on else Color(1, 1, 1, 0.45)


func _flash(text: String) -> void:
	_status.text = text
	_status.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_status, "modulate:a", 0.0, 0.5)


func _close() -> void:
	closed.emit()
	queue_free()
