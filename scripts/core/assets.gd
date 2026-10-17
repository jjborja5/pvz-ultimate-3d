class_name Assets
extends RefCounted
## Access to the CC0 KayKit model library (see assets/kaykit/*/LICENSE*.txt).
## Provides cached scenes, single merged meshes for MultiMesh use and tinted materials.

const ROOT := "res://assets/kaykit/"

static var _scenes := {}
static var _meshes := {}
static var _mats := {}


static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(ROOT + path)
	return _scenes[path]


static func instance(path: String) -> Node3D:
	return scene(path).instantiate()


static func mesh(path: String) -> ArrayMesh:
	## All MeshInstance3D nodes of a model merged (with transforms) into one multi-surface mesh.
	if _meshes.has(path):
		return _meshes[path]
	var root := instance(path)
	var out := ArrayMesh.new()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var xf := _xform_to(mi, root)
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			a[Mesh.ARRAY_VERTEX] = xf * v
			if a[Mesh.ARRAY_NORMAL] != null:
				var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
				var nx := Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO)
				var tn: PackedVector3Array = nx * n
				for i in tn.size():
					tn[i] = tn[i].normalized()
				a[Mesh.ARRAY_NORMAL] = tn
			a[Mesh.ARRAY_TANGENT] = null
			# drop skinning data if any
			a[Mesh.ARRAY_BONES] = null
			a[Mesh.ARRAY_WEIGHTS] = null
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
			var mat := mi.get_active_material(s)
			out.surface_set_material(out.get_surface_count() - 1, mat)
	root.free()
	_meshes[path] = out
	return out


static func _xform_to(node: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func texture_of(path: String) -> Texture2D:
	var m := mesh(path)
	for s in m.get_surface_count():
		var mat := m.surface_get_material(s) as BaseMaterial3D
		if mat and mat.albedo_texture:
			return mat.albedo_texture
	return null


static func tinted(path: String, tint: Color, amount: float, snow := 0.0, snow_height := 0.6, emission := 0.0) -> ShaderMaterial:
	## Material using the model's atlas, recoloured. snow > 0 whitens upward faces above snow_height (model space).
	var key := "%s|%s|%.2f|%.2f|%.2f|%.2f" % [path, tint.to_html(), amount, snow, snow_height, emission]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/prop_tex.gdshader")
	m.set_shader_parameter("atlas", texture_of(path))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("tint_amount", amount)
	m.set_shader_parameter("snow", snow)
	m.set_shader_parameter("snow_height", snow_height)
	m.set_shader_parameter("emission_strength", emission)
	_mats[key] = m
	return m


static func stone(path: String, tint := Color.WHITE, amount := 0.0, brick := Vector2(1.1, 0.55)) -> ShaderMaterial:
	## Atlas material with world-space masonry detail on stone-coloured surfaces.
	var key := "stone|%s|%s|%.2f|%s" % [path, tint.to_html(), amount, brick]
	if _mats.has(key):
		return _mats[key]
	var m: ShaderMaterial = tinted(path, tint, amount).duplicate()
	m.set_shader_parameter("stone_detail", 1.0)
	m.set_shader_parameter("brick_width", brick.x)
	m.set_shader_parameter("brick_height", brick.y)
	_mats[key] = m
	return m


static func place(parent: Node3D, path: String, pos: Vector3, scl: Variant = 1.0, rot_y := 0.0, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(path)
	if mat:
		mi.material_override = mat
	mi.set_meta("static_ok", true)   # eligible for StaticBatcher merging
	parent.add_child(mi)
	mi.position = pos
	mi.rotation.y = rot_y
	mi.scale = scl if scl is Vector3 else Vector3.ONE * float(scl)
	return mi
