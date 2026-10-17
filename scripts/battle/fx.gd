class_name FX
extends Node3D
## Visual effects: explosions, lightning, frost bursts, shockwaves, floating numbers.
## Particles are short-lived GPUParticles3D; materials are created once and shared.

const MAX_LIGHTS := 8
const MAX_NUMBERS := 40

var camera: Camera3D
var _soft_tex: Texture2D
var _mats := {}
var _light_count := 0
var _number_count := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_soft_tex = gt


func quality() -> float:
	return clampf(float(GameState.settings.get("particles_quality", 1.0)), 0.25, 1.0)


func additive_material(color: Color, billboard := true) -> StandardMaterial3D:
	var key := str(color, billboard)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _soft_tex
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = false
	m.disable_receive_shadows = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mats[key] = m
	return m


func _burst(pos: Vector3, amount: int, lifetime: float, speed: float, size: float, ramp: PackedColorArray, color_mul: Color, gravity := Vector3(0, -6, 0), spread := 180.0, dir := Vector3.UP) -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = gravity
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(0.2, 1.0))
	sc.add_point(Vector2(1, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	for i in ramp.size():
		offs.append(float(i) / float(maxi(ramp.size() - 1, 1)))
	g.offsets = offs
	g.colors = ramp
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	p.amount = maxi(4, int(amount * quality()))
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = additive_material(color_mul)
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 20, 24))
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(lifetime + 0.3, false).timeout.connect(p.queue_free)


func flash_light(pos: Vector3, color: Color, energy: float, rng: float, duration: float) -> void:
	if _light_count >= MAX_LIGHTS:
		return
	_light_count += 1
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, duration)
	tw.tween_callback(func():
		_light_count -= 1
		l.queue_free())


func shockwave(pos: Vector3, radius: float, color: Color, duration := 0.45) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	t.rings = 24
	t.ring_segments = 4
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.3, 0)
	mi.scale = Vector3(0.2, 0.3, 0.2)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.3, radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)


func explosion(pos: Vector3, radius: float, color := Color(1.0, 0.55, 0.15), big := false) -> void:
	Audio.sfx("explosion_big" if big and radius >= 4.0 else "explosion", -4.0 if not big else 0.0)
	var n := 40 if big else 22
	_burst(pos + Vector3(0, 0.5, 0), n, 0.7 if not big else 1.1, 6.0 + radius * 1.5, 1.4 + radius * 0.35,
		PackedColorArray([Color(1, 1, 0.8, 1), color, Color(color.r * 0.5, color.g * 0.2, 0.05, 0.6), Color(0.1, 0.1, 0.1, 0)]),
		Color(2.2, 1.6, 1.1), Vector3(0, 1.5, 0))
	# sparks / debris
	_burst(pos + Vector3(0, 0.3, 0), 18 if not big else 36, 0.9, 12.0 + radius * 2.0, 0.3,
		PackedColorArray([Color(1, 0.9, 0.5, 1), Color(1, 0.4, 0.1, 1), Color(0.5, 0.1, 0.0, 0)]),
		Color(3, 2, 1), Vector3(0, -14, 0), 70.0)
	# smoke
	if big or _rng.randf() < 0.5:
		_burst(pos + Vector3(0, 1.0, 0), 10 if not big else 22, 1.8, 2.5, 2.4 + radius * 0.4,
			PackedColorArray([Color(0.3, 0.27, 0.25, 0.0), Color(0.25, 0.22, 0.2, 0.45), Color(0.2, 0.2, 0.2, 0.0)]),
			Color(0.6, 0.6, 0.6), Vector3(0, 1.2, 0), 40.0)
	flash_light(pos + Vector3(0, 2, 0), color, 6.0 if big else 3.0, radius * 3.0 + 4.0, 0.35 if not big else 0.7)
	if radius > 2.0:
		shockwave(pos, radius, Color(color.r, color.g, color.b, 0.8))


func frost_burst(pos: Vector3, radius: float) -> void:
	Audio.sfx("ice_shatter", -6.0)
	_burst(pos + Vector3(0, 0.4, 0), 24, 0.8, 4.0 + radius, 0.9,
		PackedColorArray([Color(1, 1, 1, 1), Color(0.6, 0.9, 1.0, 0.9), Color(0.3, 0.6, 1.0, 0)]),
		Color(1.4, 1.8, 2.2), Vector3(0, -3, 0))
	if radius > 1.5:
		shockwave(pos, radius, Color(0.6, 0.9, 1.0, 0.7), 0.35)


func hit_spark(pos: Vector3, color: Color) -> void:
	_burst(pos, 6, 0.35, 5.0, 0.35, PackedColorArray([Color(1, 1, 1, 1), color, Color(color.r, color.g, color.b, 0)]),
		Color(2, 2, 2), Vector3(0, -8, 0))


func soul_puff(pos: Vector3, color: Color) -> void:
	## Death effect for enemies.
	_burst(pos + Vector3(0, 0.8, 0), 8, 0.7, 2.0, 0.8,
		PackedColorArray([Color(color.r, color.g, color.b, 0.0), Color(color.r, color.g, color.b, 0.7), Color(0.2, 0.2, 0.2, 0)]),
		Color(1.2, 1.2, 1.2), Vector3(0, 2.5, 0), 50.0)


func lightning(points: Array, color := Color(0.6, 0.8, 1.0), width := 0.35, duration := 0.28) -> void:
	if points.size() < 2:
		return
	Audio.sfx("lightning" if width >= 0.55 else "chain_zap", -3.0 if width >= 0.55 else -6.0)
	var cam_pos := camera.global_position if camera else Vector3(0, 30, 30)
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 1)
	mi.material_override = m
	# build jagged path
	var path: Array[Vector3] = []
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var segs := maxi(3, int(a.distance_to(b) / 1.2))
		for s in segs:
			var t := float(s) / segs
			var p := a.lerp(b, t)
			if s > 0:
				p += Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5))
			path.append(p)
	path.append(points[points.size() - 1])
	for pass_i in 2:
		var w := width * (3.0 if pass_i == 0 else 1.0)
		var col := Color(color.r, color.g, color.b, 0.35) if pass_i == 0 else Color(1.5, 1.6, 2.0, 1.0)
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in path.size():
			var p: Vector3 = path[i]
			var dir: Vector3 = (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
			var side := dir.cross((cam_pos - p).normalized()).normalized() * w * 0.5
			im.surface_set_color(col)
			im.surface_add_vertex(p - side)
			im.surface_set_color(col)
			im.surface_add_vertex(p + side)
		im.surface_end()
	add_child(mi)
	for p in points:
		hit_spark(p, color)
	flash_light(points[0], color, 2.5, 10.0, duration)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.tween_callback(mi.queue_free)


func damage_number(pos: Vector3, amount: float, color := Color(1, 0.95, 0.6)) -> void:
	if not GameState.settings.get("show_damage_numbers", true) or _number_count >= MAX_NUMBERS:
		return
	_number_count += 1
	var l := Label3D.new()
	l.text = str(int(round(amount))) if amount < 1e6 else "KO"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0.1, 0.05, 0.0)
	l.pixel_size = 0.012
	add_child(l)
	l.global_position = pos + Vector3(_rng.randf_range(-0.4, 0.4), 2.2, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.8, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(func():
		_number_count -= 1
		l.queue_free())


func banner_text(text: String, color: Color) -> void:
	## Large 3D text above the battlefield (e.g. boss arrival).
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 120
	l.outline_size = 24
	l.modulate = color
	l.pixel_size = 0.02
	add_child(l)
	l.global_position = Vector3(0, 10, -30)
	l.scale = Vector3.ONE * 0.3
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
