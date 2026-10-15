class_name LootDrops
extends Node3D
## Visual loot: gold coins that fly to the castle on kills, and treasure chests dropped by
## bosses / elites (and rarely regular enemies) that burst open to reveal equipment.

signal item_found(item: Dictionary)

const MAX_COINS := 48

var battle: Node
var fx: FX
var _coins := 0


func setup(p_battle: Node) -> void:
	battle = p_battle
	fx = battle.fx


func on_kill(e: EnemyManager.Enemy) -> void:
	if _coins < MAX_COINS and (e.boss or e.elite != "" or randf() < 0.35):
		var n := 12 if e.boss else (4 if e.elite != "" else 1)
		for i in n:
			_coin(e.pos + Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)))
	var luck := GameState.upgrade_value("loot_luck") + (0.15 if GameState.is_god("enabled") else 0.0)
	var chance: float = 0.006 * (1.0 + battle.mod("loot"))
	if e.boss:
		_chest(e.pos, Loot.roll_item(luck + 0.3, 3), true)
	elif e.elite != "":
		if randf() < 0.35 * (1.0 + battle.mod("loot")):
			_chest(e.pos, Loot.roll_item(luck + 0.1, 1), false)
	elif randf() < chance:
		_chest(e.pos, Loot.roll_item(luck), false)


func _coin(from: Vector3) -> void:
	_coins += 1
	var c := Assets.place(self, "dungeon/coin.glb", from, 2.2, randf() * TAU)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var target := Vector3(randf_range(-4, 4), 5.0, -1.0)
	var mid := (from + target) * 0.5 + Vector3(0, 6, 0)
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(t: float):
		var a := from.lerp(mid, t)
		var b := mid.lerp(target, t)
		c.global_position = a.lerp(b, t), 0.0, 1.0, randf_range(0.7, 1.1)).set_delay(randf() * 0.2)
	tw.tween_property(c, "rotation:y", c.rotation.y + 12.0, 1.2)
	tw.chain().tween_callback(func():
		_coins -= 1
		c.queue_free())


func _chest(at: Vector3, item: Dictionary, big: bool) -> void:
	var path := "dungeon/chest_gold.glb" if big or int(item["rarity"]) >= 3 else "dungeon/chest.glb"
	var p := Vector3(clampf(at.x, -13, 13), battle.world.height_at(at.x, at.z), at.z)
	var chest := Assets.place(self, path, p + Vector3(0, 8, 0), 1.6 if big else 1.1, randf_range(-0.4, 0.4) + PI)
	var col := Loot.rarity_color(item)
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.9
	cyl.height = 14.0
	beam.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, 0.0)
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beam.global_position = p + Vector3(0, 7, 0)
	var tw := chest.create_tween()
	tw.tween_property(chest, "global_position", p, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bm, "albedo_color:a", 0.5, 0.4)
	tw.tween_interval(0.6)
	tw.tween_callback(func():
		fx.explosion(p + Vector3(0, 1, 0), 2.5, col)
		fx.flash_light(p + Vector3(0, 2, 0), col, 5.0, 10.0, 0.8)
		var item_saved := GameState.add_item(item)
		battle.run.loot_found.append(item_saved)
		item_found.emit(item_saved))
	tw.tween_interval(1.4)
	tw.tween_property(chest, "scale", Vector3.ZERO, 0.3)
	tw.parallel().tween_property(bm, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(func():
		chest.queue_free()
		beam.queue_free())
