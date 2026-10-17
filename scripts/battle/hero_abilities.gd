class_name HeroAbilities
extends RefCounted
## Hero ultimate abilities and the large-scale effects they share with spells:
## arrow storms, fire tornadoes, ice spike fields, light pillars, grasping roots,
## the army of the dead, mortar barrages and the Elder Dragon fly-over.

static var _ice_mat: StandardMaterial3D
static var _root_mat: StandardMaterial3D
static var _beam_mat: StandardMaterial3D


static func cast(hero: Hero, ability_id: String) -> void:
	var b: Node = hero.battle
	var snd := {"arrow_storm": "arrow_shoot", "firestorm": "fire_roar", "glacial_spikes": "ice_cast", "thunder_dome": "lightning",
		"divine_judgment": "holy_cast", "wrath_of_grove": "nature_cast", "army_of_dead": "summon", "mortar_barrage": "cannon_fire",
		"elder_dragon": "dragon_roar"}
	Audio.sfx(snd.get(ability_id, "magic_cast"), 2.0, 0.03, 0.0)
	Audio.sfx("magic_cast", -6.0, 0.05, 0.0)
	var dmg := hero.ability_damage()
	var a: Dictionary = hero.def["ability"]
	var center: Vector3 = b.enemies.densest_point()
	if center == Vector3.INF:
		center = Vector3(0, 0, -35)
	match ability_id:
		"arrow_storm": arrow_storm(b, center, a["radius"], dmg, 80)
		"firestorm":
			for i in 3:
				fire_tornado(b, Vector3(WorldBuilder.lane_x(i, -55.0), 0, -55.0), dmg, a["radius"], 6.0)
		"glacial_spikes": ice_spike_field(b, center, 9.0, dmg, 2.5)
		"thunder_dome": thunder_dome(b, dmg, 40, 4.0)
		"divine_judgment":
			light_pillar(b, center, a["radius"], dmg)
			b.castle.heal(b.castle.max_hp * 0.15)
		"wrath_of_grove": grasping_roots(b, center, a["radius"], dmg)
		"army_of_dead":
			for i in 14:
				var p := Vector3(-13.0 + i * 2.0, 0, -6.0 - randf() * 3.0)
				p.y = b.world.height_at(p.x, p.z)
				b.enemies.spawn_ally(p, dmg, 12.0)
				if i % 2 == 0:
					b.fx.rune_circle(p, 2.0, Color(0.3, 1.0, 1.0), 1.5)
			b.fx.flash_light(Vector3(0, 3, -6), Color(0.3, 1.0, 1.0), 6.0, 25.0, 1.0)
		"mortar_barrage": mortar_barrage(b, hero.muzzle(), center, dmg, 12, a["radius"])
		"elder_dragon":
			elder_dragon(b, center.z, dmg, a["radius"])
			if hero.stats["effects"].has("dragon"):
				b.get_tree().create_timer(2.6, false).timeout.connect(func(): elder_dragon(b, center.z - 12.0, dmg, a["radius"]))
	if b.has_combo("hero_legend"):
		b.spells.force_cast("fireball", center)


# ------------------------------------------------------------------ arrow storm

static func arrow_storm(b: Node, center: Vector3, radius: float, dmg: float, count: int) -> void:
	for i in count:
		var delay := randf() * 1.6
		var p := center + Vector3(randf_range(-radius, radius), 0, randf_range(-radius, radius))
		p.y = b.world.height_at(p.x, p.z)
		b.get_tree().create_timer(delay, false).timeout.connect(func():
			b.projectiles.fire("arrow", p + Vector3(randf_range(-4, 4), 22, 6), null, 55.0, 0.0, func(hit: Vector3, _t):
				b.enemies.damage_radius(hit, 1.4, dmg, "physical", false, "ability")
				if randf() < 0.3:
					b.fx.hit_spark(hit, Color(1, 0.9, 0.6)), p))
	b.fx.shockwave(center, radius, Color(0.5, 1.0, 0.5, 0.6), 1.6)


# ------------------------------------------------------------------ fire tornado

static func fire_tornado(b: Node, start: Vector3, dmg: float, radius: float, duration: float) -> void:
	var node := Node3D.new()
	b.add_child(node)
	node.global_position = Vector3(start.x, b.world.height_at(start.x, start.z), start.z)
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_height = 0.5
	pm.emission_ring_radius = 1.2
	pm.emission_ring_inner_radius = 0.4
	pm.direction = Vector3.UP
	pm.spread = 10
	pm.initial_velocity_min = 6
	pm.initial_velocity_max = 10
	pm.gravity = Vector3.ZERO
	pm.orbit_velocity_min = 1.2
	pm.orbit_velocity_max = 1.8
	pm.radial_velocity_min = 0.6
	pm.radial_velocity_max = 1.2
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.75, 1.0])
	g.colors = PackedColorArray([Color(1, 0.95, 0.6, 1), Color(1, 0.5, 0.1, 1), Color(0.6, 0.12, 0.02, 0.7), Color(0.1, 0.05, 0.05, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(1, 2.2))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	p.process_material = pm
	p.amount = int(110 * b.fx.quality())
	p.lifetime = 1.3
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	q.material = b.fx.additive_material(Color(1.5, 0.95, 0.5), true, "puff")
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 20, 16))
	node.add_child(p)
	var vortex := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 2.6
	cone.bottom_radius = 0.7
	cone.height = 9.0
	cone.radial_segments = 20
	cone.cap_top = false
	cone.cap_bottom = false
	vortex.mesh = cone
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/tornado.gdshader")
	vm.set_shader_parameter("noise_tex", FXTextures.get_tex("noise"))
	vortex.material_override = vm
	vortex.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vortex.position.y = 4.5
	node.add_child(vortex)
	var inner := vortex.duplicate() as MeshInstance3D
	inner.scale = Vector3(0.6, 0.95, 0.6)
	node.add_child(inner)
	vortex.create_tween().set_loops().tween_property(vortex, "rotation:y", TAU, 0.6).as_relative()
	inner.create_tween().set_loops().tween_property(inner, "rotation:y", -TAU, 0.45).as_relative()
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.15)
	l.light_energy = 4.0
	l.omni_range = 12.0
	l.position.y = 3.0
	node.add_child(l)
	for k in int(duration / 0.8):
		b.get_tree().create_timer(k * 0.8, false).timeout.connect(func():
			if is_instance_valid(node):
				b.fx.decal("scorch", node.global_position, 4.0, Color(1, 1, 1, 0.75), 5.0))
	var end := Vector3(start.x * 0.6, 0, -8.0)
	var tw := node.create_tween()
	tw.tween_property(node, "global_position", Vector3(end.x, 0, end.z), duration).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		p.emitting = false
		l.queue_free()
		vortex.queue_free()
		inner.queue_free())
	tw.tween_interval(1.5)
	tw.tween_callback(node.queue_free)
	var ticks := int(duration / 0.25)
	for i in ticks:
		b.get_tree().create_timer(i * 0.25, false).timeout.connect(func():
			if is_instance_valid(node):
				for e in b.enemies.enemies_in_radius(node.global_position, radius):
					b.enemies.damage(e, dmg * 0.25, "fire", i % 4 == 0, "ability")
					b.enemies.apply_burn(e, dmg * 0.2, 3.0))


# ------------------------------------------------------------------ ice spikes

static func _ice_material() -> StandardMaterial3D:
	if _ice_mat == null:
		_ice_mat = StandardMaterial3D.new()
		_ice_mat.albedo_color = Color(0.7, 0.92, 1.0, 0.85)
		_ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ice_mat.roughness = 0.05
		_ice_mat.metallic = 0.3
		_ice_mat.emission_enabled = true
		_ice_mat.emission = Color(0.4, 0.75, 1.0)
		_ice_mat.emission_energy_multiplier = 1.2
		_ice_mat.rim_enabled = true
		_ice_mat.rim = 1.0
	return _ice_mat


static func ice_spike_field(b: Node, center: Vector3, radius: float, dmg: float, freeze: float) -> void:
	var holder := Node3D.new()
	b.add_child(holder)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.55
	cone.height = 3.2
	cone.radial_segments = 5
	cone.rings = 1
	for i in int(46 * b.fx.quality()) + 10:
		var r := sqrt(randf()) * radius
		var a := randf() * TAU
		var p := center + Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = b.world.height_at(p.x, p.z) - 1.8
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = _ice_material()
		holder.add_child(mi)
		mi.global_position = p
		mi.rotation = Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))
		var s := randf_range(0.6, 1.5)
		mi.scale = Vector3(s, s * randf_range(0.8, 1.6), s)
		var tw := mi.create_tween()
		tw.tween_interval(r / radius * 0.35)
		tw.tween_property(mi, "global_position:y", p.y + 1.8 + s * 0.5, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.fx.frost_burst(center, radius)
	b.fx.decal("frost", center, radius * 2.6, Color(1, 1, 1, 1), freeze + 2.0, 1.2)
	b.fx.rune_circle(center, radius, Color(0.5, 0.85, 1.0), 1.2)
	b.fx.shockwave(center, radius, Color(0.6, 0.9, 1.0, 0.8), 0.5)
	b.fx.flash_light(center + Vector3(0, 4, 0), Color(0.5, 0.8, 1.0), 6.0, radius * 3.0, 1.2)
	b.shake(0.35)
	for e in b.enemies.enemies_in_radius(center, radius):
		b.enemies.damage(e, dmg, "ice", true, "ability")
		b.enemies.apply_freeze(e, freeze)
	var tw2 := holder.create_tween()
	tw2.tween_interval(freeze + 0.6)
	tw2.tween_callback(func():
		for c in holder.get_children():
			b.fx.hit_spark(c.global_position + Vector3(0, 1, 0), Color(0.7, 0.9, 1.0))
		holder.queue_free())


# ------------------------------------------------------------------ thunder dome

static func thunder_dome(b: Node, dmg: float, bolts: int, duration: float) -> void:
	for i in bolts:
		b.get_tree().create_timer(i * duration / bolts, false).timeout.connect(func():
			var targets: Array = b.enemies.random_enemies(1)
			var p: Vector3
			if targets.is_empty():
				p = Vector3(randf_range(-12, 12), 0, randf_range(-60, -10))
			else:
				p = targets[0].pos
			b.fx.lightning([p + Vector3(randf_range(-3, 3), 28, randf_range(-3, 3)), p + Vector3(0, 0.5, 0)], Color(0.7, 0.75, 1.0), 0.7, 0.3)
			b.fx.explosion(p, 2.0, Color(0.6, 0.7, 1.0))
			b.enemies.damage_radius(p, 2.4, dmg, "lightning", false, "ability")
			b.shake(0.12))


# ------------------------------------------------------------------ light pillar

static func light_pillar(b: Node, center: Vector3, radius: float, dmg: float) -> void:
	if _beam_mat == null:
		_beam_mat = StandardMaterial3D.new()
		_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat: StandardMaterial3D = _beam_mat.duplicate()
	mat.albedo_color = Color(1.6, 1.3, 0.6, 0.9)
	var beam := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius * 0.7
	c.bottom_radius = radius * 0.5
	c.height = 60.0
	c.radial_segments = 24
	beam.mesh = c
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(beam)
	beam.global_position = center + Vector3(0, 30, 0)
	beam.scale = Vector3(0.05, 1, 0.05)
	var tw := beam.create_tween()
	tw.tween_property(beam, "scale", Vector3(1, 1, 1), 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw.tween_callback(beam.queue_free)
	b.fx.rune_circle(center, radius, Color(1.0, 0.85, 0.4), 1.4)
	b.fx.decal("crack", center, radius * 2.2, Color(1, 1, 1, 0.9), 6.0)
	b.fx.explosion(center, radius, Color(1.0, 0.85, 0.4), true)
	b.fx.shockwave(center, radius * 1.3, Color(1.0, 0.9, 0.5, 0.9), 0.6)
	b.fx.flash_light(center + Vector3(0, 6, 0), Color(1.0, 0.9, 0.6), 12.0, radius * 4.0, 1.0)
	b.flash_screen(Color(1.0, 0.95, 0.7), 0.35)
	b.shake(0.6)
	b.enemies.damage_radius(center, radius, dmg, "holy", true, "ability")


# ------------------------------------------------------------------ roots

static func grasping_roots(b: Node, center: Vector3, radius: float, dmg: float) -> void:
	if _root_mat == null:
		_root_mat = StandardMaterial3D.new()
		_root_mat.albedo_color = Color(0.35, 0.25, 0.15)
		_root_mat.roughness = 0.9
		_root_mat.emission_enabled = true
		_root_mat.emission = Color(0.3, 0.9, 0.2)
		_root_mat.emission_energy_multiplier = 0.4
	var holder := Node3D.new()
	b.add_child(holder)
	var vine := CylinderMesh.new()
	vine.top_radius = 0.05
	vine.bottom_radius = 0.28
	vine.height = 2.6
	vine.radial_segments = 6
	for i in int(40 * b.fx.quality()) + 10:
		var r := sqrt(randf()) * radius
		var ang := randf() * TAU
		var p := center + Vector3(cos(ang) * r, 0, sin(ang) * r)
		p.y = b.world.height_at(p.x, p.z) - 1.3
		var mi := MeshInstance3D.new()
		mi.mesh = vine
		mi.material_override = _root_mat
		holder.add_child(mi)
		mi.global_position = p
		mi.rotation = Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf_range(-0.6, 0.6))
		var tw := mi.create_tween()
		tw.tween_interval(randf() * 0.4)
		tw.tween_property(mi, "global_position:y", p.y + 1.2, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.fx.shockwave(center, radius, Color(0.4, 1.0, 0.3, 0.8), 0.7)
	b.fx.rune_circle(center, radius, Color(0.4, 1.0, 0.35), 3.4)
	b.fx.decal("crack", center, radius * 2.0, Color(0.6, 0.8, 0.4, 0.8), 5.0)
	b.fx.flash_light(center + Vector3(0, 3, 0), Color(0.4, 1.0, 0.3), 5.0, radius * 3.0, 1.5)
	for e in b.enemies.enemies_in_radius(center, radius):
		b.enemies.damage(e, dmg, "nature", true, "ability")
		b.enemies.apply_freeze(e, 3.0)
		b.enemies.apply_poison(e, dmg * 0.5, 5.0)
	var tw2 := holder.create_tween()
	tw2.tween_interval(3.4)
	tw2.tween_property(holder, "position:y", -2.0, 0.6)
	tw2.tween_callback(holder.queue_free)


# ------------------------------------------------------------------ mortar

static func mortar_barrage(b: Node, from: Vector3, center: Vector3, dmg: float, shells: int, radius: float) -> void:
	for i in shells:
		b.get_tree().create_timer(i * 0.15, false).timeout.connect(func():
			var p := center + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
			p.y = b.world.height_at(p.x, p.z)
			b.projectiles.fire("bomb", from, null, 22.0, 14.0, func(hit: Vector3, _t):
				b.fx.explosion(hit, radius, Color(1.0, 0.6, 0.2), true)
				b.enemies.damage_radius(hit, radius, dmg, "physical", true, "ability")
				b.shake(0.25), p))


# ------------------------------------------------------------------ elder dragon

static func dragon_model() -> Node3D:
	## Procedural stylised dragon (original model) with flapping wings.
	var root := Node3D.new()
	var body_k := MeshKit.new(4242)
	body_k.jitter = 0.03
	var scale_c := Color(0.15, 0.55, 0.5)
	var belly := Color(0.85, 0.75, 0.45)
	var horn := Color(0.95, 0.85, 0.6)
	body_k.sphere(1.4, Vector3(0, 0, 0), scale_c, Vector3(1.0, 0.9, 2.0))
	body_k.sphere(1.0, Vector3(0, -0.35, 0.4), belly, Vector3(0.9, 0.7, 1.6))
	# neck + head
	for i in 4:
		body_k.sphere(0.6 - i * 0.05, Vector3(0, 0.4 + i * 0.35, 2.4 + i * 0.6), scale_c)
	body_k.box(Vector3(1.0, 0.7, 1.6), Vector3(0, 1.9, 5.1), scale_c)
	body_k.box(Vector3(0.8, 0.35, 1.0), Vector3(0, 1.6, 5.9), scale_c.darkened(0.2))
	body_k.cone(0.15, 0.9, Vector3(0.35, 2.4, 4.7), horn, Vector3(-60, 0, 0))
	body_k.cone(0.15, 0.9, Vector3(-0.35, 2.4, 4.7), horn, Vector3(-60, 0, 0))
	body_k.sphere(0.12, Vector3(0.4, 2.05, 5.5), Color(1, 1, 1), Vector3.ONE, MeshKit.PART_GLOW, 6)
	body_k.sphere(0.12, Vector3(-0.4, 2.05, 5.5), Color(1, 1, 1), Vector3.ONE, MeshKit.PART_GLOW, 6)
	# spine ridges + tail
	for i in 7:
		body_k.cone(0.22, 0.6, Vector3(0, 1.1 - i * 0.05, 1.5 - i * 0.8), horn)
	for i in 8:
		body_k.sphere(0.8 - i * 0.09, Vector3(0, -0.1 * i, -2.4 - i * 0.75), scale_c)
	body_k.cone(0.5, 1.2, Vector3(0, -0.8, -8.6), horn, Vector3(-90, 0, 0))
	# legs
	for sx in [-1, 1]:
		body_k.box(Vector3(0.45, 1.2, 0.45), Vector3(sx * 0.9, -1.2, 1.0), scale_c, Vector3(30, 0, 0))
		body_k.box(Vector3(0.45, 1.2, 0.45), Vector3(sx * 0.9, -1.2, -1.2), scale_c, Vector3(30, 0, 0))
	var body := MeshInstance3D.new()
	body.mesh = body_k.build()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/prop.gdshader")
	mat.set_shader_parameter("glow_color", Color(1.0, 0.85, 0.3))
	mat.set_shader_parameter("glow_strength", 6.0)
	mat.set_shader_parameter("roughness_value", 0.5)
	body.material_override = mat
	root.add_child(body)
	for sx in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "WingL" if sx < 0 else "WingR"
		pivot.position = Vector3(sx * 1.0, 0.6, 0.6)
		root.add_child(pivot)
		var wk := MeshKit.new(77 + sx)
		var membrane := Color(0.2, 0.7, 0.62)
		wk.box(Vector3(5.5, 0.12, 0.3), Vector3(sx * 2.75, 0.3, 0.6), horn)
		for j in 4:
			wk.box(Vector3(0.08, 0.08, 3.4 - j * 0.5), Vector3(sx * (1.5 + j * 1.25), 0.25, -0.9 + j * 0.15), horn, Vector3(0, sx * (20 - j * 12), 0))
		wk.box(Vector3(5.2, 0.05, 3.2), Vector3(sx * 2.8, 0.2, -0.8), membrane)
		var wing := MeshInstance3D.new()
		wing.mesh = wk.build()
		wing.material_override = mat
		pivot.add_child(wing)
		var tw := pivot.create_tween().set_loops()
		tw.tween_property(pivot, "rotation:z", sx * -0.7, 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_property(pivot, "rotation:z", sx * 0.45, 0.35).set_trans(Tween.TRANS_SINE)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 1.0, 0.9)
	l.light_energy = 2.0
	l.omni_range = 12.0
	root.add_child(l)
	return root


static func elder_dragon(b: Node, z: float, dmg: float, radius: float) -> void:
	var dragon := dragon_model()
	b.add_child(dragon)
	var start := Vector3(-55, 16, z - 6)
	var end := Vector3(55, 16, z + 6)
	dragon.global_position = start
	dragon.look_at(end, Vector3.UP)
	dragon.rotate_object_local(Vector3.UP, PI)
	dragon.scale = Vector3.ONE * 1.3
	var mouth := Node3D.new()
	mouth.position = Vector3(0, 1.6, 6.2)
	dragon.add_child(mouth)
	var jet: GPUParticles3D = b.fx.fire_jet(mouth, Color(0.3, 1.0, 0.8), 1.3)
	jet.emitting = false
	b.get_tree().create_timer(0.7, false).timeout.connect(func():
		if is_instance_valid(jet):
			jet.emitting = true)
	b.get_tree().create_timer(2.5, false).timeout.connect(func():
		if is_instance_valid(jet):
			jet.emitting = false)
	var tw := dragon.create_tween()
	tw.tween_property(dragon, "global_position", end, 3.2).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(dragon.queue_free)
	b.banner_world("ELDER DRAGON!", Color(0.4, 1.0, 0.9))
	# breath: a stream of fire bursts beneath the flight path across the battlefield
	for i in 18:
		var t := 0.8 + i * 0.09
		b.get_tree().create_timer(t, false).timeout.connect(func():
			if not is_instance_valid(dragon):
				return
			var head := dragon.global_position
			var ground := Vector3(clampf(head.x, -16, 16), 0, head.z + randf_range(-2, 2))
			ground.y = b.world.height_at(ground.x, ground.z)
			if absf(head.x) > 18.0:
				return
			b.projectiles.fire("dragonfire", head + Vector3(0, -1, 0), null, 40.0, 0.0, func(hit: Vector3, _t):
				b.fx.explosion(hit, radius, Color(0.3, 1.0, 0.8))
				b.fx.decal("scorch", hit, radius * 2.2, Color(0.6, 1.0, 0.9, 0.85), 6.0, 0.8)
				for e in b.enemies.enemies_in_radius(hit, radius):
					b.enemies.damage(e, dmg, "fire", true, "ability")
					b.enemies.apply_burn(e, dmg * 0.3, 4.0), ground))
