extends Node
## Renders the game and saves screenshots (needs a real renderer, e.g. under xvfb):
##   xvfb-run -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 res://tests/screenshot.tscn -- <out_dir> <map> <mode>

var out_dir := "user://shots"
var scene: Node
var frame := 0
var shots := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		GameState.current_map = args[1]
	var which := args[2] if args.size() > 2 else "battle"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.current_mode = "campaign"
	if which == "menu":
		scene = load("res://scenes/main_menu.tscn").instantiate()
	else:
		scene = load("res://scenes/battle.tscn").instantiate()
	add_child(scene)


func _snap(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _process(_d: float) -> void:
	frame += 1
	if not scene.has_method("call_next_wave"):
		if frame == 90:
			_snap("menu_%s" % GameState.current_map)
			get_tree().quit()
		return
	match frame:
		5:
			scene.god_fill_pads()
			scene.call_next_wave()
			scene.god_spawn_army("mixed", 160)
			scene.god_spawn_boss()
		60:
			_snap("battle_%s_a" % GameState.current_map)
		200:
			var e = scene.enemies.enemies
			if e.size() > 0:
				scene.spells.cast("meteor", e[0].pos)
				scene.spells.cast("ice_storm", e[min(5, e.size() - 1)].pos)
				scene.spells.cast("lightning", e[e.size() / 2].pos)
				scene.spells.cast("fireball", e[e.size() - 1].pos)
		252:
			_snap("battle_%s_b" % GameState.current_map)
		260:
			scene.select_pad(0)
		275:
			_snap("battle_%s_sheet" % GameState.current_map)
			scene.deselect()
			scene.hud.open_god_panel()
		300:
			_snap("battle_%s_god" % GameState.current_map)
			get_tree().quit()
