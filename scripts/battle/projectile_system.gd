class_name ProjectileSystem
extends Node3D
## Lightweight pooled projectiles (arrows, cannon shells, fire orbs, ice shards, fireballs).
## Each projectile homes on its target enemy's current position and follows an arc.

var enemies: EnemyManager
var fx: FX
var _active: Array = []
var _pool := {}   # kind -> Array[Node3D]
var _meshes := {}
var _mats := {}


class Shot:
	extends RefCounted
	var node: Node3D
	var kind := ""
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var target: EnemyManager.Enemy
	var t := 0.0
	var duration := 0.5
	var arc := 1.0
	var on_hit: Callable


func setup(p_enemies: EnemyManager, p_fx: FX) -> void:
	enemies = p_enemies
	fx = p_fx
	_meshes["arrow"] = _arrow_mesh()
	var shell := SphereMesh.new()
	shell.radius = 0.28
	shell.height = 0.56
	_meshes["shell"] = shell
	var orb := SphereMesh.new()
	orb.radius = 0.4
	orb.height = 0.8
	_meshes["fire"] = orb
	var big := SphereMesh.new()
	big.radius = 0.9
	big.height = 1.8
	_meshes["fireball"] = big
	var shard := PrismMesh.new()
	shard.size = Vector3(0.25, 0.9, 0.25)
	_meshes["ice"] = shard
	_mats["arrow"] = MeshKit.vertex_color_material(0.6)
	_mats["shell"] = _solid(Color(0.12, 0.12, 0.14), 0.0)
	_mats["fire"] = _glow(Color(1.0, 0.45, 0.1), 6.0)
	_mats["fireball"] = _glow(Color(1.0, 0.5, 0.15), 8.0)
	_mats["ice"] = _glow(Color(0.6, 0.9, 1.0), 3.0)


func _arrow_mesh() -> ArrayMesh:
	var k := MeshKit.new(900)
	k.box(Vector3(0.05, 0.05, 1.0), Vector3.ZERO, Color(0.55, 0.4, 0.25))
	k.cone(0.08, 0.2, Vector3(0, 0, 0.55), Color(0.8, 0.8, 0.85), Vector3(90, 0, 0))
	k.box(Vector3(0.18, 0.02, 0.2), Vector3(0, 0, -0.45), Color(0.9, 0.9, 0.9))
	return k.build()


func _solid(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.6
	return m


func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _get_node(kind: String) -> Node3D:
	var pool: Array = _pool.get(kind, [])
	if not pool.is_empty():
		var n: Node3D = pool.pop_back()
		n.visible = true
		return n
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[kind]
	mi.material_override = _mats[kind]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "fire" or kind == "fireball":
		mi.add_child(_trail(Color(1.0, 0.5, 0.1), 1.0 if kind == "fire" else 2.2))
	elif kind == "ice":
		mi.add_child(_trail(Color(0.6, 0.9, 1.0), 0.6))
	add_child(mi)
	return mi


func _trail(color: Color, size: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, 1.5, 0)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.6
	pm.spread = 180
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(color.r, color.g * 0.3, 0.0, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	p.process_material = pm
	p.amount = int(24 * fx.quality())
	p.lifetime = 0.4
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = fx.additive_material(Color(color.r * 2.0, color.g * 2.0, color.b * 2.0))
	p.draw_pass_1 = q
	return p


func fire(kind: String, from: Vector3, target: EnemyManager.Enemy, speed: float, arc: float, on_hit: Callable, to_point := Vector3.INF) -> void:
	var s := Shot.new()
	s.kind = kind
	s.from = from
	s.target = target
	s.to = to_point if to_point != Vector3.INF else enemies.enemy_center(target)
	s.duration = maxf(0.12, from.distance_to(s.to) / speed)
	s.arc = arc
	s.on_hit = on_hit
	s.node = _get_node(kind)
	s.node.global_position = from
	_active.append(s)


func _process(delta: float) -> void:
	var i := 0
	while i < _active.size():
		var s: Shot = _active[i]
		s.t += delta / s.duration
		if s.target != null and s.target.alive:
			s.to = enemies.enemy_center(s.target)
		var t := minf(s.t, 1.0)
		var p := s.from.lerp(s.to, t)
		p.y += s.arc * 4.0 * t * (1.0 - t)
		var prev := s.node.global_position
		s.node.global_position = p
		if (p - prev).length_squared() > 0.0001 and s.kind != "fire" and s.kind != "fireball":
			s.node.look_at(p + (p - prev), Vector3.UP)
			if s.kind == "ice":
				s.node.rotate_object_local(Vector3.RIGHT, -PI / 2)
			elif s.kind == "arrow":
				s.node.rotate_object_local(Vector3.UP, PI)
		if s.t >= 1.0:
			s.on_hit.call(s.to, s.target)
			s.node.visible = false
			var pool: Array = _pool.get(s.kind, [])
			pool.append(s.node)
			_pool[s.kind] = pool
			_active.remove_at(i)
			continue
		i += 1


func clear_all() -> void:
	for s in _active:
		s.node.queue_free()
	_active.clear()
