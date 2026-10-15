class_name IconArt
extends Control
## Vector icons drawn in code (no external image assets): spells, towers, currencies, UI.

@export var kind := "fireball":
	set(v):
		kind = v
		queue_redraw()
var tint := Color.WHITE


func _init(p_kind := "fireball", p_size := 56.0) -> void:
	kind = p_kind
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var r := s * 0.42
	match kind:
		"fireball":
			_glow_disc(c, r, Color(1.0, 0.45, 0.1))
			_flame(c + Vector2(0, r * 0.15), r * 0.75, Color(1.0, 0.8, 0.2))
			draw_circle(c + Vector2(0, r * 0.25), r * 0.28, Color(1, 1, 0.8))
		"lightning", "storm":
			_glow_disc(c, r, Color(0.35, 0.55, 1.0))
			var pts := PackedVector2Array([
				c + Vector2(r * 0.15, -r * 0.85), c + Vector2(-r * 0.4, r * 0.1), c + Vector2(-r * 0.02, r * 0.1),
				c + Vector2(-r * 0.2, r * 0.85), c + Vector2(r * 0.45, -r * 0.15), c + Vector2(r * 0.05, -r * 0.15)])
			draw_colored_polygon(pts, Color(1, 0.98, 0.7))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.2, 0.3, 0.8), 2.0, true)
		"ice_storm", "ice":
			_glow_disc(c, r, Color(0.45, 0.8, 1.0))
			for i in 6:
				var a := i * PI / 3.0
				var d := Vector2(cos(a), sin(a))
				draw_line(c, c + d * r * 0.8, Color(1, 1, 1), 4.0, true)
				var m := c + d * r * 0.5
				draw_line(m, m + d.rotated(0.7) * r * 0.25, Color(1, 1, 1), 3.0, true)
				draw_line(m, m + d.rotated(-0.7) * r * 0.25, Color(1, 1, 1), 3.0, true)
		"meteor":
			_glow_disc(c, r, Color(0.8, 0.25, 0.05))
			for i in 3:
				var o := Vector2(-r * 0.2 * i, -r * 0.2 * i)
				draw_line(c + Vector2(r * 0.1, r * 0.1) + o * 0.4, c + Vector2(-r * 0.8, -r * 0.8) + Vector2(i * 6, -i * 4), Color(1, 0.6 - i * 0.15, 0.1, 0.8), 6.0 - i, true)
			draw_circle(c + Vector2(r * 0.2, r * 0.2), r * 0.42, Color(0.35, 0.22, 0.15))
			draw_circle(c + Vector2(r * 0.12, r * 0.12), r * 0.18, Color(1, 0.6, 0.15))
		"crown":
			var pts := PackedVector2Array([
				c + Vector2(-r, r * 0.55), c + Vector2(-r, -r * 0.35), c + Vector2(-r * 0.5, r * 0.05),
				c + Vector2(0, -r * 0.7), c + Vector2(r * 0.5, r * 0.05), c + Vector2(r, -r * 0.35), c + Vector2(r, r * 0.55)])
			draw_colored_polygon(pts, Color(1.0, 0.8, 0.25))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.45, 0.25, 0.0), 3.0, true)
			draw_circle(c + Vector2(0, r * 0.2), r * 0.15, Color(0.9, 0.15, 0.2))
			draw_circle(c + Vector2(-r * 0.55, r * 0.3), r * 0.1, Color(0.2, 0.6, 1.0))
			draw_circle(c + Vector2(r * 0.55, r * 0.3), r * 0.1, Color(0.2, 0.9, 0.4))
		"gold":
			draw_circle(c, r, Color(0.6, 0.38, 0.05))
			draw_circle(c, r * 0.85, Color(1.0, 0.8, 0.25))
			draw_circle(c - Vector2(r * 0.2, r * 0.2), r * 0.3, Color(1, 0.95, 0.6, 0.7))
		"gem":
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.8, -r * 0.2)])
			draw_colored_polygon(pts, Color(0.85, 0.2, 0.6))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, -r * 0.1)]), Color(1, 0.6, 0.85))
		"diamond":
			var pts := PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.3), c + Vector2(-r * 0.4, -r * 0.8), c + Vector2(r * 0.4, -r * 0.8), c + Vector2(r * 0.8, -r * 0.3), c + Vector2(0, r)])
			draw_colored_polygon(pts, Color(0.5, 0.9, 1.0))
			draw_line(c + Vector2(-r * 0.8, -r * 0.3), c + Vector2(r * 0.8, -r * 0.3), Color(1, 1, 1), 2.0, true)
		"heart":
			draw_circle(c + Vector2(-r * 0.4, -r * 0.2), r * 0.5, Color(0.9, 0.15, 0.2))
			draw_circle(c + Vector2(r * 0.4, -r * 0.2), r * 0.5, Color(0.9, 0.15, 0.2))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.88, 0), c + Vector2(r * 0.88, 0), c + Vector2(0, r * 0.9)]), Color(0.9, 0.15, 0.2))
		"shield":
			var pts := PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.7, r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.7, r * 0.2)])
			draw_colored_polygon(pts, Color(0.3, 0.6, 1.0))
			pts.append(pts[0])
			draw_polyline(pts, Color(1, 0.85, 0.3), 3.0, true)
		"skull":
			draw_circle(c - Vector2(0, r * 0.15), r * 0.75, Color(0.92, 0.9, 0.82))
			draw_rect(Rect2(c + Vector2(-r * 0.4, r * 0.3), Vector2(r * 0.8, r * 0.5)), Color(0.92, 0.9, 0.82))
			draw_circle(c + Vector2(-r * 0.3, -r * 0.15), r * 0.2, Color(0.8, 0.1, 0.1))
			draw_circle(c + Vector2(r * 0.3, -r * 0.15), r * 0.2, Color(0.8, 0.1, 0.1))
		"pause":
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.7), Vector2(r * 0.4, r * 1.4)), Color(1, 0.95, 0.85))
			draw_rect(Rect2(c + Vector2(r * 0.2, -r * 0.7), Vector2(r * 0.4, r * 1.4)), Color(1, 0.95, 0.85))
		"speed":
			for i in 2:
				var o := Vector2(i * r * 0.7 - r * 0.6, 0)
				draw_colored_polygon(PackedVector2Array([c + o + Vector2(0, -r * 0.6), c + o + Vector2(r * 0.65, 0), c + o + Vector2(0, r * 0.6)]), Color(1, 0.95, 0.85))
		"archer":
			_glow_disc(c, r, Color(0.3, 0.6, 0.3))
			draw_arc(c + Vector2(-r * 0.2, 0), r * 0.7, -PI * 0.4, PI * 0.4, 16, Color(0.6, 0.4, 0.2), 5.0, true)
			draw_line(c + Vector2(-r * 0.6, 0), c + Vector2(r * 0.8, 0), Color(1, 1, 1), 3.0, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.85, 0), c + Vector2(r * 0.55, -r * 0.18), c + Vector2(r * 0.55, r * 0.18)]), Color(0.85, 0.85, 0.9))
		"cannon":
			_glow_disc(c, r, Color(0.45, 0.45, 0.5))
			draw_set_transform(c, -0.5, Vector2.ONE)
			draw_rect(Rect2(Vector2(-r * 0.6, -r * 0.25), Vector2(r * 1.3, r * 0.5)), Color(0.15, 0.15, 0.18))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			draw_circle(c + Vector2(-r * 0.15, r * 0.35), r * 0.3, Color(0.5, 0.32, 0.15))
		"fire":
			_glow_disc(c, r, Color(0.8, 0.3, 0.05))
			_flame(c + Vector2(0, r * 0.2), r * 0.8, Color(1.0, 0.6, 0.1))
			_flame(c + Vector2(0, r * 0.35), r * 0.45, Color(1.0, 0.95, 0.5))
		"swords":
			draw_line(c + Vector2(-r * 0.7, r * 0.7), c + Vector2(r * 0.7, -r * 0.7), Color(0.85, 0.85, 0.9), 6.0, true)
			draw_line(c + Vector2(r * 0.7, r * 0.7), c + Vector2(-r * 0.7, -r * 0.7), Color(0.85, 0.85, 0.9), 6.0, true)
			draw_line(c + Vector2(-r * 0.6, r * 0.3), c + Vector2(-r * 0.3, r * 0.6), Color(1, 0.8, 0.3), 6.0, true)
			draw_line(c + Vector2(r * 0.6, r * 0.3), c + Vector2(r * 0.3, r * 0.6), Color(1, 0.8, 0.3), 6.0, true)
		"leaf":
			_glow_disc(c, r, Color(0.3, 0.7, 0.25))
			var pts := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0 * TAU
				pts.append(c + Vector2(sin(t) * r * 0.42, -cos(t) * r * 0.75))
			draw_colored_polygon(pts, Color(0.45, 0.9, 0.35))
			draw_line(c + Vector2(0, -r * 0.7), c + Vector2(0, r * 0.8), Color(0.2, 0.45, 0.15), 3.0, true)
		"dragon":
			_glow_disc(c, r, Color(0.15, 0.6, 0.55))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.85, -r * 0.1), c + Vector2(-r * 0.15, -r * 0.6), c + Vector2(0, 0)]), Color(0.3, 0.9, 0.8))
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.85, -r * 0.1), c + Vector2(r * 0.15, -r * 0.6), c + Vector2(0, 0)]), Color(0.3, 0.9, 0.8))
			draw_circle(c + Vector2(0, r * 0.15), r * 0.32, Color(0.2, 0.7, 0.6))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.15, r * 0.3), c + Vector2(r * 0.15, r * 0.3), c + Vector2(0, r * 0.85)]), Color(1, 0.6, 0.15))
			draw_circle(c + Vector2(-r * 0.12, r * 0.08), r * 0.06, Color(1, 0.9, 0.3))
			draw_circle(c + Vector2(r * 0.12, r * 0.08), r * 0.06, Color(1, 0.9, 0.3))
		"castle":
			_glow_disc(c, r, Color(0.45, 0.45, 0.55))
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.2), Vector2(r * 1.4, r * 0.8)), Color(0.75, 0.73, 0.7))
			for i in 4:
				draw_rect(Rect2(c + Vector2(-r * 0.7 + i * r * 0.4, -r * 0.45), Vector2(r * 0.22, r * 0.3)), Color(0.75, 0.73, 0.7))
			draw_rect(Rect2(c + Vector2(-r * 0.15, r * 0.2), Vector2(r * 0.3, r * 0.4)), Color(0.25, 0.18, 0.12))
		"meteor_shower":
			_glow_disc(c, r, Color(0.8, 0.25, 0.05))
			for i in 3:
				var o := Vector2(-r * 0.45 + i * r * 0.45, -r * 0.2 + (i % 2) * r * 0.35)
				draw_line(c + o + Vector2(r * 0.1, r * 0.1), c + o + Vector2(-r * 0.35, -r * 0.45), Color(1, 0.55, 0.1, 0.8), 4.0, true)
				draw_circle(c + o + Vector2(r * 0.1, r * 0.1), r * 0.2, Color(0.4, 0.22, 0.12))
				draw_circle(c + o + Vector2(r * 0.07, r * 0.07), r * 0.09, Color(1, 0.6, 0.15))
		"firestorm":
			_glow_disc(c, r, Color(0.8, 0.3, 0.05))
			for i in 5:
				var w := r * (0.75 - i * 0.12)
				draw_arc(c + Vector2(i * r * 0.06, -r * 0.55 + i * r * 0.3), w, 0.2, PI - 0.2, 12, Color(1, 0.75 - i * 0.1, 0.2), 4.0, true)
		"frost_nova":
			_glow_disc(c, r, Color(0.4, 0.75, 1.0))
			for i in 8:
				var a := i * TAU / 8.0
				draw_colored_polygon(PackedVector2Array([c + Vector2(cos(a - 0.15), sin(a - 0.15)) * r * 0.2, c + Vector2(cos(a), sin(a)) * r * 0.85,
					c + Vector2(cos(a + 0.15), sin(a + 0.15)) * r * 0.2]), Color(0.85, 0.97, 1.0))
		"divine_wrath":
			_glow_disc(c, r, Color(1.0, 0.85, 0.35))
			draw_rect(Rect2(c + Vector2(-r * 0.15, -r * 0.85), Vector2(r * 0.3, r * 1.7)), Color(1, 1, 0.85))
			draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.3), Vector2(r * 1.1, r * 0.25)), Color(1, 1, 0.85))
		_:
			draw_circle(c, r, Color(0.6, 0.6, 0.7))


func _glow_disc(c: Vector2, r: float, col: Color) -> void:
	for i in 4:
		draw_circle(c, r * (1.0 - i * 0.12), Color(col.r, col.g, col.b, 0.25 + i * 0.2))
	draw_arc(c, r, 0, TAU, 32, Color(1, 0.85, 0.4, 0.9), 2.5, true)


func _flame(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0 * TAU
		var rr := r * 0.55
		var p := Vector2(sin(t) * rr, cos(t) * rr * 0.8)
		if p.y < 0:
			p.x *= 1.0 + p.y / r
			p.y *= 1.8
		pts.append(c + p)
	draw_colored_polygon(pts, col)
