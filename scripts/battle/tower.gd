class_name Tower
extends Node3D
## A defensive tower on a build pad. The body is a CC0 KayKit hexagon tower in the
## tower's colour; every level grows it and adds flags, gold bands, banners and an aura.

signal upgraded(tower: Tower)

const BODY := {
	"archer": ["building_tower_base_green", Color(1, 1, 1), 0.0],
	"cannon": ["building_tower_base_red", Color(1, 1, 1), 0.0],
	"lightning": ["building_tower_base_yellow", Color(0.6, 0.6, 1.0), 0.25],
	"fire": ["building_tower_base_red", Color(0.55, 0.3, 0.25), 0.45],
	"ice": ["building_tower_base_blue", Color(0.75, 0.95, 1.0), 0.35],
}
const ELEMENT := {"archer": "physical", "cannon": "physical", "lightning": "lightning", "fire": "fire", "ice": "ice"}

var type := "archer"
var level := 1
var cooldown := 0.0
var enemies: EnemyManager
var projectiles: ProjectileSystem
var fx: FX
var battle: Node
var total_spent := 0

var _head: Node3D
var _head_mesh: MeshInstance3D
var _range_ring: MeshInstance3D
var _target: EnemyManager.Enemy
var _retarget := 0.0
var _light: OmniLight3D
var _archer_frames: Dictionary
var _archer_t := 0.0
var _aura: MeshInstance3D


func setup(p_type: String, p_level: int, p_battle: Node) -> void:
	type = p_type
	level = p_level
	battle = p_battle
	enemies = battle.enemies
	projectiles = battle.projectiles
	fx = battle.fx
	_rebuild()


func stat(key: String) -> Variant:
	var arr: Array = GameData.TOWERS[type][key]
	return arr[clampi(level - 1, 0, arr.size() - 1)]


func upgrade_cost() -> int:
	if level >= GameData.TOWER_MAX_LEVEL:
		return 0
	return int(GameData.TOWERS[type]["cost"][level])


func can_upgrade() -> bool:
	return level < GameData.TOWER_MAX_LEVEL


func set_level(lv: int) -> void:
	level = clampi(lv, 1, GameData.TOWER_MAX_LEVEL)
	_rebuild()
	fx.flash_light(global_position + Vector3(0, 4, 0), Color(1.0, 0.85, 0.4), 4.0, 8.0, 0.5)
	fx.hit_spark(global_position + Vector3(0, 3, 0), Color(1, 0.85, 0.3))
	fx.shockwave(global_position, 2.5, Color(1, 0.85, 0.3, 0.8))
	scale = Vector3.ONE * 1.25
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	upgraded.emit(self)


func _prop_material(glow: Color, pulse := 0.0, strength := 2.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/prop.gdshader")
	m.set_shader_parameter("glow_color", glow)
	m.set_shader_parameter("pulse_speed", pulse)
	m.set_shader_parameter("glow_strength", strength)
	return m


func body_scale() -> float:
	return 2.3 + 0.17 * (level - 1)


func top_height() -> float:
	return 1.5 * body_scale()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_aura = null
	var accent: Color = GameData.TOWERS[type]["color"]
	var b: Array = BODY[type]
	var path: String = "hexagon/%s.gltf" % b[0]
	var s := body_scale()
	var mat: Material = Assets.tinted(path, b[1], b[2]) if b[2] > 0.0 else null
	Assets.place(self, path, Vector3.ZERO, Vector3(s, s * (1.0 + 0.05 * (level - 1)), s), 0.0, mat)
	var top := top_height() * (1.0 + 0.05 * (level - 1))
	var flag := {"archer": "flag_green", "cannon": "flag_red", "lightning": "flag_yellow", "fire": "flag_red", "ice": "flag_blue"}
	if level >= 2:
		Assets.place(self, "hexagon/%s.gltf" % flag[type], Vector3(0.95, top, 0.5), 5.0, PI * 0.5)
	if level >= 3:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 1.05
		t.outer_radius = 1.25
		t.rings = 24
		t.ring_segments = 6
		ring.mesh = t
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(1.0, 0.78, 0.25)
		gm.metallic = 0.85
		gm.roughness = 0.25
		gm.emission_enabled = true
		gm.emission = Color(1.0, 0.7, 0.2)
		gm.emission_energy_multiplier = 0.4
		ring.material_override = gm
		ring.position.y = top * 0.55
		add_child(ring)
	if level >= 4:
		for i in 3:
			var a := i * TAU / 3.0 + 0.5
			Assets.place(self, "dungeon/banner_thin_blue.glb", Vector3(cos(a) * 1.15, top * 0.25, sin(a) * 1.15), 0.8, -a + PI * 0.5)
	if level >= 5:
		_aura = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.8
		cyl.bottom_radius = 1.8
		cyl.height = 0.05
		_aura.mesh = cyl
		var am := StandardMaterial3D.new()
		am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		am.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		am.albedo_color = Color(accent.r, accent.g, accent.b, 0.35)
		_aura.material_override = am
		_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_aura.position.y = 0.15
		add_child(_aura)
	_head = Node3D.new()
	_head.position = Vector3(0, top, 0)
	add_child(_head)
	_head_mesh = MeshInstance3D.new()
	if type == "archer":
		_archer_frames = UnitBaker.get_frames("archer_xbow")
		_head_mesh.mesh = _archer_frames["walk"][0]
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/unit_tex.gdshader")
		sm.set_shader_parameter("atlas", _archer_frames["texture"])
		sm.set_shader_parameter("tint", Color(0.5, 0.85, 0.45))
		sm.set_shader_parameter("tint_amount", 0.3 if level < 5 else 0.0)
		_head_mesh.material_override = sm
		_head_mesh.scale = Vector3.ONE * (1.25 + level * 0.05)
	else:
		_head_mesh.mesh = Models.tower_head(type, level)
		_head_mesh.material_override = _prop_material(accent, 4.0, 1.4 + level * 0.3)
	_head.add_child(_head_mesh)
	if type in ["lightning", "fire", "ice"]:
		_light = OmniLight3D.new()
		_light.light_color = accent
		_light.light_energy = 0.8 + level * 0.3
		_light.omni_range = 5.0 + level
		_light.position = Vector3(0, 0.6, 0)
		_head.add_child(_light)
	_range_ring = MeshInstance3D.new()
	var tr := TorusMesh.new()
	var r: float = stat("range")
	tr.inner_radius = r - 0.15
	tr.outer_radius = r
	tr.rings = 48
	tr.ring_segments = 3
	_range_ring.mesh = tr
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(accent.r, accent.g, accent.b, 0.6)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_range_ring.material_override = rm
	_range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_range_ring.position = Vector3(0, 0.3 - position.y, 0)
	_range_ring.visible = false
	add_child(_range_ring)


func show_range(on: bool) -> void:
	if _range_ring:
		_range_ring.visible = on


func muzzle() -> Vector3:
	return _head.global_position + Vector3(0, 1.0 if type == "archer" else 0.5, 0)


func _mod(key: String) -> float:
	return battle.mod(key) if battle and battle.has_method("mod") else 0.0


func _process(delta: float) -> void:
	var spd := GameState.god_value("attack_speed", 1.0) * (1.0 + _mod("tower_aspd"))
	cooldown -= delta * spd
	if _aura:
		_aura.rotation.y += delta
	if type == "archer":
		_archer_t += delta
		var frames: Array = _archer_frames["attack"] if _archer_t < 0.5 else _archer_frames["walk"]
		var fi := int(_archer_t * 12.0) % frames.size() if _archer_t < 0.5 else int(_archer_t * 3.0) % frames.size()
		_head_mesh.mesh = frames[fi]
	elif type == "lightning" or type == "fire" or type == "ice":
		_head_mesh.rotation.y += delta * 1.5
		_head_mesh.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.12
	var rng: float = stat("range")
	_retarget -= delta
	var focus: EnemyManager.Enemy = battle.focus_target
	if focus != null and focus.alive and _in_range(focus, rng):
		_target = focus
	elif _retarget <= 0.0 or _target == null or not _target.alive or not _in_range(_target, rng):
		_target = enemies.find_target(global_position, rng)
		_retarget = 0.25
	if _target == null:
		return
	if type == "archer" or type == "cannon":
		var d := _target.pos - _head.global_position
		_head.rotation.y = lerp_angle(_head.rotation.y, atan2(d.x, d.z), minf(1.0, delta * 10.0))
	if cooldown <= 0.0:
		cooldown = 1.0 / float(stat("rate"))
		_attack(_target)


func _in_range(e: EnemyManager.Enemy, rng: float) -> bool:
	return Vector2(e.pos.x - global_position.x, e.pos.z - global_position.z).length() <= rng + e.radius


func _attack(target: EnemyManager.Enemy) -> void:
	var dmg: float = stat("damage") * (1.0 + _mod("tower_" + type))
	var el: String = ELEMENT[type]
	match type:
		"archer":
			Audio.sfx("arrow_shoot", -8.0)
			_archer_t = 0.0
			var shots: int = int(stat("multishot")) + int(_mod("archer_extra"))
			var used: Array = [target]
			_shoot_arrow(target, dmg)
			for i in shots - 1:
				var extra := enemies.find_target(global_position, stat("range"), used)
				if extra == null:
					break
				used.append(extra)
				_shoot_arrow(extra, dmg)
		"cannon":
			var splash: float = stat("splash") * (1.0 + _mod("cannon_splash"))
			fx.hit_spark(muzzle() + Vector3(0, 0.2, 0), Color(1, 0.8, 0.4))
			Audio.sfx("cannon_fire", -5.0)
			projectiles.fire("shell", muzzle(), target, 26.0, 3.0, func(p: Vector3, _t):
				fx.explosion(p, splash, Color(1.0, 0.55, 0.2), level >= 4)
				enemies.damage_radius(p, splash, dmg, el, true, "tower")
				battle.shake(0.12 + level * 0.03))
		"lightning":
			var chain: Array = [target]
			var pts: Array = [muzzle(), enemies.enemy_center(target)]
			var last := target
			for i in int(stat("chains")) - 1 + int(_mod("chains")):
				var nxt := enemies.find_nearest(last.pos, 6.0, chain)
				if nxt == null:
					break
				chain.append(nxt)
				pts.append(enemies.enemy_center(nxt))
				last = nxt
			fx.lightning(pts, Color(0.5, 0.7, 1.0), 0.25 + level * 0.04)
			var f := 1.0
			for e in chain:
				enemies.damage(e, dmg * f, el, true, "tower")
				f *= 0.85
		"fire":
			Audio.sfx("fire_whoosh", -10.0)
			var splash: float = stat("splash")
			var burn: float = stat("burn") * (1.0 + _mod("burn"))
			projectiles.fire("fire", muzzle(), target, 18.0, 2.0, func(p: Vector3, _t):
				fx.explosion(p, splash, Color(1.0, 0.4, 0.05))
				for e in enemies.enemies_in_radius(p, splash):
					enemies.damage(e, dmg, el, true, "tower")
					enemies.apply_burn(e, burn, 3.0))
		"ice":
			var splash: float = stat("splash")
			Audio.sfx("ice_cast", -12.0)
			var slow: float = stat("slow") + _mod("slow")
			var freeze_chance := (0.15 if level >= 5 else 0.0) + _mod("freeze")
			projectiles.fire("ice", muzzle(), target, 22.0, 1.0, func(p: Vector3, _t):
				fx.frost_burst(p, splash)
				for e in enemies.enemies_in_radius(p, splash):
					enemies.damage(e, dmg, el, true, "tower")
					enemies.apply_slow(e, slow, 2.5)
					if randf() < freeze_chance:
						enemies.apply_freeze(e, 1.2))


func _shoot_arrow(target: EnemyManager.Enemy, dmg: float) -> void:
	projectiles.fire("arrow", muzzle(), target, 38.0, 1.2, func(p: Vector3, t):
		Audio.sfx("arrow_hit", -10.0)
		if t != null and t.alive:
			enemies.damage(t, dmg, "physical", true, "tower")
		else:
			var e := enemies.find_nearest(p, 1.2)
			if e:
				enemies.damage(e, dmg, "physical", true, "tower"))
