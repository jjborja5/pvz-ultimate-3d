extends Node
## Renders the game and saves screenshots (needs a real renderer, e.g. xvfb + lavapipe):
##   tests/shoot.sh <out_dir> <map> <battle|menu|heroes>

var out_dir := "user://shots"
var scene: Node
var frame := 0
var which := "battle"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		GameState.current_map = args[1]
	which = args[2] if args.size() > 2 else "battle"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.current_mode = "campaign"
	if which == "menu" or which == "heroes":
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
	if which == "menu":
		if frame == 90:
			_snap("menu_%s" % GameState.current_map)
			get_tree().quit()
		return
	if which == "heroes":
		match frame:
			60: scene.call("_show_heroes")
			140: _snap("menu_heroes")
			150: scene.call("_show_equipment")
			200: _snap("menu_equipment")
			210: scene.call("_show_inventory")
			250: _snap("menu_inventory")
			260: scene.call("_show_upgrades")
			300:
				_snap("menu_upgrades")
				get_tree().quit()
		return
	match frame:
		5:
			scene.god_fill_pads()
			scene.god_build_defenses()
			scene.call_next_wave()
			scene.god_spawn_army("mixed", 180)
		40:
			scene.god_spawn_boss("boss_molten")
		75:
			_snap("battle_%s_boss_intro" % GameState.current_map)
		140:
			_snap("battle_%s_a" % GameState.current_map)
			for i in scene.heroes.size():
				scene.cast_hero(i)
		160:
			_snap("battle_%s_abilities" % GameState.current_map)
		200:
			var e = scene.enemies.enemies
			if e.size() > 0:
				scene.spells.cast("meteor_shower", e[0].pos)
				scene.spells.cast("frost_nova", e[min(5, e.size() - 1)].pos)
				scene.spells.cast("lightning", e[e.size() / 2].pos)
		245:
			_snap("battle_%s_spells" % GameState.current_map)
		255:
			scene.select_pad(0)
		270:
			_snap("battle_%s_sheet" % GameState.current_map)
			scene.deselect()
			scene.offer_blessing()
		290:
			_snap("battle_%s_blessing" % GameState.current_map)
			scene.pick_blessing("inferno")
			scene.pick_blessing("permafrost")
		300:
			scene.hud.open_god_panel()
		325:
			_snap("battle_%s_god" % GameState.current_map)
			get_tree().quit()
