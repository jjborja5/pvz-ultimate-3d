class_name Hero
extends Node3D
## A deployed hero standing on a castle wall post. Uses a fully rigged and animated
## CC0 KayKit character (AnimationPlayer), re-equipped and recoloured per hero/skin.

signal ability_cast(hero: Hero)

const SCALE := 2.4

var id := ""
var def: Dictionary
var stats: Dictionary
var battle: Node
var enemies: EnemyManager
var projectiles: ProjectileSystem
var fx: FX
var ability_cd := 0.0
var cooldown := 0.0
var kills := 0
var xp_earned := 0

var _model: Node3D
var _anim: AnimationPlayer
var _target: EnemyManager.Enemy
var _retarget := 0.0
var _busy := 0.0
var _ring: MeshInstance3D


func setup(p_id: String, p_battle: Node) -> void:
	id = p_id
	def = GameData.HEROES[id]
	battle = p_battle
	enemies = battle.enemies
	projectiles = battle.projectiles
	fx = battle.fx
	stats = HeroStats.compute(id)
	_build_model()
	ability_cd = 3.0


func _build_model() -> void:
	_model = Assets.instance("characters/%s.glb" % def["model"])
	add_child(_model)
	var sc: Vector3 = def.get("scale", Vector3.ONE)
	_model.scale = sc * SCALE
	_model.rotation.y = PI   # face the enemy (-Z)
	var keep: Array = def["keep"]
	var skin_i := int(GameState.heroes[id].get("skin", 0))
	var skin: Dictionary = GameData.SKINS[skin_i]
	var tint: Color = def["tint"]
	var amount: float = def["tint_amount"]
	if float(skin["amount"]) >= 0.0:
		tint = skin["tint"]
		amount = skin["amount"]
	var mat: ShaderMaterial = null
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null and not keep.has(String(mi.name)):
			mi.visible = false
			continue
		if mat == null:
			var base := mi.mesh.surface_get_material(0) as BaseMaterial3D
			mat = ShaderMaterial.new()
			mat.shader = load("res://shaders/unit_tex.gdshader")
			mat.set_shader_parameter("atlas", base.albedo_texture if base else null)
			mat.set_shader_parameter("tint", tint)
			mat.set_shader_parameter("tint_amount", amount)
			mat.set_shader_parameter("emissive_body", skin["glow"])
			mat.set_shader_parameter("rim_strength", 0.45)
		mi.material_override = mat
	_anim = _model.find_child("AnimationPlayer", true, false)
	_play(def["anims"]["idle"], true)
	# glowing hero ring + nameplate
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.75
	t.outer_radius = 0.95
	t.rings = 32
	t.ring_segments = 4
	_ring.mesh = t
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = def["color"]
	rm.emission_enabled = true
	rm.emission = def["color"]
	rm.emission_energy_multiplier = 2.0
	_ring.material_override = rm
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.08
	add_child(_ring)
	var l := Label3D.new()
	l.text = "%s  Lv %d" % [String(def["class"]), stats["level"]]
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 56
	l.outline_size = 10
	l.pixel_size = 0.01
	l.modulate = def["color"].lightened(0.3)
	l.position.y = 6.2
	l.no_depth_test = true
	add_child(l)


func _play(anim: String, loop := false) -> void:
	if _anim == null or not _anim.has_animation(anim):
		return
	var a := _anim.get_animation(anim)
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_anim.play(anim, 0.15)


func ability_ready_fraction() -> float:
	if GameState.is_god("no_cooldowns"):
		return 1.0
	var cd := cooldown_total()
	return 1.0 - clampf(ability_cd / cd, 0.0, 1.0)


func cooldown_total() -> float:
	return float(stats["cooldown"]) * (1.0 - battle.mod("ability_cd"))


func can_cast() -> bool:
	return GameState.is_god("no_cooldowns") or ability_cd <= 0.0


func celebrate(duration := 2.5) -> void:
	## Victory / wave-clear celebration.
	_play("Cheer", true)
	_busy = duration


func cast_ability() -> bool:
	if not can_cast():
		return false
	ability_cd = 0.0 if GameState.is_god("no_cooldowns") else cooldown_total()
	_play(def["anims"]["cast"])
	_busy = 1.2
	fx.flash_light(global_position + Vector3(0, 3, 0), def["color"], 6.0, 12.0, 0.6)
	fx.shockwave(global_position, 3.0, Color(def["color"], 0.9))
	HeroAbilities.cast(self, def["ability"]["id"])
	ability_cast.emit(self)
	if stats["effects"].has("holy_boost"):
		battle.castle.heal(battle.castle.max_hp * 0.05)
	return true


func ability_damage() -> float:
	return float(stats["ability_damage"]) * (1.0 + battle.mod("hero_dmg"))


func muzzle() -> Vector3:
	return global_position + Vector3(0, 2.6, -0.6)


func _process(delta: float) -> void:
	ability_cd = maxf(0.0, ability_cd - delta)
	_ring.rotation.y += delta * 1.5
	if _busy > 0.0:
		_busy -= delta
		if _busy <= 0.0:
			_play(def["anims"]["idle"], true)
	var rate: float = stats["rate"] * (1.0 + battle.mod("hero_aspd")) * GameState.god_value("attack_speed", 1.0)
	cooldown -= delta * rate
	_retarget -= delta
	var rng: float = stats["range"]
	var focus: EnemyManager.Enemy = battle.focus_target
	if focus != null and focus.alive and _dist(focus) <= rng:
		_target = focus
	elif _retarget <= 0.0 or _target == null or not _target.alive:
		_target = enemies.find_target(global_position, rng)
		_retarget = 0.3
	if _target == null:
		return
	var d := _target.pos - global_position
	_model.rotation.y = lerp_angle(_model.rotation.y, atan2(d.x, d.z), minf(1.0, delta * 8.0))
	if cooldown <= 0.0:
		cooldown = 1.0
		_attack(_target)


func _dist(e: EnemyManager.Enemy) -> float:
	return Vector2(e.pos.x - global_position.x, e.pos.z - global_position.z).length()


func _damage_value() -> float:
	var dmg: float = stats["damage"] * (1.0 + battle.mod("hero_dmg"))
	if randf() < float(stats["crit"]):
		dmg *= 2.0
	return dmg


func _hit(e: EnemyManager.Enemy, dmg: float, el: String) -> void:
	if e == null or not e.alive:
		return
	var effects: Array = stats["effects"]
	if effects.has("void"):
		dmg += e.max_hp * 0.02 * (0.25 if e.boss else 1.0)
	enemies.damage(e, dmg, el, true, "hero:" + id)
	if effects.has("ignite"):
		enemies.apply_burn(e, dmg * 0.3, 3.0)
	if effects.has("chill"):
		enemies.apply_slow(e, 0.3, 2.0)
	if not e.alive:
		kills += 1


func _attack(target: EnemyManager.Enemy) -> void:
	_play(def["anims"]["attack"])
	_busy = 0.6
	var a: Dictionary = def["attack"]
	var kind: String = a["kind"]
	var el: String = a["element"]
	var dmg := _damage_value()
	var effects: Array = stats["effects"]
	var targets: Array = [target]
	var extra := int(a.get("multishot", 1)) - 1 + (2 if effects.has("multishot") else 0) + (2 if effects.has("chain") and kind != "chain" else 0)
	for i in extra:
		var t2 := enemies.find_target(global_position, stats["range"], targets)
		if t2 == null:
			break
		targets.append(t2)
	var snd := {"arrow": "arrow_shoot", "holy": "sword_slash", "bomb": "fire_whoosh", "chain": "chain_zap"}
	Audio.sfx(snd.get(kind, "magic_cast"), -9.0)
	match kind:
		"chain":
			var chain: Array = [target]
			var pts: Array = [muzzle(), enemies.enemy_center(target)]
			var last := target
			for i in int(a.get("chains", 4)) + int(battle.mod("chains")) + (2 if effects.has("chain") else 0):
				var nxt := enemies.find_nearest(last.pos, 7.0, chain)
				if nxt == null:
					break
				chain.append(nxt)
				pts.append(enemies.enemy_center(nxt))
				last = nxt
			fx.lightning(pts, Color(0.7, 0.6, 1.0), 0.4)
			for e in chain:
				_hit(e, dmg, el)
		_:
			for t in targets:
				_shoot(kind, t, dmg, el, a)


func _shoot(kind: String, t: EnemyManager.Enemy, dmg: float, el: String, a: Dictionary) -> void:
	var speed := {"arrow": 42.0, "fire": 22.0, "ice": 26.0, "holy": 28.0, "thorn": 30.0, "soul": 24.0, "bomb": 20.0, "dragonfire": 26.0}
	var arc := {"arrow": 1.0, "fire": 2.0, "ice": 1.0, "holy": 1.5, "thorn": 0.8, "soul": 1.2, "bomb": 6.0, "dragonfire": 2.0}
	var splash: float = a.get("splash", 0.0)
	var slow: float = a.get("slow", 0.0)
	var poison: float = a.get("poison", 0.0)
	var col := Color(def["color"])
	var cb := func(p: Vector3, target):
		if splash > 0.0:
			if kind == "ice":
				fx.frost_burst(p, splash)
			else:
				fx.explosion(p, splash, col, kind == "bomb")
			for e in enemies.enemies_in_radius(p, splash):
				_hit(e, dmg, el)
				if slow > 0.0:
					enemies.apply_slow(e, slow, 2.5)
				if kind == "fire" or kind == "dragonfire":
					enemies.apply_burn(e, dmg * 0.25, 3.0)
			if kind == "bomb":
				battle.shake(0.2)
		else:
			var e2: EnemyManager.Enemy = target if target != null and target.alive else enemies.find_nearest(p, 1.5)
			if e2:
				_hit(e2, dmg, el)
				if poison > 0.0:
					enemies.apply_poison(e2, poison * (1.0 + battle.mod("el_nature")), 4.0)
			fx.hit_spark(p, col)
	projectiles.fire(kind, muzzle(), t, speed.get(kind, 25.0), arc.get(kind, 1.0), cb)
