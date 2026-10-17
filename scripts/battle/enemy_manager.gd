class_name EnemyManager
extends Node3D
## Data-oriented horde simulation + rendering.
## Units are plain objects updated in one loop. They are drawn with rigged CC0 KayKit
## characters whose walk / attack / death animations were baked into frame meshes by
## UnitBaker; one MultiMesh per (unit type, animation, frame, LOD) draws every unit in
## that pose with a single draw call. Also hosts spectral allies and lane blockers.

signal enemy_killed(enemy: Enemy)
signal castle_hit(damage: float, pos: Vector3)
signal boss_spawned(enemy: Enemy)
signal ranged_attack(enemy: Enemy)
signal blocker_hit(blocker: Object, damage: float, enemy: Enemy)

const HPBAR_CAPACITY := 600
const FLOATS_PER_INSTANCE := 16  # 12 transform + 4 custom
const UNIT_SCALE := 1.2          # readability scale for the elevated camera
const DEATH_TIME := 0.7
const CORPSE_TIME := 1.6
const ALLY_TYPE := "ally_skeleton"

class Enemy:
	extends RefCounted
	var type := ""
	var model := ""
	var hp := 1.0
	var max_hp := 1.0
	var speed := 1.0
	var damage := 1.0
	var radius := 0.5
	var scale := 1.0
	var attack_rate := 1.0
	var reward := 1
	var armor := 0.0
	var ranged := 0.0
	var boss := false
	var elite := ""
	var aura := 0.0          # encoded aura hue (+1) for elites
	var lane := 0
	var offset := 0.0
	var pos := Vector3.ZERO
	var heading := 0.0
	var alive := true
	var attacking := false
	var blocked_by: Object = null
	var atk_cd := 0.0
	var slow := 0.0
	var slow_t := 0.0
	var frozen_t := 0.0
	var burn_dps := 0.0
	var burn_t := 0.0
	var poison_dps := 0.0
	var poison_t := 0.0
	var immune_t := 0.0
	var haste_t := 0.0
	var ability_t := 0.0
	var anim_t := 0.0
	var death_t := 0.0
	var flash := 0.0
	var hit_t := 0.0
	var special_t := 0.0
	var ally := false
	var life := 0.0
	var target: Enemy = null

var world: WorldBuilder
var fx: FX
var enemies: Array[Enemy] = []
var allies: Array[Enemy] = []
var blockers: Array = []          # objects with: x, z, half_width, alive, func take_damage(d)
var hp_mult := 1.0
var attack_line_z := -2.6
var lod_z := -44.0
var damage_modifier: Callable     # (e, amount, element, source) -> float, set by battle
var kill_hooks: Array[Callable] = []

var _dying: Array[Enemy] = []
const CELL := 4.0
var _grid := {}                  # cell key -> Array[Enemy] (rebuilt every frame)
var stats := {"sim_us": 0, "render_us": 0, "buckets": 0}
var _mmi := {}                   # "type|anim|frame|lod" -> MultiMeshInstance3D
var _mats := {}
var _frames := {}                # model -> baked frames dictionary
var _hp_mm: MultiMesh
var _shadow_mm: MultiMesh
var _rng := RandomNumberGenerator.new()
var _number_throttle := 0.0
var _shader: Shader


func setup(p_world: WorldBuilder, p_fx: FX) -> void:
	world = p_world
	fx = p_fx
	_rng.randomize()
	_shader = load("res://shaders/unit_tex.gdshader")
	for type in GameData.ENEMIES:
		var model: String = GameData.ENEMIES[type]["model"]
		if not _frames.has(model):
			_frames[model] = UnitBaker.get_frames(model)
	_frames["skel_warrior"] = UnitBaker.get_frames("skel_warrior")
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
	# blob shadows: one instanced draw for the whole horde instead of per-unit shadow passes
	_shadow_mm = MultiMesh.new()
	_shadow_mm.transform_format = MultiMesh.TRANSFORM_3D
	var sq := QuadMesh.new()
	sq.size = Vector2(1, 1)
	sq.orientation = PlaneMesh.FACE_Y
	_shadow_mm.mesh = sq
	_shadow_mm.instance_count = 0
	var smi := MultiMeshInstance3D.new()
	smi.multimesh = _shadow_mm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = FXTextures.get_tex("soft")
	sm.albedo_color = Color(0.05, 0.03, 0.08, 0.55)
	sm.disable_receive_shadows = true
	smi.material_override = sm
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smi.custom_aabb = AABB(Vector3(-80, -10, -160), Vector3(160, 60, 220))
	add_child(smi)


func _material(type: String) -> ShaderMaterial:
	if _mats.has(type):
		return _mats[type]
	var m := ShaderMaterial.new()
	m.shader = _shader
	if type == ALLY_TYPE:
		m.set_shader_parameter("atlas", _frames["skel_warrior"]["texture"])
		m.set_shader_parameter("ghost", 1.0)
	else:
		var def: Dictionary = GameData.ENEMIES[type]
		m.set_shader_parameter("atlas", _frames[def["model"]]["texture"])
		m.set_shader_parameter("tint", def.get("tint", Color.WHITE))
		m.set_shader_parameter("tint_amount", def.get("tint_amount", 0.0))
		m.set_shader_parameter("glow_color", def.get("glow", Color(1, 0.4, 0.1)))
		m.set_shader_parameter("emissive_body", def.get("emissive", 0.0))
	_mats[type] = m
	return m


func _mmi_for(type: String, model: String, anim: String, frame: int, lo: bool) -> MultiMeshInstance3D:
	var key := "%s|%s|%d|%d" % [type, anim, frame, 1 if lo else 0]
	if _mmi.has(key):
		return _mmi[key]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var frames: Array = _frames[model][anim + ("_lo" if lo else "")]
	mm.mesh = frames[frame]
	mm.instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _material(type)
	mmi.custom_aabb = AABB(Vector3(-80, -10, -160), Vector3(160, 60, 220))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # units use blob shadows (see _render)
	add_child(mmi)
	_mmi[key] = mmi
	return mmi


# ------------------------------------------------------------------ spawning

func spawn(type: String, lane := -1, z := WorldBuilder.SPAWN_Z, hp_scale := 1.0, elite := "") -> Enemy:
	if not GameData.ENEMIES.has(type):
		return null
	var def: Dictionary = GameData.ENEMIES[type]
	if enemies.size() >= 1500:
		return null
	var e := Enemy.new()
	e.type = type
	e.model = def["model"]
	e.boss = def.get("boss", false)
	e.max_hp = float(def["hp"]) * hp_mult * hp_scale
	e.speed = float(def["speed"]) * _rng.randf_range(0.9, 1.1)
	e.damage = def["damage"]
	e.radius = float(def["radius"]) * UNIT_SCALE
	e.scale = float(def["scale"]) * UNIT_SCALE * _rng.randf_range(0.95, 1.05)
	e.attack_rate = def["attack_rate"]
	e.reward = def["reward"]
	e.armor = def.get("armor", 0.0)
	e.ranged = def.get("ranged", 0.0)
	if elite != "" and GameData.ELITES.has(elite) and not e.boss:
		var ed: Dictionary = GameData.ELITES[elite]
		e.elite = elite
		e.max_hp *= ed["hp"]
		e.scale *= ed["scale"]
		e.radius *= ed["scale"]
		e.speed *= ed["speed"]
		e.armor = maxf(e.armor, ed.get("armor", 0.0))
		e.reward *= 4
		e.aura = 1.0 + (ed["aura"] as Color).h
	e.hp = e.max_hp
	e.lane = lane if lane >= 0 else _rng.randi_range(0, WorldBuilder.LANE_COUNT - 1)
	e.offset = 0.0 if e.boss else _rng.randf_range(-2.6, 2.6)
	e.anim_t = _rng.randf() * 3.0
	e.ability_t = 6.0
	var x := WorldBuilder.lane_x(e.lane, z) + e.offset
	e.pos = Vector3(x, world.height_at(x, z), z - _rng.randf_range(0.0, 3.0))
	enemies.append(e)
	var gk := _key(int(floor(e.pos.x / CELL)), int(floor(e.pos.z / CELL)))
	if _grid.has(gk):
		_grid[gk].append(e)
	else:
		_grid[gk] = [e]
	if e.boss:
		boss_spawned.emit(e)
	return e


func spawn_ally(pos: Vector3, dps: float, life := 10.0) -> Enemy:
	var a := Enemy.new()
	a.type = ALLY_TYPE
	a.model = "skel_warrior"
	a.ally = true
	a.pos = pos
	a.speed = 5.0
	a.damage = dps
	a.scale = 1.15 * UNIT_SCALE
	a.radius = 0.6
	a.life = life
	a.heading = PI
	a.anim_t = _rng.randf()
	allies.append(a)
	fx.soul_puff(pos, Color(0.3, 1.0, 1.0))
	return a


func count_type(type: String) -> int:
	var n := 0
	for e in enemies:
		if e.type == type and e.alive:
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
	var t_start := Time.get_ticks_usec()
	_number_throttle = maxf(0.0, _number_throttle - delta)
	var field := WorldBuilder.FIELD_HALF - 1.0
	var any_dead := false
	for e in enemies:
		if not e.alive:
			any_dead = true
			continue
		e.flash = maxf(0.0, e.flash - delta * 5.0)
		e.hit_t = maxf(0.0, e.hit_t - delta)
		e.special_t = maxf(0.0, e.special_t - delta)
		e.immune_t = maxf(0.0, e.immune_t - delta)
		e.haste_t = maxf(0.0, e.haste_t - delta)
		if e.burn_t > 0.0:
			e.burn_t -= delta
			_apply_damage(e, e.burn_dps * delta, "fire", false, "burn")
		if e.poison_t > 0.0 and e.alive:
			e.poison_t -= delta
			_apply_damage(e, e.poison_dps * delta, "nature", false, "poison")
		if not e.alive:
			any_dead = true
			continue
		if e.slow_t > 0.0:
			e.slow_t -= delta
			if e.slow_t <= 0.0:
				e.slow = 0.0
		if e.frozen_t > 0.0:
			e.frozen_t -= delta
		var move_mult := 0.0 if e.frozen_t > 0.0 or e.special_t > 0.0 else (1.0 - e.slow) * (1.5 if e.haste_t > 0.0 else 1.0)
		var line := attack_line_z - e.radius
		if e.ranged > 0.0:
			line = attack_line_z - e.ranged
		# lane blockers (walls / barriers) hold the enemy in place
		if e.blocked_by != null and not bool(e.blocked_by.get("alive")):
			e.blocked_by = null
			e.attacking = false
		if not e.attacking:
			var nz := minf(e.pos.z + e.speed * move_mult * delta, line)
			var nx := clampf(WorldBuilder.lane_x(e.lane, nz) + e.offset, -field, field)
			var b := _blocker_ahead(e, nz, nx)
			if b != null:
				nz = minf(nz, float(b.get("z")) - e.radius - 0.7)
				e.blocked_by = b
			var d := Vector2(nx - e.pos.x, nz - e.pos.z)
			if d.length_squared() > 0.000001:
				e.heading = lerp_angle(e.heading, atan2(d.x, d.y), minf(1.0, delta * 6.0))
			e.pos = Vector3(nx, world.height_at(nx, nz), nz)
			e.anim_t += delta * move_mult * clampf(e.speed / 2.5, 0.6, 1.6) / maxf(e.scale * 0.8, 0.6)
			if nz >= line or e.blocked_by != null:
				e.attacking = true
				e.atk_cd = _rng.randf_range(0.2, 1.0)
				e.anim_t = 0.0
		else:
			e.heading = lerp_angle(e.heading, 0.0, minf(1.0, delta * 4.0))
			e.anim_t += delta * move_mult * e.attack_rate
			e.atk_cd -= delta * move_mult
			if e.atk_cd <= 0.0:
				e.atk_cd = 1.0 / e.attack_rate
				if e.blocked_by != null:
					blocker_hit.emit(e.blocked_by, e.damage, e)
					Audio.sfx("sword_hit", -12.0, 0.1, 0.12)
				elif e.ranged > 0.0:
					ranged_attack.emit(e)
				else:
					castle_hit.emit(e.damage, e.pos)
	if any_dead:
		enemies = enemies.filter(func(x): return x.alive)
	_update_allies(delta)
	for c in _dying:
		c.death_t += delta
	_dying = _dying.filter(func(x): return x.death_t < CORPSE_TIME)
	_rebuild_grid()
	var t_mid := Time.get_ticks_usec()
	_render()
	stats["sim_us"] = t_mid - t_start
	stats["render_us"] = Time.get_ticks_usec() - t_mid


func _key(cx: int, cz: int) -> int:
	return (cx + 512) * 4096 + (cz + 512)


func _rebuild_grid() -> void:
	_grid.clear()
	for e in enemies:
		if not e.alive:
			continue
		var k := _key(int(floor(e.pos.x / CELL)), int(floor(e.pos.z / CELL)))
		if _grid.has(k):
			_grid[k].append(e)
		else:
			_grid[k] = [e]


func _nearby(center: Vector3, radius: float) -> Array:
	## Candidate enemies from grid cells overlapping the query circle.
	var out: Array = []
	var r := radius + 2.0   # largest unit radius slack
	var x0 := int(floor((center.x - r) / CELL))
	var x1 := int(floor((center.x + r) / CELL))
	var z0 := int(floor((center.z - r) / CELL))
	var z1 := int(floor((center.z + r) / CELL))
	if _grid.is_empty() or (x1 - x0 + 1) * (z1 - z0 + 1) > _grid.size():
		return enemies   # huge query: a linear scan is cheaper
	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			var k := _key(cx, cz)
			if _grid.has(k):
				out.append_array(_grid[k])
	return out


func _blocker_ahead(e: Enemy, nz: float, nx: float) -> Object:
	for b in blockers:
		if not bool(b.get("alive")):
			continue
		var bz: float = b.get("z")
		if e.pos.z < bz and nz + e.radius + 0.7 >= bz and absf(nx - float(b.get("x"))) < float(b.get("half_width")) + e.radius * 0.5:
			return b
	return null


func _update_allies(delta: float) -> void:
	var gone := false
	for a in allies:
		a.life -= delta
		if a.life <= 0.0:
			a.alive = false
			gone = true
			fx.soul_puff(a.pos, Color(0.3, 1.0, 1.0))
			continue
		if a.target == null or not a.target.alive:
			a.target = find_nearest(a.pos, 40.0)
		if a.target == null:
			a.attacking = false
			a.anim_t += delta
			continue
		var to := Vector2(a.target.pos.x - a.pos.x, a.target.pos.z - a.pos.z)
		var dist := to.length()
		a.heading = lerp_angle(a.heading, atan2(to.x, to.y), minf(1.0, delta * 8.0))
		if dist > a.target.radius + a.radius + 0.4:
			a.attacking = false
			var step := to.normalized() * a.speed * delta
			var nx := a.pos.x + step.x
			var nz := a.pos.y + 0.0
			nz = a.pos.z + step.y
			a.pos = Vector3(nx, world.height_at(nx, nz), nz)
			a.anim_t += delta * 1.6
		else:
			if not a.attacking:
				a.anim_t = 0.0
			a.attacking = true
			a.anim_t += delta * 1.3
			_apply_damage(a.target, a.damage * delta, "shadow", false, "ally")
	if gone:
		allies = allies.filter(func(x): return x.alive)


var max_hi_units := 140


func _update_lod_cut() -> void:
	## Only the max_hi_units enemies nearest the castle use full-detail meshes.
	_hi_cut = lod_z
	if enemies.size() > max_hi_units:
		var zs := PackedFloat32Array()
		zs.resize(enemies.size())
		for i in enemies.size():
			zs[i] = enemies[i].pos.z
		zs.sort()
		_hi_cut = maxf(lod_z, zs[zs.size() - max_hi_units])


var _hi_cut := -44.0


func _render() -> void:
	_update_lod_cut()
	# bucket units by (type, anim, frame, lod)
	var buckets := {}
	for e in enemies:
		_bucket(buckets, e)
	for e in allies:
		_bucket(buckets, e)
	for e in _dying:
		_bucket(buckets, e)
	var used := {}
	var hp_buf := PackedFloat32Array()
	var hp_n := 0
	for key in buckets:
		var list: Array = buckets[key]
		var e0: Enemy = list[0]
		var parts: PackedStringArray = (key as String).split("|")
		var mmi := _mmi_for(e0.type, e0.model, parts[1], int(parts[2]), parts[3] == "1")
		var mm := mmi.multimesh
		var n := list.size()
		if mm.instance_count < n:
			mm.instance_count = int(ceil(n * 1.5 / 16.0)) * 16
		var buf := PackedFloat32Array()
		buf.resize(mm.instance_count * FLOATS_PER_INSTANCE)
		var o := 0
		for e: Enemy in list:
			var s := e.scale
			var c := cos(e.heading) * s
			var sn := sin(e.heading) * s
			var y := e.pos.y
			if e.death_t > DEATH_TIME:
				y -= (e.death_t - DEATH_TIME) * 1.2 * s
			buf[o] = c; buf[o + 1] = 0.0; buf[o + 2] = sn; buf[o + 3] = e.pos.x
			buf[o + 4] = 0.0; buf[o + 5] = s; buf[o + 6] = 0.0; buf[o + 7] = y
			buf[o + 8] = -sn; buf[o + 9] = 0.0; buf[o + 10] = c; buf[o + 11] = e.pos.z
			buf[o + 12] = e.flash
			buf[o + 13] = 1.0 if e.frozen_t > 0.0 else minf(e.slow * 1.5, 0.8)
			buf[o + 14] = 1.0 if e.burn_t > 0.0 else 0.0
			buf[o + 15] = e.aura + (2.5 if e.immune_t > 0.0 else 0.0)
			o += FLOATS_PER_INSTANCE
			if e.alive and not e.ally and e.hp < e.max_hp and not e.boss and hp_n < HPBAR_CAPACITY:
				hp_buf.append_array([1.0, 0.0, 0.0, e.pos.x, 0.0, 1.0, 0.0, e.pos.y + 2.6 * e.scale, 0.0, 0.0, 1.0, e.pos.z,
					e.hp / e.max_hp, clampf(e.scale, 0.8, 1.8), 0.0, 0.0])
				hp_n += 1
		mm.buffer = buf
		mm.visible_instance_count = n
		used[mmi] = true
	for key in _mmi:
		var mmi: MultiMeshInstance3D = _mmi[key]
		if not used.has(mmi):
			mmi.multimesh.visible_instance_count = 0
	if hp_n > 0:
		hp_buf.resize(HPBAR_CAPACITY * FLOATS_PER_INSTANCE)
		_hp_mm.buffer = hp_buf
	_hp_mm.visible_instance_count = hp_n
	_render_blob_shadows()


func _render_blob_shadows() -> void:
	var n := enemies.size() + allies.size()
	if _shadow_mm.instance_count < n:
		_shadow_mm.instance_count = int(ceil(n * 1.5 / 32.0)) * 32
	var buf := PackedFloat32Array()
	buf.resize(_shadow_mm.instance_count * 12)
	var o := 0
	for list in [enemies, allies]:
		for e: Enemy in list:
			var s := e.radius * 2.6 + e.scale * 0.4
			buf[o] = s; buf[o + 1] = 0.0; buf[o + 2] = 0.0; buf[o + 3] = e.pos.x + 0.25
			buf[o + 4] = 0.0; buf[o + 5] = 1.0; buf[o + 6] = 0.0; buf[o + 7] = e.pos.y + 0.06
			buf[o + 8] = 0.0; buf[o + 9] = 0.0; buf[o + 10] = s * 0.85; buf[o + 11] = e.pos.z + 0.2
			o += 12
	if _shadow_mm.instance_count > 0:
		_shadow_mm.buffer = buf
	_shadow_mm.visible_instance_count = n


func _bucket(buckets: Dictionary, e: Enemy) -> void:
	var frames: Dictionary = _frames[e.model]
	var anim := "walk"
	var frame := 0
	if not e.alive and not e.ally:
		anim = "death"
		var n: int = frames["death"].size()
		frame = mini(int(e.death_t / DEATH_TIME * n), n - 1)
	elif e.special_t > 0.0 and frames.has("special"):
		anim = "special"
		var ns: int = frames["special"].size()
		frame = mini(int((1.0 - e.special_t / 1.6) * ns), ns - 1)
	elif e.hit_t > 0.0 and frames.has("hit"):
		anim = "hit"
		var nh: int = frames["hit"].size()
		frame = mini(int((1.0 - e.hit_t / 0.25) * nh), nh - 1)
	elif e.attacking:
		anim = "attack"
		var n2: int = frames["attack"].size()
		frame = int(e.anim_t * n2) % n2
	else:
		var n3: int = frames["walk"].size()
		frame = int(e.anim_t * n3 * 1.25) % n3
	var lo := e.pos.z < _hi_cut and not e.boss
	if lo and anim == "walk":
		frame = frame - frame % 2   # distant units share every other pose: half the buckets
	var key := "%s|%s|%d|%d" % [e.type, anim, frame, 1 if lo else 0]
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append(e)


# ------------------------------------------------------------------ combat API

func damage(e: Enemy, amount: float, element := "physical", show_number := true, source := "") -> void:
	_apply_damage(e, amount, element, show_number, source)


func _apply_damage(e: Enemy, amount: float, element: String, show_number: bool, source: String) -> void:
	if not e.alive:
		return
	if e.immune_t > 0.0 and source != "god":
		return
	if damage_modifier.is_valid():
		amount = damage_modifier.call(e, amount, element, source)
	if e.armor > 0.0 and source != "god":
		amount *= 1.0 - (e.armor if element == "physical" else e.armor * 0.5)
	if GameState.is_god("one_hit_kill"):
		amount = e.hp + 1.0
	e.hp -= amount
	if show_number:
		e.flash = 1.0
		if amount > e.max_hp * 0.08 and not e.boss and e.hit_t <= 0.0:
			e.hit_t = 0.25
		Audio.sfx("enemy_hit", -14.0)
		if _number_throttle <= 0.0 or e.boss:
			fx.damage_number(e.pos + Vector3(0, e.scale, 0), amount, _element_color(element) if amount < 400 else Color(1, 0.5, 0.2))
			_number_throttle = 0.03
	if e.hp <= 0.0:
		_kill(e)


func _kill(e: Enemy) -> void:
	Audio.sfx("skeleton_death" if e.model.begins_with("skel") else "enemy_death", -9.0)
	e.alive = false
	e.attacking = false
	e.death_t = 0.0
	_dying.append(e)
	var def: Dictionary = GameData.ENEMIES[e.type]
	fx.soul_puff(e.pos, def.get("glow", Color(1, 0.5, 0.1)))
	if e.boss:
		fx.explosion(e.pos + Vector3(0, 2, 0), 6.0, def.get("glow", Color(1, 0.5, 0.1)), true)
	enemy_killed.emit(e)
	for h in kill_hooks:
		h.call(e)


func _element_color(el: String) -> Color:
	match el:
		"fire": return Color(1.0, 0.6, 0.25)
		"ice": return Color(0.6, 0.9, 1.0)
		"lightning": return Color(0.75, 0.8, 1.0)
		"holy": return Color(1.0, 0.95, 0.5)
		"nature": return Color(0.6, 1.0, 0.4)
		"shadow": return Color(0.8, 0.5, 1.0)
	return Color(1, 0.95, 0.6)


func damage_radius(center: Vector3, radius: float, amount: float, element := "physical", falloff := true, source := "") -> int:
	var hits := 0
	for e: Enemy in _nearby(center, radius).duplicate():
		if not e.alive:
			continue
		var d2 := Vector2(e.pos.x - center.x, e.pos.z - center.z).length_squared()
		var rr := radius + e.radius
		if d2 <= rr * rr:
			var f := 1.0 - (sqrt(d2) / rr) * 0.5 if falloff else 1.0
			_apply_damage(e, amount * f, element, hits < 6, source)
			if e.alive and not e.boss and amount * f > e.max_hp * 0.3 and not e.attacking:
				e.pos.z -= 1.2 / maxf(e.scale, 0.8)   # knockback away from the castle
			hits += 1
	return hits


func enemies_in_radius(center: Vector3, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e: Enemy in _nearby(center, radius):
		var rr := radius + e.radius
		if e.alive and Vector2(e.pos.x - center.x, e.pos.z - center.z).length_squared() <= rr * rr:
			out.append(e)
	return out


func densest_point() -> Vector3:
	## Rough crowd centre used by auto-meteors.
	if enemies.is_empty():
		return Vector3.INF
	var best := enemies[0].pos
	var best_n := -1
	for i in mini(enemies.size(), 24):
		var e: Enemy = enemies[_rng.randi_range(0, enemies.size() - 1)]
		var n := enemies_in_radius(e.pos, 5.0).size()
		if n > best_n:
			best_n = n
			best = e.pos
	return best


func find_target(from: Vector3, rng: float, exclude: Array = []) -> Enemy:
	## "First" targeting: the enemy in range closest to the castle (highest z).
	var best: Enemy = null
	var best_z := -INF
	var r2 := rng * rng
	for e: Enemy in _nearby(from, rng):
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
	for e: Enemy in _nearby(from, rng):
		if not e.alive or exclude.has(e):
			continue
		var d := Vector2(e.pos.x - from.x, e.pos.z - from.z).length_squared()
		if d <= best_d:
			best_d = d
			best = e
	return best


func random_enemies(n: int) -> Array[Enemy]:
	var pool := enemies.filter(func(x): return x.alive)
	pool.shuffle()
	var out: Array[Enemy] = []
	for i in mini(n, pool.size()):
		out.append(pool[i])
	return out


func apply_slow(e: Enemy, amount: float, duration: float) -> void:
	if e.boss:
		amount *= 0.5
	e.slow = clampf(maxf(e.slow, amount), 0.0, 0.85)
	e.slow_t = maxf(e.slow_t, duration)


func apply_freeze(e: Enemy, duration: float) -> void:
	if e.boss:
		apply_slow(e, 0.5, duration)
		return
	e.frozen_t = maxf(e.frozen_t, duration)


func apply_burn(e: Enemy, dps: float, duration: float) -> void:
	e.burn_dps = maxf(e.burn_dps, dps)
	e.burn_t = maxf(e.burn_t, duration)


func apply_poison(e: Enemy, dps: float, duration: float) -> void:
	e.poison_dps = maxf(e.poison_dps, dps)
	e.poison_t = maxf(e.poison_t, duration)


func kill_all() -> void:
	for e: Enemy in enemies.duplicate():
		if e.alive:
			e.immune_t = 0.0
			_apply_damage(e, e.hp + 1e9, "physical", false, "god")
	enemies = enemies.filter(func(x): return x.alive)


func clear_all() -> void:
	enemies.clear()
	allies.clear()
	_dying.clear()
	_render()


func enemy_center(e: Enemy) -> Vector3:
	return e.pos + Vector3(0, 1.1 * e.scale, 0)
