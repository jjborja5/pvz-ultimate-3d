class_name BossDirector
extends Node
## Cinematic boss encounters. Each of the four bosses has its own identity:
##  - an aura that follows it (lava embers, soul wisps, bone dust, crimson flame)
##  - a unique camera angle for its fly-in intro, name card and slow motion
##  - signature attacks (molten slam + fire rain, summon + soul shield,
##    bone-spike eruption, war rally) with their own ground effects
##  - an enrage transformation at 50% health (growth, glow, aura flare, music sting)
##  - a death sequence: slow motion, chained explosions, light pillar, loot shower

var battle: Node
var enemies: EnemyManager
var fx: FX
var bosses: Array = []          # [{e, aura, light, slam_t, summon_t, shield_t, rally_t, enraged}]
var cinematic_t := 0.0
var cinematic_target: EnemyManager.Enemy
var cinematic_offset := Vector3(6.0, 9.0, 16.0)
var _death_slowmo := 0.0

const IDENTITY := {
	"boss_molten": {"aura": [Color(1, 0.75, 0.3), Color(1, 0.3, 0.05)], "aura_dir": Vector3(0, 1, 0), "light": Color(1, 0.45, 0.1),
		"cam": Vector3(-7.0, 7.0, 14.0), "title_color": Color(1, 0.5, 0.15)},
	"boss_lich": {"aura": [Color(0.6, 1, 1), Color(0.2, 0.7, 1)], "aura_dir": Vector3(0, 1, 0), "light": Color(0.3, 0.9, 1),
		"cam": Vector3(5.0, 11.0, 13.0), "title_color": Color(0.4, 1, 0.95)},
	"boss_colossus": {"aura": [Color(0.95, 0.9, 0.8), Color(0.6, 0.55, 0.45)], "aura_dir": Vector3(0, 0.3, 0), "light": Color(1, 0.3, 0.2),
		"cam": Vector3(0.0, 4.5, 15.0), "title_color": Color(0.95, 0.9, 0.8)},
	"boss_warlord": {"aura": [Color(1, 0.3, 0.25), Color(0.5, 0.0, 0.05)], "aura_dir": Vector3(0, 1, 0), "light": Color(1, 0.15, 0.1),
		"cam": Vector3(8.0, 6.0, 12.0), "title_color": Color(1, 0.25, 0.2)},
}


func setup(p_battle: Node) -> void:
	battle = p_battle
	enemies = battle.enemies
	fx = battle.fx
	enemies.enemy_killed.connect(_on_killed)


func on_boss(e: EnemyManager.Enemy) -> void:
	var id: Dictionary = IDENTITY.get(e.type, IDENTITY["boss_molten"])
	var entry := {"e": e, "slam_t": 8.0, "summon_t": 6.0, "shield_t": 12.0, "rally_t": 7.0, "spike_t": 7.0, "enraged": false}
	entry["aura"] = _make_aura(e, id)
	bosses.append(entry)
	Audio.sfx("boss_roar", 2.0, 0.02, 0.0)
	Audio.play_music("boss", 0.8)
	e.special_t = 1.6
	if cinematic_t <= 0.0 and not GameState.is_god("auto_complete_waves"):
		cinematic_t = 2.8
		cinematic_target = e
		cinematic_offset = id["cam"]
		var def: Dictionary = GameData.ENEMIES[e.type]
		var name: String = def["name"]
		battle.hud.boss_intro(name.get_slice(",", 0), name.get_slice(",", 1).strip_edges() if name.contains(",") else "", id["title_color"])
		fx.flash_light(e.pos + Vector3(0, 6, 0), def.get("glow", Color(1, 0.3, 0.1)), 10.0, 40.0, 2.0)
		fx.rune_circle(e.pos, e.scale * 2.4, id["light"], 2.6)
		fx.shockwave(e.pos, 10.0, Color(id["light"], 0.9), 0.8)
		battle.shake(0.6)


func _make_aura(e: EnemyManager.Enemy, id: Dictionary) -> Node3D:
	var root := Node3D.new()
	battle.add_child(root)
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = e.scale * 0.9
	pm.direction = id["aura_dir"]
	pm.spread = 35
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, 1.2, 0) if e.type != "boss_colossus" else Vector3(0, -0.6, 0)
	if e.type == "boss_lich":
		pm.orbit_velocity_min = 0.4
		pm.orbit_velocity_max = 0.8
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	var c0: Color = id["aura"][0]
	var c1: Color = id["aura"][1]
	g.colors = PackedColorArray([Color(c0, 0.0), Color(c0, 0.9), Color(c1, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	p.amount = int(60 * fx.quality())
	p.lifetime = 1.6
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5) if e.type != "boss_colossus" else Vector2(1.6, 1.6)
	q.material = fx.additive_material(Color(1.6, 1.6, 1.6), true, "spark" if e.type == "boss_molten" else "puff") if e.type != "boss_colossus" else fx.smoke_material()
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 20, 20))
	p.position.y = e.scale * 1.2
	root.add_child(p)
	var l := OmniLight3D.new()
	l.light_color = id["light"]
	l.light_energy = 2.0
	l.omni_range = 9.0 + e.scale * 2.0
	l.position.y = e.scale * 1.5
	root.add_child(l)
	root.set_meta("light", l)
	root.set_meta("particles", p)
	return root


func is_cinematic() -> bool:
	return (cinematic_t > 0.0 and cinematic_target != null and cinematic_target.alive) or _death_slowmo > 0.0


func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.01)
	if cinematic_t > 0.0:
		cinematic_t -= real_dt
		if cinematic_t <= 0.0:
			battle.hud.boss_intro_end()
	_death_slowmo = maxf(0.0, _death_slowmo - real_dt)
	for b in bosses.duplicate():
		var e: EnemyManager.Enemy = b["e"]
		var aura: Node3D = b["aura"]
		if not e.alive:
			if is_instance_valid(aura):
				aura.queue_free()
			bosses.erase(b)
			continue
		if is_instance_valid(aura):
			aura.global_position = e.pos
		var ability: String = GameData.ENEMIES[e.type].get("ability", "")
		if not b["enraged"] and e.hp < e.max_hp * 0.5:
			b["enraged"] = true
			_enrage(e, aura)
		match ability:
			"slam":
				b["slam_t"] -= delta
				if b["slam_t"] <= 0.0:
					b["slam_t"] = 9.0 if not b["enraged"] else 6.0
					_slam(e)
				if e.type == "boss_colossus":
					b["spike_t"] -= delta
					if b["spike_t"] <= 0.0:
						b["spike_t"] = 8.0 if not b["enraged"] else 5.0
						_bone_spikes(e)
			"summon":
				b["summon_t"] -= delta
				b["shield_t"] -= delta
				if b["summon_t"] <= 0.0:
					b["summon_t"] = 9.0 if not b["enraged"] else 6.0
					_summon(e)
				if b["shield_t"] <= 0.0:
					b["shield_t"] = 14.0 if not b["enraged"] else 9.0
					_soul_shield(e)
			"rally":
				b["rally_t"] -= delta
				if b["rally_t"] <= 0.0:
					b["rally_t"] = 10.0 if not b["enraged"] else 7.0
					_rally(e)


# ------------------------------------------------------------------ transformations

func _enrage(e: EnemyManager.Enemy, aura: Node3D) -> void:
	e.speed *= 1.4
	e.attack_rate *= 1.5
	e.special_t = 1.6
	var grow := e.scale * 1.15
	var tw := create_tween()
	tw.tween_method(func(v: float): e.scale = v, e.scale, grow, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var mat: ShaderMaterial = enemies._material(e.type)
	var base_em: float = GameData.ENEMIES[e.type].get("emissive", 0.0)
	mat.set_shader_parameter("emissive_body", base_em + 0.45)
	if is_instance_valid(aura):
		var l: OmniLight3D = aura.get_meta("light")
		l.light_energy = 5.0
		var p: GPUParticles3D = aura.get_meta("particles")
		p.amount = int(p.amount * 1.8)
	Audio.sfx("boss_roar", 3.0, 0.0, 0.0)
	var col: Color = IDENTITY.get(e.type, IDENTITY["boss_molten"])["light"]
	fx.explosion(e.pos + Vector3(0, 3, 0), 5.0, col, true)
	fx.rune_circle(e.pos, 6.0, col, 2.0)
	fx.shockwave(e.pos, 12.0, Color(col, 0.9), 0.7)
	battle.hud.banner("ENRAGED!", Color(1, 0.3, 0.2))
	battle.flash_screen(col, 0.3)
	battle.shake(0.6)


func _on_killed(e: EnemyManager.Enemy) -> void:
	if not e.boss:
		return
	## Death sequence: slow motion, chained explosions, light pillar, loot shower.
	_death_slowmo = 1.4
	cinematic_target = e
	cinematic_offset = Vector3(4.0, 7.0, 13.0)
	var col: Color = IDENTITY.get(e.type, IDENTITY["boss_molten"])["light"]
	var pos := e.pos
	battle.flash_screen(Color(1, 0.95, 0.8), 0.6)
	for i in 5:
		get_tree().create_timer(0.12 + i * 0.16, false).timeout.connect(func():
			var off := Vector3(randf_range(-2, 2), randf_range(0.5, 3.5) * (e.scale / 3.0), randf_range(-2, 2))
			fx.explosion(pos + off, 3.0 + i * 0.6, col if i % 2 == 0 else Color(1, 0.8, 0.4), i == 4)
			battle.shake(0.5))
	get_tree().create_timer(0.9, false).timeout.connect(func():
		HeroAbilities.light_pillar(battle, pos, 5.0, 0.0)
		for k in 3:
			fx.hit_spark(pos + Vector3(randf_range(-2, 2), 2, randf_range(-2, 2)), Color(1, 0.85, 0.3))
		battle.hud.boss_defeated(String(GameData.ENEMIES[e.type]["name"]).get_slice(",", 0)))
	fx.decal("crack", pos, e.scale * 4.0, Color(1, 1, 1, 1), 10.0)


# ------------------------------------------------------------------ signature attacks

func _slam(e: EnemyManager.Enemy) -> void:
	Audio.sfx("boss_slam", 2.0, 0.03, 0.0)
	e.special_t = 1.6
	var r := 9.0
	var col := Color(1.0, 0.45, 0.1) if e.type == "boss_molten" else Color(0.75, 0.6, 0.45)
	fx.explosion(e.pos, r * 0.6, col, true)
	fx.decal("crack", e.pos, r * 2.4, Color(1, 1, 1, 1), 8.0)
	if e.type == "boss_molten":
		fx.decal("scorch", e.pos, r * 2.0, Color(1.0, 0.6, 0.3, 0.9), 6.0, 1.5)
		# molten rain on the field ahead
		for i in 6:
			var p := e.pos + Vector3(randf_range(-8, 8), 0, randf_range(3, 14))
			p.y = battle.world.height_at(p.x, p.z)
			get_tree().create_timer(0.25 + i * 0.12, false).timeout.connect(func():
				fx.explosion(p, 2.2, Color(1.0, 0.4, 0.05))
				for d in battle.defenses.defenses:
					if Vector2(d.x - p.x, d.z - p.z).length() < 2.5:
						d.take_damage(e.damage))
	fx.shockwave(e.pos, r, Color(col, 0.9), 0.5)
	battle.shake(0.8)
	for d in battle.defenses.defenses.duplicate():
		if Vector2(d.x - e.pos.x, d.z - e.pos.z).length() < r:
			if d.half_width > 0.0:
				d.take_damage(e.damage * 4.0)
			elif not GameState.is_god("invincible"):
				d.alive = false
	for a in enemies.allies:
		if Vector2(a.pos.x - e.pos.x, a.pos.z - e.pos.z).length() < r:
			a.life = 0.0
	if e.pos.z > -14.0:
		battle.castle.take_damage(e.damage * 1.5, e.pos)


func _bone_spikes(e: EnemyManager.Enemy) -> void:
	## Bone Colossus: a line of jagged bone spikes erupts from the boss toward the castle.
	Audio.sfx("boss_slam", 0.0, 0.05, 0.0)
	e.special_t = 1.6
	var holder := Node3D.new()
	battle.add_child(holder)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.6
	cone.height = 3.4
	cone.radial_segments = 6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.88, 0.78)
	m.roughness = 0.6
	m.emission_enabled = true
	m.emission = Color(0.6, 0.1, 0.05)
	m.emission_energy_multiplier = 0.3
	for i in 12:
		var p := e.pos + Vector3(randf_range(-1.2, 1.2), 0, 2.5 + i * 1.6)
		p.y = battle.world.height_at(p.x, p.z) - 2.0
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = m
		holder.add_child(mi)
		mi.global_position = p
		mi.rotation = Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
		var tw := mi.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(mi, "global_position:y", p.y + 2.4, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			fx.hit_spark(mi.global_position + Vector3(0, 1, 0), Color(0.9, 0.85, 0.75))
			for d in battle.defenses.defenses:
				if Vector2(d.x - p.x, d.z - p.z).length() < 2.0:
					d.take_damage(e.damage * 1.5))
	fx.decal("crack", e.pos + Vector3(0, 0, 10), 10.0, Color(1, 1, 1, 0.9), 6.0)
	battle.shake(0.5)
	var t2 := holder.create_tween()
	t2.tween_interval(2.6)
	t2.tween_property(holder, "position:y", -3.0, 0.5)
	t2.tween_callback(holder.queue_free)


func _summon(e: EnemyManager.Enemy) -> void:
	Audio.sfx("summon", 0.0, 0.03, 0.0)
	e.special_t = 1.6
	for i in 6:
		var a := i * TAU / 6.0
		var z := e.pos.z + sin(a) * 3.0
		var s := enemies.spawn("skeleton", e.lane, z)
		if s:
			s.offset = clampf(e.pos.x + cos(a) * 3.0 - WorldBuilder.lane_x(e.lane, z), -6.0, 6.0)
			s.pos.x = e.pos.x + cos(a) * 3.0
			s.pos.z = z
			s.special_t = 1.0   # rises with its special (taunt) animation
			fx.rune_circle(s.pos, 1.4, Color(0.3, 1.0, 0.9), 1.2)
	fx.shockwave(e.pos, 5.0, Color(0.3, 1.0, 0.9, 0.8), 0.6)
	fx.rune_circle(e.pos, 5.0, Color(0.3, 1.0, 0.9), 1.8)


func _soul_shield(e: EnemyManager.Enemy) -> void:
	e.immune_t = 3.0
	var holder := Node3D.new()
	battle.add_child(holder)
	holder.global_position = e.pos
	fx.shield(holder, e.scale * 1.6, Color(0.3, 0.9, 1.0), 3.0, Vector3(0, e.scale * 1.2, 0))
	var follow := holder.create_tween().set_loops(36)
	follow.tween_callback(func():
		if e.alive:
			holder.global_position = e.pos).set_delay(0.1)
	get_tree().create_timer(3.6, false).timeout.connect(holder.queue_free)
	Audio.sfx("shield_up", 0.0, 0.0, 0.0)
	fx.shockwave(e.pos, 4.0, Color(0.3, 0.9, 1.0, 0.8), 0.6)
	battle.hud.show_hint("Vael'Zhur raises a soul shield!")


func _rally(e: EnemyManager.Enemy) -> void:
	e.special_t = 1.6
	Audio.sfx("boss_roar", 0.0, 0.1, 0.0)
	for o in enemies.enemies_in_radius(e.pos, 16.0):
		o.haste_t = 4.0
		o.flash = 0.6
	fx.shockwave(e.pos, 16.0, Color(1.0, 0.2, 0.15, 0.8), 0.8)
	fx.rune_circle(e.pos, 7.0, Color(1.0, 0.15, 0.1), 1.6)
	fx.flash_light(e.pos + Vector3(0, 4, 0), Color(1, 0.2, 0.1), 6.0, 20.0, 0.8)
	battle.hud.show_hint("The Warlord rallies his troops!")
