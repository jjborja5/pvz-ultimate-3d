class_name BattleHUD
extends Control
## In-battle interface: wave counter, castle health, currency, boss bar, spell bar,
## build/upgrade sheets, God Mode access, pause and results screens.

var battle: Node
var _wave_label: Label
var _enemy_label: Label
var _gold_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _shield_icon: IconArt
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_name: Label
var _spell_buttons := {}
var _spell_overlays := {}
var _banner: Label
var _hint: Label
var _sheet: PanelContainer
var _speed_btn: Button
var _next_btn: Button
var _modal: Control
var _god_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.get_theme()
	_build_top_bar()
	_build_boss_bar()
	_build_spell_bar()
	_banner = UITheme.title("", 64)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -360
	_banner.offset_right = 360
	_banner.offset_top = -260
	_banner.offset_bottom = -170
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_hint = UITheme.label("", 24, Color(1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -340
	_hint.offset_right = 340
	_hint.offset_top = -250
	_hint.offset_bottom = -210
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_top = 10
	bar.add_theme_stylebox_override("panel", UITheme.box(Color(0.06, 0.05, 0.12, 0.82), UITheme.GOLD_DARK, 18, 2, 6))
	add_child(bar)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	bar.add_child(v)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	v.add_child(row1)
	var pause := UITheme.button("", UITheme.PURPLE, Vector2(64, 64))
	pause.add_child(_centered_icon("pause", 34))
	pause.pressed.connect(func(): battle.toggle_pause())
	row1.add_child(pause)
	var wv := VBoxContainer.new()
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wv.add_theme_constant_override("separation", -4)
	_wave_label = UITheme.label("WAVE 1", 30, UITheme.GOLD)
	_enemy_label = UITheme.label("", 18, Color(0.9, 0.85, 0.8))
	wv.add_child(_wave_label)
	wv.add_child(_enemy_label)
	row1.add_child(wv)
	var gold_box := HBoxContainer.new()
	gold_box.add_child(IconArt.new("gold", 36))
	_gold_label = UITheme.label("0", 30, Color(1, 0.88, 0.4))
	gold_box.add_child(_gold_label)
	gold_box.add_child(IconArt.new("gem", 32))
	var gem_l := UITheme.label(GameState.currency_text("gems"), 26, Color(1, 0.7, 0.9))
	gold_box.add_child(gem_l)
	row1.add_child(gold_box)
	_speed_btn = UITheme.button("1x", UITheme.BLUE, Vector2(70, 64))
	_speed_btn.pressed.connect(_cycle_speed)
	row1.add_child(_speed_btn)
	_god_btn = UITheme.button("", Color(0.55, 0.38, 0.05), Vector2(70, 64))
	_god_btn.add_child(_centered_icon("crown", 44))
	_god_btn.pressed.connect(open_god_panel)
	row1.add_child(_god_btn)
	# castle health row
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	v.add_child(row2)
	row2.add_child(IconArt.new("heart", 30))
	var hp_holder := Control.new()
	hp_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_holder.custom_minimum_size = Vector2(0, 28)
	row2.add_child(hp_holder)
	_hp_bar = ProgressBar.new()
	_hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_bar.show_percentage = false
	_hp_bar.max_value = 1.0
	_hp_bar.value = 1.0
	_hp_bar.add_theme_stylebox_override("fill", UITheme.box(Color(0.3, 0.8, 0.3), Color(0, 0, 0, 0), 10, 0, 0))
	hp_holder.add_child(_hp_bar)
	_hp_label = UITheme.label("", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_holder.add_child(_hp_label)
	_shield_icon = IconArt.new("shield", 30)
	row2.add_child(_shield_icon)


func _centered_icon(kind: String, s: float) -> IconArt:
	var ic := IconArt.new(kind, s)
	ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ic.offset_left = -s / 2
	ic.offset_top = -s / 2
	ic.offset_right = s / 2
	ic.offset_bottom = s / 2
	return ic


func _build_boss_bar() -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_boss_box.offset_top = 170
	_boss_box.offset_left = 40
	_boss_box.offset_right = -40
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_box)
	_boss_name = UITheme.label("", 26, Color(1, 0.55, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	_boss_box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(0, 26)
	_boss_bar.show_percentage = false
	_boss_bar.max_value = 1.0
	_boss_bar.add_theme_stylebox_override("fill", UITheme.box(Color(0.8, 0.15, 0.6), Color(0, 0, 0, 0), 10, 0, 0))
	_boss_box.add_child(_boss_bar)


func _build_spell_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 14
	bar.offset_right = -14
	bar.offset_top = -150
	bar.offset_bottom = -20
	bar.add_theme_constant_override("separation", 10)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bar)
	for id in GameData.SPELL_ORDER:
		var b := Button.new()
		b.custom_minimum_size = Vector2(118, 126)
		b.toggle_mode = true
		b.add_theme_stylebox_override("normal", UITheme.box(Color(0.12, 0.08, 0.2, 0.92), UITheme.GOLD_DARK, 20))
		b.add_theme_stylebox_override("hover", UITheme.box(Color(0.18, 0.12, 0.3, 0.95), UITheme.GOLD, 20))
		b.add_theme_stylebox_override("pressed", UITheme.box(Color(0.35, 0.2, 0.08, 0.95), Color(1, 0.9, 0.4), 20, 5))
		UITheme.juice(b)
		var ic := IconArt.new(id, 70)
		ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		ic.offset_left = -35
		ic.offset_right = 35
		ic.offset_top = 10
		ic.offset_bottom = 80
		b.add_child(ic)
		var l := UITheme.label(GameData.SPELLS[id]["name"], 17, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		l.offset_top = -38
		l.offset_bottom = -8
		b.add_child(l)
		var overlay := ColorRect.new()
		overlay.color = Color(0, 0, 0, 0.6)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(overlay)
		b.pressed.connect(func(): battle.arm_spell(id if b.button_pressed else ""))
		bar.add_child(b)
		_spell_buttons[id] = b
		_spell_overlays[id] = overlay
	_next_btn = UITheme.button("NEXT\nWAVE", UITheme.RED, Vector2(110, 126))
	_next_btn.add_theme_font_size_override("font_size", 22)
	_next_btn.pressed.connect(func(): battle.call_next_wave())
	bar.add_child(_next_btn)


func set_armed_spell(id: String) -> void:
	for k in _spell_buttons:
		(_spell_buttons[k] as Button).set_pressed_no_signal(k == id)
	_hint.text = ("Tap the battlefield to cast " + String(GameData.SPELLS[id]["name"])) if id != "" else ""


func show_hint(text: String) -> void:
	_hint.text = text


func _process(_delta: float) -> void:
	if battle == null:
		return
	var wm: WaveManager = battle.waves
	var max_w := ("/%d" % wm.max_waves) if wm.max_waves > 0 else ""
	_wave_label.text = ("WAVE %d%s" % [maxi(wm.wave, 1), max_w]) if wm.auto_waves else "SANDBOX"
	_enemy_label.text = "%d enemies on field  •  %s" % [battle.enemies.alive_count(), GameData.MAPS[battle.map_id]["name"]]
	_gold_label.text = GameState.INFINITE_DISPLAY if GameState.has_unlimited_resources() else str(battle.gold)
	var c: Castle = battle.castle
	_hp_bar.value = c.hp / Castle.MAX_HP
	var inv := GameState.is_god("invincible")
	_hp_label.text = "INVINCIBLE" if inv else "%d / %d" % [int(c.hp), int(Castle.MAX_HP)]
	_shield_icon.visible = inv
	var spells: SpellSystem = battle.spells
	for id in _spell_overlays:
		var o: ColorRect = _spell_overlays[id]
		var f := spells.ready_fraction(id) if not GameState.is_god("no_cooldowns") else 1.0
		o.anchor_top = f
		o.visible = f < 1.0
	_next_btn.visible = wm.auto_waves and not wm.active
	_speed_btn.text = "%sx" % str(snappedf(GameState.god_value("game_speed", 1.0), 0.25)).trim_suffix(".0")
	var boss: EnemyManager.Enemy = battle.current_boss
	_boss_box.visible = boss != null and boss.alive
	if _boss_box.visible:
		_boss_bar.value = boss.hp / boss.max_hp
		_boss_name.text = GameData.ENEMIES[boss.type]["name"]
	_god_btn.modulate = Color(1, 1, 1) if GameState.god["enabled"] else Color(0.5, 0.5, 0.5)


func _cycle_speed() -> void:
	var speeds := [1.0, 2.0, 3.0, 0.5]
	var cur := GameState.god_value("game_speed", 1.0)
	var idx := 0
	for i in speeds.size():
		if absf(speeds[i] - cur) < 0.01:
			idx = (i + 1) % speeds.size()
	if not GameState.god["enabled"]:
		GameState.set_god("enabled", true)
	GameState.set_god("game_speed", speeds[idx])


func banner(text: String, color := UITheme.GOLD) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.pivot_offset = _banner.size / 2
	_banner.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)


# ------------------------------------------------------------------ sheets

func close_sheet() -> void:
	if _sheet:
		_sheet.queue_free()
		_sheet = null


func _new_sheet(title_text: String) -> VBoxContainer:
	close_sheet()
	_sheet = PanelContainer.new()
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_sheet.offset_left = 12
	_sheet.offset_right = -12
	_sheet.offset_bottom = -160
	_sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sheet.add_theme_stylebox_override("panel", UITheme.box(Color(0.07, 0.05, 0.13, 0.96), UITheme.GOLD, 22, 3, 10))
	add_child(_sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_sheet.add_child(v)
	var head := HBoxContainer.new()
	var t := UITheme.label(title_text, 30, UITheme.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := UITheme.button("X", UITheme.RED, Vector2(64, 64))
	x.pressed.connect(func(): battle.deselect())
	head.add_child(x)
	v.add_child(head)
	_sheet.modulate.a = 0.0
	_sheet.position.y += 40
	_sheet.create_tween().tween_property(_sheet, "modulate:a", 1.0, 0.15)
	return v


func show_build_sheet(pad_index: int) -> void:
	var v := _new_sheet("Build Defense")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for type in GameData.TOWER_ORDER:
		var def: Dictionary = GameData.TOWERS[type]
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", UITheme.box(Color(0.14, 0.1, 0.24), UITheme.GOLD_DARK, 18))
		b.add_theme_stylebox_override("hover", UITheme.box(Color(0.2, 0.15, 0.32), UITheme.GOLD, 18))
		b.add_theme_stylebox_override("pressed", UITheme.box(Color(0.1, 0.08, 0.16), UITheme.GOLD, 18))
		UITheme.juice(b)
		var ic := IconArt.new(type, 64)
		ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		ic.offset_left = -32
		ic.offset_right = 32
		ic.offset_top = 8
		ic.offset_bottom = 72
		b.add_child(ic)
		var cost: int = def["cost"][0]
		var free := GameState.has_unlimited_resources()
		var l := UITheme.label("%s\n%s" % [def["name"], "FREE" if free else str(cost) + " gold"], 19, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		l.offset_top = -70
		l.offset_bottom = -6
		b.add_child(l)
		b.disabled = not free and battle.gold < cost
		b.pressed.connect(func(): battle.build_tower(pad_index, type))
		grid.add_child(b)


func show_tower_sheet(t: Tower) -> void:
	var def: Dictionary = GameData.TOWERS[t.type]
	var v := _new_sheet("%s  —  Level %d" % [def["name"], t.level])
	var stars := ""
	for i in GameData.TOWER_MAX_LEVEL:
		stars += "★" if i < t.level else "☆"
	v.add_child(UITheme.label(stars, 34, UITheme.GOLD))
	v.add_child(UITheme.label(def["desc"], 20, Color(0.85, 0.82, 0.78)))
	var info := "Damage %d   Rate %.1f/s   Range %d" % [int(t.stat("damage")), t.stat("rate"), int(t.stat("range"))]
	v.add_child(UITheme.label(info, 21, Color(0.8, 0.95, 1.0)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var free := GameState.is_god("free_upgrades") or GameState.has_unlimited_resources()
	var up := UITheme.button("MAXED" if not t.can_upgrade() else ("UPGRADE  (FREE)" if free else "UPGRADE  %d" % t.upgrade_cost()), UITheme.GREEN, Vector2(0, 80))
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.disabled = not t.can_upgrade() or (not free and battle.gold < t.upgrade_cost())
	up.pressed.connect(func(): battle.upgrade_selected())
	row.add_child(up)
	if free and t.can_upgrade():
		var mx := UITheme.button("MAX", Color(0.6, 0.42, 0.05), Vector2(120, 80))
		mx.pressed.connect(func(): battle.max_selected())
		row.add_child(mx)
	var sell := UITheme.button("SELL", UITheme.RED, Vector2(120, 80))
	sell.pressed.connect(func(): battle.sell_selected())
	row.add_child(sell)


# ------------------------------------------------------------------ modals

func open_god_panel() -> void:
	var gp := GodPanel.new()
	gp.battle = battle
	add_child(gp)


func show_pause() -> void:
	_show_modal("PAUSED", [
		["Resume", UITheme.GREEN, func(): battle.toggle_pause()],
		["Restart Battle", UITheme.BLUE, func(): battle.god_reset()],
		["God Mode", Color(0.55, 0.38, 0.05), func(): open_god_panel()],
		["Main Menu", UITheme.RED, func(): battle.exit_to_menu()],
	])


func show_result(victory: bool, wave: int) -> void:
	_show_modal("VICTORY!" if victory else "CASTLE FALLEN", [
		["Play Again", UITheme.GREEN, func(): battle.god_reset()],
		["Main Menu", UITheme.RED, func(): battle.exit_to_menu()],
	], "Waves survived: %d" % wave)


func hide_modal() -> void:
	if _modal:
		_modal.queue_free()
		_modal = null


func _show_modal(title_text: String, buttons: Array, subtitle := "") -> void:
	hide_modal()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -270
	p.offset_right = 270
	p.offset_top = -300
	p.offset_bottom = 300
	_modal.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	v.add_child(UITheme.title(title_text, 54))
	if subtitle != "":
		v.add_child(UITheme.label(subtitle, 26, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	for b in buttons:
		var btn := UITheme.button(b[0], b[1], Vector2(0, 84))
		btn.pressed.connect(b[2])
		v.add_child(btn)
	add_child(_modal)
