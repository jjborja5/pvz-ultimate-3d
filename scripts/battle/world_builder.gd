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
	if GameState.quality_profile()["weather"]:
		_build_weather()
	StaticBatcher.batch(self)


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
	e.ambient_light_energy = 0.45
	e.ambient_light_sky_contribution = 0.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	e.tonemap_white = 5.0
	# restrained bloom: only genuinely bright effects (HDR > 1.4) glow
	e.glow_enabled = true
	e.glow_intensity = 0.35
	e.glow_strength = 0.9
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.4
	e.glow_hdr_scale = 1.5
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.set_glow_level(0, 0.0)
	e.set_glow_level(1, 1.0)
	e.set_glow_level(2, 0.6)
	e.set_glow_level(3, 0.3)
	e.fog_enabled = true
	e.fog_light_color = pal["fog"]
	e.fog_light_energy = 0.9
	e.fog_density = 0.0016
	e.fog_aerial_perspective = 0.15
	e.fog_sky_affect = 0.25
	# low valley mist that thickens below 2 m (distant mountains sit in haze)
	e.fog_height = 2.0
	e.fog_height_density = 0.02
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.18
	e.adjustment_contrast = 1.08
	env.environment = e
	add_child(env)

	sun = DirectionalLight3D.new()
	sun.light_color = pal["sun"]
	sun.light_energy = pal["sun_energy"]
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.shadow_enabled = bool(GameState.settings.get("shadows", true))
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if int(GameState.settings.get("quality", 2)) >= 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = float(GameState.settings.get("shadow_distance", 80.0))
	sun.directional_shadow_fade_start = 0.8
	add_child(sun)
	# cool fill light from the opposite side (stylised two-tone lighting, no shadows)
	var fill := DirectionalLight3D.new()
	fill.light_color = (pal["ambient"] as Color).lerp(Color(0.55, 0.65, 1.0), 0.5)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-25, 150, 0)
	fill.shadow_enabled = false
	fill.light_specular = 0.0
	add_child(fill)


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
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	tex.generate_mipmaps = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.05
	fn.fractal_octaves = 3
	tex.noise = fn
	mat.set_shader_parameter("detail", tex)
	mat.set_shader_parameter("snow", 1.0 if map_id == "skyspire_peaks" else 0.0)
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


const H := "hexagon/"
const HW := "halloween/"
const DG := "dungeon/"


func _scatter(path: String, count: int, min_abs_x: float, smin: float, smax: float, mat: Material = null, sink := 0.0, area := Rect2(-66, -135, 132, 165)) -> void:
	## Scatter a CC0 KayKit model with one MultiMesh (one draw call per surface).
	if count <= 0:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Assets.mesh(path)
	var xforms: Array[Transform3D] = []
	for i in count:
		var p := Vector3.INF
		for _attempt in 24:
			var x := _rng.randf_range(area.position.x, area.end.x)
			var z := _rng.randf_range(area.position.y, area.end.y)
			if absf(x) < min_abs_x and z < 8.0:
				continue
			if z > -6.0 and absf(x) < 28.0:
				continue
			var h := height_at(x, z)
			if h < -0.6:
				continue
			p = Vector3(x, h - sink, z)
			break
		if p == Vector3.INF:
			continue
		var sc := _rng.randf_range(smin, smax)
		xforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * sc), p))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat:
		mmi.material_override = mat
	add_child(mmi)


func _place_ring(paths: Array, count: int, radius_min: float, smin: float, smax: float, mat: Material = null, sides_only := false) -> void:
	## Big landmarks (mountains) framing the battlefield on the sides and far end.
	for i in count:
		var path: String = paths[i % paths.size()]
		var x: float
		var z: float
		if sides_only or i % 3 != 0:
			var side := 1.0 if i % 2 == 0 else -1.0
			x = side * _rng.randf_range(radius_min, radius_min + 22.0)
			z = _rng.randf_range(-140.0, 10.0)
		else:
			x = _rng.randf_range(-70.0, 70.0)
			z = _rng.randf_range(-150.0, -122.0)
		var y := height_at(x, z) - 1.0
		Assets.place(self, path, Vector3(x, y, z), _rng.randf_range(smin, smax), _rng.randf() * TAU, mat)


func _build_vegetation() -> void:
	match map_id:
		"verdant_pass":
			_place_ring([H + "mountain_A_grass_trees.gltf", H + "mountain_B_grass_trees.gltf", H + "mountain_C_grass_trees.gltf"], 16, 42.0, 15.0, 24.0)
			_scatter(H + "hills_A_trees.gltf", 10, FIELD_HALF + 12.0, 7.0, 11.0, null, 0.5)
			_scatter(H + "hills_B_trees.gltf", 10, FIELD_HALF + 12.0, 7.0, 11.0, null, 0.5)
			for t in ["trees_A_large", "trees_A_medium", "trees_B_large", "trees_B_medium"]:
				_scatter(H + t + ".gltf", 26, FIELD_HALF + 4.0, 3.0, 4.6)
			for t in ["tree_single_A", "tree_single_B"]:
				_scatter(H + t + ".gltf", 40, FIELD_HALF + 2.0, 3.2, 5.0)
		"molten_abyss":
			var dark := Assets.tinted(H + "mountain_A.gltf", Color(0.32, 0.2, 0.17), 0.8, 0.0, 0.6, 0.05)
			_place_ring([H + "mountain_A.gltf", H + "mountain_B.gltf", H + "mountain_C.gltf"], 18, 40.0, 16.0, 26.0, dark)
			_scatter(H + "hills_A.gltf", 12, FIELD_HALF + 12.0, 7.0, 11.0, dark, 0.5)
			for t in ["tree_dead_large", "tree_dead_medium", "tree_dead_small"]:
				_scatter(HW + t + ".gltf", 14, FIELD_HALF + 3.0, 1.0, 1.6, Assets.tinted(HW + t + ".gltf", Color(0.25, 0.18, 0.15), 0.7))
		"shattered_ruins":
			_place_ring([H + "mountain_A_grass.gltf", H + "mountain_B_grass.gltf", H + "mountain_C_grass.gltf"], 14, 42.0, 14.0, 22.0,
				Assets.tinted(H + "mountain_A_grass.gltf", Color(0.6, 0.6, 0.5), 0.35))
			_scatter(H + "hills_C.gltf", 10, FIELD_HALF + 12.0, 7.0, 10.0, null, 0.5)
			for t in ["tree_dead_large", "tree_dead_medium", "tree_dead_small"]:
				_scatter(HW + t + ".gltf", 18, FIELD_HALF + 2.0, 1.0, 1.7)
			_scatter(HW + "tree_pine_orange_large.gltf", 14, FIELD_HALF + 4.0, 1.0, 1.4)
			_scatter(HW + "tree_pine_yellow_large.gltf", 14, FIELD_HALF + 4.0, 1.0, 1.4)
		"skyspire_peaks":
			var snowy := Assets.tinted(H + "mountain_A_grass_trees.gltf", Color(1, 1, 1), 0.0, 1.0, 1.15)
			_place_ring([H + "mountain_A_grass_trees.gltf", H + "mountain_B_grass_trees.gltf", H + "mountain_C_grass_trees.gltf", H + "mountain_A.gltf"], 22, 36.0, 18.0, 30.0, snowy)
			_scatter(H + "hills_A_trees.gltf", 12, FIELD_HALF + 10.0, 7.0, 11.0, Assets.tinted(H + "hills_A_trees.gltf", Color(1, 1, 1), 0.0, 1.0, 0.9), 0.5)
			for t in ["trees_B_large", "trees_B_medium", "trees_B_small"]:
				_scatter(H + t + ".gltf", 30, FIELD_HALF + 3.0, 3.0, 4.6, Assets.tinted(H + t + ".gltf", Color(1, 1, 1), 0.0, 0.8, 0.55))
	_build_clouds()


func _build_clouds() -> void:
	if map_id == "molten_abyss":
		return
	var count := 14 if map_id == "skyspire_peaks" else 8
	var mat := Assets.tinted(H + "cloud_big.gltf", Color(1, 1, 1), 0.0, 0.0, 0.6, 0.35)
	for i in count:
		var side := 1.0 if i % 2 == 0 else -1.0
		var c := Assets.place(self, H + ("cloud_big.gltf" if i % 3 else "cloud_small.gltf"),
			Vector3(side * _rng.randf_range(24.0, 60.0), _rng.randf_range(16.0, 28.0), _rng.randf_range(-140.0, -20.0)),
			_rng.randf_range(4.0, 7.0), _rng.randf() * TAU, mat)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		c.remove_meta("static_ok")
		var tw := c.create_tween().set_loops()
		var drift := _rng.randf_range(4.0, 9.0)
		tw.tween_property(c, "position:x", c.position.x + drift, _rng.randf_range(14.0, 24.0)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(c, "position:x", c.position.x, _rng.randf_range(14.0, 24.0)).set_trans(Tween.TRANS_SINE)


func _build_rocks_and_ruins() -> void:
	var rock_mat: Material = null
	if map_id == "molten_abyss":
		rock_mat = Assets.tinted(H + "rock_single_A.gltf", Color(0.3, 0.2, 0.18), 0.8)
	for r in ["rock_single_A", "rock_single_B", "rock_single_C", "rock_single_D", "rock_single_E"]:
		_scatter(H + r + ".gltf", int(pal["rocks"]) / 5, FIELD_HALF - 1.0, 4.0, 9.0, rock_mat)
	# small rubble/props along the lane edges for detail
	match map_id:
		"verdant_pass":
			_edge_props([H + "resource_lumber.gltf", H + "crate_A_big.gltf", H + "barrel.gltf", H + "tent.gltf", H + "weaponrack.gltf"], 18, 3.2)
			Assets.place(self, H + "building_windmill_blue.gltf", Vector3(-34, height_at(-34, -60), -60), 6.0, 0.6)
			Assets.place(self, H + "building_home_A_blue.gltf", Vector3(-30, height_at(-30, -48), -48), 5.0, 1.2)
			Assets.place(self, H + "building_lumbermill_blue.gltf" if ResourceLoader.exists(Assets.ROOT + H + "building_lumbermill_blue.gltf") else H + "building_home_B_blue.gltf",
				Vector3(32, height_at(32, -70), -70), 5.0, -0.8)
		"molten_abyss":
			_edge_props([DG + "rubble_large.glb", DG + "rubble_half.glb", HW + "skull.gltf", HW + "ribcage.gltf"], 26, 1.4)
			_edge_props([H + "building_destroyed.gltf"], 6, 5.0)
		"shattered_ruins":
			_edge_props([HW + "grave_A.gltf", HW + "grave_B.gltf", HW + "gravestone.gltf", HW + "grave_A_destroyed.gltf", HW + "gravemarker_A.gltf"], 40, 1.3)
			_edge_props([DG + "pillar.glb", DG + "column.glb", DG + "rubble_large.glb", DG + "wall_broken.glb"], 18, 1.6)
			_edge_props([HW + "skull.gltf", HW + "ribcage.gltf", HW + "bone_A.gltf", HW + "fence_broken.gltf"], 24, 1.5)
			_edge_props([HW + "lantern_standing.gltf", HW + "post_skull.gltf"], 10, 1.6)
			_edge_props([H + "building_destroyed.gltf"], 8, 5.5)
			Assets.place(self, HW + "crypt.gltf", Vector3(-30, height_at(-30, -70), -70), 1.4, 0.8)
			Assets.place(self, HW + "arch_gate.gltf", Vector3(0, height_at(0, -98), -98), 2.4, 0.0)
			Assets.place(self, HW + "shrine_candles.gltf", Vector3(28, height_at(28, -40), -40), 1.6, -0.6)
		"skyspire_peaks":
			_edge_props([H + "rock_single_B.gltf", H + "rock_single_C.gltf"], 20, 6.0, Assets.tinted(H + "rock_single_B.gltf", Color(1, 1, 1), 0.0, 1.0, 0.03))
			_edge_props([H + "tent.gltf", H + "flag_blue.gltf", H + "crate_B_big.gltf"], 10, 3.5)


func _edge_props(paths: Array, count: int, scl: float, mat: Material = null) -> void:
	## Props just outside the lanes so the battlefield edges feel lived-in.
	for i in count:
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var x := side * _rng.randf_range(FIELD_HALF - 0.5, FIELD_HALF + 9.0)
		var z := _rng.randf_range(-100.0, -12.0)
		if height_at(x, z) < -0.6:
			continue
		var path: String = paths[i % paths.size()]
		Assets.place(self, path, Vector3(x, height_at(x, z) - 0.05, z), scl * _rng.randf_range(0.8, 1.25), _rng.randf() * TAU, mat)


func _build_weather() -> void:
	## Map-specific atmosphere: drifting leaves, falling snow or low graveyard mist.
	var quality: float = GameState.settings.get("particles_quality", 1.0)
	var cfg := {}
	match map_id:
		"verdant_pass": cfg = {"amount": 70, "size": 0.35, "grav": Vector3(0.6, -0.8, 0.3), "life": 9.0, "tex": "puff",
			"ramp": [Color(0.55, 0.8, 0.3, 0.0), Color(0.6, 0.85, 0.3, 0.9), Color(0.85, 0.55, 0.2, 0.0)], "y": 12.0, "unshaded": false}
		"skyspire_peaks": cfg = {"amount": 260, "size": 0.18, "grav": Vector3(0.4, -2.2, 0.2), "life": 7.0, "tex": "soft",
			"ramp": [Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.0)], "y": 16.0, "unshaded": true}
		"shattered_ruins": cfg = {"amount": 26, "size": 7.0, "grav": Vector3(0.25, 0.0, 0.1), "life": 14.0, "tex": "smoke",
			"ramp": [Color(0.8, 0.82, 0.85, 0.0), Color(0.8, 0.82, 0.85, 0.16), Color(0.8, 0.82, 0.85, 0.0)], "y": 0.8, "unshaded": true}
		_: return
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(36, 1.0 if map_id == "shattered_ruins" else 2.0, 55)
	pm.gravity = cfg["grav"]
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.6
	pm.angle_min = -180
	pm.angle_max = 180
	pm.angular_velocity_min = -120 if map_id == "verdant_pass" else 0
	pm.angular_velocity_max = 120 if map_id == "verdant_pass" else 0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray(cfg["ramp"])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	p.amount = maxi(8, int(int(cfg["amount"]) * quality))
	p.lifetime = cfg["life"]
	p.preprocess = cfg["life"]
	p.visibility_aabb = AABB(Vector3(-45, -20, -70), Vector3(90, 40, 140))
	var q := QuadMesh.new()
	q.size = Vector2(cfg["size"], cfg["size"] * (0.6 if map_id == "verdant_pass" else 1.0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if cfg["unshaded"] else BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = FXTextures.get_tex(cfg["tex"])
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0, cfg["y"], -40)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)


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
