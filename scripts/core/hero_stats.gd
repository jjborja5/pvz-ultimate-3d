class_name HeroStats
extends RefCounted
## Combines hero level, ability level, equipment and permanent upgrades into combat stats.


static func compute(hero_id: String) -> Dictionary:
	var def: Dictionary = GameData.HEROES[hero_id]
	var lvl := GameState.hero_level(hero_id)
	var alvl := GameState.ability_level(hero_id)
	var atk := 0.0
	var aspd := 0.0
	var crit := 5.0
	var power := 0.0
	var cdr := 0.0
	var hp := 0.0
	var effects: Array = []
	for slot in GameData.SLOTS:
		var it := GameState.equipped_item(hero_id, slot)
		if it.is_empty():
			continue
		var st := Loot.item_stats(it)
		atk += st.get("atk", 0.0)
		aspd += st.get("aspd", 0.0)
		crit += st.get("crit", 0.0)
		power += st.get("power", 0.0)
		cdr += st.get("cdr", 0.0)
		hp += st.get("hp", 0.0)
		if it.has("effect"):
			effects.append(it["effect"])
	var level_mult := 1.0 + 0.07 * (lvl - 1)
	var dmg_mult := level_mult * (1.0 + atk / 100.0) * (1.0 + GameState.upgrade_value("hero_damage"))
	var ability_mult := (1.0 + 0.15 * (alvl - 1)) * (1.0 + power / 100.0) * level_mult
	if effects.has("power"):
		ability_mult *= 1.5
	var cd_mult := clampf(1.0 - 0.03 * (alvl - 1) - cdr / 100.0 - (0.25 if effects.has("rebirth") else 0.0), 0.25, 1.0)
	var aspd_mult := (1.0 + aspd / 100.0) * (1.25 if effects.has("haste") else 1.0)
	var atk_def: Dictionary = def["attack"]
	return {
		"level": lvl, "ability_level": alvl,
		"damage": float(atk_def["damage"]) * dmg_mult,
		"rate": float(atk_def["rate"]) * aspd_mult,
		"range": float(atk_def["range"]),
		"crit": clampf(crit / 100.0, 0.0, 0.8),
		"ability_damage": float(def["ability"]["damage"]) * ability_mult,
		"cooldown": float(def["ability"]["cooldown"]) * cd_mult,
		"castle_hp": hp / 100.0,
		"effects": effects,
		"power": ability_mult,
	}


static func power_rating(hero_id: String) -> int:
	var s := compute(hero_id)
	return int(s["damage"] * s["rate"] * 10.0 + s["ability_damage"] * 2.0)
