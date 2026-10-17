class_name HeroPreview
extends SubViewportContainer
## Live 3D turntable of a hero (animated KayKit character) for the Heroes menu.

var _vp: SubViewport
var _pivot: Node3D
var _model: Node3D
var _anim: AnimationPlayer
var _hero_id := ""
var _t := 0.0
var _anim_i := 0


func _init(size_px := Vector2(400, 420)) -> void:
	custom_minimum_size = size_px
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.own_world_3d = true
	add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.75)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	_vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.3
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_color = Color(0.6, 0.7, 1.0)
	rim.light_energy = 0.9
	_vp.add_child(rim)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.35, 5.6)
	cam.fov = 38
	_vp.add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0))
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1
	cyl.bottom_radius = 1.25
	cyl.height = 0.25
	cyl.radial_segments = 8
	base.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.35, 0.3, 0.45)
	bm.metallic = 0.4
	bm.roughness = 0.4
	base.material_override = bm
	base.position.y = -0.12
	_vp.add_child(base)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	if _hero_id != "":
		show_hero(_hero_id)


static func build_model(id: String) -> Node3D:
	## Hero model with its weapons, tint and current skin applied (shared with portraits).
	var def: Dictionary = GameData.HEROES[id]
	var model := Assets.instance("characters/%s.glb" % def["model"])
	var sc: Vector3 = def.get("scale", Vector3.ONE)
	model.scale = sc
	var skin: Dictionary = GameData.SKINS[int(GameState.heroes[id].get("skin", 0))]
	var tint: Color = def["tint"]
	var amount: float = def["tint_amount"]
	if float(skin["amount"]) >= 0.0:
		tint = skin["tint"]
		amount = skin["amount"]
	var mat: ShaderMaterial = null
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null and not (def["keep"] as Array).has(String(mi.name)):
			mi.visible = false
			continue
		if mat == null:
			var b := mi.mesh.surface_get_material(0) as BaseMaterial3D
			mat = ShaderMaterial.new()
			mat.shader = load("res://shaders/unit_tex.gdshader")
			mat.set_shader_parameter("atlas", b.albedo_texture if b else null)
			mat.set_shader_parameter("tint", tint)
			mat.set_shader_parameter("tint_amount", amount)
			mat.set_shader_parameter("emissive_body", skin["glow"])
			mat.set_shader_parameter("rim_strength", 0.5)
		mi.material_override = mat
	return model


func show_hero(id: String) -> void:
	_hero_id = id
	if _pivot == null:
		return
	if _model:
		_model.queue_free()
	_model = build_model(id)
	_pivot.add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false)
	_anim_i = 0
	_t = 0.0
	_cycle()


func _cycle() -> void:
	if _anim == null:
		return
	var anims: Dictionary = GameData.HEROES[_hero_id]["anims"]
	var order := [anims["idle"], anims["attack"], anims["idle"], anims["cast"]]
	var name: String = order[_anim_i % order.size()]
	if _anim.has_animation(name):
		var a := _anim.get_animation(name)
		a.loop_mode = Animation.LOOP_LINEAR
		_anim.play(name, 0.2)


func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotation.y += delta * 0.5
	_t += delta
	if _t > 2.5:
		_t = 0.0
		_anim_i += 1
		_cycle()
