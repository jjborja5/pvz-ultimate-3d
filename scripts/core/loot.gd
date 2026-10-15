class_name Loot
extends RefCounted
## Equipment generation, naming and stat math.
## Item dictionary: {uid, slot, rarity (0-4), level, base, name, stats{...}, legendary?, effect?}

const PREFIXES := ["Sturdy", "Keen", "Ancient", "Gleaming", "Runed", "Savage", "Arcane", "Blessed", "Grim", "Royal"]
const SUFFIXES := ["of Might", "of Swiftness", "of the Fox", "of Embers", "of Frost", "of Storms", "of the Bear",
	"of Valor", "of the Owl", "of Ruin"]


static func roll_rarity(luck: float, min_rarity := 0) -> int:
	var r := randf()
	var thresholds := [0.0, 0.45, 0.78, 0.94, 0.99]   # rare, epic, legendary, mythic cut-offs
	var rarity := 0
	for i in range(1, thresholds.size()):
		if r >= thresholds[i] - luck * (0.25 if i < 3 else 0.12):
			rarity = i
	return maxi(rarity, min_rarity)


static func roll_item(luck := 0.0, min_rarity := 0, slot := "") -> Dictionary:
	if slot == "":
		slot = GameData.SLOTS[randi() % GameData.SLOTS.size()]
	var rarity := roll_rarity(luck, min_rarity)
	if rarity >= 3 and randf() < 0.6:
		# named legendary of a matching slot when possible
		var pool: Array = []
		for id in GameData.LEGENDARIES:
			if GameData.LEGENDARIES[id]["slot"] == slot and int(GameData.LEGENDARIES[id]["rarity"]) <= rarity:
				pool.append(id)
		if not pool.is_empty():
			return make_legendary(pool[randi() % pool.size()], 1)
	var bases: Array = GameData.ITEM_BASES[slot]
	var base: Dictionary = bases[randi() % bases.size()]
	var stats: Dictionary = (base["stats"] as Dictionary).duplicate()
	# rarer items roll a bonus stat
	if rarity >= 1:
		var extra: String = ["atk", "aspd", "crit", "power", "cdr", "hp"][randi() % 6]
		stats[extra] = float(stats.get(extra, 0.0)) + 2.0 + rarity
	var name: String = base["name"]
	if rarity >= 1:
		name = PREFIXES[randi() % PREFIXES.size()] + " " + name
	if rarity >= 2:
		name += " " + SUFFIXES[randi() % SUFFIXES.size()]
	return {"slot": slot, "rarity": rarity, "level": 1, "base": base["name"], "name": name, "stats": stats}


static func make_legendary(id: String, level := 1) -> Dictionary:
	var d: Dictionary = GameData.LEGENDARIES[id]
	return {"slot": d["slot"], "rarity": int(d["rarity"]), "level": level, "base": d["name"], "name": d["name"],
		"stats": (d["stats"] as Dictionary).duplicate(), "legendary": id, "effect": d["effect"]}


static func item_stats(item: Dictionary) -> Dictionary:
	## Final stats after rarity multiplier and level scaling.
	var out := {}
	if item.is_empty():
		return out
	var mult := float(GameData.RARITIES[int(item["rarity"])]["mult"]) * (1.0 + 0.08 * (GameState.item_level(item) - 1))
	for k in item["stats"]:
		out[k] = float(item["stats"][k]) * mult
	return out


static func rarity_color(item: Dictionary) -> Color:
	return GameData.RARITIES[int(item.get("rarity", 0))]["color"]


static func rarity_name(item: Dictionary) -> String:
	return GameData.RARITIES[int(item.get("rarity", 0))]["name"]


static func stats_text(item: Dictionary) -> String:
	var names := {"atk": "Attack", "hp": "Castle HP", "aspd": "Attack Speed", "crit": "Crit", "power": "Ability Power", "cdr": "Cooldown"}
	var parts: Array = []
	var st := item_stats(item)
	for k in st:
		parts.append("+%d%% %s" % [roundi(st[k]), names.get(k, k)])
	return "  ".join(parts)


static func effect_desc(item: Dictionary) -> String:
	if item.has("legendary"):
		return GameData.LEGENDARIES[item["legendary"]]["desc"]
	return ""
