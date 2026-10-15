class_name Castle
extends Node3D
## The player's fortress: procedural stone walls, gatehouse, towers, keep, banners,
## torches, build pads and a magical barrier that flares when hit under God Mode.

signal destroyed
signal hp_changed(hp: float, max_hp: float)

const WIDTH := 30.0
const MAX_HP := 3000.0
const WALL_TOP := 5.05

var hp := MAX_HP
var pads: Array[Dictionary] = []   # {pos: Vector3, tower: Tower, node: Node3D}
var _barrier_mat: StandardMaterial3D
var _barrier_flash := 0.0
var fx: FX


func build(p_fx: FX) -> void:
	fx = p_fx
	var body := MeshInstance3D.new()
	body.mesh = Models.castle(WIDTH)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/prop.gdshader")
	m.set_shader_parameter("glow_color", Color(1.0, 0.75, 0.4))
	m.set_shader_parameter("glow_strength", 2.0)
	body.material_override = m
	add_child(body)
	var trim := MeshInstance3D.new()
	trim.mesh = Models.castle_trim(WIDTH)
	var tm := MeshKit.vertex_color_material(0.5)
	tm.metallic = 0.3
	trim.material_override = tm
	add_child(trim)
	for side in [-1, 1]:
		_torch(Vector3(side * 2.0, 4.2, -1.9))
		_torch(Vector3(side * 9.5, 5.6, -1.4))
	_build_barrier()
	_build_pads()


func _torch(pos: Vector3) -> void:
	var holder := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.12
	c.bottom_radius = 0.06
	c.height = 0.5
	holder.mesh = c
	holder.material_override = MeshKit.vertex_color_material()
	holder.position = pos
	add_child(holder)
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 1.0, 0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 0.9, 0.5, 1), Color(1, 0.45, 0.1, 0.8), Color(0.4, 0.1, 0.0, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0.1))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	p.process_material = pm
	p.amount = 18
	p.lifetime = 0.6
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.45)
	q.material = fx.additive_material(Color(2.0, 1.4, 0.8))
	p.draw_pass_1 = q
	p.position = pos + Vector3(0, 0.35, 0)
	add_child(p)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 1.2
	l.omni_range = 6.0
	l.position = pos + Vector3(0, 0.6, -0.3)
	add_child(l)


func _build_barrier() -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(WIDTH + 2.0, 7.0, 0.05)
	mi.mesh = b
	_barrier_mat = StandardMaterial3D.new()
	_barrier_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_barrier_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_barrier_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_barrier_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_barrier_mat.albedo_color = Color(0.4, 0.75, 1.0, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 1.0)
	gt.fill_to = Vector2(0.5, 0.0)
	_barrier_mat.albedo_texture = gt
	mi.material_override = _barrier_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 3.5, -2.2)
	add_child(mi)


func _build_pads() -> void:
	var spots := [
		Vector3(-11.5, WALL_TOP, 0.0), Vector3(-7.5, WALL_TOP, 0.0), Vector3(7.5, WALL_TOP, 0.0), Vector3(11.5, WALL_TOP, 0.0),
		Vector3(-3.4, 7.5, -0.2), Vector3(3.4, 7.5, -0.2),
		Vector3(-15.4, 9.5, 0.0), Vector3(15.4, 9.5, 0.0),
		Vector3(-4.0, 0.0, -11.0), Vector3(4.0, 0.0, -11.0), Vector3(-12.5, 0.0, -17.0), Vector3(12.5, 0.0, -17.0),
	]
	var pad_mat := ShaderMaterial.new()
	pad_mat.shader = load("res://shaders/prop.gdshader")
	pad_mat.set_shader_parameter("glow_color", Color(1.0, 0.85, 0.35))
	pad_mat.set_shader_parameter("pulse_speed", 3.0)
	for s in spots:
		var node := MeshInstance3D.new()
		node.mesh = Models.build_pad()
		node.material_override = pad_mat
		add_child(node)
		node.position = s
		pads.append({"pos": s, "tower": null, "node": node})


func ground_pads(height_fn: Callable) -> void:
	## Snap field pads onto the terrain after it has been generated.
	for p in pads:
		if p["pos"].y == 0.0:
			var pos: Vector3 = p["pos"]
			pos.y = height_fn.call(pos.x, pos.z) + 0.05
			p["pos"] = pos
			(p["node"] as Node3D).position = pos


func take_damage(amount: float, at: Vector3) -> void:
	if GameState.is_god("invincible") or amount <= 0.0:
		_barrier_flash = 1.0
		return
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, MAX_HP)
	if randf() < 0.15:
		fx.hit_spark(Vector3(at.x, 2.0 + randf() * 2.0, -1.3), Color(0.8, 0.7, 0.6))
	if hp <= 0.0:
		destroyed.emit()


func repair_full() -> void:
	hp = MAX_HP
	hp_changed.emit(hp, MAX_HP)


func _process(delta: float) -> void:
	_barrier_flash = maxf(0.0, _barrier_flash - delta * 2.0)
	var base := 0.06 if GameState.is_god("invincible") else 0.0
	_barrier_mat.albedo_color.a = base + _barrier_flash * 0.35 + sin(Time.get_ticks_msec() * 0.002) * base * 0.4
