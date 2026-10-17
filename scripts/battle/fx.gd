class_name FX
extends Node3D
## Visual effects library: shader fireballs, textured fire/smoke/spark particles, debris,
## projected ground decals (cracks, scorch, frost, runes), branching lightning, ground
## shockwave rings, energy shields, floating numbers and banners.
## A global particle budget (scaled by the graphics quality setting) keeps big battles
## within mobile GPU limits: optional layers (smoke, debris, decals) drop first.

const MAX_LIGHTS := 8
const MAX_NUMBERS := 40
const MAX_DECALS := 24

var camera: Camera3D
var _mats := {}
var _light_count := 0
var _number_count := 0
var _decal_count := 0
var _active_particles := 0
var _rng := RandomNumberGenerator.new()
var _sphere: SphereMesh
var _explosion_shader: Shader
var _debris_mesh: BoxMesh
var _ring_mesh: QuadMesh


func _ready() -> void:
	_sphere = SphereMesh.new()
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 20
	_sphere.rings = 10
	_explosion_shader = load("res://shaders/explosion.gdshader")
	_debris_mesh = BoxMesh.new()
	_debris_mesh.size = Vector3(0.35, 0.3, 0.3)
	_ring_mesh = QuadMesh.new()
	_ring_mesh.size = Vector2(2, 2)
	_ring_mesh.orientation = PlaneMesh.FACE_Y


func quality() -> float:
	return clampf(float(GameState.settings.get("particles_quality", 1.0)), 0.25, 1.0)


func budget() -> int:
	## Max concurrent particle systems before optional layers are skipped.
	return int(70 * quality())


func over_budget() -> bool:
	return _active_particles > budget()


func additive_material(color: Color, billboard := true, tex := "soft") -> StandardMaterial3D:
	var key := str(color, billboard, tex)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = FXTextures.get_tex(tex)
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mats[key] = m
	return m


func smoke_material() -> StandardMaterial3D:
	if _mats.has("smoke"):
		return _mats["smoke"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = FXTextures.get_tex("smoke")
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.disable_receive_shadows = true
	_mats["smoke"] = m
	return m


func _ramp(colors: PackedColorArray) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	for i in colors.size():
		offs.append(float(i) / float(maxi(colors.size() - 1, 1)))
	g.offsets = offs
	g.colors = colors
	var gt := GradientTexture1D.new()
	gt.gradient = g
	return gt


func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var ct := CurveTexture.new()
	ct.curve = c
	return ct


func _burst(pos: Vector3, amount: int, lifetime: float, speed: float, size: float, ramp: PackedColorArray, color_mul: Color,
		gravity := Vector3(0, -6, 0), spread := 180.0, dir := Vector3.UP, tex := "soft", material: Material = null,
		mesh: Mesh = null, optional := false) -> void:
	if optional and over_budget():
		return
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
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.scale_curve = _curve([Vector2(0, 0.6), Vector2(0.2, 1.0), Vector2(1, 0.0)])
	pm.color_ramp = _ramp(ramp)
	p.process_material = pm
	p.amount = maxi(3, int(amount * quality()))
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	if mesh:
		p.draw_pass_1 = mesh
		if material:
			p.material_override = material
	else:
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		q.material = material if material else additive_material(color_mul, true, tex)
		p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-14, -4, -14), Vector3(28, 24, 28))
	add_child(p)
	p.global_position = pos
	p.emitting = true
	_active_particles += 1
	get_tree().create_timer(lifetime + 0.3, false).timeout.connect(func():
		_active_particles -= 1
		p.queue_free())


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


# ------------------------------------------------------------------ ground effects

func shockwave(pos: Vector3, radius: float, color: Color, duration := 0.45) -> void:
	## Ground-aligned expanding ring with a soft inner glow.
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = FXTextures.get_tex("ring")
	m.albedo_color = Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, color.a)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.25, 0)
	mi.scale = Vector3(0.15, 1, 0.15)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1, radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


func decal(kind: String, pos: Vector3, size: float, color := Color.WHITE, life := 6.0, emission := 0.0) -> void:
	## Projected ground decal (cracks, scorch, frost, rune). Fades out over its life.
	if _decal_count >= MAX_DECALS or quality() < 0.4:
		return
	_decal_count += 1
	var d := Decal.new()
	d.texture_albedo = FXTextures.get_tex(kind)
	d.size = Vector3(size, 6.0, size)
	d.modulate = color
	d.albedo_mix = 1.0
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	if emission > 0.0:
		d.texture_emission = FXTextures.get_tex(kind)
		d.emission_energy = emission
	d.cull_mask = 1
	add_child(d)
	d.global_position = pos + Vector3(0, 1.0, 0)
	d.rotation.y = _rng.randf() * TAU
	var tw := create_tween()
	tw.tween_interval(life * 0.6)
	tw.tween_property(d, "modulate:a", 0.0, life * 0.4)
	if emission > 0.0:
		tw.parallel().tween_property(d, "emission_energy", 0.0, life * 0.4)
	tw.tween_callback(func():
		_decal_count -= 1
		d.queue_free())


func rune_circle(pos: Vector3, radius: float, color: Color, life := 2.0) -> Node3D:
	## Glowing spinning magic circle on the ground (summons, casts).
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = FXTextures.get_tex("rune")
	m.albedo_color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 0.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.2, 0)
	mi.scale = Vector3(radius, 1, radius)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 1.0, 0.25)
	tw.parallel().tween_property(mi, "rotation:y", PI * 2.0 * life * 0.25, life).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(mi.queue_free)
	return mi


func shield(target: Node3D, radius: float, color: Color, duration: float, offset := Vector3(0, 1.5, 0)) -> MeshInstance3D:
	## Energy-shield bubble around a node (or at a world point if target is null).
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/shield.gdshader")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("strength", 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if target:
		target.add_child(mi)
		mi.position = offset
	else:
		add_child(mi)
		mi.global_position = offset
	mi.scale = Vector3.ONE * radius
	var tw := mi.create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("strength", v), 0.0, 1.0, 0.25)
	if duration > 0.0:
		tw.tween_interval(duration)
		tw.tween_method(func(v: float): m.set_shader_parameter("strength", v), 1.0, 0.0, 0.35)
		tw.tween_callback(mi.queue_free)
	return mi


# ------------------------------------------------------------------ explosions

func fireball_sphere(pos: Vector3, radius: float, color: Color, duration := 0.9) -> void:
	## Shader fireball: expands, cools from white-hot through the colour to smoke, dissolves.
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	var m := ShaderMaterial.new()
	m.shader = _explosion_shader
	m.set_shader_parameter("noise_tex", FXTextures.get_tex("noise"))
	m.set_shader_parameter("mid", color)
	m.set_shader_parameter("hot", color.lerp(Color(1, 1, 0.85), 0.75))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + Vector3(0, radius * 0.35, 0)
	mi.set_instance_shader_parameter("seed", _rng.randf() * 10.0)
	mi.set_instance_shader_parameter("age", 0.0)
	mi.scale = Vector3.ONE * radius * 0.25
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 0.85, duration * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(mi, "global_position:y", pos.y + radius * 0.9, duration).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("age", v), 0.0, 1.0, duration)
	tw.chain().tween_callback(mi.queue_free)


func explosion(pos: Vector3, radius: float, color := Color(1.0, 0.55, 0.15), big := false) -> void:
	Audio.sfx("explosion_big" if big and radius >= 4.0 else "explosion", -4.0 if not big else 0.0)
	fireball_sphere(pos, radius * (1.15 if big else 0.9), color, 1.1 if big else 0.7)
	# flame puffs
	_burst(pos + Vector3(0, 0.6, 0), 26 if big else 14, 0.6 if not big else 0.9, 5.0 + radius * 1.4, 1.2 + radius * 0.35,
		PackedColorArray([Color(1, 1, 0.85, 1), color, Color(color.r * 0.6, color.g * 0.25, 0.05, 0.5), Color(0.1, 0.05, 0.05, 0)]),
		Color(2.0, 1.5, 1.0), Vector3(0, 2.0, 0), 180.0, Vector3.UP, "puff")
	# sparks and embers (streaks)
	_burst(pos + Vector3(0, 0.4, 0), 26 if big else 12, 1.0, 13.0 + radius * 2.0, 0.45,
		PackedColorArray([Color(1, 0.95, 0.6, 1), Color(1, 0.5, 0.1, 1), Color(0.6, 0.15, 0.0, 0)]),
		Color(3, 2.2, 1.2), Vector3(0, -12, 0), 75.0, Vector3.UP, "spark")
	# smoke (normal-blended, rises and lingers)
	if big or radius > 2.5:
		_burst(pos + Vector3(0, 1.2, 0), 12 if big else 6, 2.2, 2.5, 2.6 + radius * 0.5,
			PackedColorArray([Color(0.25, 0.22, 0.2, 0.0), Color(0.22, 0.2, 0.18, 0.55), Color(0.3, 0.3, 0.3, 0.0)]),
			Color.WHITE, Vector3(0, 1.6, 0), 45.0, Vector3.UP, "smoke", smoke_material(), null, true)
	# rock debris for big blasts
	if big:
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.3, 0.25, 0.22)
		dm.vertex_color_use_as_albedo = false
		_burst(pos + Vector3(0, 0.5, 0), 14, 1.3, 14.0, 0.4, PackedColorArray([Color.WHITE, Color.WHITE]), Color.WHITE,
			Vector3(0, -24, 0), 50.0, Vector3.UP, "soft", dm, _debris_mesh, true)
		decal("crack", pos, radius * 2.4, Color(1, 1, 1, 0.95), 8.0)
	if radius >= 1.8:
		decal("scorch", pos, radius * 2.0, Color(1, 1, 1, 0.8), 5.0)
	flash_light(pos + Vector3(0, 2, 0), color, 6.0 if big else 3.0, radius * 3.0 + 4.0, 0.35 if not big else 0.7)
	if radius > 2.0:
		shockwave(pos, radius * 1.2, Color(color.r, color.g, color.b, 0.9))


func frost_burst(pos: Vector3, radius: float) -> void:
	Audio.sfx("ice_shatter", -6.0)
	_burst(pos + Vector3(0, 0.5, 0), 22, 0.8, 4.0 + radius, 0.9,
		PackedColorArray([Color(1, 1, 1, 1), Color(0.6, 0.9, 1.0, 0.9), Color(0.3, 0.6, 1.0, 0)]),
		Color(1.4, 1.8, 2.2), Vector3(0, -4, 0), 180.0, Vector3.UP, "spark")
	_burst(pos + Vector3(0, 0.4, 0), 8, 1.4, 1.5, 1.8 + radius * 0.4,
		PackedColorArray([Color(0.8, 0.95, 1.0, 0.0), Color(0.75, 0.9, 1.0, 0.35), Color(0.8, 0.9, 1.0, 0.0)]),
		Color(1.0, 1.2, 1.4), Vector3(0, 0.5, 0), 90.0, Vector3.UP, "puff", null, null, true)
	if radius > 1.5:
		shockwave(pos, radius, Color(0.6, 0.9, 1.0, 0.7), 0.35)
		decal("frost", pos, radius * 2.2, Color(1, 1, 1, 0.9), 4.0, 0.6)


func hit_spark(pos: Vector3, color: Color) -> void:
	if over_budget():
		return
	_burst(pos, 6, 0.35, 6.0, 0.4, PackedColorArray([Color(1, 1, 1, 1), color, Color(color.r, color.g, color.b, 0)]),
		Color(2, 2, 2), Vector3(0, -8, 0), 180.0, Vector3.UP, "spark")


func soul_puff(pos: Vector3, color: Color) -> void:
	## Death effect for enemies.
	if over_budget():
		return
	_burst(pos + Vector3(0, 0.8, 0), 7, 0.8, 2.0, 1.0,
		PackedColorArray([Color(color.r, color.g, color.b, 0.0), Color(color.r, color.g, color.b, 0.6), Color(0.2, 0.2, 0.2, 0)]),
		Color(1.2, 1.2, 1.2), Vector3(0, 2.5, 0), 50.0, Vector3.UP, "puff")


func fire_jet(parent: Node3D, color: Color, size := 1.0) -> GPUParticles3D:
	## Continuous fire stream attached to a node (dragon breath). Emits along -Z of the parent.
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -0.6, 1.0)
	pm.spread = 14.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 24.0
	pm.gravity = Vector3(0, -6, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(0.4, 1.4), Vector2(1, 2.4)])
	pm.color_ramp = _ramp(PackedColorArray([Color(1, 1, 0.9, 1), color, Color(color.r * 0.6, color.g * 0.3, 0.05, 0.6), Color(0.1, 0.08, 0.08, 0)]))
	pm.angle_min = -180
	pm.angle_max = 180
	p.process_material = pm
	p.amount = int(140 * quality())
	p.lifetime = 0.9
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(1.6 * size, 1.6 * size)
	q.material = additive_material(Color(2.2, 1.6, 1.0), true, "puff")
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	parent.add_child(p)
	return p


# ------------------------------------------------------------------ lightning

func _bolt_path(a: Vector3, b: Vector3, jitter: float) -> Array[Vector3]:
	var path: Array[Vector3] = []
	var segs := maxi(4, int(a.distance_to(b) / 1.0))
	for s in segs:
		var t := float(s) / segs
		var p := a.lerp(b, t)
		if s > 0:
			p += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * jitter
		path.append(p)
	path.append(b)
	return path


func _strip(im: ImmediateMesh, path: Array[Vector3], width: float, col: Color, cam_pos: Vector3) -> void:
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in path.size():
		var p: Vector3 = path[i]
		var dir: Vector3 = (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side := dir.cross((cam_pos - p).normalized()).normalized() * width * 0.5
		var taper := 1.0 - float(i) / path.size() * 0.4
		im.surface_set_color(col)
		im.surface_add_vertex(p - side * taper)
		im.surface_set_color(col)
		im.surface_add_vertex(p + side * taper)
	im.surface_end()


func lightning(points: Array, color := Color(0.6, 0.8, 1.0), width := 0.35, duration := 0.28) -> void:
	## Branching bolt through all points: glow halo, white-hot core, forked side branches,
	## impact flashes and scorch marks. Flickers once before fading.
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
	var halo := Color(color.r, color.g, color.b, 0.3)
	var core := Color(1.6, 1.7, 2.2, 1.0)
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var path := _bolt_path(a, b, 0.55 + a.distance_to(b) * 0.02)
		_strip(im, path, width * 3.2, halo, cam_pos)
		_strip(im, path, width, core, cam_pos)
		# forks
		var forks := 1 + int(a.distance_to(b) / 6.0)
		for f in forks:
			var start: Vector3 = path[_rng.randi_range(1, maxi(1, path.size() - 2))]
			var end := start + Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-3, 0.5), _rng.randf_range(-3, 3))
			var fork := _bolt_path(start, end, 0.4)
			_strip(im, fork, width * 1.4, Color(color.r, color.g, color.b, 0.25), cam_pos)
			_strip(im, fork, width * 0.45, Color(1.3, 1.4, 1.9, 0.8), cam_pos)
	add_child(mi)
	for i in range(1, points.size()):
		hit_spark(points[i], color)
	var last: Vector3 = points[points.size() - 1]
	if width >= 0.55:
		decal("scorch", Vector3(last.x, 0, last.z), 2.5, Color(1, 1, 1, 0.7), 3.0)
		shockwave(Vector3(last.x, 0, last.z), 2.5, Color(color.r, color.g, color.b, 0.8), 0.3)
	flash_light(points[mini(1, points.size() - 1)], color, 3.0, 12.0, duration)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.35, duration * 0.25)
	tw.tween_property(m, "albedo_color:a", 1.0, duration * 0.1)
	tw.tween_property(m, "albedo_color:a", 0.0, duration * 0.65)
	tw.tween_callback(mi.queue_free)


# ------------------------------------------------------------------ text

func damage_number(pos: Vector3, amount: float, color := Color(1, 0.95, 0.6)) -> void:
	if not GameState.settings.get("show_damage_numbers", true) or _number_count >= MAX_NUMBERS:
		return
	_number_count += 1
	var l := Label3D.new()
	l.text = str(int(round(amount))) if amount < 1e6 else "KO"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font = UITheme.font_body()
	l.font_size = 64 if amount < 300 else 86
	l.outline_size = 14
	l.modulate = color
	l.outline_modulate = Color(0.1, 0.05, 0.0)
	l.pixel_size = 0.012
	add_child(l)
	l.global_position = pos + Vector3(_rng.randf_range(-0.4, 0.4), 2.2, 0)
	l.scale = Vector3.ONE * 1.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT)
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
	l.font = UITheme.font_title()
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
