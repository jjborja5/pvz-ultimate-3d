class_name StaticBatcher
extends RefCounted
## Merges static props (MeshInstance3D children tagged by Assets.place) that share a
## material into a single mesh per material. Godot does not batch 3D draws automatically,
## so this cuts hundreds of environment draw calls down to a handful (big mobile win).


static func batch(root: Node3D) -> int:
	## Returns the number of meshes merged. Only direct children tagged "static_ok" are merged.
	var groups := {}       # material key -> {material, verts, norms, uvs, idx, shadow}
	var merged: Array[MeshInstance3D] = []
	var root_inv := root.global_transform.affine_inverse()
	for c in root.get_children():
		var mi := c as MeshInstance3D
		if mi == null or not mi.has_meta("static_ok") or not mi.visible or mi.mesh == null:
			continue
		if _uses_model_space(mi.material_override):
			continue   # snow line is in model space; merging would move it
		if not _has_geometry(mi.mesh):
			continue   # headless/dummy renderer returns no surface data: keep the original node
		var xf := root_inv * mi.global_transform
		var nb := xf.basis.inverse().transposed()
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.material_override if mi.material_override else mi.get_active_material(s)
			var key := _key(mat)
			if not groups.has(key):
				groups[key] = {"material": _shared(mat), "verts": PackedVector3Array(), "norms": PackedVector3Array(),
					"uvs": PackedVector2Array(), "idx": PackedInt32Array(), "shadow": mi.cast_shadow}
			var g: Dictionary = groups[key]
			var a := mi.mesh.surface_get_arrays(s)
			# Packed arrays are values: read, append, then write back to the dictionary.
			var gv: PackedVector3Array = g["verts"]
			var gn: PackedVector3Array = g["norms"]
			var guv: PackedVector2Array = g["uvs"]
			var gi: PackedInt32Array = g["idx"]
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var base := gv.size()
			gv.append_array(xf * v)
			var n = a[Mesh.ARRAY_NORMAL]
			if n == null:
				n = PackedVector3Array()
				n.resize(v.size())
				n.fill(Vector3.UP)
			gn.append_array(Transform3D(nb, Vector3.ZERO) * (n as PackedVector3Array))
			var uv = a[Mesh.ARRAY_TEX_UV]
			if uv == null or (uv as PackedVector2Array).size() != v.size():
				uv = PackedVector2Array()
				uv.resize(v.size())
			guv.append_array(uv)
			var ind = a[Mesh.ARRAY_INDEX]
			if ind == null:
				for i in v.size():
					gi.append(base + i)
			else:
				var shifted: PackedInt32Array = (ind as PackedInt32Array).duplicate()
				for i in shifted.size():
					shifted[i] += base
				gi.append_array(shifted)
			g["verts"] = gv
			g["norms"] = gn
			g["uvs"] = guv
			g["idx"] = gi
		merged.append(mi)
	if merged.size() < 2:
		return 0
	for key in groups:
		var g: Dictionary = groups[key]
		if (g["verts"] as PackedVector3Array).is_empty():
			continue
		var norms: PackedVector3Array = g["norms"]
		for i in norms.size():
			norms[i] = norms[i].normalized()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g["verts"]
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = g["uvs"]
		arrays[Mesh.ARRAY_INDEX] = g["idx"]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var out := MeshInstance3D.new()
		out.mesh = am
		out.material_override = g["material"]
		out.cast_shadow = g["shadow"]
		out.name = "Batched"
		root.add_child(out)
	for mi in merged:
		mi.queue_free()
	return merged.size()


static func _uses_model_space(mat: Material) -> bool:
	var sm := mat as ShaderMaterial
	if sm == null:
		return false
	var snow = sm.get_shader_parameter("snow")
	return snow != null and float(snow) > 0.0


static func _has_geometry(m: Mesh) -> bool:
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		if a.is_empty() or a[Mesh.ARRAY_VERTEX] == null or (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			return false
	return m.get_surface_count() > 0


static func _key(mat: Material) -> String:
	if mat is ShaderMaterial:
		return "sm%d" % mat.get_instance_id()
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		var tex_id := bm.albedo_texture.get_rid().get_id() if bm.albedo_texture else 0
		return "bm%d_%s_%d" % [tex_id, bm.albedo_color.to_html(), bm.transparency]
	return "none"


static var _shared_mats := {}


static func _shared(mat: Material) -> Material:
	if mat is ShaderMaterial or mat == null:
		return mat
	var k := _key(mat)
	if not _shared_mats.has(k):
		_shared_mats[k] = mat
	return _shared_mats[k]
