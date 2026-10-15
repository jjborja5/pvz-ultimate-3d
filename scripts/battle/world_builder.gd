class_name WorldBuilder
extends Node3D
## Procedurally builds the battlefield for a map palette: terrain, lanes, sky,
## lighting, vegetation, ruins, rocks, lava/water and ambient particles.

const FIELD_HALF := 15.0       # playable half-width near the castle
const SPAWN_Z := -95.0
const WALL_Z := 0.0
const LANE_COUNT := 3
const LANE_BASE := [-8.0, 0.0, 8.0]

var map_id := "verdant_pass"
var pal: Dictionary
var noise := FastNoiseLite.new()
var sun: DirectionalLight3D
var env: WorldEnvironment
var _rng := RandomNumberGenerator.new()


static func lane_x(lane: int, z: float) -> float:
	var t := clampf(-z / 95.0, 0.0, 1.0)
	var base: float = LANE_BASE[clampi(lane, 0, LANE_COUNT - 1)]
	return base * (1.0 - 0.35 * t) + sin(z * 0.045 + lane * 2.1) * 6.0 * t


func build(p_map: String) -> void:
	map_id = p_map
	pal = GameData.MAPS[map_id]
	_rng.seed = hash(map_id)
	noise.seed = hash(map_id) & 0xffff
	noise.frequency = 0.03
	noise.fractal_octaves = 4
	_build_environment()
	_build_terrain()
	_build_liquid()
	_build_vegetation()
	_build_rocks_and_ruins()
	_build_ambient_particles()


func has_channel() -> bool:
	return map_id == "verdant_pass" or bool(pal["lava"])


func height_at(x: float, z: float) -> float:
	var ax := absf(x)
	var hill: float = pal["hill"]
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	var side := smoothstep(FIELD_HALF + 2.0, FIELD_HALF + 22.0, ax)
	var far := smoothstep(-100.0, -125.0, z)
	var h := (side + far * 0.8) * hill * (0.4 + n * 1.2)
	# gentle undulation in the field itself
	h += noise.get_noise_2d(x * 2.0, z * 2.0) * 0.35
	if has_channel():
		var ch := 1.0 - smoothstep(0.0, 3.5, absf(ax - (FIELD_HALF + 6.0)))
		h -= ch * 2.6 * (1.0 - far)
	# flatten behind the castle wall and inside lanes
	if z > -4.0:
		h = lerpf(h, 0.0, clampf((z + 4.0) / 4.0, 0.0, 1.0) * (1.0 - side))
	return h


func _lane_dist(x: float, z: float) -> float:
	var d := 999.0
	for i in LANE_COUNT:
		d = minf(d, absf(x - lane_x(i, z)))
	return d


func _build_environment() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = pal["sky_top"]
	sky_mat.sky_horizon_color = pal["sky_horizon"]
	sky_mat.ground_horizon_color = pal["sky_horizon"]
	sky_mat.ground_bottom_color = (pal["sky_top"] as Color).darkened(0.5)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = pal["ambient"]
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.45
	e.glow_strength = 1.0
	e.glow_bloom = 0.08
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = true
	e.fog_light_color = pal["fog"]
	e.fog_density = 0.0022
	e.fog_aerial_perspective = 0.2
	e.fog_sky_affect = 0.3
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.25
	e.adjustment_contrast = 1.1
	env.environment = e
	add_child(env)

	sun = DirectionalLight3D.new()
	sun.light_color = pal["sun"]
	sun.light_energy = pal["sun_energy"]
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.shadow_enabled = bool(GameState.settings.get("shadows", true))
	sun.shadow_bias = 0.04
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_fade_start = 0.85
	add_child(sun)


func _build_terrain() -> void:
	var step := 1.6
	var x0 := -70.0
	var x1 := 70.0
	var z0 := -140.0
	var z1 := 45.0
	var nx := int((x1 - x0) / step) + 1
	var nz := int((z1 - z0) / step) + 1
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(nx * nz)
	cols.resize(nx * nz)
	var grass: Color = pal["grass"]
	var grass2: Color = pal["grass2"]
	var path_c: Color = pal["path"]
	var rock_c: Color = pal["rock"]
	var peak_c: Color = pal["peak"]
	var hill: float = pal["hill"]
	for iz in nz:
		for ix in nx:
			var x := x0 + ix * step
			var z := z0 + iz * step
			var h := height_at(x, z)
			var n := noise.get_noise_2d(x * 3.1, z * 3.1) * 0.5 + 0.5
			var c := grass.lerp(grass2, n)
			var ld := _lane_dist(x, z)
			if z < -3.0 and absf(x) < FIELD_HALF + 4.0:
				c = c.lerp(path_c, (1.0 - smoothstep(2.0, 4.5, ld)) * 0.85)
			# churned ground in front of the wall
			if z > -10.0 and z < -1.0 and absf(x) < FIELD_HALF:
				c = c.lerp(path_c.darkened(0.1), 0.5)
			var slope_t := clampf(h / maxf(hill, 1.0), 0.0, 1.0)
			c = c.lerp(rock_c, smoothstep(0.25, 0.6, slope_t))
			c = c.lerp(peak_c, smoothstep(0.75, 1.1, slope_t))
			if h < -0.8:
				c = c.lerp(rock_c.darkened(0.4), 0.7)
			verts[iz * nx + ix] = Vector3(x, h, z)
			cols[iz * nx + ix] = c
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			var b := a + 1
			var c2 := a + nx
			var d := c2 + 1
			idx.append_array([a, b, c2, b, d, c2])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in verts.size():
		st.set_color(cols[i])
		st.add_vertex(verts[i])
	for i in idx:
		st.add_index(i)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mi.material_override = mat
	mi.name = "Terrain"
	add_child(mi)


func _build_liquid() -> void:
	if not has_channel():
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 190)
	plane.subdivide_width = 40
	plane.subdivide_depth = 48
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = Vector3(0, -1.1, -45)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/liquid.gdshader")
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	tex.noise = fn
	sm.set_shader_parameter("noise_tex", tex)
	if pal["lava"]:
		sm.set_shader_parameter("color_a", Color(0.9, 0.18, 0.02))
		sm.set_shader_parameter("color_b", Color(1.0, 0.75, 0.2))
		sm.set_shader_parameter("emissive", 2.8)
		var lava_light := OmniLight3D.new()
		lava_light.light_color = Color(1.0, 0.4, 0.1)
		lava_light.omni_range = 40.0
		lava_light.light_energy = 1.5
		lava_light.position = Vector3(0, 6, -30)
		add_child(lava_light)
	else:
		sm.set_shader_parameter("color_a", Color(0.05, 0.25, 0.45))
		sm.set_shader_parameter("color_b", Color(0.35, 0.7, 0.85))
		sm.set_shader_parameter("emissive", 0.25)
		sm.set_shader_parameter("roughness_value", 0.08)
		sm.set_shader_parameter("scroll", 0.015)
		sm.set_shader_parameter("wave_height", 0.05)
	mi.material_override = sm
	add_child(mi)


func _scatter_point(min_abs_x: float) -> Vector3:
	for _attempt in 20:
		var x := _rng.randf_range(-66.0, 66.0)
		var z := _rng.randf_range(-135.0, 30.0)
		if absf(x) < min_abs_x and z < 6.0:
			continue
		if z > -6.0 and absf(x) < 26.0:
			continue  # keep castle area clear
		var h := height_at(x, z)
		if h < -0.6:
			continue
		return Vector3(x, h, z)
	return Vector3(60, height_at(60, -60), -60)


func _build_vegetation() -> void:
	var count: int = pal["trees"]
	var style: String = pal["tree_style"]
	var variants := 4
	var per := []
	for v in variants:
		per.append([])
	for i in count:
		per[i % variants].append(_scatter_point(FIELD_HALF + 3.0))
	var mat := MeshKit.vertex_color_material(0.9)
	for v in variants:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Models.tree(style, v)
		var pts: Array = per[v]
		mm.instance_count = pts.size()
		for i in pts.size():
			var s := _rng.randf_range(0.8, 1.6)
			var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.9, 1.2), s))
			mm.set_instance_transform(i, Transform3D(b, pts[i]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		add_child(mmi)


func _build_rocks_and_ruins() -> void:
	var mat := MeshKit.vertex_color_material(0.95)
	var rock_c: Color = pal["rock"]
	for v in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Models.rock(v, rock_c)
		var n: int = int(pal["rocks"]) / 3
		mm.instance_count = n
		for i in n:
			var p := _scatter_point(FIELD_HALF - 1.0)
			var s := _rng.randf_range(0.6, 2.4)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), p - Vector3(0, 0.15, 0)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		add_child(mmi)
	var ruins: int = pal["ruins"]
	for i in ruins:
		var mi := MeshInstance3D.new()
		mi.mesh = Models.ruin(i)
		mi.material_override = mat
		var p: Vector3
		if map_id == "shattered_ruins" and i % 2 == 0:
			# scatter some ruins along the battlefield edges for atmosphere
			var x := (FIELD_HALF + _rng.randf_range(0.0, 6.0)) * (1.0 if i % 4 == 0 else -1.0)
			var z := _rng.randf_range(-90.0, -15.0)
			p = Vector3(x, height_at(x, z), z)
		else:
			p = _scatter_point(FIELD_HALF + 1.0)
		mi.position = p
		mi.rotation.y = _rng.randf() * TAU
		mi.scale = Vector3.ONE * _rng.randf_range(1.0, 1.8)
		add_child(mi)


func _build_ambient_particles() -> void:
	var quality: float = GameState.settings.get("particles_quality", 1.0)
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(40, 2, 60)
	pm.gravity = Vector3(0, 0.6, 0) if pal["embers"] else Vector3(0, 0.05, 0)
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 1.2
	pm.direction = Vector3(0.3, 1, 0)
	pm.spread = 60
	pm.turbulence_enabled = false
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	if pal["embers"]:
		grad.colors = PackedColorArray([Color(1.0, 0.6, 0.1, 0.0), Color(1.0, 0.5, 0.1, 1.0), Color(1.0, 0.2, 0.05, 0.0)])
	else:
		grad.colors = PackedColorArray([Color(1.0, 1.0, 0.8, 0.0), Color(1.0, 1.0, 0.7, 0.8), Color(1.0, 1.0, 0.8, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	p.amount = int((260 if pal["embers"] else 90) * quality)
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.visibility_aabb = AABB(Vector3(-50, -5, -70), Vector3(100, 30, 140))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(3, 2, 1) if pal["embers"] else Color(2, 2, 1.6)
	quad.material = qm
	p.draw_pass_1 = quad
	p.position = Vector3(0, 1.5, -45)
	add_child(p)
