class_name Castle
extends Node3D
## The player's fortress, assembled from CC0 KayKit Medieval Hexagon pieces: stone wall
## segments, a gate, gate towers, corner towers, a keep and a small town behind it.
## Also owns torches, build pads, hero posts and the magical barrier that flares under God Mode.

signal destroyed
signal hp_changed(hp: float, max_hp: float)

const WIDTH := 30.0
const BASE_HP := 3000.0
const MAX_HP := 3000.0                 # legacy constant (base value)
const WALL_SCALE := Vector3(3.0, 4.0, 3.75)
const WALL_TOP := 3.6                  # walkway height (0.9 * WALL_SCALE.y)
const GATE_TOWER_TOP := 4.5            # tower_base top (1.5 * 3.0)
const HEX := "hexagon/"

var hp := BASE_HP
var max_hp := BASE_HP
var armor := 0.0                       # damage reduction from upgrades / items
var pads: Array[Dictionary] = []       # {pos: Vector3, tower: Tower, node: Node3D}
var hero_posts: Array[Vector3] = [Vector3(-9.2, WALL_TOP, -0.2), Vector3(0.0, WALL_TOP + 0.5, -0.2), Vector3(9.2, WALL_TOP, -0.2)]
var _barrier_mat: StandardMaterial3D
var _barrier_flash := 0.0
var fx: FX


func build(p_fx: FX) -> void:
	fx = p_fx
	# stone wall: five segments, gate in the middle
	for i in 5:
		var x := -12.0 + i * 6.0
		var piece := "wall_straight_gate" if i == 2 else "wall_straight"
		Assets.place(self, HEX + piece + ".gltf", Vector3(x, 0, 0), WALL_SCALE)
	# gate towers flanking the gate
	for side in [-1, 1]:
		Assets.place(self, HEX + "building_tower_base_blue.gltf", Vector3(side * 3.2, 0, -0.4), 3.0)
		Assets.place(self, HEX + "flag_blue.gltf", Vector3(side * 3.2, GATE_TOWER_TOP, 0.6), 6.0, PI * 0.5)
	# corner towers
	for side in [-1, 1]:
		Assets.place(self, HEX + "building_tower_B_blue.gltf", Vector3(side * 15.8, 0, 0.0), 4.6, side * 0.4)
		Assets.place(self, HEX + "flag_red.gltf", Vector3(side * 15.8, 11.4, 0.0), 8.0, PI * 0.5)
	# keep and town behind the wall
	Assets.place(self, HEX + "building_castle_blue.gltf", Vector3(0, 0, 10.0), 4.6)
	Assets.place(self, HEX + "building_church_blue.gltf", Vector3(-11.0, 0, 9.0), 4.0, 0.3)
	Assets.place(self, HEX + "building_barracks_blue.gltf", Vector3(11.0, 0, 8.0), 4.2, -0.4)
	Assets.place(self, HEX + "building_home_A_blue.gltf", Vector3(-6.5, 0, 6.5), 4.0, 0.8)
	Assets.place(self, HEX + "building_home_B_blue.gltf", Vector3(6.5, 0, 6.0), 4.0, -0.6)
	Assets.place(self, HEX + "building_blacksmith_blue.gltf", Vector3(-15.5, 0, 6.5), 4.0, 0.2)
	Assets.place(self, HEX + "building_windmill_blue.gltf", Vector3(17.0, 0, 9.0), 4.0, -0.3)
	Assets.place(self, HEX + "building_tavern_blue.gltf", Vector3(-3.0, 0, 15.5), 4.0, 0.0)
	Assets.place(self, HEX + "building_well_blue.gltf", Vector3(3.5, 0, 4.5), 3.5, 0.5)
	# battlements props
	for x in [-13.5, -7.5, 7.5, 13.5]:
		Assets.place(self, "dungeon/banner_patternA_blue.glb", Vector3(x, 1.0, -1.55), Vector3(1.0, 1.2, 1.0), PI)
	for side in [-1, 1]:
		_torch(Vector3(side * 1.9, 2.4, -1.7))
		_torch(Vector3(side * 10.5, 2.4, -1.6))
	_build_barrier()
	_build_pads()


func set_max_hp(value: float) -> void:
	var ratio := hp / max_hp
	max_hp = value
	hp = max_hp * ratio
	hp_changed.emit(hp, max_hp)


func _torch(pos: Vector3) -> void:
	Assets.place(self, "dungeon/torch_mounted.glb", pos + Vector3(0, -0.2, 0.15), 1.4, PI)
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
	p.position = pos + Vector3(0, 0.55, -0.35)
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
	mi.position = Vector3(0, 3.5, -2.4)
	add_child(mi)


func _build_pads() -> void:
	var spots := [
		Vector3(-12.5, WALL_TOP, 0.0), Vector3(-5.8, WALL_TOP, 0.0), Vector3(5.8, WALL_TOP, 0.0), Vector3(12.5, WALL_TOP, 0.0),
		Vector3(-3.2, GATE_TOWER_TOP, -0.4), Vector3(3.2, GATE_TOWER_TOP, -0.4),
		Vector3(-4.0, 0.0, -11.0), Vector3(4.0, 0.0, -11.0), Vector3(-12.5, 0.0, -15.0), Vector3(12.5, 0.0, -15.0),
		Vector3(-8.5, 0.0, -24.0), Vector3(8.5, 0.0, -24.0),
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
	hp = maxf(0.0, hp - amount * (1.0 - clampf(armor, 0.0, 0.9)))
	hp_changed.emit(hp, max_hp)
	if randf() < 0.15:
		fx.hit_spark(Vector3(at.x, 2.0 + randf() * 2.0, -1.3), Color(0.8, 0.7, 0.6))
	if hp <= 0.0:
		destroyed.emit()


func repair_full() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func _process(delta: float) -> void:
	_barrier_flash = maxf(0.0, _barrier_flash - delta * 2.0)
	var base := 0.06 if GameState.is_god("invincible") else 0.0
	_barrier_mat.albedo_color.a = base + _barrier_flash * 0.35 + sin(Time.get_ticks_msec() * 0.002) * base * 0.4
