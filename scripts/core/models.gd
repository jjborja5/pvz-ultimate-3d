class_name Models
extends RefCounted
## Procedural low-poly stylised model library. All models are generated in code
## (original art, no external assets) and merged into single meshes.
## Characters face +Z, stand on y = 0, hips at 0.8, shoulders at 1.45.



static var _cache := {}


static func get_enemy(type: String) -> ArrayMesh:
	var key := "enemy_" + type
	if _cache.has(key):
		return _cache[key]
	var m: ArrayMesh
	match type:
		"goblin": m = _goblin()
		"skeleton": m = _skeleton()
		"orc": m = _orc()
		"demon": m = _demon()
		"brute": m = _brute()
		"boss_molten": m = _boss_molten()
		"boss_lich": m = _boss_lich()
		_: m = _orc()
	_cache[key] = m
	return m


static func enemy_glow(type: String) -> Color:
	match type:
		"goblin": return Color(1.0, 0.9, 0.2)
		"skeleton": return Color(1.0, 0.15, 0.1)
		"orc": return Color(1.0, 0.4, 0.1)
		"demon": return Color(1.0, 0.45, 0.05)
		"brute": return Color(0.9, 0.7, 0.2)
		"boss_molten": return Color(1.0, 0.38, 0.02)
		"boss_lich": return Color(0.25, 1.0, 0.85)
	return Color(1, 0.5, 0.1)


# ------------------------------------------------------------------ humanoid parts

static func _legs(k: MeshKit, col: Color, boot: Color, width := 0.18, thick := 0.2) -> void:
	for side in [-1, 1]:
		var part := MeshKit.PART_LEG_L if side < 0 else MeshKit.PART_LEG_R
		k.box(Vector3(thick, 0.7, thick + 0.02), Vector3(side * width, 0.45, 0), col, Vector3.ZERO, part)
		k.box(Vector3(thick + 0.06, 0.16, thick + 0.18), Vector3(side * width, 0.08, 0.05), boot, Vector3.ZERO, part)


static func _arms(k: MeshKit, col: Color, hand: Color, spread := 0.42, thick := 0.17) -> void:
	k.box(Vector3(thick, 0.55, thick), Vector3(spread, 1.18, 0), col, Vector3(0, 0, 8), MeshKit.PART_ARM_W)
	k.sphere(0.1, Vector3(spread + 0.04, 0.88, 0.02), hand, Vector3.ONE, MeshKit.PART_ARM_W, 8)
	k.box(Vector3(thick, 0.55, thick), Vector3(-spread, 1.18, 0), col, Vector3(0, 0, -8), MeshKit.PART_ARM_O)
	k.sphere(0.1, Vector3(-spread - 0.04, 0.88, 0.02), hand, Vector3.ONE, MeshKit.PART_ARM_O, 8)


static func _eyes(k: MeshKit, y: float, z: float, spread := 0.09, r := 0.045) -> void:
	k.sphere(r, Vector3(spread, y, z), Color(1, 1, 1), Vector3.ONE, MeshKit.PART_GLOW, 6)
	k.sphere(r, Vector3(-spread, y, z), Color(1, 1, 1), Vector3.ONE, MeshKit.PART_GLOW, 6)


static func _goblin() -> ArrayMesh:
	var k := MeshKit.new(11)
	var skin := Color(0.42, 0.7, 0.25)
	var leather := Color(0.45, 0.3, 0.18)
	_legs(k, leather.darkened(0.2), Color(0.25, 0.17, 0.1), 0.15, 0.16)
	k.box(Vector3(0.52, 0.6, 0.36), Vector3(0, 1.08, 0), leather)
	k.box(Vector3(0.56, 0.1, 0.4), Vector3(0, 0.84, 0), Color(0.3, 0.2, 0.1))  # belt
	_arms(k, skin, skin.darkened(0.1), 0.36, 0.13)
	# dagger
	k.box(Vector3(0.05, 0.05, 0.5), Vector3(0.4, 0.85, 0.3), Color(0.8, 0.82, 0.85), Vector3.ZERO, MeshKit.PART_ARM_W)
	k.box(Vector3(0.16, 0.05, 0.05), Vector3(0.4, 0.85, 0.06), Color(0.5, 0.35, 0.1), Vector3.ZERO, MeshKit.PART_ARM_W)
	# head with big ears and nose
	k.sphere(0.27, Vector3(0, 1.62, 0.02), skin, Vector3(1.0, 0.9, 1.0))
	k.cone(0.09, 0.42, Vector3(0.3, 1.68, 0), skin, Vector3(0, 0, -75))
	k.cone(0.09, 0.42, Vector3(-0.3, 1.68, 0), skin, Vector3(0, 0, 75))
	k.cone(0.06, 0.18, Vector3(0, 1.58, 0.28), skin.darkened(0.1), Vector3(90, 0, 0))
	_eyes(k, 1.66, 0.22, 0.1, 0.05)
	k.cone(0.2, 0.25, Vector3(0, 1.88, 0), Color(0.55, 0.15, 0.12))  # cap
	return k.build()


static func _skeleton() -> ArrayMesh:
	var k := MeshKit.new(12)
	var bone := Color(0.9, 0.87, 0.78)
	var rust := Color(0.5, 0.35, 0.25)
	_legs(k, bone, bone.darkened(0.25), 0.15, 0.1)
	k.box(Vector3(0.18, 0.3, 0.14), Vector3(0, 0.88, 0), bone)  # pelvis/spine
	for i in 4:
		k.box(Vector3(0.48 - i * 0.04, 0.05, 0.3), Vector3(0, 1.0 + i * 0.12, 0), bone)  # ribs
	k.box(Vector3(0.08, 0.5, 0.08), Vector3(0, 1.18, -0.08), bone)
	k.box(Vector3(0.6, 0.1, 0.22), Vector3(0, 1.45, 0), rust)  # pauldron bar
	_arms(k, bone, bone, 0.36, 0.08)
	# sword
	k.box(Vector3(0.07, 0.07, 0.85), Vector3(0.4, 0.88, 0.45), Color(0.62, 0.6, 0.58), Vector3.ZERO, MeshKit.PART_ARM_W)
	k.box(Vector3(0.24, 0.06, 0.06), Vector3(0.4, 0.88, 0.06), rust, Vector3.ZERO, MeshKit.PART_ARM_W)
	# round shield on off arm
	k.cyl(0.32, 0.32, 0.06, Vector3(-0.5, 1.05, 0.12), rust.darkened(0.2), Vector3(90, 0, 0), MeshKit.PART_ARM_O, 12)
	k.sphere(0.08, Vector3(-0.5, 1.05, 0.17), Color(0.7, 0.6, 0.3), Vector3.ONE, MeshKit.PART_ARM_O, 6)
	# skull
	k.sphere(0.24, Vector3(0, 1.72, 0), bone, Vector3(0.95, 1.0, 1.0))
	k.box(Vector3(0.28, 0.12, 0.22), Vector3(0, 1.52, 0.04), bone.darkened(0.08))
	_eyes(k, 1.74, 0.19, 0.085, 0.05)
	return k.build()


static func _orc() -> ArrayMesh:
	var k := MeshKit.new(13)
	k.jitter = 0.02
	var skin := Color(0.3, 0.48, 0.22)
	var iron := Color(0.45, 0.46, 0.5)
	var cloth := Color(0.55, 0.15, 0.1)
	_legs(k, Color(0.3, 0.22, 0.15), Color(0.22, 0.2, 0.2), 0.2, 0.24)
	k.box(Vector3(0.75, 0.75, 0.48), Vector3(0, 1.12, 0), iron)
	k.box(Vector3(0.5, 0.5, 0.06), Vector3(0, 0.75, 0.22), cloth)  # tabard
	k.sphere(0.2, Vector3(0.48, 1.5, 0), iron.darkened(0.15), Vector3(1.2, 0.8, 1.2))
	k.sphere(0.2, Vector3(-0.48, 1.5, 0), iron.darkened(0.15), Vector3(1.2, 0.8, 1.2))
	_arms(k, skin, skin.darkened(0.15), 0.52, 0.2)
	# great axe
	k.box(Vector3(0.07, 0.07, 1.2), Vector3(0.56, 0.88, 0.4), Color(0.4, 0.27, 0.15), Vector3.ZERO, MeshKit.PART_ARM_W)
	k.box(Vector3(0.06, 0.45, 0.35), Vector3(0.56, 0.98, 0.92), Color(0.7, 0.72, 0.75), Vector3.ZERO, MeshKit.PART_ARM_W)
	# head
	k.sphere(0.3, Vector3(0, 1.75, 0.04), skin, Vector3(1.05, 0.95, 1.0))
	k.cone(0.04, 0.14, Vector3(0.12, 1.62, 0.3), Color(0.95, 0.92, 0.8), Vector3(-20, 0, 0))
	k.cone(0.04, 0.14, Vector3(-0.12, 1.62, 0.3), Color(0.95, 0.92, 0.8), Vector3(-20, 0, 0))
	_eyes(k, 1.8, 0.27, 0.11, 0.045)
	k.sphere(0.32, Vector3(0, 1.86, 0), iron.darkened(0.1), Vector3(1.0, 0.6, 1.0))  # helm
	k.cone(0.07, 0.35, Vector3(0.3, 2.05, 0), Color(0.9, 0.88, 0.8), Vector3(0, 0, -40))
	k.cone(0.07, 0.35, Vector3(-0.3, 2.05, 0), Color(0.9, 0.88, 0.8), Vector3(0, 0, 40))
	return k.build()


static func _demon() -> ArrayMesh:
	var k := MeshKit.new(14)
	var skin := Color(0.62, 0.12, 0.1)
	var dark := Color(0.18, 0.08, 0.08)
	_legs(k, skin.darkened(0.3), dark, 0.2, 0.22)
	k.box(Vector3(0.7, 0.75, 0.42), Vector3(0, 1.12, 0), skin)
	k.box(Vector3(0.4, 0.3, 0.05), Vector3(0, 1.2, 0.22), Color(1, 1, 1), Vector3.ZERO, MeshKit.PART_GLOW)  # chest rune
	_arms(k, skin, dark, 0.5, 0.19)
	# flaming blade
	k.box(Vector3(0.06, 0.14, 1.1), Vector3(0.54, 0.88, 0.55), Color(1, 1, 1), Vector3.ZERO, MeshKit.PART_GLOW)
	k.box(Vector3(0.28, 0.08, 0.08), Vector3(0.54, 0.88, 0.04), dark, Vector3.ZERO, MeshKit.PART_ARM_W)
	# wings
	k.box(Vector3(0.9, 0.7, 0.04), Vector3(0.55, 1.45, -0.3), dark, Vector3(0, 30, -20))
	k.box(Vector3(0.9, 0.7, 0.04), Vector3(-0.55, 1.45, -0.3), dark, Vector3(0, -30, 20))
	# tail
	k.cyl(0.03, 0.08, 0.8, Vector3(0, 0.75, -0.5), skin.darkened(0.2), Vector3(-60, 0, 0))
	# head + horns
	k.sphere(0.27, Vector3(0, 1.75, 0.03), skin)
	_eyes(k, 1.78, 0.24, 0.1, 0.05)
	k.cone(0.08, 0.45, Vector3(0.2, 2.05, -0.05), Color(0.15, 0.1, 0.08), Vector3(-15, 0, -30))
	k.cone(0.08, 0.45, Vector3(-0.2, 2.05, -0.05), Color(0.15, 0.1, 0.08), Vector3(-15, 0, 30))
	return k.build()


static func _brute() -> ArrayMesh:
	var k := MeshKit.new(15)
	var skin := Color(0.62, 0.52, 0.38)
	var fur := Color(0.35, 0.25, 0.15)
	_legs(k, fur, fur.darkened(0.3), 0.24, 0.3)
	k.sphere(0.55, Vector3(0, 1.12, 0), skin, Vector3(1.0, 0.85, 0.85))  # belly
	k.box(Vector3(1.0, 0.25, 0.7), Vector3(0, 0.82, 0), fur)  # loincloth
	_arms(k, skin, skin.darkened(0.2), 0.62, 0.26)
	# spiked club
	k.cyl(0.18, 0.07, 1.2, Vector3(0.66, 0.9, 0.5), Color(0.42, 0.28, 0.16), Vector3(90, 0, 0), MeshKit.PART_ARM_W)
	for i in 4:
		var a := i * PI / 2.0
		k.cone(0.05, 0.18, Vector3(0.66 + cos(a) * 0.17, 0.9 + sin(a) * 0.17, 0.95), Color(0.85, 0.85, 0.8), Vector3(0, 0, rad_to_deg(a) - 90), MeshKit.PART_ARM_W)
	k.sphere(0.28, Vector3(0, 1.62, 0.12), skin)
	_eyes(k, 1.66, 0.36, 0.1, 0.05)
	k.cone(0.05, 0.18, Vector3(0.12, 1.52, 0.38), Color(0.95, 0.9, 0.8), Vector3(-30, 0, 0))
	k.cone(0.05, 0.18, Vector3(-0.12, 1.52, 0.38), Color(0.95, 0.9, 0.8), Vector3(-30, 0, 0))
	return k.build()


static func _boss_molten() -> ArrayMesh:
	var k := MeshKit.new(16)
	k.jitter = 0.04
	var rock := Color(0.2, 0.15, 0.14)
	var glow := Color(1, 1, 1)
	_legs(k, rock, rock.darkened(0.2), 0.24, 0.3)
	k.box(Vector3(0.05, 0.5, 0.05), Vector3(0.24, 0.45, 0.17), glow, Vector3.ZERO, MeshKit.PART_GLOW)
	k.box(Vector3(0.05, 0.5, 0.05), Vector3(-0.24, 0.45, 0.17), glow, Vector3.ZERO, MeshKit.PART_GLOW)
	k.box(Vector3(0.9, 0.85, 0.55), Vector3(0, 1.15, 0), rock)
	# lava cracks
	k.box(Vector3(0.06, 0.6, 0.04), Vector3(0.1, 1.15, 0.28), glow, Vector3(0, 0, 20), MeshKit.PART_GLOW)
	k.box(Vector3(0.06, 0.45, 0.04), Vector3(-0.18, 1.2, 0.28), glow, Vector3(0, 0, -30), MeshKit.PART_GLOW)
	k.sphere(0.12, Vector3(0, 1.25, 0.26), glow, Vector3.ONE, MeshKit.PART_GLOW, 8)
	# pauldrons
	for side in [-1, 1]:
		k.sphere(0.28, Vector3(side * 0.6, 1.5, 0), rock.lightened(0.1), Vector3(1.1, 0.8, 1.0))
		k.cone(0.07, 0.4, Vector3(side * 0.7, 1.8, 0), Color(0.12, 0.1, 0.1), Vector3(0, 0, -side * 20))
	_arms(k, rock.lightened(0.05), rock, 0.62, 0.26)
	# molten war hammer
	k.box(Vector3(0.08, 0.08, 1.4), Vector3(0.66, 0.88, 0.5), Color(0.15, 0.1, 0.08), Vector3.ZERO, MeshKit.PART_ARM_W)
	k.box(Vector3(0.45, 0.4, 0.4), Vector3(0.66, 0.88, 1.2), rock.lightened(0.15), Vector3.ZERO, MeshKit.PART_ARM_W)
	k.box(Vector3(0.47, 0.1, 0.42), Vector3(0.66, 0.88, 1.2), glow, Vector3.ZERO, MeshKit.PART_GLOW)
	# head, crown of horns
	k.sphere(0.3, Vector3(0, 1.82, 0.05), rock)
	_eyes(k, 1.86, 0.3, 0.12, 0.06)
	k.box(Vector3(0.3, 0.04, 0.04), Vector3(0, 1.72, 0.3), glow, Vector3.ZERO, MeshKit.PART_GLOW)  # mouth
	for i in 5:
		var a := (i - 2) * 0.45
		k.cone(0.06, 0.35 + (0.2 if i == 2 else 0.0), Vector3(sin(a) * 0.26, 2.12, cos(a) * 0.05 - 0.02), Color(1, 1, 1), Vector3(0, 0, -rad_to_deg(a) * 0.6), MeshKit.PART_GLOW)
	return k.build()


static func _boss_lich() -> ArrayMesh:
	var k := MeshKit.new(17)
	var robe := Color(0.18, 0.12, 0.28)
	var trim := Color(0.75, 0.6, 0.25)
	var bone := Color(0.85, 0.83, 0.75)
	# robe instead of legs (legs still animate the hem a little)
	k.cyl(0.35, 0.6, 0.9, Vector3(0, 0.45, 0), robe)
	k.cyl(0.62, 0.62, 0.06, Vector3(0, 0.04, 0), trim)
	k.box(Vector3(0.7, 0.7, 0.42), Vector3(0, 1.15, 0), robe.lightened(0.05))
	k.box(Vector3(0.12, 0.9, 0.05), Vector3(0, 0.9, 0.22), trim)
	k.box(Vector3(0.95, 0.15, 0.5), Vector3(0, 1.48, 0), trim)
	_arms(k, robe, bone, 0.48, 0.18)
	# staff with soul orb
	k.cyl(0.04, 0.04, 2.2, Vector3(0.52, 1.1, 0.15), Color(0.3, 0.22, 0.15), Vector3.ZERO, MeshKit.PART_ARM_W)
	k.sphere(0.2, Vector3(0.52, 2.25, 0.15), Color(1, 1, 1), Vector3.ONE, MeshKit.PART_GLOW, 10)
	k.torus_ring(0.24, Vector3(0.52, 2.25, 0.15), trim, MeshKit.PART_ARM_W)
	# skull + crown
	k.sphere(0.25, Vector3(0, 1.78, 0), bone)
	_eyes(k, 1.8, 0.2, 0.09, 0.055)
	k.cyl(0.24, 0.22, 0.14, Vector3(0, 2.0, 0), trim)
	for i in 6:
		var a := i * TAU / 6.0
		k.cone(0.05, 0.2, Vector3(cos(a) * 0.22, 2.15, sin(a) * 0.22), trim)
	k.sphere(0.05, Vector3(0, 2.02, 0.23), Color(1, 1, 1), Vector3.ONE, MeshKit.PART_GLOW, 6)
	# hood / mantle spikes
	k.cone(0.12, 0.5, Vector3(0.4, 1.75, -0.1), robe.darkened(0.3), Vector3(0, 0, -25))
	k.cone(0.12, 0.5, Vector3(-0.4, 1.75, -0.1), robe.darkened(0.3), Vector3(0, 0, 25))
	return k.build()


# ------------------------------------------------------------------ props

static func tree(style: String, variant: int) -> ArrayMesh:
	var key := "tree_%s_%d" % [style, variant]
	if _cache.has(key):
		return _cache[key]
	var k := MeshKit.new(100 + variant)
	k.jitter = 0.05
	var trunk := Color(0.38, 0.26, 0.17)
	match style:
		"pine":
			k.cyl(0.18, 0.25, 1.2, Vector3(0, 0.6, 0), trunk)
			var g := Color(0.16, 0.4, 0.22) if variant % 2 == 0 else Color(0.2, 0.45, 0.25)
			for i in 4:
				k.cone(1.5 - i * 0.3, 1.5, Vector3(0, 1.4 + i * 0.85, 0), g.lightened(i * 0.04), Vector3.ZERO, MeshKit.PART_BODY, 8)
			if variant >= 2:
				k.cone(0.6, 0.7, Vector3(0, 4.3, 0), Color(0.95, 0.97, 1.0), Vector3.ZERO, MeshKit.PART_BODY, 8)
		"dead":
			k.cyl(0.12, 0.28, 3.0, Vector3(0, 1.5, 0), Color(0.22, 0.18, 0.15))
			for i in 4:
				var a := i * 1.7 + variant
				k.cyl(0.04, 0.1, 1.4, Vector3(cos(a) * 0.45, 2.0 + i * 0.35, sin(a) * 0.45), Color(0.22, 0.18, 0.15), Vector3(sin(a) * 50, 0, cos(a) * 50))
		_:
			if variant % 2 == 0:
				return tree("pine", variant + 1)
			k.cyl(0.2, 0.3, 1.8, Vector3(0, 0.9, 0), trunk)
			var leaf := Color(0.3, 0.58, 0.22)
			k.sphere(1.3, Vector3(0, 2.6, 0), leaf, Vector3(1, 0.85, 1), MeshKit.PART_BODY, 10)
			k.sphere(0.9, Vector3(0.7, 2.3, 0.3), leaf.lightened(0.08), Vector3.ONE, MeshKit.PART_BODY, 8)
			k.sphere(0.85, Vector3(-0.6, 2.4, -0.4), leaf.darkened(0.08), Vector3.ONE, MeshKit.PART_BODY, 8)
			k.sphere(0.8, Vector3(0.1, 3.3, 0.1), leaf.lightened(0.12), Vector3.ONE, MeshKit.PART_BODY, 8)
	var m := k.build()
	_cache[key] = m
	return m


static func rock(variant: int, base: Color) -> ArrayMesh:
	var key := "rock_%d_%s" % [variant, base.to_html()]
	if _cache.has(key):
		return _cache[key]
	var k := MeshKit.new(200 + variant)
	k.jitter = 0.06
	for i in 3:
		var p := Vector3(k.rng.randf_range(-0.4, 0.4), 0.2 + i * 0.1, k.rng.randf_range(-0.4, 0.4))
		k.box(Vector3(k.rng.randf_range(0.6, 1.2), k.rng.randf_range(0.4, 0.9), k.rng.randf_range(0.6, 1.1)), p, base,
			Vector3(k.rng.randf_range(-20, 20), k.rng.randf_range(0, 90), k.rng.randf_range(-20, 20)))
	var m := k.build()
	_cache[key] = m
	return m


static func ruin(variant: int) -> ArrayMesh:
	var key := "ruin_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var k := MeshKit.new(300 + variant)
	k.jitter = 0.05
	var stone := Color(0.62, 0.6, 0.56)
	match variant % 3:
		0:  # broken column
			k.cyl(0.55, 0.6, 0.3, Vector3(0, 0.15, 0), stone.darkened(0.1), Vector3.ZERO, MeshKit.PART_BODY, 12)
			var h := k.rng.randf_range(1.5, 4.0)
			k.cyl(0.42, 0.45, h, Vector3(0, 0.3 + h * 0.5, 0), stone, Vector3(k.rng.randf_range(-6, 6), 0, 0), MeshKit.PART_BODY, 12)
		1:  # wall fragment
			for x in 4:
				for y in 3 - abs(x - 1):
					k.box(Vector3(0.95, 0.55, 0.7), Vector3(x * 1.0 - 1.5, 0.3 + y * 0.57, 0), stone)
		_:  # fallen arch blocks
			for i in 5:
				k.box(Vector3(0.9, 0.6, 0.6), Vector3(k.rng.randf_range(-1.5, 1.5), 0.3, k.rng.randf_range(-1.0, 1.0)), stone,
					Vector3(0, k.rng.randf_range(0, 90), k.rng.randf_range(-15, 15)))
	var m := k.build()
	_cache[key] = m
	return m


# ------------------------------------------------------------------ castle

static func castle(width: float) -> ArrayMesh:
	var key := "castle_%d" % int(width)
	if _cache.has(key):
		return _cache[key]
	var k := MeshKit.new(400)
	k.jitter = 0.035
	var stone := Color(0.66, 0.63, 0.6)
	var dark := Color(0.45, 0.42, 0.42)
	var roof := Color(0.2, 0.3, 0.62)
	var wood := Color(0.42, 0.28, 0.16)
	var half := width * 0.5
	var wall_h := 4.2
	var wall_t := 2.4
	# foundation slope
	k.box(Vector3(width + 4, 0.8, wall_t + 1.6), Vector3(0, 0.2, 0.2), dark)
	# wall body built from staggered stone courses
	var course_h := 0.6
	var rows := int(wall_h / course_h)
	for r in rows:
		var off := 0.6 if r % 2 == 0 else 0.0
		var x := -half - off
		while x < half:
			var w := 1.2
			var cx := x + w * 0.5
			if absf(cx) > 2.4 or r >= 5:  # leave gate opening
				k.box(Vector3(w - 0.04, course_h - 0.04, wall_t), Vector3(clampf(cx, -half + 0.6, half - 0.6), 0.6 + r * course_h + course_h * 0.5, 0), stone)
			x += w
	# walkway + crenellations (front side faces -Z, toward enemies)
	k.box(Vector3(width, 0.3, wall_t + 0.4), Vector3(0, wall_h + 0.75, 0), dark)
	var cx2 := -half + 0.5
	while cx2 < half:
		k.box(Vector3(0.7, 0.8, 0.45), Vector3(cx2, wall_h + 1.3, -wall_t * 0.5 - 0.05), stone)
		k.box(Vector3(0.7, 0.5, 0.3), Vector3(cx2, wall_h + 1.15, wall_t * 0.5), stone.darkened(0.05))
		cx2 += 1.4
	# gatehouse
	for side in [-1, 1]:
		k.box(Vector3(2.2, 7.5, 3.4), Vector3(side * 3.4, 3.75, -0.2), stone)
		k.cone(1.9, 2.8, Vector3(side * 3.4, 8.9, -0.2), roof, Vector3(0, 45, 0), MeshKit.PART_BODY, 4)
		k.box(Vector3(0.3, 0.9, 0.1), Vector3(side * 3.4, 6.0, -1.95), Color(0.1, 0.08, 0.1))  # arrow slit
	k.box(Vector3(4.6, 1.6, 3.0), Vector3(0, 6.2, -0.2), stone.darkened(0.05))
	k.box(Vector3(4.6, 0.4, 3.2), Vector3(0, 7.2, -0.2), dark)
	k.box(Vector3(4.6, 3.4, 0.25), Vector3(0, 1.7, -0.9), wood)  # gate
	for i in 5:
		k.box(Vector3(0.12, 3.4, 0.1), Vector3(-1.8 + i * 0.9, 1.7, -1.05), Color(0.25, 0.25, 0.28))
	k.box(Vector3(4.6, 0.15, 0.1), Vector3(0, 2.5, -1.05), Color(0.25, 0.25, 0.28))
	# corner towers
	for side in [-1, 1]:
		var tx: float = side * (half + 0.4)
		k.cyl(2.2, 2.5, 9.0, Vector3(tx, 4.5, 0), stone, Vector3.ZERO, MeshKit.PART_BODY, 14)
		k.cyl(2.6, 2.6, 0.6, Vector3(tx, 9.2, 0), dark, Vector3.ZERO, MeshKit.PART_BODY, 14)
		for i in 10:
			var a := i * TAU / 10.0
			k.box(Vector3(0.6, 0.7, 0.5), Vector3(tx + cos(a) * 2.35, 9.85, sin(a) * 2.35), stone, Vector3(0, -rad_to_deg(a), 0))
		k.cone(2.8, 4.5, Vector3(tx, 12.2, 0), roof, Vector3.ZERO, MeshKit.PART_BODY, 14)
		k.cyl(0.04, 0.04, 1.6, Vector3(tx, 15.0, 0), wood)
		for j in 3:
			k.box(Vector3(0.3, 0.7, 0.08), Vector3(tx, 6.5 - j * 2.0, -2.35), Color(0.1, 0.08, 0.1))
	# keep behind the wall
	k.box(Vector3(9, 11, 7), Vector3(0, 5.5, 9), stone.darkened(0.03))
	k.cone(6.5, 6, Vector3(0, 14, 9), roof, Vector3(0, 45, 0), MeshKit.PART_BODY, 4)
	for side in [-1, 1]:
		k.cyl(1.4, 1.5, 14, Vector3(side * 4.5, 7, 6), stone, Vector3.ZERO, MeshKit.PART_BODY, 12)
		k.cone(1.9, 4.0, Vector3(side * 4.5, 16, 6), roof, Vector3.ZERO, MeshKit.PART_BODY, 12)
	for i in 4:
		k.box(Vector3(0.6, 1.2, 0.1), Vector3(-2.4 + i * 1.6, 7.5, 5.45), Color(1.0, 0.82, 0.45), Vector3.ZERO, MeshKit.PART_GLOW)
	var m := k.build()
	_cache[key] = m
	return m


static func castle_trim(width: float) -> ArrayMesh:
	## Banners and gold details (separate so it can use a shinier material).
	var k := MeshKit.new(401)
	var half := width * 0.5
	var red := Color(0.7, 0.1, 0.12)
	var gold := Color(0.95, 0.75, 0.25)
	var x := -half + 3.0
	while x < half - 2.0:
		if absf(x) > 5.0:
			k.box(Vector3(1.0, 2.2, 0.06), Vector3(x, 3.6, -1.28), red)
			k.box(Vector3(1.1, 0.12, 0.1), Vector3(x, 4.72, -1.3), gold)
			k.prism_point(Vector3(x, 2.2, -1.28), red)
			k.sphere(0.18, Vector3(x, 3.8, -1.33), gold, Vector3(1, 1, 0.3), MeshKit.PART_BODY, 8)
		x += 3.5
	for side in [-1, 1]:
		var tx: float = side * (half + 0.4)
		k.box(Vector3(1.2, 0.7, 0.04), Vector3(tx + 0.6, 15.4, 0), red)
	k.sphere(0.6, Vector3(0, 6.2, -1.75), gold, Vector3(1, 1, 0.3), MeshKit.PART_BODY, 12)
	return k.build()


# ------------------------------------------------------------------ towers

static func tower(type: String, level: int) -> ArrayMesh:
	var key := "tower_%s_%d" % [type, level]
	if _cache.has(key):
		return _cache[key]
	var k := MeshKit.new(500 + level)
	k.jitter = 0.03
	var lv := clampi(level, 1, 5)
	var stone := Color(0.7, 0.67, 0.62).lerp(Color(0.85, 0.82, 0.78), (lv - 1) * 0.15)
	var wood := Color(0.48, 0.32, 0.18)
	var gold := Color(0.95, 0.78, 0.3)
	var accent: Color = GameData.TOWERS[type]["color"]
	var h := 2.4 + lv * 0.45
	# base plinth
	k.cyl(1.25, 1.4, 0.5, Vector3(0, 0.25, 0), stone.darkened(0.2), Vector3.ZERO, MeshKit.PART_BODY, 8)
	match type:
		"archer":
			k.cyl(0.85, 1.05, h, Vector3(0, 0.5 + h * 0.5, 0), wood if lv < 3 else stone, Vector3.ZERO, MeshKit.PART_BODY, 8)
			for i in 4:
				var a := i * TAU / 4.0 + PI / 4.0
				k.box(Vector3(0.18, h, 0.18), Vector3(cos(a) * 0.95, 0.5 + h * 0.5, sin(a) * 0.95), wood.darkened(0.2))
			k.cyl(1.3, 1.3, 0.25, Vector3(0, 0.6 + h, 0), wood.darkened(0.1), Vector3.ZERO, MeshKit.PART_BODY, 8)
			var roof_col := accent.darkened(0.2) if lv < 4 else Color(0.2, 0.55, 0.3)
			k.cone(1.55, 1.4 + lv * 0.15, Vector3(0, 1.6 + h + lv * 0.07, 0), roof_col, Vector3.ZERO, MeshKit.PART_BODY, 8)
			if lv >= 2:
				k.box(Vector3(0.05, 0.9, 0.5), Vector3(0, 2.6 + h + lv * 0.15, 0.25), Color(0.75, 0.15, 0.12))
		"cannon":
			k.cyl(1.1, 1.25, h * 0.8, Vector3(0, 0.5 + h * 0.4, 0), stone, Vector3.ZERO, MeshKit.PART_BODY, 10)
			k.cyl(1.35, 1.35, 0.35, Vector3(0, 0.6 + h * 0.8, 0), stone.darkened(0.1), Vector3.ZERO, MeshKit.PART_BODY, 10)
			for i in 8:
				var a := i * TAU / 8.0
				k.box(Vector3(0.38, 0.45, 0.38), Vector3(cos(a) * 1.15, 0.95 + h * 0.8, sin(a) * 1.15), stone)
		"lightning":
			k.cyl(0.55, 0.95, h, Vector3(0, 0.5 + h * 0.5, 0), Color(0.35, 0.36, 0.48), Vector3.ZERO, MeshKit.PART_BODY, 6)
			for i in 3:
				var a := i * TAU / 3.0
				k.cyl(0.06, 0.12, h + 0.6, Vector3(cos(a) * 0.75, 0.8 + h * 0.5, sin(a) * 0.75), gold, Vector3(sin(a) * 8, 0, -cos(a) * 8))
			for i in lv:
				k.torus_ring(0.7 - i * 0.06, Vector3(0, 1.0 + i * (h / 5.0), 0), Color(1, 1, 1), MeshKit.PART_GLOW)
		"fire":
			k.cyl(0.95, 1.15, h * 0.85, Vector3(0, 0.5 + h * 0.42, 0), Color(0.35, 0.22, 0.18), Vector3.ZERO, MeshKit.PART_BODY, 8)
			k.cyl(1.25, 0.8, 0.8, Vector3(0, 0.9 + h * 0.85, 0), Color(0.25, 0.2, 0.2), Vector3.ZERO, MeshKit.PART_BODY, 8)
			for i in 6:
				var a := i * TAU / 6.0
				k.cone(0.12, 0.6 + lv * 0.08, Vector3(cos(a) * 1.15, 1.5 + h * 0.85, sin(a) * 1.15), Color(0.2, 0.12, 0.1), Vector3(sin(a) * -20, 0, cos(a) * 20))
			for i in 3:
				k.box(Vector3(0.08, h * 0.6, 0.05), Vector3(sin(i * 2.1) * 0.95, 0.5 + h * 0.4, cos(i * 2.1) * 0.95), Color(1, 1, 1), Vector3(0, rad_to_deg(i * 2.1), 0), MeshKit.PART_GLOW)
		"ice":
			k.cyl(0.8, 1.1, h * 0.7, Vector3(0, 0.5 + h * 0.35, 0), Color(0.75, 0.82, 0.92), Vector3.ZERO, MeshKit.PART_BODY, 6)
			for i in 5:
				var a := i * TAU / 5.0
				k.cone(0.25, 1.2 + lv * 0.15, Vector3(cos(a) * 0.65, 0.9 + h * 0.7, sin(a) * 0.65), Color(0.7, 0.92, 1.0), Vector3(sin(a) * -25, 0, cos(a) * 25), MeshKit.PART_BODY, 5)
	# gold bands for higher tiers
	if lv >= 3:
		k.cyl(1.0, 1.0, 0.12, Vector3(0, 0.5 + h * 0.3, 0), gold, Vector3.ZERO, MeshKit.PART_BODY, 10)
	if lv >= 5:
		k.cyl(1.0, 1.0, 0.12, Vector3(0, 0.5 + h * 0.6, 0), gold, Vector3.ZERO, MeshKit.PART_BODY, 10)
	var m := k.build()
	_cache[key] = m
	return m


static func tower_head(type: String, level: int) -> ArrayMesh:
	## Rotating top part (weapon/crystal) of a tower.
	var key := "towerhead_%s_%d" % [type, level]
	if _cache.has(key):
		return _cache[key]
	var k := MeshKit.new(600 + level)
	var lv := clampi(level, 1, 5)
	match type:
		"archer":
			k.box(Vector3(0.3, 0.5, 0.25), Vector3(0, 0.25, 0), Color(0.2, 0.45, 0.25))
			k.sphere(0.16, Vector3(0, 0.62, 0), Color(0.9, 0.75, 0.6), Vector3.ONE, MeshKit.PART_BODY, 8)
			k.cone(0.2, 0.3, Vector3(0, 0.82, 0), Color(0.2, 0.5, 0.25))
			k.torus_arc(Vector3(0.0, 0.4, 0.3), Color(0.45, 0.3, 0.15))
			for i in mini(lv, 3) - 1:
				k.box(Vector3(0.25, 0.4, 0.2), Vector3((i * 2 - 1) * 0.5, 0.2, -0.1), Color(0.2, 0.45, 0.25))
		"cannon":
			k.box(Vector3(0.9, 0.35, 1.0), Vector3(0, 0.18, 0), Color(0.4, 0.27, 0.16))
			var barrel_len := 1.4 + lv * 0.12
			var barrel_r := 0.28 + lv * 0.03
			var bc := Color(0.22, 0.22, 0.25) if lv < 4 else Color(0.62, 0.45, 0.2)
			k.cyl(barrel_r, barrel_r + 0.08, barrel_len, Vector3(0, 0.55, barrel_len * 0.35), bc, Vector3(80, 0, 0), MeshKit.PART_BODY, 12)
			k.cyl(barrel_r + 0.06, barrel_r + 0.06, 0.12, Vector3(0, 0.62, barrel_len * 0.8), bc.lightened(0.2), Vector3(80, 0, 0), MeshKit.PART_BODY, 12)
			if lv >= 5:
				k.cyl(barrel_r * 0.8, barrel_r, barrel_len, Vector3(0.5, 0.5, barrel_len * 0.3), bc, Vector3(80, 0, 0), MeshKit.PART_BODY, 10)
				k.cyl(barrel_r * 0.8, barrel_r, barrel_len, Vector3(-0.5, 0.5, barrel_len * 0.3), bc, Vector3(80, 0, 0), MeshKit.PART_BODY, 10)
		"lightning":
			k.sphere(0.35 + lv * 0.05, Vector3(0, 0.5, 0), Color(1, 1, 1), Vector3(1, 1.4, 1), MeshKit.PART_GLOW, 6)
		"fire":
			k.sphere(0.4 + lv * 0.05, Vector3(0, 0.45, 0), Color(1, 1, 1), Vector3.ONE, MeshKit.PART_GLOW, 8)
		"ice":
			k.cone(0.35, 1.2 + lv * 0.2, Vector3(0, 0.8, 0), Color(1, 1, 1), Vector3.ZERO, MeshKit.PART_GLOW, 5)
			k.cone(0.35, 0.5, Vector3(0, 0.05, 0), Color(1, 1, 1), Vector3(180, 0, 0), MeshKit.PART_GLOW, 5)
	var m := k.build()
	_cache[key] = m
	return m


static func build_pad() -> ArrayMesh:
	if _cache.has("pad"):
		return _cache["pad"]
	var k := MeshKit.new(700)
	k.cyl(1.3, 1.45, 0.2, Vector3(0, 0.1, 0), Color(0.5, 0.47, 0.43), Vector3.ZERO, MeshKit.PART_BODY, 8)
	k.cyl(1.0, 1.0, 0.04, Vector3(0, 0.22, 0), Color(1, 1, 1), Vector3.ZERO, MeshKit.PART_GLOW, 8)
	k.cyl(0.9, 0.9, 0.06, Vector3(0, 0.23, 0), Color(0.42, 0.4, 0.37), Vector3.ZERO, MeshKit.PART_BODY, 8)
	var m := k.build()
	_cache["pad"] = m
	return m
