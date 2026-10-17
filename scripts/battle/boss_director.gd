class_name BossDirector
extends Node
## Cinematic boss encounters: camera fly-in with letterbox + title card and slow motion,
## then per-boss abilities (ground slam, summoning + soul shield, war rally) and enrage.

var battle: Node
var enemies: EnemyManager
var fx: FX
var bosses: Array = []          # [{e, slam_t, summon_t, shield_t, rally_t, enraged}]
var cinematic_t := 0.0
var cinematic_target: EnemyManager.Enemy


func setup(p_battle: Node) -> void:
	battle = p_battle
	enemies = battle.enemies
	fx = battle.fx


func on_boss(e: EnemyManager.Enemy) -> void:
	bosses.append({"e": e, "slam_t": 8.0, "summon_t": 6.0, "shield_t": 12.0, "rally_t": 7.0, "enraged": false})
	Audio.sfx("boss_roar", 2.0, 0.02, 0.0)
	Audio.play_music("boss", 0.8)
	e.special_t = 1.6
	if cinematic_t <= 0.0 and not GameState.is_god("auto_complete_waves"):
		cinematic_t = 2.6
		cinematic_target = e
		var def: Dictionary = GameData.ENEMIES[e.type]
		var name: String = def["name"]
		battle.hud.boss_intro(name.get_slice(",", 0), name.get_slice(",", 1).strip_edges() if name.contains(",") else "")
		fx.flash_light(e.pos + Vector3(0, 6, 0), def.get("glow", Color(1, 0.3, 0.1)), 10.0, 40.0, 2.0)
		battle.shake(0.6)


func is_cinematic() -> bool:
	return cinematic_t > 0.0 and cinematic_target != null and cinematic_target.alive


func _process(delta: float) -> void:
	if cinematic_t > 0.0:
		cinematic_t -= delta / maxf(Engine.time_scale, 0.01)   # real-time duration
		if cinematic_t <= 0.0:
			battle.hud.boss_intro_end()
	for b in bosses.duplicate():
		var e: EnemyManager.Enemy = b["e"]
		if not e.alive:
			bosses.erase(b)
			continue
		var ability: String = GameData.ENEMIES[e.type].get("ability", "")
		if not b["enraged"] and e.hp < e.max_hp * 0.5:
			b["enraged"] = true
			e.speed *= 1.4
			e.attack_rate *= 1.5
			Audio.sfx("boss_roar", 3.0, 0.0, 0.0)
			fx.explosion(e.pos + Vector3(0, 3, 0), 5.0, Color(1.0, 0.2, 0.1), true)
			battle.hud.banner("ENRAGED!", Color(1, 0.3, 0.2))
			battle.shake(0.5)
		match ability:
			"slam":
				b["slam_t"] -= delta
				if b["slam_t"] <= 0.0:
					b["slam_t"] = 9.0 if not b["enraged"] else 6.0
					_slam(e)
			"summon":
				b["summon_t"] -= delta
				b["shield_t"] -= delta
				if b["summon_t"] <= 0.0:
					b["summon_t"] = 9.0
					_summon(e)
				if b["shield_t"] <= 0.0:
					b["shield_t"] = 14.0
					e.immune_t = 3.0
					Audio.sfx("shield_up", 0.0, 0.0, 0.0)
					fx.shockwave(e.pos, 4.0, Color(0.3, 0.9, 1.0, 0.8), 0.6)
					battle.hud.show_hint("Vael'Zhur raises a soul shield!")
			"rally":
				b["rally_t"] -= delta
				if b["rally_t"] <= 0.0:
					b["rally_t"] = 10.0
					e.special_t = 1.6
					for o in enemies.enemies_in_radius(e.pos, 16.0):
						o.haste_t = 4.0
					fx.shockwave(e.pos, 16.0, Color(1.0, 0.2, 0.15, 0.8), 0.8)
					fx.flash_light(e.pos + Vector3(0, 4, 0), Color(1, 0.2, 0.1), 6.0, 20.0, 0.8)
					battle.hud.show_hint("The Warlord rallies his troops!")


func _slam(e: EnemyManager.Enemy) -> void:
	Audio.sfx("boss_slam", 2.0, 0.03, 0.0)
	e.special_t = 1.6
	var r := 9.0
	fx.explosion(e.pos, r * 0.6, Color(0.75, 0.6, 0.45), true)
	fx.shockwave(e.pos, r, Color(1.0, 0.6, 0.3, 0.9), 0.5)
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
			fx.soul_puff(s.pos, Color(0.3, 1.0, 0.9))
	fx.shockwave(e.pos, 5.0, Color(0.3, 1.0, 0.9, 0.8), 0.6)
