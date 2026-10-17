class_name HeroPortraits
extends RefCounted
## Renders head-and-shoulders portraits of every hero (current skin) into textures using an
## offscreen SubViewport, cached in memory and as PNGs in user://portraits/.
## Falls back gracefully (returns null) on renderers that cannot read back images.

const DIR := "user://portraits/"
const VERSION := 3
const SIZE := 192

static var _tex := {}


static func _key(id: String) -> String:
	return "%s_s%d_v%d" % [id, int(GameState.heroes[id].get("skin", 0)), VERSION]


static func get_portrait(id: String) -> Texture2D:
	var k := _key(id)
	if _tex.has(k):
		return _tex[k]
	var path := DIR + k + ".png"
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img and not img.is_empty():
			_tex[k] = ImageTexture.create_from_image(img)
			return _tex[k]
	return null


static func generate_missing(host: Node) -> void:
	## Await-able: renders any portraits not yet cached.
	for id in GameData.HERO_ORDER:
		if get_portrait(id) == null:
			await _render(host, id)


static func _render(host: Node, id: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.65, 0.62, 0.75)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_energy = 1.4
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 200, 0)
	rim.light_color = GameData.HEROES[id]["color"]
	rim.light_energy = 1.6
	vp.add_child(rim)
	var model := HeroPreview.build_model(id)
	vp.add_child(model)
	model.rotation.y = -0.45
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var idle: String = GameData.HEROES[id]["anims"]["idle"]
	if ap and ap.has_animation(idle):
		ap.play(idle)
		ap.seek(0.3, true)
	var cam := Camera3D.new()
	cam.fov = 30
	var sc: Vector3 = GameData.HEROES[id].get("scale", Vector3.ONE)
	var head_y := 1.75 * sc.y
	cam.position = Vector3(-0.1, head_y + 0.05, 2.6)
	vp.add_child(cam)
	cam.look_at(Vector3(0, head_y - 0.15, 0))
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image() if vp.get_texture() else null
	if img and not img.is_empty() and img.get_width() == SIZE:
		DirAccess.make_dir_recursive_absolute(DIR)
		img.save_png(DIR + _key(id) + ".png")
		_tex[_key(id)] = ImageTexture.create_from_image(img)
	vp.queue_free()
