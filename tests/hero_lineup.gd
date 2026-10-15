extends Node
## Renders all nine heroes side by side (visual check). Args: <out.png>
var b
var f := 0
func _ready():
	GameState.current_mode = "sandbox"
	b = load("res://scenes/battle.tscn").instantiate()
	add_child(b)
func _process(_d):
	f += 1
	if f == 3:
		for h in b.heroes:
			h.queue_free()
		b.heroes.clear()
		var i := 0
		for id in GameData.HERO_ORDER:
			var h := Hero.new()
			b.add_child(h)
			h.global_position = Vector3(-12.0 + (i % 5) * 6.0 + (i / 5) * 3.0, 0, -17.0 - (i / 5) * 6.0)
			h.setup(id, b)
			h.set_process(false)
			h._model.rotation.y = 0.0
			i += 1
	if f > 3:
		b.camera.global_position = Vector3(0, 13, 3)
		b.camera.look_at(Vector3(0, 1.8, -19))
		b.set_process(false)
	if f == 60:
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		get_tree().quit()
