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


static func box(bg: Color, border: Color = GOLD, radius := 16, border_w := 3, shadow := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = shadow
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
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


static func title(text: String, size := 44) -> Label:
	var l := label(text, size, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.0))
	return l
