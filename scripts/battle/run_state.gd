class_name RunState
extends RefCounted
## Roguelike state for a single battle: picked blessings, stacked modifiers and combos.

var picks: Array[String] = []
var combos: Array[String] = []
var mods := {}
var tags := {}
var loot_found: Array = []
var gold_earned := 0
var gems_earned := 0
var materials_earned := 0


func mod(key: String) -> float:
	return float(mods.get(key, 0.0))


func has_combo(id: String) -> bool:
	return combos.has(id)


func offer(count := 3) -> Array[String]:
	## Random distinct blessings, favouring ones not yet picked.
	var pool: Array = GameData.BLESSINGS.keys()
	pool.shuffle()
	pool.sort_custom(func(a, b): return picks.count(a) < picks.count(b))
	var out: Array[String] = []
	for id in pool:
		if out.size() >= count:
			break
		out.append(id)
	return out


func add_blessing(id: String) -> Array[String]:
	## Applies a blessing; returns any combos it newly unlocked.
	var def: Dictionary = GameData.BLESSINGS[id]
	picks.append(id)
	for k in def["mods"]:
		mods[k] = float(mods.get(k, 0.0)) + float(def["mods"][k])
	for t in def["tags"]:
		tags[t] = int(tags.get(t, 0)) + 1
	var unlocked: Array[String] = []
	for cid in GameData.COMBOS:
		if combos.has(cid):
			continue
		var ok := true
		for need in GameData.COMBOS[cid]["needs"]:
			if not tags.has(need):
				ok = false
				break
		if ok:
			combos.append(cid)
			unlocked.append(cid)
	return unlocked
