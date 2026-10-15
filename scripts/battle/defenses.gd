class_name DefenseSystem
extends Node3D
## Buildable battlefield defenses: spike traps, blast barrels, frost runes (traps) and
## arcane barriers / stone walls (blockers that hold enemies until destroyed).
## Models: CC0 KayKit Dungeon + Medieval Hexagon pieces, plus procedural runes/fields.

signal changed

const MIN_SPACING := 3.2

class Defense:
	extends Node3D
	var type := ""
	var level := 1
	var x := 0.0
	var z := 0.0
	var half_width := 0.0
	var alive := true
	var hp := 1.0
	var max_hp := 1.0
	var regen := 0.0
	var timer := 0.0
	var armed := true
	var spent := 0
	var model: Node3D
	var bar: MeshInstance3D
	var bar_mat: ShaderMaterial
	var field_mat: ShaderMaterial
	var hit := 0.0

	func take_damage(d: float) -> void:
		hit = 1.0
		if GameState.is_god("invincible") or not alive:
			return
		hp -= d
		if hp <= 0.0:
			alive = false


var battle: Node
var enemies: EnemyManager
var fx: FX
var defenses: Array[Defense] = []


func setup(p_battle: Node) -> void:
	battle = p_battle
	enemies = battle.enemies
	fx = battle.fx


func stat(type: String, key: String, level: int) -> Variant:
	var v = GameData.DEFENSES[type][key]
	if v is Array:
		return v[clampi(level - 1, 0, v.size() - 1)]
	return v


func cost(type: String, level := 1) -> int:
	if battle.has_combo("war_economy"):
		return 0
	return int(stat(type, "cost", level))


func can_place(p: Vector3) -> bool:
	if absf(p.x) > WorldBuilder.FIELD_HALF - 0.8 or p.z > -6.0 or p.z < -78.0:
		return false
	for d in defenses:
		if Vector2(d.x - p.x, d.z - p.z).length() < MIN_SPACING:
			return false
	for pad in battle.castle.pads:
		var pp: Vector3 = pad["pos"]
		if pp.y < 1.0 and Vector2(pp.x - p.x, pp.z - p.z).length() < 2.6:
			return false
	return true


func place(type: String, p: Vector3, level := 1) -> Defense:
	var d := Defense.new()
	d.type = type
	d.level = level
	d.x = p.x
	d.z = p.z
	add_child(d)
	d.global_position = Vector3(p.x, battle.world.height_at(p.x, p.z), p.z)
	d.spent = cost(type, 1)
	_configure(d)
	defenses.append(d)
	if GameData.DEFENSES[type]["kind"] == "blocker":
		enemies.blockers.append(d)
	fx.shockwave(d.global_position, 2.5, Color(1, 0.85, 0.4, 0.8))
	fx.hit_spark(d.global_position + Vector3(0, 1, 0), Color(1, 0.9, 0.5))
	d.scale = Vector3(1, 0.1, 1)
	d.create_tween().tween_property(d, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	changed.emit()
	return d


func upgrade(d: Defense) -> void:
	if d.level >= GameData.DEFENSE_MAX_LEVEL:
		return
	d.level += 1
	_configure(d)
	fx.shockwave(d.global_position, 2.5, Color(1, 0.85, 0.3, 0.8))
	fx.flash_light(d.global_position + Vector3(0, 2, 0), Color(1, 0.85, 0.4), 3.0, 6.0, 0.4)
	changed.emit()


func remove(d: Defense, explode := false) -> void:
	if explode:
		fx.explosion(d.global_position + Vector3(0, 1, 0), 2.5, Color(0.8, 0.7, 0.55))
	d.alive = false
	enemies.blockers.erase(d)
	defenses.erase(d)
	d.queue_free()
	changed.emit()


func defense_at(p: Vector3, radius := 2.5) -> Defense:
	for d in defenses:
		if Vector2(d.x - p.x, d.z - p.z).length() < maxf(radius, d.half_width * 0.8):
			return d
	return null


func max_hp_for(type: String, level: int) -> float:
	var base: float = stat(type, "hp", level)
	return base * (1.0 + GameState.upgrade_value("defense_hp") + battle.mod("fortify"))


func _configure(d: Defense) -> void:
	if d.model:
		d.model.queue_free()
	d.model = Node3D.new()
	d.add_child(d.model)
	var lv := d.level
	match d.type:
		"spike_trap":
			var frame := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 2.2
			cyl.bottom_radius = 2.4
			cyl.height = 0.2
			cyl.radial_segments = 8
			frame.mesh = cyl
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color(0.25, 0.22, 0.2)
			fm.metallic = 0.6
			fm.roughness = 0.5
			fm.emission_enabled = lv >= 2
			fm.emission = Color(1.0, 0.25, 0.1)
			fm.emission_energy_multiplier = 0.3 * lv
			frame.material_override = fm
			frame.position.y = 0.05
			d.model.add_child(frame)
			var spikes := Assets.place(d.model, "dungeon/floor_tile_big_spikes.glb", Vector3(0, -1.9, 0), Vector3(0.95 + lv * 0.08, 1.0, 0.95 + lv * 0.08), PI * 0.25,
				Assets.tinted("dungeon/floor_tile_big_spikes.glb", Color(1.0, 0.4, 0.3), 0.5) if lv >= 3 else null)
			spikes.name = "Spikes"
		"barrel_trap":
			var path := "dungeon/barrel_large.glb" if lv == 1 else "dungeon/barrel_large_decorated.glb"
			var b := Assets.place(d.model, path, Vector3.ZERO, 0.75 + lv * 0.08, randf() * TAU,
				Assets.tinted(path, Color(1.0, 0.4, 0.2), 0.35, 0.0, 0.6, 0.15) if lv >= 3 else null)
			b.name = "Barrel"
			if lv >= 2:
				Assets.place(d.model, "dungeon/barrel_small_stack.glb", Vector3(1.1, 0, 0.4), 0.6, 1.0)
			var fuse := OmniLight3D.new()
			fuse.light_color = Color(1.0, 0.5, 0.1)
			fuse.light_energy = 0.6 + lv * 0.4
			fuse.omni_range = 3.0
			fuse.position.y = 2.0
			d.model.add_child(fuse)
		"frost_rune":
			var k := MeshKit.new(900 + lv)
			k.cyl(1.6 + lv * 0.25, 1.6 + lv * 0.25, 0.06, Vector3(0, 0.06, 0), Color(1, 1, 1), Vector3.ZERO, MeshKit.PART_GLOW, 24)
			k.cyl(1.4 + lv * 0.25, 1.4 + lv * 0.25, 0.07, Vector3(0, 0.07, 0), Color(0.15, 0.25, 0.4), Vector3.ZERO, MeshKit.PART_BODY, 24)
			for i in 6 + lv * 2:
				var a := i * TAU / (6 + lv * 2)
				k.box(Vector3(0.12, 0.08, 0.7), Vector3(cos(a) * (1.0 + lv * 0.2), 0.1, sin(a) * (1.0 + lv * 0.2)), Color(1, 1, 1), Vector3(0, -rad_to_deg(a), 0), MeshKit.PART_GLOW)
			for i in lv:
				k.cone(0.18, 0.9 + i * 0.3, Vector3(cos(i * 2.1) * 0.5, 0.45, sin(i * 2.1) * 0.5), Color(1, 1, 1), Vector3.ZERO, MeshKit.PART_GLOW, 5)
			var rune := MeshInstance3D.new()
			rune.mesh = k.build()
			var rm := ShaderMaterial.new()
			rm.shader = load("res://shaders/prop.gdshader")
			rm.set_shader_parameter("glow_color", Color(0.4, 0.8, 1.0))
			rm.set_shader_parameter("glow_strength", 2.0 + lv)
			rm.set_shader_parameter("pulse_speed", 2.0)
			rune.material_override = rm
			rune.name = "Rune"
			d.model.add_child(rune)
		"barrier":
			var w: float = stat(d.type, "width", lv)
			d.half_width = w * 0.5
			for side in [-1, 1]:
				Assets.place(d.model, "dungeon/barrier_column.glb", Vector3(side * w * 0.5, 0, 0), 1.0 + lv * 0.1)
			Assets.place(d.model, "dungeon/barrier_half.glb", Vector3(0, 0, 0.3), Vector3(w / 4.0, 1.0, 1.0))
			var field := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(w, 3.4 + lv * 0.4)
			field.mesh = q
			d.field_mat = ShaderMaterial.new()
			d.field_mat.shader = load("res://shaders/force_field.gdshader")
			var col: Color = [Color(0.3, 0.7, 1.0), Color(0.6, 0.45, 1.0), Color(1.0, 0.8, 0.3)][lv - 1]
			d.field_mat.set_shader_parameter("color", col)
			field.material_override = d.field_mat
			field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			field.position = Vector3(0, q.size.y * 0.5 + 0.2, -0.1)
			field.rotation.y = PI
			d.model.add_child(field)
		"wall":
			var w2: float = stat(d.type, "width", lv)
			d.half_width = w2 * 0.5
			if lv == 1:
				Assets.place(d.model, "hexagon/fence_stone_straight.gltf", Vector3.ZERO, Vector3(3.0, 3.2, 3.0))
			else:
				Assets.place(d.model, "hexagon/wall_straight.gltf", Vector3.ZERO, Vector3(3.0, 2.2 + lv * 0.4, 3.0))
			if lv >= 3:
				for side in [-1, 1]:
					Assets.place(d.model, "hexagon/flag_blue.gltf", Vector3(side * 2.4, 2.2 + lv * 0.4, 0), 5.0, PI * 0.5)
	if GameData.DEFENSES[d.type]["kind"] == "blocker":
		var new_max := max_hp_for(d.type, lv)
		d.hp = new_max if d.hp <= 1.0 or d.max_hp <= 1.0 else d.hp + (new_max - d.max_hp)
		d.max_hp = new_max
		d.regen = stat(d.type, "regen", lv)
		d.bar = MeshInstance3D.new()
		var bq := QuadMesh.new()
		bq.size = Vector2(maxf(2.0 * d.half_width * 0.6, 2.0), 0.28)
		d.bar.mesh = bq
		d.bar_mat = ShaderMaterial.new()
		d.bar_mat.shader = load("res://shaders/bar.gdshader")
		d.bar.material_override = d.bar_mat
		d.bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.bar.position.y = 4.6 + lv * 0.4
		d.model.add_child(d.bar)


func _process(delta: float) -> void:
	var trap_mult: float = 1.0 + battle.mod("trap") + GameState.upgrade_value("trap_damage")
	for d in defenses.duplicate():
		if not d.alive:
			remove(d, true)
			continue
		match d.type:
			"spike_trap":
				d.timer -= delta
				if d.timer <= 0.0:
					var r: float = stat(d.type, "radius", d.level)
					var hits := enemies.enemies_in_radius(d.global_position, r)
					if not hits.is_empty():
						d.timer = float(stat(d.type, "interval", d.level))
						var dmg: float = float(stat(d.type, "damage", d.level)) * trap_mult
						for e in hits:
							enemies.damage(e, dmg, "physical", false, "trap")
						_thrust(d)
			"barrel_trap":
				if d.armed:
					if not enemies.enemies_in_radius(d.global_position, 2.2).is_empty():
						d.armed = false
						d.timer = float(stat(d.type, "rearm", d.level))
						var r2: float = stat(d.type, "radius", d.level)
						fx.explosion(d.global_position + Vector3(0, 0.8, 0), r2, Color(1.0, 0.5, 0.15), true)
						enemies.damage_radius(d.global_position, r2, float(stat(d.type, "damage", d.level)) * trap_mult, "fire", true, "trap")
						for e in enemies.enemies_in_radius(d.global_position, r2):
							enemies.apply_burn(e, 20.0 * d.level, 3.0)
						battle.shake(0.35)
						d.model.visible = false
				else:
					d.timer -= delta
					if d.timer <= 0.0:
						d.armed = true
						d.model.visible = true
						d.model.scale = Vector3(0.2, 0.2, 0.2)
						d.model.create_tween().tween_property(d.model, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			"frost_rune":
				var rune: Node3D = d.model.get_node_or_null("Rune")
				if rune:
					rune.rotation.y += delta * 0.6
				d.timer -= delta
				if d.timer <= 0.0:
					d.timer = 0.5
					var r3: float = stat(d.type, "radius", d.level)
					for e in enemies.enemies_in_radius(d.global_position, r3):
						enemies.damage(e, float(stat(d.type, "damage", d.level)) * trap_mult * 0.5, "ice", false, "trap")
						enemies.apply_slow(e, float(stat(d.type, "slow", d.level)), 1.0)
			_:
				if d.regen > 0.0:
					d.hp = minf(d.max_hp, d.hp + d.regen * delta)
				if d.bar_mat:
					d.bar_mat.set_shader_parameter("ratio", d.hp / d.max_hp)
					d.bar.visible = d.hp < d.max_hp
				if d.field_mat:
					d.hit = maxf(0.0, d.hit - delta * 3.0)
					d.field_mat.set_shader_parameter("hit", d.hit)


func _thrust(d: Defense) -> void:
	var spikes: Node3D = d.model.get_node_or_null("Spikes")
	if spikes == null:
		return
	var tw := spikes.create_tween()
	tw.tween_property(spikes, "position:y", -0.45, 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_property(spikes, "position:y", -1.9, 0.3)
	fx.hit_spark(d.global_position + Vector3(0, 0.8, 0), Color(0.9, 0.3, 0.2))


func clear() -> void:
	for d in defenses.duplicate():
		remove(d)
