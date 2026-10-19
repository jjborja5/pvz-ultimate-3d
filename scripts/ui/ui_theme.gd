class_name UITheme
extends RefCounted
## Fantasy-styled UI theme built in code + small "juice" helpers for buttons.

const GOLD := Color(0.95, 0.75, 0.3)
const GOLD_DARK := Color(0.55, 0.38, 0.12)
const PANEL := Color(0.08, 0.07, 0.15, 0.94)
const PURPLE := Color(0.3, 0.17, 0.46)
const RED := Color(0.62, 0.14, 0.12)
const GREEN := Color(0.18, 0.5, 0.22)
const BLUE := Color(0.16, 0.3, 0.58)
const TEXT := Color(1.0, 0.96, 0.88)

static var _theme: Theme


static var _box_cache := {}
static var _font_title: FontVariation
static var _font_body: FontVariation
static var _font_body_bold: FontVariation


static func font_title() -> Font:
	if _font_title == null:
		_font_title = FontVariation.new()
		_font_title.base_font = load("res://assets/fonts/Cinzel-Variable.ttf")
		_font_title.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
		_font_title.fallbacks = [ThemeDB.fallback_font]   # symbols such as ∞ (browsers offer no system fallback)
	return _font_title


static func font_body() -> Font:
	if _font_body == null:
		_font_body = FontVariation.new()
		_font_body.base_font = load("res://assets/fonts/Fredoka-Variable.ttf")
		_font_body.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
		_font_body.fallbacks = [ThemeDB.fallback_font]   # symbols such as ∞ (browsers offer no system fallback)
	return _font_body


static func font_bold() -> Font:
	if _font_body_bold == null:
		_font_body_bold = FontVariation.new()
		_font_body_bold.base_font = load("res://assets/fonts/Fredoka-Variable.ttf")
		_font_body_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
		_font_body_bold.fallbacks = [ThemeDB.fallback_font]   # symbols such as ∞ (browsers offer no system fallback)
	return _font_body_bold


static func box(bg: Color, border: Color = GOLD, radius := 16, border_w := 3, shadow := 6) -> StyleBox:
	## Premium panel/button style: vertical gradient fill with a glossy top highlight,
	## a bevelled metallic rim and a baked soft drop shadow (9-slice texture).
	var key := "%s|%s|%d|%d|%d" % [bg.to_html(), border.to_html(), radius, border_w, shadow]
	if _box_cache.has(key):
		return (_box_cache[key] as StyleBox).duplicate()
	var r := maxi(radius, 2)
	var pad := shadow + 2
	var w := r * 2 + 24 + pad * 2
	var h := r * 2 + 40 + pad * 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var top := bg.lightened(0.16)
	var bottom := bg.darkened(0.22)
	top.a = bg.a
	bottom.a = bg.a
	var rim_hi := border.lightened(0.35)
	var rim_lo := border.darkened(0.35)
	var half := Vector2((w - pad * 2) * 0.5, (h - pad * 2) * 0.5)
	var center := Vector2(w * 0.5, pad + half.y)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5) - center
			var d := _sd_round(p, half, r)
			var c := Color(0, 0, 0, 0)
			# baked drop shadow
			if shadow > 0:
				var ds := _sd_round(p - Vector2(0, shadow * 0.5), half, r)
				var sa := clampf(1.0 - ds / float(shadow), 0.0, 1.0)
				c = Color(0, 0, 0, sa * sa * 0.5)
			if d < 1.0:
				var ty := clampf((p.y + half.y) / (half.y * 2.0), 0.0, 1.0)
				var fill := top.lerp(bottom, ty)
				# glossy highlight on the top 42%
				if ty < 0.42:
					var gl := (1.0 - ty / 0.42) * 0.12
					fill = Color(fill.r + gl, fill.g + gl, fill.b + gl, fill.a)
				var col := fill
				if border_w > 0 and border.a > 0.01 and d > -border_w:
					var rim := rim_hi.lerp(rim_lo, ty)
					# inner bevel line
					var bev := clampf(1.0 - absf(d + border_w * 0.5) / (border_w * 0.6), 0.0, 1.0)
					rim = rim.lightened(bev * 0.25)
					col = col.lerp(rim, border.a)
				elif border_w > 0 and border.a > 0.01 and d > -border_w - 2.0:
					col = col.darkened(0.25)   # dark inner line under the rim
				var aa := clampf(0.5 - d, 0.0, 1.0)
				col.a *= aa
				# composite over shadow
				var out_a := col.a + c.a * (1.0 - col.a)
				if out_a > 0.0:
					c = Color((col.r * col.a + c.r * c.a * (1.0 - col.a)) / out_a, (col.g * col.a + c.g * c.a * (1.0 - col.a)) / out_a,
						(col.b * col.a + c.b * c.a * (1.0 - col.a)) / out_a, out_a)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	var m := r + pad + 2
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.expand_margin_left = pad
	sb.expand_margin_right = pad
	sb.expand_margin_top = pad
	sb.expand_margin_bottom = pad
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_box_cache[key] = sb
	return sb.duplicate()


static func _sd_round(p: Vector2, half: Vector2, r: float) -> float:
	var q := Vector2(absf(p.x), absf(p.y)) - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font_body()
	t.default_font_size = 26
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0.05, 0.02, 0.0))
	t.set_constant("outline_size", "Label", 6)
	t.set_stylebox("panel", "Panel", box(PANEL))
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	t.set_stylebox("normal", "Button", box(PURPLE))
	t.set_stylebox("hover", "Button", box(PURPLE.lightened(0.15), GOLD.lightened(0.2)))
	t.set_stylebox("pressed", "Button", box(PURPLE.darkened(0.3), GOLD_DARK))
	t.set_stylebox("disabled", "Button", box(Color(0.2, 0.2, 0.24), Color(0.4, 0.4, 0.4)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 0.9))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_outline_color", "Button", Color(0.05, 0.02, 0.0))
	t.set_constant("outline_size", "Button", 6)
	t.set_font_size("font_size", "Button", 26)
	t.set_font("font", "Button", font_bold())
	# CheckButton (God Mode switches)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color(1, 1, 0.9))
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_font_size("font_size", "CheckButton", 26)
	t.set_stylebox("normal", "CheckButton", box(Color(0.14, 0.12, 0.24), GOLD_DARK, 12, 2, 0))
	t.set_stylebox("hover", "CheckButton", box(Color(0.18, 0.15, 0.3), GOLD, 12, 2, 0))
	t.set_stylebox("pressed", "CheckButton", box(Color(0.18, 0.15, 0.3), GOLD, 12, 2, 0))
	t.set_stylebox("hover_pressed", "CheckButton", box(Color(0.2, 0.17, 0.32), GOLD, 12, 2, 0))
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_icon("checked", "CheckButton", _switch_icon(true))
	t.set_icon("unchecked", "CheckButton", _switch_icon(false))
	# sliders
	var grab := _knob_icon()
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)
	var track := box(Color(0.15, 0.12, 0.22), GOLD_DARK, 8, 2, 0)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(GOLD.darkened(0.2), GOLD, 8, 2, 0)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	# option button / popup
	t.set_stylebox("normal", "OptionButton", box(BLUE))
	t.set_stylebox("hover", "OptionButton", box(BLUE.lightened(0.15)))
	t.set_stylebox("pressed", "OptionButton", box(BLUE.darkened(0.2)))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PopupMenu", box(PANEL))
	t.set_font_size("font_size", "PopupMenu", 28)
	t.set_font_size("font_size", "OptionButton", 24)
	t.set_constant("v_separation", "PopupMenu", 14)
	# progress bars
	t.set_stylebox("background", "ProgressBar", box(Color(0.1, 0.05, 0.05, 0.9), Color(0.1, 0.05, 0.02), 10, 2, 2))
	t.set_stylebox("fill", "ProgressBar", box(Color(0.85, 0.2, 0.15), Color(1, 0.5, 0.4, 0.0), 10, 0, 0))
	t.set_font_size("font_size", "ProgressBar", 18)
	# scroll
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	var sg := box(GOLD.darkened(0.3), GOLD_DARK, 6, 0, 0)
	t.set_stylebox("grabber", "VScrollBar", sg)
	t.set_stylebox("grabber_highlight", "VScrollBar", sg)
	t.set_stylebox("grabber_pressed", "VScrollBar", sg)
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 6, 0, 0))
	_theme = t
	return t


static func _switch_icon(on: bool) -> Texture2D:
	var w := 84
	var h := 44
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := Color(0.25, 0.75, 0.35) if on else Color(0.3, 0.28, 0.36)
	var r := h / 2.0
	for y in h:
		for x in w:
			var cx := clampf(x, r, w - r)
			var d := Vector2(x - cx, y - r).length()
			if d <= r - 1:
				img.set_pixel(x, y, track)
			elif d <= r:
				img.set_pixel(x, y, Color(track, 0.5))
	var kx := w - r if on else r
	for y in h:
		for x in w:
			var d := Vector2(x - kx, y - r).length()
			if d <= r - 4:
				var shade := 1.0 - (y / float(h)) * 0.25
				img.set_pixel(x, y, Color(GOLD.r * shade + 0.1, GOLD.g * shade + 0.1, GOLD.b * shade))
	return ImageTexture.create_from_image(img)


static func _knob_icon() -> Texture2D:
	var s := 36
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s / 2.0, y - s / 2.0).length()
			if d <= s / 2.0 - 1:
				img.set_pixel(x, y, GOLD if d < s / 2.0 - 4 else GOLD_DARK)
	return ImageTexture.create_from_image(img)


static func juice(b: Control) -> void:
	## Springy press/hover animation for touch-friendly buttons.
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.pivot_offset = b.size / 2.0
	if b is BaseButton:
		var bb := b as BaseButton
		bb.pressed.connect(func(): Audio.sfx("ui_click", -6.0, 0.05, 0.02))
		bb.button_down.connect(func():
			b.create_tween().tween_property(b, "scale", Vector2(0.92, 0.92), 0.06))
		bb.button_up.connect(func():
			b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.mouse_entered.connect(func():
		if b.scale.x >= 1.0:
			b.create_tween().tween_property(b, "scale", Vector2(1.04, 1.04), 0.1))
	b.mouse_exited.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))


static func button(text: String, color: Color = PURPLE, min_size := Vector2(0, 72)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_stylebox_override("normal", box(color))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.15), GOLD.lightened(0.2)))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.3), GOLD_DARK))
	juice(b)
	return b


static func label(text: String, size := 26, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func apply_safe_area(c: Control) -> void:
	## Keeps a full-screen Control clear of the iPhone notch / home indicator and Android
	## display cutouts. Re-applied whenever the window or safe area changes.
	var update := func():
		if not is_instance_valid(c) or not c.is_inside_tree():
			return
		var ins: Dictionary = GameState.safe_insets(c.get_viewport_rect().size)
		c.offset_top = ins["top"]
		c.offset_bottom = -ins["bottom"]
		c.offset_left = ins["left"]
		c.offset_right = -ins["right"]
	if c.is_inside_tree():
		update.call()
	else:
		c.ready.connect(update, CONNECT_ONE_SHOT)
	GameState.safe_area_changed.connect(update)
	c.tree_exiting.connect(func():
		if GameState.safe_area_changed.is_connected(update):
			GameState.safe_area_changed.disconnect(update), CONNECT_ONE_SHOT)


static func vignette() -> TextureRect:
	## Soft dark screen-edge vignette for cinematic framing (ignores input).
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.05), Color(0.02, 0.0, 0.05, 0.45)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(1.15, 1.0)
	gt.width = 128
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func portrait(hero_id: String, size: float, framed := true) -> Control:
	## Rendered hero portrait in a coloured frame (falls back to the vector icon).
	var tex := HeroPortraits.get_portrait(hero_id)
	var col: Color = GameData.HEROES[hero_id]["color"]
	var holder := Panel.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_stylebox_override("panel", box(Color(col.r * 0.25, col.g * 0.25, col.b * 0.3), col if framed else Color(0, 0, 0, 0), int(size * 0.22), 3 if framed else 0, 0))
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 3
		tr.offset_top = 3
		tr.offset_right = -3
		tr.offset_bottom = -3
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tr)
	else:
		var ic := IconArt.new(BattleHUD.HERO_ICONS.get(hero_id, "crown"), size * 0.8)
		ic.position = Vector2(size * 0.1, size * 0.1)
		holder.add_child(ic)
	return holder


static func title(text: String, size := 44) -> Label:
	var l := label(text, size, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", font_title())
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.0))
	return l
