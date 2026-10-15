class_name MeshKit
extends RefCounted
## Accumulates transformed primitive meshes into a single vertex-coloured ArrayMesh.
## One merged mesh == one draw call, which keeps procedural models cheap on mobile.
## The vertex colour alpha channel carries a "part id" used by the enemy shader
## to animate limbs (see shaders/unit.gdshader).

const PART_LEG_L := 0.1
const PART_LEG_R := 0.3
const PART_ARM_W := 0.5   # weapon arm
const PART_ARM_O := 0.7   # off arm
const PART_GLOW := 0.88   # emissive (eyes, runes, crystals)
const PART_BODY := 1.0

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()
var jitter := 0.0  # random per-primitive colour variation
var rng := RandomNumberGenerator.new()

static var _cache := {}


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value


func add(mesh: PrimitiveMesh, xf: Transform3D, color: Color, part: float = PART_BODY) -> void:
	var key := str(mesh.get_class(), "|", _mesh_key(mesh))
	var arrays: Array
	if _cache.has(key):
		arrays = _cache[key]
	else:
		arrays = mesh.get_mesh_arrays()
		_cache[key] = arrays
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var ind = arrays[Mesh.ARRAY_INDEX]
	var base := verts.size()
	var nb := xf.basis.inverse().transposed()
	var c := color
	if jitter > 0.0:
		var j := rng.randf_range(-jitter, jitter)
		c = Color(clampf(c.r + j, 0, 1), clampf(c.g + j, 0, 1), clampf(c.b + j * 0.8, 0, 1))
	c.a = part
	for k in v.size():
		verts.append(xf * v[k])
		norms.append((nb * n[k]).normalized())
		cols.append(c)
	if ind == null or (ind as PackedInt32Array).is_empty():
		for k in v.size():
			idx.append(base + k)
	else:
		for k in ind:
			idx.append(base + k)


func _mesh_key(m: PrimitiveMesh) -> String:
	if m is BoxMesh:
		return str(m.size, m.subdivide_width)
	if m is SphereMesh:
		return str(m.radius, m.height, m.radial_segments, m.rings, m.is_hemisphere)
	if m is CylinderMesh:
		return str(m.top_radius, m.bottom_radius, m.height, m.radial_segments, m.cap_top, m.cap_bottom)
	if m is PrismMesh:
		return str(m.size, m.left_to_right)
	if m is TorusMesh:
		return str(m.inner_radius, m.outer_radius, m.rings, m.ring_segments)
	return str(m.get_instance_id())


# ---- convenience helpers (position/rotation/scale) -----------------------

static func xf(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scl)
	return Transform3D(b, pos)


func box(size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO, part := PART_BODY) -> void:
	var m := BoxMesh.new()
	m.size = Vector3.ONE
	add(m, xf(pos, rot, size), color, part)


func sphere(radius: float, pos: Vector3, color: Color, scl := Vector3.ONE, part := PART_BODY, segs := 12) -> void:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = segs
	m.rings = maxi(segs / 2, 4)
	add(m, xf(pos, Vector3.ZERO, scl * radius), color, part)


func cyl(r_top: float, r_bot: float, h: float, pos: Vector3, color: Color, rot := Vector3.ZERO, part := PART_BODY, segs := 10) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	add(m, xf(pos, rot), color, part)


func cone(r: float, h: float, pos: Vector3, color: Color, rot := Vector3.ZERO, part := PART_BODY, segs := 10) -> void:
	cyl(0.0, r, h, pos, color, rot, part, segs)


func torus_ring(radius: float, pos: Vector3, color: Color, part := PART_BODY) -> void:
	var m := TorusMesh.new()
	m.inner_radius = radius * 0.85
	m.outer_radius = radius
	m.rings = 16
	m.ring_segments = 6
	add(m, xf(pos), color, part)


func torus_arc(pos: Vector3, color: Color, part := PART_BODY) -> void:
	## A bow: a thin ring squashed and stood on its side.
	var m := TorusMesh.new()
	m.inner_radius = 0.36
	m.outer_radius = 0.4
	m.rings = 12
	m.ring_segments = 4
	add(m, xf(pos, Vector3(0, 0, 90), Vector3(1.0, 0.3, 1.0)), color, part)


func prism_point(pos: Vector3, color: Color, part := PART_BODY) -> void:
	## Downward pointing pennant tip.
	var m := PrismMesh.new()
	m.size = Vector3(1.0, 0.6, 0.06)
	add(m, xf(pos + Vector3(0, -0.3, 0), Vector3(0, 0, 180)), color, part)


func build() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


static func vertex_color_material(roughness := 0.85, emission_strength := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = roughness
	if emission_strength > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(1, 1, 1)
		mat.emission_energy_multiplier = emission_strength
	return mat
