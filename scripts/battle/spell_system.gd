class_name SpellSystem
extends Node3D
## Player-cast magic: Fireball, Chain Storm, Ice Storm, Meteor, Meteor Rain, Firestorm,
## Frost Nova and Divine Wrath.
## Cooldowns are skipped entirely while God Mode "no cooldowns" is on.

signal cast_done(spell_id: String)

var battle: Node
var enemies: EnemyManager
var fx: FX
var projectiles: ProjectileSystem
var cooldowns := {}
var _storms: Array = []


func setup(p_battle: Node) -> void:
	battle = p_battle
	enemies = battle.enemies
	fx = battle.fx
	projectiles = battle.projectiles
	for id in GameData.SPELL_ORDER:
		cooldowns[id] = 0.0


func cooldown_for(id: String) -> float:
	var cd: float = GameData.SPELLS[id]["cooldown"]
	return cd * clampf(1.0 - battle.mod("spell_cd") - GameState.upgrade_value("spell_cooldown"), 0.2, 1.0)


func power() -> float:
	return 1.0 + battle.mod("spell") + GameState.upgrade_value("spell_power")


func ready_fraction(id: String) -> float:
	return 1.0 - clampf(cooldowns.get(id, 0.0) / cooldown_for(id), 0.0, 1.0)


func can_cast(id: String) -> bool:
	return GameState.is_god("no_cooldowns") or cooldowns.get(id, 0.0) <= 0.0


func cast(id: String, point: Vector3) -> bool:
	if not can_cast(id):
		return false
	cooldowns[id] = 0.0 if GameState.is_god("no_cooldowns") else cooldown_for(id)
	force_cast(id, point)
	cast_done.emit(id)
	return true


func force_cast(id: String, point: Vector3) -> void:
	## Cast without cooldown checks (used by combos and auto-blessings).
	var def: Dictionary = (GameData.SPELLS[id] as Dictionary).duplicate()
	def["damage"] = float(def["damage"]) * power()
	var cast_snd := {"fireball": "fire_cast", "ice_storm": "ice_cast", "meteor": "meteor_fall", "meteor_shower": "meteor_fall",
		"firestorm": "fire_roar", "frost_nova": "ice_cast", "divine_wrath": "holy_cast"}
	if cast_snd.has(id):
		Audio.sfx(cast_snd[id], 0.0, 0.04, 0.0)
	match id:
		"fireball": _fireball(point, def)
		"lightning": _chain_storm(point, def)
		"ice_storm": _ice_storm(point, def)
		"meteor": _meteor(point, def)
		"meteor_shower":
			for i in int(def["count"]):
				var p := point + Vector3(randf_range(-12, 12), 0, randf_range(-14, 14))
				p.y = battle.world.height_at(p.x, p.z)
				var d2 := def.duplicate()
				get_tree().create_timer(i * 0.22, false).timeout.connect(func(): _meteor(p, d2, 0.6))
		"firestorm":
			HeroAbilities.fire_tornado(battle, point + Vector3(0, 0, -6), def["damage"], def["radius"], def["duration"])
			HeroAbilities.fire_tornado(battle, point + Vector3(-5, 0, -10), def["damage"], def["radius"], def["duration"])
		"frost_nova":
			HeroAbilities.ice_spike_field(battle, point, def["radius"], def["damage"], 3.0)
		"divine_wrath":
			battle.flash_screen(Color(1.0, 0.95, 0.7), 0.8)
			for i in 9:
				var p2 := Vector3(randf_range(-12, 12), 0, randf_range(-70, -12))
				p2.y = battle.world.height_at(p2.x, p2.z)
				var dmg: float = def["damage"]
				get_tree().create_timer(i * 0.12, false).timeout.connect(func(): HeroAbilities.light_pillar(battle, p2, 6.0, dmg))


func _process(delta: float) -> void:
	for id in cooldowns:
		cooldowns[id] = maxf(0.0, cooldowns[id] - delta)
	var i := 0
	while i < _storms.size():
		var s: Dictionary = _storms[i]
		s["t"] -= delta
		s["tick"] -= delta
		if s["tick"] <= 0.0:
			s["tick"] = 0.25
			for e in enemies.enemies_in_radius(s["pos"], s["radius"]):
				enemies.damage(e, s["dps"] * 0.25, "ice", false, "spell")
				enemies.apply_slow(e, 0.7, 1.0)
				if randf() < 0.08:
					enemies.apply_freeze(e, 1.0)
		if s["t"] <= 0.0:
			(s["node"] as Node3D).queue_free()
			_storms.remove_at(i)
			continue
		i += 1


func _fireball(point: Vector3, def: Dictionary) -> void:
	var from: Vector3 = battle.castle_cast_point()
	var dmg: float = def["damage"]
	var radius: float = def["radius"]
	var on_hit := func(p: Vector3, _t):
		fx.explosion(p, radius, Color(1.0, 0.5, 0.1), true)
		enemies.damage_radius(p, radius, dmg, "fire", true, "spell")
		battle.shake(0.35)
	projectiles.fire("fireball", from, null, 40.0, 6.0, on_hit, point)


func _chain_storm(point: Vector3, def: Dictionary) -> void:
	var first := enemies.find_nearest(point, 10.0)
	var sky := point + Vector3(0, 25, 0)
	if first == null:
		fx.lightning([sky, point], Color(0.6, 0.75, 1.0), 0.6)
		fx.explosion(point, 2.0, Color(0.5, 0.7, 1.0))
		return
	var chain: Array = [first]
	var pts: Array = [sky, enemies.enemy_center(first)]
	var last := first
	for i in int(def["chains"]) - 1:
		var nxt := enemies.find_nearest(last.pos, 8.0, chain)
		if nxt == null:
			break
		chain.append(nxt)
		pts.append(enemies.enemy_center(nxt))
		last = nxt
	fx.lightning(pts, Color(0.6, 0.75, 1.0), 0.6, 0.4)
	for e in chain:
		enemies.damage(e, def["damage"], "lightning", true, "spell")
	battle.shake(0.2)


func _ice_storm(point: Vector3, def: Dictionary) -> void:
	var radius: float = def["radius"]
	var node := Node3D.new()
	add_child(node)
	node.global_position = point
	# falling ice shards
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3(0.2, -1, 0)
	pm.spread = 8
	pm.initial_velocity_min = 14
	pm.initial_velocity_max = 20
	pm.gravity = Vector3(0, -10, 0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(0.7, 0.9, 1, 1), Color(0.6, 0.85, 1, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	p.amount = int(160 * fx.quality())
	p.lifetime = 0.9
	p.position = Vector3(0, 12, 0)
	p.visibility_aabb = AABB(Vector3(-10, -16, -10), Vector3(20, 20, 20))
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 1.1)
	var qm := fx.additive_material(Color(1.6, 2.0, 2.4)).duplicate()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = qm
	p.draw_pass_1 = q
	node.add_child(p)
	# frost disc on the ground
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.05
	cm.radial_segments = 32
	disc.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.albedo_color = Color(0.4, 0.7, 1.0, 0.35)
	disc.material_override = dm
	disc.position = Vector3(0, 0.3, 0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(disc)
	var l := OmniLight3D.new()
	l.light_color = Color(0.5, 0.8, 1.0)
	l.light_energy = 2.0
	l.omni_range = radius * 2.0
	l.position = Vector3(0, 3, 0)
	node.add_child(l)
	fx.frost_burst(point, radius)
	fx.decal("frost", point, radius * 2.4, Color(1, 1, 1, 1), float(def["duration"]) + 1.5, 1.0)
	_storms.append({"pos": point, "radius": radius, "t": float(def["duration"]), "tick": 0.0,
		"dps": float(def["damage"]), "node": node})


func _meteor(point: Vector3, def: Dictionary, size := 1.0) -> void:
	var radius: float = def["radius"]
	var dmg: float = def["damage"]
	var rock := MeshInstance3D.new()
	var k := MeshKit.new(77)
	k.jitter = 0.08
	for i in 6:
		k.box(Vector3.ONE * randf_range(1.2, 2.0), Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)),
			Color(0.3, 0.2, 0.15), Vector3(randf() * 90, randf() * 90, randf() * 90))
	for i in 4:
		k.box(Vector3(0.15, 1.6, 0.15), Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)), Color(1, 1, 1),
			Vector3(randf() * 90, 0, randf() * 90), MeshKit.PART_GLOW)
	rock.mesh = k.build()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/prop.gdshader")
	m.set_shader_parameter("glow_color", Color(1.0, 0.45, 0.05))
	m.set_shader_parameter("glow_strength", 6.0)
	rock.material_override = m
	add_child(rock)
	var start := point + Vector3(-18, 45, -25)
	rock.global_position = start
	rock.scale = Vector3.ONE * size
	# fiery trail
	var trail := projectiles._trail(Color(1.0, 0.45, 0.1), 3.5)
	trail.amount = int(90 * fx.quality())
	trail.lifetime = 0.8
	rock.add_child(trail)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.15)
	l.light_energy = 4.0
	l.omni_range = 18.0
	rock.add_child(l)
	# warning ring at the impact site
	fx.rune_circle(point, radius, Color(1.0, 0.35, 0.05), 1.0)
	Audio.sfx("meteor_fall", -2.0, 0.05, 0.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(rock, "global_position", point, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(rock, "rotation", Vector3(4, 6, 2), 0.9)
	tw.chain().tween_callback(func():
		rock.queue_free()
		fx.explosion(point, radius, Color(1.0, 0.4, 0.05), true)
		fx.explosion(point + Vector3(2, 0, 1), radius * 0.6, Color(1.0, 0.6, 0.2), true)
		fx.shockwave(point, radius * 1.4, Color(1.0, 0.6, 0.2, 0.9), 0.6)
		enemies.damage_radius(point, radius, dmg, "fire", true, "spell")
		for e in enemies.enemies_in_radius(point, radius):
			enemies.apply_burn(e, dmg * 0.04, 3.0)
		battle.shake(0.9 * size))
