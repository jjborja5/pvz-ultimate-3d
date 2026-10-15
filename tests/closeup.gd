extends Node
## Close-up render of every enemy type (visual check). Args: <out.png> [attack]
var b
var f := 0
func _ready():
	GameState.current_mode = "sandbox"
	b = load("res://scenes/battle.tscn").instantiate()
	add_child(b)
func _process(_d):
	f += 1
	if f == 3:
		var i := 0
		for t in GameData.ENEMIES:
			var boss: bool = GameData.ENEMIES[t].get("boss", false)
			var e = b.enemies.spawn(t, 1, -20.0)
			e.pos = Vector3(-10.5 + (i % 7) * 3.5, 0, -16.0 - (i / 7) * 6.0 - (3.0 if boss else 0.0))
			e.speed = 0.0
			e.heading = 0.0
			if OS.get_cmdline_user_args().size() > 1:
				e.attacking = true
			if i == 2: e.elite = "giant"; e.aura = 1.0 + GameData.ELITES["giant"]["aura"].h
			i += 1
	if f > 3:
		b.camera.global_position = Vector3(0, 9, 0)
		b.camera.look_at(Vector3(0, 1.5, -19))
		b.set_process(false)
	if f == 50:
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		get_tree().quit()
