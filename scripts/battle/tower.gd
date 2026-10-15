class_name Tower
extends Node3D
## A defensive tower on a build pad. Visual model changes with every level.

signal upgraded(tower: Tower)

var type := "archer"
var level := 1
var cooldown := 0.0
var enemies: EnemyManager
var projectiles: ProjectileSystem
var fx: FX
var battle: Node
var total_spent := 0

var _base: MeshInstance3D
var _head: Node3D
var _head_mesh: MeshInstance3D
var _range_ring: MeshInstance3D
var _target: EnemyManager.Enemy
var _retarget := 0.0
var _light: OmniLight3D


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
	# celebratory upgrade effect
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


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var accent: Color = GameData.TOWERS[type]["color"]
	_base = MeshInstance3D.new()
	_base.mesh = Models.tower(type, level)
	_base.material_override = _prop_material(accent, 2.0, 1.2 + level * 0.3)
	add_child(_base)
	var h := 2.4 + level * 0.45
	_head = Node3D.new()
	var head_y := 0.6 + h
	match type:
		"archer": head_y = 0.75 + h
		"cannon": head_y = 1.0 + h * 0.8
		"lightning": head_y = 1.2 + h
		"fire": head_y = 1.3 + h * 0.85
		"ice": head_y = 1.0 + h * 0.7
	_head.position = Vector3(0, head_y, 0)
	add_child(_head)
	_head_mesh = MeshInstance3D.new()
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
	# range indicator (hidden until selected)
	_range_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	var r: float = stat("range")
	t.inner_radius = r - 0.15
	t.outer_radius = r
	t.rings = 48
	t.ring_segments = 3
	_range_ring.mesh = t
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
	return _head.global_position + Vector3(0, 0.5, 0)


func _process(delta: float) -> void:
	var spd := GameState.god_value("attack_speed", 1.0)
	cooldown -= delta * spd
	if type == "lightning" or type == "fire" or type == "ice":
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
	var dmg: float = stat("damage")
	match type:
		"archer":
			var shots: int = stat("multishot")
			var used: Array = [target]
			_shoot_arrow(target, dmg)
			for i in shots - 1:
				var extra := enemies.find_target(global_position, stat("range"), used)
				if extra == null:
					break
				used.append(extra)
				_shoot_arrow(extra, dmg)
		"cannon":
			var splash: float = stat("splash")
			fx.hit_spark(muzzle() + Vector3(0, 0.2, 0), Color(1, 0.8, 0.4))
			projectiles.fire("shell", muzzle(), target, 26.0, 3.0, func(p: Vector3, _t):
				fx.explosion(p, splash, Color(1.0, 0.55, 0.2), level >= 4)
				enemies.damage_radius(p, splash, dmg)
				battle.shake(0.12 + level * 0.03))
		"lightning":
			var chain: Array = [target]
			var pts: Array = [muzzle(), enemies.enemy_center(target)]
			var last := target
			for i in int(stat("chains")) - 1:
				var nxt := enemies.find_nearest(last.pos, 6.0, chain)
				if nxt == null:
					break
				chain.append(nxt)
				pts.append(enemies.enemy_center(nxt))
				last = nxt
			fx.lightning(pts, Color(0.5, 0.7, 1.0), 0.25 + level * 0.04)
			var f := 1.0
			for e in chain:
				enemies.damage(e, dmg * f)
				f *= 0.85
		"fire":
			var splash: float = stat("splash")
			var burn: float = stat("burn")
			projectiles.fire("fire", muzzle(), target, 18.0, 2.0, func(p: Vector3, _t):
				fx.explosion(p, splash, Color(1.0, 0.4, 0.05))
				for e in enemies.enemies_in_radius(p, splash):
					enemies.damage(e, dmg)
					enemies.apply_burn(e, burn, 3.0))
		"ice":
			var splash: float = stat("splash")
			var slow: float = stat("slow")
			projectiles.fire("ice", muzzle(), target, 22.0, 1.0, func(p: Vector3, _t):
				fx.frost_burst(p, splash)
				for e in enemies.enemies_in_radius(p, splash):
					enemies.damage(e, dmg)
					enemies.apply_slow(e, slow, 2.5)
					if level >= 5 and randf() < 0.15:
						enemies.apply_freeze(e, 1.2))


func _shoot_arrow(target: EnemyManager.Enemy, dmg: float) -> void:
	projectiles.fire("arrow", muzzle(), target, 38.0, 1.2, func(p: Vector3, t):
		if t != null and t.alive:
			enemies.damage(t, dmg)
		else:
			var e := enemies.find_nearest(p, 1.2)
			if e:
				enemies.damage(e, dmg))
