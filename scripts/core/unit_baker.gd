class_name UnitBaker
extends RefCounted
## Bakes skeletal animations of rigged KayKit characters (CC0) into per-frame static meshes.
## Hordes are then drawn with one MultiMesh per (model, frame): real character animation
## for hundreds of units at MultiMesh cost. Skinning is done on the CPU here so baking
## works on every renderer (including headless tests). Results are cached in memory and
## on disk (user://bake_cache) so later launches skip the work.

const CHAR_DIR := "res://assets/kaykit/characters/"
const CACHE_DIR := "user://bake_cache/"
## Release builds ship pre-baked frames here (tools/prebake.gd) so phones skip the bake.
const PREBAKED_DIR := "res://assets/prebaked/units/"
const BAKE_VERSION := 5

## Model configs: source character, visible accessory meshes, extra weapons, animations.
## anims: name -> [clip, frame_count, loop]
const CONFIGS := {
	"rogue": {"src": "Rogue", "keep": ["Knife", "Knife_Offhand"],
		"anims": {"walk": ["Running_A", 8, true], "attack": ["Dualwield_Melee_Attack_Stab", 6, true], "death": ["Death_A", 6, false], "hit": ["Hit_A", 3, false], "special": ["Cheer", 6, false]}},
	"barbarian": {"src": "Barbarian", "keep": ["1H_Axe", "Barbarian_Round_Shield", "Barbarian_Hat"],
		"anims": {"walk": ["Walking_A", 8, true], "attack": ["1H_Melee_Attack_Chop", 6, true], "death": ["Death_A", 6, false], "hit": ["Hit_A", 3, false], "special": ["Cheer", 6, false]}},
	"barbarian_2h": {"src": "Barbarian", "keep": ["2H_Axe", "Barbarian_Hat", "Barbarian_Cape"],
		"anims": {"walk": ["Walking_A", 8, true], "attack": ["2H_Melee_Attack_Chop", 6, true], "death": ["Death_B", 6, false], "hit": ["Hit_A", 3, false], "special": ["2H_Melee_Attack_Spin", 6, false]}},
	"knight": {"src": "Knight", "keep": ["1H_Sword", "Spike_Shield", "Knight_Helmet", "Knight_Cape"],
		"anims": {"walk": ["Walking_A", 8, true], "attack": ["1H_Melee_Attack_Slice_Diagonal", 6, true], "death": ["Death_A", 6, false], "hit": ["Hit_A", 3, false], "special": ["Cheer", 6, false]}},
	"knight_2h": {"src": "Knight", "keep": ["2H_Sword", "Knight_Helmet", "Knight_Cape"],
		"anims": {"walk": ["Walking_A", 8, true], "attack": ["2H_Melee_Attack_Slice", 6, true], "death": ["Death_B", 6, false], "hit": ["Hit_A", 3, false], "special": ["2H_Melee_Attack_Spin", 6, false]}},
	"archer_xbow": {"src": "Rogue_Hooded", "keep": ["2H_Crossbow", "Rogue_Cape"],
		"anims": {"walk": ["2H_Ranged_Aiming", 4, true], "attack": ["2H_Ranged_Shoot", 6, true], "death": ["Death_A", 2, false], "hit": ["Hit_A", 3, false], "special": ["Cheer", 6, false]}},
	"skel_minion": {"src": "Skeleton_Minion", "keep": ["*"], "weapons": {"handslot.r": "Skeleton_Blade"},
		"anims": {"walk": ["Walking_D_Skeletons", 8, true], "attack": ["1H_Melee_Attack_Chop", 6, true], "death": ["Death_C_Skeletons", 6, false], "hit": ["Hit_A", 3, false], "special": ["Taunt", 6, false]}},
	"skel_warrior": {"src": "Skeleton_Warrior", "keep": ["*"], "weapons": {"handslot.r": "Skeleton_Axe", "handslot.l": "Skeleton_Shield_Large_A"},
		"anims": {"walk": ["Walking_D_Skeletons", 8, true], "attack": ["1H_Melee_Attack_Slice_Horizontal", 6, true], "death": ["Death_C_Skeletons", 6, false], "hit": ["Hit_A", 3, false], "special": ["Taunt", 6, false]}},
	"skel_rogue": {"src": "Skeleton_Rogue", "keep": ["*"], "weapons": {"handslot.r": "Skeleton_Crossbow"},
		"anims": {"walk": ["Walking_D_Skeletons", 8, true], "attack": ["1H_Ranged_Shoot", 6, true], "death": ["Death_C_Skeletons", 6, false], "hit": ["Hit_A", 3, false], "special": ["Taunt", 6, false]}},
	"skel_mage": {"src": "Skeleton_Mage", "keep": ["*"], "weapons": {"handslot.r": "Skeleton_Staff"},
		"anims": {"walk": ["Walking_D_Skeletons", 8, true], "attack": ["Spellcast_Shoot", 6, true], "death": ["Death_C_Skeletons", 6, false], "hit": ["Hit_A", 3, false], "special": ["Spellcast_Summon", 6, false]}},
}

static var _mem := {}   # config -> {anim -> Array[ArrayMesh]}


static func get_frames(config: String) -> Dictionary:
	if _mem.has(config):
		return _mem[config]
	var cached := _load_cache(config)
	if cached.is_empty():
		cached = _bake(config)
		_save_cache(config, cached)
	_mem[config] = cached
	return cached


static func is_baked(config: String) -> bool:
	return _mem.has(config)


static func _cache_path(config: String) -> String:
	return CACHE_DIR + "%s_v%d.res" % [config, BAKE_VERSION]


static func _load_cache(config: String) -> Dictionary:
	var p := _cache_path(config)
	if not FileAccess.file_exists(p):
		p = PREBAKED_DIR + p.get_file()
		if not ResourceLoader.exists(p):
			return {}
	var res = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null or not res.has_meta("frames"):
		return {}
	return res.get_meta("frames")


static func _save_cache(config: String, frames: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var holder := Resource.new()
	holder.set_meta("frames", frames)
	ResourceSaver.save(holder, _cache_path(config), ResourceSaver.FLAG_COMPRESS)


# ------------------------------------------------------------------ baking

class _Part:
	var single_groups := {}   # bind index -> [PackedInt32Array vertex ids, PackedVector3Array verts, PackedVector3Array normals]
	var multi_ids := PackedInt32Array()
	var verts: PackedVector3Array
	var normals: PackedVector3Array
	var uvs: PackedVector2Array
	var indices: PackedInt32Array
	var bones: PackedInt32Array
	var weights: PackedFloat32Array
	var bind_bone := PackedInt32Array()   # bind index -> skeleton bone
	var bind_pose: Array[Transform3D] = []
	var rigid_bone := -1                  # for bone-attached meshes
	var rigid_local := Transform3D.IDENTITY
	var glow := false


static func _bake(config: String) -> Dictionary:
	var cfg: Dictionary = CONFIGS[config]
	var scene: Node3D = load(CHAR_DIR + cfg["src"] + ".glb").instantiate()
	var sk: Skeleton3D = scene.find_child("Skeleton3D", true, false)
	var ap: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	var keep: Array = cfg["keep"]
	var parts: Array[_Part] = []
	var texture: Texture2D = null
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var is_skinned := mi.skin != null
		if not is_skinned and not keep.has("*") and not keep.has(String(mi.name)):
			continue
		var p := _make_part(mi, sk)
		if p == null:
			continue
		if texture == null:
			var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
			if mat:
				texture = mat.albedo_texture
		parts.append(p)
	# extra weapons from separate glTF files, rigidly attached to hand slots
	var weapons: Dictionary = cfg.get("weapons", {})
	for slot in weapons:
		var ws: Node3D = load(CHAR_DIR + "weapons/" + weapons[slot] + ".gltf").instantiate()
		for wmi: MeshInstance3D in ws.find_children("*", "MeshInstance3D", true, false):
			var p := _make_part(wmi, null)
			p.rigid_bone = sk.find_bone(slot)
			p.rigid_local = _local_to(wmi, ws)
			parts.append(p)
		ws.free()
	var out := {"texture": texture}
	var anims: Dictionary = cfg["anims"]
	for key in anims:
		var clip: String = anims[key][0]
		var count: int = anims[key][1]
		var loop: bool = anims[key][2]
		var anim := ap.get_animation(clip)
		var frames: Array = []
		var lo_frames: Array = []
		for f in count:
			var t: float = anim.length * (float(f) / count if loop else float(f) / maxi(count - 1, 1) * 0.98)
			_pose_skeleton(sk, anim, t)
			var hi := _build_frame(parts, sk)
			frames.append(hi)
			lo_frames.append(_make_lod(hi))
		out[key] = frames
		out[key + "_lo"] = lo_frames
	scene.free()
	return out


static func _make_lod(hi: ArrayMesh) -> ArrayMesh:
	## Decimated copy (about a third of the triangles) for distant units.
	var a := hi.surface_get_arrays(0)
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, a)
	im.generate_lods(25.0, 60.0, [])
	if im.get_surface_lod_count(0) == 0:
		return hi
	var lod_idx := im.get_surface_lod_indices(0, im.get_surface_lod_count(0) - 1)
	var remap := {}
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var sv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var su: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var sc: PackedColorArray = a[Mesh.ARRAY_COLOR]
	for i in lod_idx:
		var ni: int
		if remap.has(i):
			ni = remap[i]
		else:
			ni = verts.size()
			remap[i] = ni
			verts.append(sv[i])
			norms.append(sn[i])
			uvs.append(su[i])
			cols.append(sc[i])
		idx.append(ni)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


static func _local_to(node: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _make_part(mi: MeshInstance3D, sk: Skeleton3D) -> _Part:
	var mesh := mi.mesh
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var p := _Part.new()
	var a := mesh.surface_get_arrays(0)
	p.verts = a[Mesh.ARRAY_VERTEX]
	p.normals = a[Mesh.ARRAY_NORMAL]
	p.uvs = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	if p.uvs.size() != p.verts.size():
		p.uvs.resize(p.verts.size())
	p.indices = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	p.glow = String(mi.name).contains("Eyes")
	if mi.skin != null and sk != null:
		p.bones = a[Mesh.ARRAY_BONES]
		p.weights = a[Mesh.ARRAY_WEIGHTS]
		var skin := mi.skin
		for b in skin.get_bind_count():
			var bone := skin.get_bind_bone(b)
			if bone < 0:
				bone = sk.find_bone(skin.get_bind_name(b))
			p.bind_bone.append(bone)
			p.bind_pose.append(skin.get_bind_pose(b))
		var stride := p.bones.size() / p.verts.size()
		var groups := {}
		for v in p.verts.size():
			var o := v * stride
			if p.weights[o] >= 0.999:
				var bi: int = p.bones[o]
				if not groups.has(bi):
					groups[bi] = PackedInt32Array()
				groups[bi].append(v)
			else:
				p.multi_ids.append(v)
		for bi in groups:
			var ids: PackedInt32Array = groups[bi]
			var gv := PackedVector3Array()
			var gn := PackedVector3Array()
			gv.resize(ids.size())
			gn.resize(ids.size())
			for i in ids.size():
				gv[i] = p.verts[ids[i]]
				gn[i] = p.normals[ids[i]]
			p.single_groups[bi] = [ids, gv, gn]
	elif mi.get_parent() is BoneAttachment3D and sk != null:
		p.rigid_bone = sk.find_bone((mi.get_parent() as BoneAttachment3D).bone_name)
		p.rigid_local = mi.transform
	else:
		p.rigid_local = mi.transform
	return p


static func _pose_skeleton(sk: Skeleton3D, anim: Animation, t: float) -> void:
	sk.reset_bone_poses()
	for tr in anim.get_track_count():
		var path := anim.track_get_path(tr)
		var bone := sk.find_bone(path.get_concatenated_subnames())
		if bone < 0:
			continue
		match anim.track_get_type(tr):
			Animation.TYPE_POSITION_3D:
				sk.set_bone_pose_position(bone, anim.position_track_interpolate(tr, t))
			Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(bone, anim.rotation_track_interpolate(tr, t))
			Animation.TYPE_SCALE_3D:
				sk.set_bone_pose_scale(bone, anim.scale_track_interpolate(tr, t))


static func _build_frame(parts: Array[_Part], sk: Skeleton3D) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var globals: Array[Transform3D] = []
	for b in sk.get_bone_count():
		globals.append(sk.get_bone_global_pose(b))
	for p in parts:
		var base := verts.size()
		var n := p.verts.size()
		var pv := PackedVector3Array()
		var pn := PackedVector3Array()
		pv.resize(n)
		pn.resize(n)
		if not p.bind_bone.is_empty():
			var mats: Array[Transform3D] = []
			for b in p.bind_bone.size():
				var bone: int = p.bind_bone[b]
				mats.append((globals[bone] if bone >= 0 else Transform3D.IDENTITY) * p.bind_pose[b])
			for bi in p.single_groups:
				var g: Array = p.single_groups[bi]
				var m: Transform3D = mats[bi]
				var tv: PackedVector3Array = m * (g[1] as PackedVector3Array)
				var tn: PackedVector3Array = Transform3D(m.basis, Vector3.ZERO) * (g[2] as PackedVector3Array)
				var ids: PackedInt32Array = g[0]
				for i in ids.size():
					pv[ids[i]] = tv[i]
					pn[ids[i]] = tn[i]
			var stride := p.bones.size() / n
			for v in p.multi_ids:
				var acc := Vector3.ZERO
				var accn := Vector3.ZERO
				for k in stride:
					var w := p.weights[v * stride + k]
					if w <= 0.0:
						continue
					var m2: Transform3D = mats[p.bones[v * stride + k]]
					acc += (m2 * p.verts[v]) * w
					accn += (m2.basis * p.normals[v]) * w
				pv[v] = acc
				pn[v] = accn.normalized()
		else:
			var m3 := p.rigid_local
			if p.rigid_bone >= 0:
				m3 = globals[p.rigid_bone] * p.rigid_local
			pv = m3 * p.verts
			pn = Transform3D(m3.basis, Vector3.ZERO) * p.normals
		verts.append_array(pv)
		norms.append_array(pn)
		uvs.append_array(p.uvs)
		var c := Color(1, 1, 1, MeshKit.PART_GLOW if p.glow else 1.0)
		var pc := PackedColorArray()
		pc.resize(n)
		pc.fill(c)
		cols.append_array(pc)
		if p.indices.is_empty():
			for i in n:
				idx.append(base + i)
		else:
			var shifted := p.indices.duplicate()
			for i in shifted.size():
				shifted[i] += base
			idx.append_array(shifted)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am
