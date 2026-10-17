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
var pause_open := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UITheme.apply_safe_area(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.get_theme()
	var vig := UITheme.vignette()
	add_child(vig)
	# the vignette spans the whole screen even though the HUD itself is inset from the notch
	GameState.safe_area_changed.connect(func(): _extend_full_screen.call_deferred(vig))
	_extend_full_screen.call_deferred(vig)
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
	_hint.offset_top = -312
	_hint.offset_bottom = -272
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1, 0.9))
	add_child(_hint)


func _extend_full_screen(c: Control) -> void:
	if is_instance_valid(c):
		c.offset_top = -offset_top
		c.offset_bottom = -offset_bottom
		c.offset_left = -offset_left
		c.offset_right = -offset_right


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


const HERO_ICONS := {"archer": "archer", "fire_mage": "fire", "ice_wizard": "ice", "storm_sorcerer": "lightning", "paladin": "shield",
	"druid": "leaf", "necromancer": "skull", "engineer": "cannon", "dragon_summoner": "dragon"}
const SPELLS_PER_PAGE := 4

var _spell_page := 0
var _spell_row: HBoxContainer
var _hero_overlays: Array = []
var _hero_buttons: Array = []
var _build_btn: Button
var _flash_rect: ColorRect
var _letterbox: Array = []
var _boss_title: Label
var _boss_sub: Label
var _toasts: VBoxContainer
var _row1: HBoxContainer
var _fps: Label


func _build_spell_bar() -> void:
	# --- row 1: hero ultimates, build button, next wave
	var row1 := HBoxContainer.new()
	_row1 = row1
	row1.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row1.offset_left = 10
	row1.offset_right = -10
	row1.offset_top = -258
	row1.offset_bottom = -150
	row1.add_theme_constant_override("separation", 8)
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row1)
	_hero_overlays.clear()
	_hero_buttons.clear()
	for i in battle.heroes.size():
		var h: Hero = battle.heroes[i]
		var col: Color = h.def["color"]
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 104)
		b.add_theme_stylebox_override("normal", UITheme.box(Color(col.r * 0.25, col.g * 0.25, col.b * 0.3, 0.94), col, 22, 3))
		b.add_theme_stylebox_override("hover", UITheme.box(Color(col.r * 0.35, col.g * 0.35, col.b * 0.4, 0.96), col.lightened(0.3), 22, 3))
		b.add_theme_stylebox_override("pressed", UITheme.box(Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.96), Color(1, 1, 0.8), 22, 4))
		UITheme.juice(b)
		var ic := UITheme.portrait(h.id, 60)
		ic.position = Vector2(6, 6)
		b.add_child(ic)
		var nl := UITheme.label(String(h.def["class"]).get_slice(" ", 0), 18, col.lightened(0.4))
		nl.position = Vector2(68, 8)
		b.add_child(nl)
		var al := UITheme.label(String(h.def["ability"]["name"]), 15, UITheme.TEXT)
		al.position = Vector2(68, 34)
		al.size = Vector2(80, 50)
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(al)
		var lv := UITheme.label("Lv %d" % h.stats["level"], 15, UITheme.GOLD)
		lv.position = Vector2(10, 70)
		b.add_child(lv)
		var ov := ColorRect.new()
		ov.color = Color(0, 0, 0, 0.62)
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(ov)
		var idx: int = i
		b.pressed.connect(func(): battle.cast_hero(idx))
		row1.add_child(b)
		_hero_overlays.append(ov)
		_hero_buttons.append(b)
	_build_btn = UITheme.button("BUILD", UITheme.GREEN, Vector2(96, 104))
	_build_btn.add_theme_font_size_override("font_size", 20)
	_build_btn.pressed.connect(func():
		if battle.placing_defense != "":
			battle.stop_placing()
		else:
			show_defense_build_sheet())
	row1.add_child(_build_btn)
	_next_btn = UITheme.button("NEXT\nWAVE", UITheme.RED, Vector2(96, 104))
	_next_btn.add_theme_font_size_override("font_size", 20)
	_next_btn.pressed.connect(func(): battle.call_next_wave())
	row1.add_child(_next_btn)
	# --- row 2: spells (paged)
	_spell_row = HBoxContainer.new()
	_spell_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_spell_row.offset_left = 10
	_spell_row.offset_right = -10
	_spell_row.offset_top = -142
	_spell_row.offset_bottom = -16
	_spell_row.add_theme_constant_override("separation", 8)
	_spell_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_spell_row)
	_fill_spell_row()
	# overlays: flash, letterbox, toasts
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	add_child(_flash_rect)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.92)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 120 if top else 200)
		if top:
			bar.offset_top = 0
			bar.offset_bottom = 120
		else:
			bar.offset_top = -200
		bar.visible = false
		add_child(bar)
		_letterbox.append(bar)
	_boss_title = UITheme.title("", 58)
	_boss_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_title.offset_left = -360
	_boss_title.offset_right = 360
	_boss_title.offset_top = -330
	_boss_title.offset_bottom = -250
	_boss_title.add_theme_color_override("font_color", Color(1, 0.45, 0.3))
	_boss_title.visible = false
	_boss_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_title)
	_boss_sub = UITheme.label("", 28, Color(1, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	_boss_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_sub.offset_left = -360
	_boss_sub.offset_right = 360
	_boss_sub.offset_top = -255
	_boss_sub.offset_bottom = -215
	_boss_sub.visible = false
	_boss_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_sub)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toasts.offset_top = 240
	_toasts.offset_left = 60
	_toasts.offset_right = -60
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	add_child(_toasts)


func _fill_spell_row() -> void:
	for c in _spell_row.get_children():
		c.queue_free()
	_spell_buttons.clear()
	_spell_overlays.clear()
	var start := _spell_page * SPELLS_PER_PAGE
	for i in range(start, mini(start + SPELLS_PER_PAGE, GameData.SPELL_ORDER.size())):
		var id: String = GameData.SPELL_ORDER[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(124, 124)
		b.toggle_mode = true
		b.add_theme_stylebox_override("normal", UITheme.box(Color(0.12, 0.08, 0.2, 0.92), UITheme.GOLD_DARK, 20))
		b.add_theme_stylebox_override("hover", UITheme.box(Color(0.18, 0.12, 0.3, 0.95), UITheme.GOLD, 20))
		b.add_theme_stylebox_override("pressed", UITheme.box(Color(0.35, 0.2, 0.08, 0.95), Color(1, 0.9, 0.4), 20, 5))
		UITheme.juice(b)
		var ic := IconArt.new(id, 70)
		ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		ic.offset_left = -35
		ic.offset_right = 35
		ic.offset_top = 8
		ic.offset_bottom = 78
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
		b.set_pressed_no_signal(battle.armed_spell == id)
		_spell_row.add_child(b)
		_spell_buttons[id] = b
		_spell_overlays[id] = overlay
	var pages := int(ceil(GameData.SPELL_ORDER.size() / float(SPELLS_PER_PAGE)))
	var pg := UITheme.button("%d/%d\n>" % [_spell_page + 1, pages], UITheme.BLUE, Vector2(76, 124))
	pg.add_theme_font_size_override("font_size", 22)
	pg.pressed.connect(func():
		_spell_page = (_spell_page + 1) % pages
		_fill_spell_row())
	_spell_row.add_child(pg)


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
	_hp_bar.value = c.hp / c.max_hp
	var inv := GameState.is_god("invincible")
	_hp_label.text = "INVINCIBLE" if inv else "%d / %d" % [int(c.hp), int(c.max_hp)]
	_shield_icon.visible = inv
	var spells: SpellSystem = battle.spells
	for id in _spell_overlays:
		var o: ColorRect = _spell_overlays[id]
		if not is_instance_valid(o):
			continue
		var f := spells.ready_fraction(id) if not GameState.is_god("no_cooldowns") else 1.0
		o.anchor_top = f
		o.visible = f < 1.0
	for i in mini(_hero_overlays.size(), battle.heroes.size()):
		if not is_instance_valid(battle.heroes[i]):
			continue
		var hf: float = battle.heroes[i].ability_ready_fraction()
		var ho: ColorRect = _hero_overlays[i]
		ho.anchor_top = hf
		ho.visible = hf < 1.0
		(_hero_buttons[i] as Control).modulate = Color(1.15, 1.15, 1.0) if hf >= 1.0 and int(Time.get_ticks_msec() / 400) % 2 == 0 else Color.WHITE
	_build_btn.text = "STOP" if battle.placing_defense != "" else "BUILD"
	_next_btn.visible = wm.auto_waves and not wm.active
	_speed_btn.text = "%sx" % str(snappedf(GameState.god_value("game_speed", 1.0), 0.25)).trim_suffix(".0")
	var boss: EnemyManager.Enemy = battle.current_boss
	_boss_box.visible = boss != null and boss.alive
	if _boss_box.visible:
		_boss_bar.value = boss.hp / boss.max_hp
		_boss_name.text = GameData.ENEMIES[boss.type]["name"] + ("  [SHIELDED]" if boss.immune_t > 0.0 else "")
	_god_btn.modulate = Color(1, 1, 1) if GameState.god["enabled"] else Color(0.5, 0.5, 0.5)
	if GameState.settings.get("show_fps", false):
		if _fps == null:
			_fps = UITheme.label("", 16, Color(0.7, 1, 0.7))
			_fps.position = Vector2(14, 214)
			add_child(_fps)
		_fps.text = "%d FPS (%.1f ms)  •  %d enemies  •  %d draws  •  %dk tris\nsim %.1f ms  •  RAM %d MB  •  VRAM %d MB  •  %s" % [
			Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			battle.enemies.alive_count(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
			battle.enemies.stats["sim_us"] / 1000.0,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			GameState.quality_profile()["name"]]
		_fps.add_theme_constant_override("outline_size", 6)
		_fps.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	elif _fps:
		_fps.queue_free()
		_fps = null


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

func close_sheet(silent := false) -> void:
	if _sheet:
		if not silent:
			Audio.sfx("ui_back", -8.0, 0.03, 0.05)
		_sheet.queue_free()
		_sheet = null


func _new_sheet(title_text: String) -> VBoxContainer:
	close_sheet(true)
	Audio.sfx("ui_open", -8.0, 0.03, 0.05)
	_sheet = PanelContainer.new()
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_sheet.offset_left = 12
	_sheet.offset_right = -12
	_sheet.offset_bottom = -266
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

func close_god_panel() -> bool:
	for c in get_children():
		if c is GodPanel:
			c.queue_free()
			return true
	return false


func open_god_panel() -> void:
	Audio.sfx("ui_open", -6.0, 0.0, 0.05)
	var gp := GodPanel.new()
	gp.battle = battle
	add_child(gp)


func show_pause() -> void:
	_show_modal("PAUSED", [
		["Resume", UITheme.GREEN, func(): battle.toggle_pause()],
		["Restart Battle", UITheme.BLUE, func(): battle.god_reset()],
		["God Mode", Color(0.55, 0.38, 0.05), func(): open_god_panel()],
		["Save Game", UITheme.BLUE, func():
			GameState.save_state()
			_toast("Game saved", UITheme.GREEN, "Progress is also saved automatically.")],
		["Main Menu", UITheme.RED, func(): battle.exit_to_menu()],
	])
	pause_open = true


func show_result(victory: bool, wave: int, summary := {}) -> void:
	var lines := "Waves survived: %d" % wave
	if not summary.is_empty():
		lines += "\nKills: %d   Hero XP: +%d" % [summary["kills"], summary["xp"]]
		lines += "\n+%d gold  +%d gems  +%d materials" % [summary["gold"], summary["gems"], summary["materials"]]
		for hid in summary["levels"]:
			if int(summary["levels"][hid]) > 0:
				lines += "\n%s gained %d level(s)!" % [GameData.HEROES[hid]["name"], summary["levels"][hid]]
		var items: Array = summary["items"]
		if not items.is_empty():
			lines += "\nLoot found: %d item(s)" % items.size()
			for it in items.slice(0, 4):
				lines += "\n  [%s] %s" % [Loot.rarity_name(it), it["name"]]
	_show_modal("VICTORY!" if victory else "CASTLE FALLEN", [
		["Play Again", UITheme.GREEN, func(): battle.god_reset()],
		["Main Menu", UITheme.RED, func(): battle.exit_to_menu()],
	], lines)


# ------------------------------------------------------------------ defenses

func show_defense_build_sheet() -> void:
	var v := _new_sheet("Build Defenses")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var icons := {"spike_trap": "swords", "barrel_trap": "fire", "frost_rune": "ice", "barrier": "shield", "wall": "castle"}
	for type in GameData.DEFENSE_ORDER:
		var def: Dictionary = GameData.DEFENSES[type]
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 140)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", UITheme.box(Color(0.1, 0.16, 0.12), UITheme.GOLD_DARK, 18))
		b.add_theme_stylebox_override("hover", UITheme.box(Color(0.14, 0.22, 0.16), UITheme.GOLD, 18))
		b.add_theme_stylebox_override("pressed", UITheme.box(Color(0.08, 0.12, 0.1), UITheme.GOLD, 18))
		UITheme.juice(b)
		var ic := IconArt.new(icons[type], 56)
		ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		ic.offset_left = -28
		ic.offset_right = 28
		ic.offset_top = 6
		ic.offset_bottom = 62
		b.add_child(ic)
		var cost: int = battle.defenses.cost(type)
		var free := GameState.has_unlimited_resources() or cost == 0
		var l := UITheme.label("%s\n%s" % [def["name"], "FREE" if free else str(cost) + " gold"], 18, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		l.offset_top = -64
		l.offset_bottom = -6
		b.add_child(l)
		b.pressed.connect(func():
			close_sheet()
			battle.begin_placing(type))
		grid.add_child(b)
	var note := UITheme.label("Traps damage enemies that walk over them. Barriers and walls block a lane until destroyed.", 18, Color(0.85, 0.85, 0.8))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)


func show_defense_sheet(d: Object) -> void:
	var def: Dictionary = GameData.DEFENSES[d.type]
	var v := _new_sheet("%s  —  Level %d" % [def["name"], d.level])
	var stars := ""
	for i in GameData.DEFENSE_MAX_LEVEL:
		stars += "★" if i < d.level else "☆"
	v.add_child(UITheme.label(stars, 34, UITheme.GOLD))
	var desc := UITheme.label(def["desc"], 20, Color(0.85, 0.82, 0.78))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	if d.max_hp > 1.0:
		v.add_child(UITheme.label("Health %d / %d" % [int(d.hp), int(d.max_hp)], 21, Color(0.8, 0.95, 1.0)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var maxed: bool = d.level >= GameData.DEFENSE_MAX_LEVEL
	var free := GameState.is_god("free_upgrades") or GameState.has_unlimited_resources()
	var up := UITheme.button("MAXED" if maxed else ("UPGRADE (FREE)" if free else "UPGRADE %d" % battle.defenses.cost(d.type, d.level + 1)), UITheme.GREEN, Vector2(0, 80))
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.disabled = maxed
	up.pressed.connect(func(): battle.upgrade_defense())
	row.add_child(up)
	if free and not maxed:
		var mx := UITheme.button("MAX", Color(0.6, 0.42, 0.05), Vector2(110, 80))
		mx.pressed.connect(func(): battle.max_defense())
		row.add_child(mx)
	var sell := UITheme.button("SELL", UITheme.RED, Vector2(110, 80))
	sell.pressed.connect(func(): battle.sell_defense())
	row.add_child(sell)


# ------------------------------------------------------------------ roguelike / feedback

func show_blessing_picker(ids: Array) -> void:
	hide_modal()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.06, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_right = -24
	v.offset_top = 200
	v.offset_bottom = -120
	v.add_theme_constant_override("separation", 18)
	_modal.add_child(v)
	v.add_child(UITheme.title("CHOOSE A BLESSING", 46))
	v.add_child(UITheme.label("Blessings last for this battle. Matching elements unlock combos.", 20, Color(0.9, 0.85, 0.75), HORIZONTAL_ALIGNMENT_CENTER))
	var tag_col := {"fire": Color(1, 0.5, 0.2), "ice": Color(0.5, 0.85, 1), "lightning": Color(0.65, 0.65, 1), "physical": Color(0.9, 0.85, 0.7),
		"hero": Color(1, 0.8, 0.3), "arcane": Color(0.85, 0.5, 1), "wealth": Color(1, 0.9, 0.3), "defense": Color(0.5, 1, 0.6),
		"holy": Color(1, 0.95, 0.6), "nature": Color(0.5, 1, 0.4)}
	for i in ids.size():
		var id: String = ids[i]
		var def: Dictionary = GameData.BLESSINGS[id]
		var tag: String = def["tags"][0]
		var col: Color = tag_col.get(tag, UITheme.GOLD)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 150)
		b.add_theme_stylebox_override("normal", UITheme.box(Color(col.r * 0.18, col.g * 0.18, col.b * 0.22, 0.97), col, 22, 4, 10))
		b.add_theme_stylebox_override("hover", UITheme.box(Color(col.r * 0.28, col.g * 0.28, col.b * 0.32, 0.97), col.lightened(0.3), 22, 4, 10))
		b.add_theme_stylebox_override("pressed", UITheme.box(Color(col.r * 0.4, col.g * 0.4, col.b * 0.4, 0.97), Color(1, 1, 1), 22, 5, 10))
		UITheme.juice(b)
		var t := UITheme.label(def["name"], 32, col.lightened(0.3))
		t.position = Vector2(24, 16)
		b.add_child(t)
		var dsc := UITheme.label(def["desc"], 22, UITheme.TEXT)
		dsc.position = Vector2(24, 62)
		dsc.size = Vector2(580, 60)
		dsc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(dsc)
		var tg := UITheme.label(", ".join(def["tags"]).to_upper() + ("   (owned x%d)" % battle.run.picks.count(id) if battle.run.picks.has(id) else ""), 16, col)
		tg.position = Vector2(24, 116)
		b.add_child(tg)
		b.pressed.connect(func(): battle.pick_blessing(id))
		v.add_child(b)
		b.modulate.a = 0.0
		b.position.x += 60
		var tw := b.create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(b, "modulate:a", 1.0, 0.2)
	if GameState.is_god("enabled"):
		var rr := UITheme.button("REROLL (God Mode)", Color(0.55, 0.38, 0.05), Vector2(0, 70))
		rr.pressed.connect(func(): show_blessing_picker(battle.run.offer(3)))
		v.add_child(rr)
	add_child(_modal)


func _toast(text: String, color: Color, sub := "") -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(Color(0.06, 0.04, 0.1, 0.92), color, 16, 3, 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_child(UITheme.label(text, 24, color.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER))
	if sub != "":
		var s := UITheme.label(sub, 18, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	p.add_child(v)
	_toasts.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).free()


func combo_toast(id: String) -> void:
	var c: Dictionary = GameData.COMBOS[id]
	_toast("COMBO UNLOCKED: " + String(c["name"]), Color(1.0, 0.75, 0.25), c["desc"])


func loot_toast(item: Dictionary) -> void:
	_toast("%s LOOT: %s" % [Loot.rarity_name(item).to_upper(), item["name"]], Loot.rarity_color(item), Loot.stats_text(item))


func flash(color: Color, duration: float) -> void:
	_flash_rect.color = Color(color.r, color.g, color.b, 0.35)
	var tw := _flash_rect.create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, duration)


func boss_intro(name: String, epithet: String, color := Color(1, 0.45, 0.3)) -> void:
	_boss_title.add_theme_color_override("font_color", color)
	for bar in _letterbox:
		bar.visible = true
		bar.modulate.a = 0.0
		bar.create_tween().tween_property(bar, "modulate:a", 1.0, 0.3)
	_row1.visible = false
	_spell_row.visible = false
	_hint.visible = false
	_boss_title.text = name.to_upper()
	_boss_sub.text = epithet
	_boss_title.visible = true
	_boss_sub.visible = true
	_boss_title.pivot_offset = Vector2(360, 40)
	_boss_title.scale = Vector2(1.6, 1.6)
	_boss_title.modulate.a = 0.0
	var tw := _boss_title.create_tween().set_parallel(true)
	tw.tween_property(_boss_title, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_boss_title, "modulate:a", 1.0, 0.3)


func boss_defeated(name: String) -> void:
	## Reward celebration after a boss death sequence.
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var glow := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 0.85, 0.4, 0.55), Color(1, 0.7, 0.2, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	glow.texture = gt
	glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	glow.offset_left = -360
	glow.offset_right = 360
	glow.offset_top = -420
	glow.offset_bottom = 60
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow)
	var t := UITheme.title("VICTORY OVER", 34)
	t.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	t.offset_left = -360
	t.offset_right = 360
	t.offset_top = -280
	t.offset_bottom = -235
	t.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	root.add_child(t)
	var n := UITheme.title(name.to_upper(), 58)
	n.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	n.offset_left = -360
	n.offset_right = 360
	n.offset_top = -235
	n.offset_bottom = -165
	root.add_child(n)
	var rw := UITheme.label("Treasure chest  •  +5 gems  •  +3 materials", 24, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	rw.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rw.offset_left = -360
	rw.offset_right = 360
	rw.offset_top = -160
	rw.offset_bottom = -125
	root.add_child(rw)
	var ic := IconArt.new("crown", 90)
	ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ic.offset_left = -45
	ic.offset_right = 45
	ic.offset_top = -380
	ic.offset_bottom = -290
	root.add_child(ic)
	root.pivot_offset = Vector2(360, 300)
	root.scale = Vector2(0.6, 0.6)
	root.modulate.a = 0.0
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "modulate:a", 1.0, 0.25)
	tw.chain().tween_interval(2.4)
	tw.chain().tween_property(root, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(root.queue_free)


func boss_intro_end() -> void:
	_row1.visible = true
	_spell_row.visible = true
	_hint.visible = true
	for bar in _letterbox:
		var tw: Tween = bar.create_tween()
		tw.tween_property(bar, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func(): bar.visible = false)
	_boss_title.visible = false
	_boss_sub.visible = false


func hide_modal() -> void:
	pause_open = false
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
