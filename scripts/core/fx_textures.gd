class_name FXTextures
extends RefCounted
## Procedurally generated effect textures (no external image assets).
## Generated once, cached for the whole session.

static var _cache := {}


static func _noise(seed_v: int, freq: float, octaves := 4) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = octaves
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	return n


const DISK_CACHE := "user://fx_cache/"
const PREBAKED := "res://assets/prebaked/fx/"   # shipped Image resources (tools/prebake.gd)
const NAMES := ["soft", "puff", "smoke", "spark", "ring", "crack", "scorch", "frost", "rune", "noise"]
const VERSION := 3


static func get_tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := DISK_CACHE + "%s_v%d.png" % [name, VERSION]
	var img: Image
	var shipped := PREBAKED + "%s_v%d.res" % [name, VERSION]
	if ResourceLoader.exists(shipped):
		img = load(shipped)
	elif FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img == null or img.is_empty():
		img = _generate(name)
		DirAccess.make_dir_recursive_absolute(DISK_CACHE)
		img.save_png(path)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[name] = tex
	return tex


static func _generate(name: String) -> Image:
	var img: Image
	match name:
		"soft": img = _soft(64)
		"puff": img = _puff(128, 11, 0.55)
		"smoke": img = _puff(128, 23, 0.75)
		"spark": img = _spark(64)
		"ring": img = _ring(128)
		"crack": img = _crack(256)
		"scorch": img = _scorch(256)
		"frost": img = _frost(256)
		"rune": img = _rune(256)
		"noise": img = _noise_img(128)
		_: img = _soft(32)
	return img


static func _soft(s: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s / 2.0 + 0.5, y - s / 2.0 + 0.5).length() / (s / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return img


static func _puff(s: int, seed_v: int, softness: float) -> Image:
	## Cloudy blob with a noisy edge: fire and smoke particles.
	var n := _noise(seed_v, 4.0 / s, 4)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var p := Vector2(x - s / 2.0, y - s / 2.0) / (s / 2.0)
			var nv := n.get_noise_2d(x, y) * 0.5 + 0.5
			var d := p.length() - nv * 0.35
			var a := clampf((1.0 - d / softness) , 0.0, 1.0)
			a = smoothstep(0.0, 1.0, a)
			var shade := 0.7 + nv * 0.3
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	return img


static func _spark(s: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var px := absf(x - s / 2.0 + 0.5) / (s / 2.0)
			var py := absf(y - s / 2.0 + 0.5) / (s / 2.0)
			var a := clampf(1.0 - px * 4.0, 0.0, 1.0) * clampf(1.0 - py, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return img


static func _ring(s: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s / 2.0 + 0.5, y - s / 2.0 + 0.5).length() / (s / 2.0)
			var a := clampf(1.0 - absf(d - 0.85) / 0.12, 0.0, 1.0)
			a = a * a + clampf(1.0 - absf(d - 0.85) / 0.4, 0.0, 1.0) * 0.25 * float(d < 0.85)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


static func _crack(s: int) -> Image:
	## Branching ground fissures radiating from the centre (for decals).
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var c := Vector2(s / 2.0, s / 2.0)
	for i in 9:
		var ang := i * TAU / 9.0 + rng.randf_range(-0.25, 0.25)
		_crack_branch(img, c, ang, s * 0.46, 3.2, rng, 0)
	# dark scorched centre
	for y in s:
		for x in s:
			var d := Vector2(x, y).distance_to(c) / (s / 2.0)
			if d < 0.3:
				var cur := img.get_pixel(x, y)
				var a := maxf(cur.a, (1.0 - d / 0.3) * 0.7)
				img.set_pixel(x, y, Color(0.05, 0.03, 0.02, a))
	return img


static func _crack_branch(img: Image, from: Vector2, ang: float, length: float, width: float, rng: RandomNumberGenerator, depth: int) -> void:
	var p := from
	var steps := int(length / 4.0)
	for i in steps:
		ang += rng.randf_range(-0.35, 0.35)
		var nxt := p + Vector2(cos(ang), sin(ang)) * 4.0
		var w := width * (1.0 - float(i) / steps) + 0.6
		_line(img, p, nxt, w)
		p = nxt
		if depth < 2 and rng.randf() < 0.12:
			_crack_branch(img, p, ang + rng.randf_range(-1.0, 1.0), length * 0.45, w * 0.7, rng, depth + 1)


static func _line(img: Image, a: Vector2, b: Vector2, w: float) -> void:
	var s := img.get_width()
	var n := int(a.distance_to(b)) + 1
	for i in n:
		var p := a.lerp(b, float(i) / n)
		for oy in range(-int(w) - 1, int(w) + 2):
			for ox in range(-int(w) - 1, int(w) + 2):
				var x := int(p.x) + ox
				var y := int(p.y) + oy
				if x < 0 or y < 0 or x >= s or y >= s:
					continue
				var d := Vector2(ox, oy).length()
				var a2 := clampf(1.0 - d / (w + 0.5), 0.0, 1.0)
				var cur := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(0.04, 0.02, 0.01, maxf(cur.a, a2)))


static func _scorch(s: int) -> Image:
	var n := _noise(31, 6.0 / s, 5)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s / 2.0, y - s / 2.0).length() / (s / 2.0)
			var nv := n.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf(1.0 - (d + (nv - 0.5) * 0.5), 0.0, 1.0)
			a = smoothstep(0.0, 0.6, a) * 0.85
			img.set_pixel(x, y, Color(0.06 + nv * 0.05, 0.04, 0.03, a))
	return img


static func _frost(s: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var n := _noise(55, 8.0 / s, 4)
	for y in s:
		for x in s:
			var p := Vector2(x - s / 2.0, y - s / 2.0)
			var d := p.length() / (s / 2.0)
			var ang := atan2(p.y, p.x)
			var spokes := pow(absf(cos(ang * 6.0)), 18.0) * clampf(1.0 - d, 0.0, 1.0)
			var nv := n.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - d) * (0.45 + nv * 0.5) + spokes * 0.8, 0.0, 1.0) * (1.0 - smoothstep(0.75, 1.0, d))
			img.set_pixel(x, y, Color(0.85 * a, 0.95 * a, 1.0 * a, a))
	return img


static func _rune(s: int) -> Image:
	## Glowing magic circle (summon portals, rune traps, boss auras).
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(s / 2.0, s / 2.0)
	for y in s:
		for x in s:
			var p := Vector2(x, y) - c
			var d := p.length() / (s / 2.0)
			var ang := atan2(p.y, p.x)
			var a := 0.0
			a = maxf(a, clampf(1.0 - absf(d - 0.92) / 0.025, 0.0, 1.0))
			a = maxf(a, clampf(1.0 - absf(d - 0.78) / 0.018, 0.0, 1.0))
			a = maxf(a, clampf(1.0 - absf(d - 0.45) / 0.02, 0.0, 1.0))
			# runic ticks between the two outer rings
			if d > 0.79 and d < 0.91 and fmod(ang + PI, TAU / 24.0) < 0.06:
				a = maxf(a, 0.9)
			# hexagram
			for k in 6:
				var a0 := k * TAU / 6.0
				var p0 := Vector2(cos(a0), sin(a0)) * 0.78
				var p1 := Vector2(cos(a0 + TAU / 3.0), sin(a0 + TAU / 3.0)) * 0.78
				var q := p / (s / 2.0)
				var seg := p1 - p0
				var tt := clampf((q - p0).dot(seg) / seg.length_squared(), 0.0, 1.0)
				var dist := q.distance_to(p0 + seg * tt)
				a = maxf(a, clampf(1.0 - dist / 0.012, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


static func _noise_img(s: int) -> Image:
	var n := _noise(91, 4.0 / s, 4)
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			# seamless via 4-corner blend
			var fx := float(x) / s
			var fy := float(y) / s
			var v := (n.get_noise_2d(x, y) * (1 - fx) * (1 - fy) + n.get_noise_2d(x - s, y) * fx * (1 - fy)
				+ n.get_noise_2d(x, y - s) * (1 - fx) * fy + n.get_noise_2d(x - s, y - s) * fx * fy) * 0.5 + 0.5
			img.set_pixel(x, y, Color(v, v, v, 1))
	return img
