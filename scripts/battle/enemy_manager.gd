class_name EnemyManager
extends Node3D
## Data-oriented horde simulation. Enemies are plain objects updated in one loop and
## rendered through one MultiMesh per enemy type (one draw call per type), with limb
## animation done on the GPU (shaders/unit.gdshader). Handles hundreds of enemies.

signal enemy_killed(enemy: Enemy)
signal castle_hit(damage: float, pos: Vector3)
signal boss_spawned(enemy: Enemy)

const CAPACITY := 900
const HPBAR_CAPACITY := 600
const FLOATS_PER_INSTANCE := 16  # 12 transform + 4 custom
const UNIT_SCALE := 1.35        # global readability scale for the top-down camera

class Enemy:
	extends RefCounted
	var type := ""
	var hp := 1.0
	var max_hp := 1.0
	var speed := 1.0
	var damage := 1.0
	var radius := 0.5
	var scale := 1.0
	var attack_rate := 1.0
	var reward := 1
	var boss := false
	var lane := 0
	var offset := 0.0
	var pos := Vector3.ZERO
	var heading := 0.0
	var alive := true
	var attacking := false
	var atk_cd := 0.0
	var slow := 0.0
	var slow_t := 0.0
	var frozen_t := 0.0
	var burn_dps := 0.0
	var burn_t := 0.0
	var anim := 0.0
	var flash := 0.0

var world: WorldBuilder
var fx: FX
var enemies: Array[Enemy] = []
var hp_mult := 1.0
var _mm := {}        # type -> MultiMesh
var _hp_mm: MultiMesh
var _rng := RandomNumberGenerator.new()
var _number_throttle := 0.0
var attack_line_z := -2.6


func setup(p_world: WorldBuilder, p_fx: FX) -> void:
	world = p_world
	fx = p_fx
	_rng.randomize()
	var shader: Shader = load("res://shaders/unit.gdshader")
	for type in GameData.ENEMIES:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = Models.get_enemy(type)
		mm.instance_count = CAPACITY if not GameData.ENEMIES[type].get("boss", false) else 16
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("glow_color", Models.enemy_glow(type))
		if type == "boss_lich":
			mat.set_shader_parameter("stride", 0.15)
		mmi.material_override = mat
		mmi.custom_aabb = AABB(Vector3(-80, -10, -160), Vector3(160, 60, 220))
		mmi.name = "Horde_" + type
		add_child(mmi)
		_mm[type] = mm
	# health bars
	_hp_mm = MultiMesh.new()
	_hp_mm.transform_format = MultiMesh.TRANSFORM_3D
	_hp_mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 0.16)
	_hp_mm.mesh = q
	_hp_mm.instance_count = HPBAR_CAPACITY
	_hp_mm.visible_instance_count = 0
	var hpi := MultiMeshInstance3D.new()
	hpi.multimesh = _hp_mm
	var hm := ShaderMaterial.new()
	hm.shader = load("res://shaders/hpbar.gdshader")
	hpi.material_override = hm
	hpi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hpi.custom_aabb = AABB(Vector3(-80, -10, -160), Vector3(160, 60, 220))
	add_child(hpi)


# ------------------------------------------------------------------ spawning

func spawn(type: String, lane := -1, z := WorldBuilder.SPAWN_Z, hp_scale := 1.0) -> Enemy:
	if not GameData.ENEMIES.has(type):
		return null
	var def: Dictionary = GameData.ENEMIES[type]
	if count_type(type) >= _mm[type].instance_count:
		return null
	var e := Enemy.new()
	e.type = type
	e.boss = def.get("boss", false)
	e.max_hp = float(def["hp"]) * hp_mult * hp_scale
	e.hp = e.max_hp
	e.speed = float(def["speed"]) * _rng.randf_range(0.9, 1.1)
	e.damage = def["damage"]
	e.radius = float(def["radius"]) * UNIT_SCALE
	e.scale = float(def["scale"]) * UNIT_SCALE * _rng.randf_range(0.95, 1.05)
	e.attack_rate = def["attack_rate"]
	e.reward = def["reward"]
	e.lane = lane if lane >= 0 else _rng.randi_range(0, WorldBuilder.LANE_COUNT - 1)
	e.offset = 0.0 if e.boss else _rng.randf_range(-2.6, 2.6)
	e.anim = _rng.randf() * TAU
	var x := WorldBuilder.lane_x(e.lane, z) + e.offset
	e.pos = Vector3(x, world.height_at(x, z), z - _rng.randf_range(0.0, 3.0))
	enemies.append(e)
	if e.boss:
		boss_spawned.emit(e)
	return e


func count_type(type: String) -> int:
	var n := 0
	for e in enemies:
		if e.type == type:
			n += 1
	return n


func alive_count() -> int:
	var n := 0
	for e in enemies:
		if e.alive:
			n += 1
	return n


# ------------------------------------------------------------------ simulation

func _process(delta: float) -> void:
	_number_throttle = maxf(0.0, _number_throttle - delta)
	var invincible := GameState.is_god("invincible")
	var field := WorldBuilder.FIELD_HALF - 1.0
	var any_dead := false
	for e in enemies:
		if not e.alive:
			any_dead = true
			continue
		e.flash = maxf(0.0, e.flash - delta * 5.0)
		# status effects
		if e.burn_t > 0.0:
			e.burn_t -= delta
			_apply_damage(e, e.burn_dps * delta, false)
			if not e.alive:
				any_dead = true
				continue
		if e.slow_t > 0.0:
			e.slow_t -= delta
			if e.slow_t <= 0.0:
				e.slow = 0.0
		if e.frozen_t > 0.0:
			e.frozen_t -= delta
		var move_mult := 0.0 if e.frozen_t > 0.0 else (1.0 - e.slow)
		var line := attack_line_z - e.radius
		if not e.attacking:
			var nz := minf(e.pos.z + e.speed * move_mult * delta, line)
			var nx := clampf(WorldBuilder.lane_x(e.lane, nz) + e.offset, -field, field)
			var d := Vector2(nx - e.pos.x, nz - e.pos.z)
			if d.length_squared() > 0.000001:
				e.heading = lerp_angle(e.heading, atan2(d.x, d.y), minf(1.0, delta * 6.0))
			e.pos = Vector3(nx, world.height_at(nx, nz), nz)
			e.anim += delta * e.speed * move_mult * 3.2 / maxf(e.scale, 0.5)
			if nz >= line:
				e.attacking = true
				e.atk_cd = _rng.randf_range(0.2, 1.0)
		else:
			e.heading = lerp_angle(e.heading, 0.0, minf(1.0, delta * 4.0))
			e.anim += delta * 4.0 * move_mult
			e.atk_cd -= delta * move_mult
			if e.atk_cd <= 0.0:
				e.atk_cd = 1.0 / e.attack_rate
				castle_hit.emit(0.0 if invincible else e.damage, e.pos)
	if any_dead:
		enemies = enemies.filter(func(x): return x.alive)
	_render()


func _render() -> void:
	var groups := {}
	for type in _mm:
		groups[type] = []
	for e in enemies:
		groups[e.type].append(e)
	var hp_buf := PackedFloat32Array()
	var hp_n := 0
	for type in _mm:
		var mm: MultiMesh = _mm[type]
		var list: Array = groups[type]
		var n := mini(list.size(), mm.instance_count)
		if n > 0:
			var buf := PackedFloat32Array()
			buf.resize(mm.instance_count * FLOATS_PER_INSTANCE)
			var o := 0
			for i in n:
				var e: Enemy = list[i]
				var s := e.scale
				var c := cos(e.heading) * s
				var sn := sin(e.heading) * s
				# Y-rotation * uniform scale, row-major 3x4, then custom data.
				buf[o] = c; buf[o + 1] = 0.0; buf[o + 2] = sn; buf[o + 3] = e.pos.x
				buf[o + 4] = 0.0; buf[o + 5] = s; buf[o + 6] = 0.0; buf[o + 7] = e.pos.y
				buf[o + 8] = -sn; buf[o + 9] = 0.0; buf[o + 10] = c; buf[o + 11] = e.pos.z
				buf[o + 12] = e.anim
				buf[o + 13] = e.flash
				buf[o + 14] = 1.0 if e.frozen_t > 0.0 else minf(e.slow * 1.5, 0.8)
				buf[o + 15] = 1.0 if e.attacking else 0.0
				o += FLOATS_PER_INSTANCE
				if e.hp < e.max_hp and not e.boss and hp_n < HPBAR_CAPACITY:
					hp_buf.append_array([1.0, 0.0, 0.0, e.pos.x, 0.0, 1.0, 0.0, e.pos.y + 2.25 * e.scale, 0.0, 0.0, 1.0, e.pos.z,
						e.hp / e.max_hp, clampf(e.scale, 0.8, 1.8), 0.0, 0.0])
					hp_n += 1
			mm.buffer = buf
		mm.visible_instance_count = n
	if hp_n > 0:
		hp_buf.resize(HPBAR_CAPACITY * FLOATS_PER_INSTANCE)
		_hp_mm.buffer = hp_buf
	_hp_mm.visible_instance_count = hp_n


# ------------------------------------------------------------------ combat API

func damage(e: Enemy, amount: float, show_number := true) -> void:
	_apply_damage(e, amount, show_number)


func _apply_damage(e: Enemy, amount: float, show_number: bool) -> void:
	if not e.alive:
		return
	if GameState.is_god("one_hit_kill"):
		amount = e.hp + 1.0
	e.hp -= amount
	if show_number:
		e.flash = 1.0
		if _number_throttle <= 0.0 or e.boss:
			fx.damage_number(e.pos + Vector3(0, e.scale, 0), amount, Color(1, 0.95, 0.6) if amount < 200 else Color(1, 0.5, 0.2))
			_number_throttle = 0.03
	if e.hp <= 0.0:
		e.alive = false
		fx.soul_puff(e.pos, Models.enemy_glow(e.type))
		if e.boss:
			fx.explosion(e.pos + Vector3(0, 2, 0), 6.0, Models.enemy_glow(e.type), true)
		enemy_killed.emit(e)


func damage_radius(center: Vector3, radius: float, amount: float, falloff := true) -> int:
	var hits := 0
	var r2 := radius * radius
	for e in enemies:
		if not e.alive:
			continue
		var d2 := Vector2(e.pos.x - center.x, e.pos.z - center.z).length_squared()
		var rr := r2 + e.radius * e.radius * 2.0
		if d2 <= rr:
			var f := 1.0 - (sqrt(d2) / (radius + e.radius)) * 0.5 if falloff else 1.0
			_apply_damage(e, amount * f, hits < 6)
			hits += 1
	return hits


func enemies_in_radius(center: Vector3, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var r2 := radius * radius
	for e in enemies:
		if e.alive and Vector2(e.pos.x - center.x, e.pos.z - center.z).length_squared() <= r2:
			out.append(e)
	return out


func find_target(from: Vector3, rng: float, exclude: Array = []) -> Enemy:
	## "First" targeting: the enemy in range closest to the castle (highest z).
	var best: Enemy = null
	var best_z := -INF
	var r2 := rng * rng
	for e in enemies:
		if not e.alive or exclude.has(e):
			continue
		if Vector2(e.pos.x - from.x, e.pos.z - from.z).length_squared() <= r2:
			var score := e.pos.z + (30.0 if e.boss else 0.0)
			if score > best_z:
				best_z = score
				best = e
	return best


func find_nearest(from: Vector3, rng: float, exclude: Array = []) -> Enemy:
	var best: Enemy = null
	var best_d := rng * rng
	for e in enemies:
		if not e.alive or exclude.has(e):
			continue
		var d := Vector2(e.pos.x - from.x, e.pos.z - from.z).length_squared()
		if d <= best_d:
			best_d = d
			best = e
	return best


func apply_slow(e: Enemy, amount: float, duration: float) -> void:
	if e.boss:
		amount *= 0.5
	e.slow = maxf(e.slow, amount)
	e.slow_t = maxf(e.slow_t, duration)


func apply_freeze(e: Enemy, duration: float) -> void:
	if e.boss:
		apply_slow(e, 0.5, duration)
		return
	e.frozen_t = maxf(e.frozen_t, duration)


func apply_burn(e: Enemy, dps: float, duration: float) -> void:
	e.burn_dps = maxf(e.burn_dps, dps)
	e.burn_t = maxf(e.burn_t, duration)


func kill_all() -> void:
	for e in enemies.duplicate():
		if e.alive:
			_apply_damage(e, e.hp + 1e9, false)
	enemies = enemies.filter(func(x): return x.alive)


func clear_all() -> void:
	enemies.clear()
	_render()


func enemy_center(e: Enemy) -> Vector3:
	return e.pos + Vector3(0, 1.1 * e.scale, 0)
