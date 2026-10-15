extends Node
## Loads the main menu and every game mode on every map for a few frames.
##   godot --headless res://tests/modes_test.tscn
var combos: Array = []
var cur: Node
var frames := 0

func _ready() -> void:
	combos.append(["menu", "verdant_pass"])
	for mode in GameData.MODE_ORDER:
		for map in GameData.MAP_ORDER:
			combos.append([mode, map])
	_next()

func _next() -> void:
	if cur:
		cur.queue_free()
	if combos.is_empty():
		print("=== MODES TEST DONE ===")
		get_tree().quit()
		return
	var c: Array = combos.pop_front()
	GameState.current_map = c[1]
	if c[0] == "menu":
		cur = load("res://scenes/main_menu.tscn").instantiate()
	else:
		GameState.current_mode = c[0]
		cur = load("res://scenes/battle.tscn").instantiate()
	add_child(cur)
	print("  loaded ", c[0], " / ", c[1])
	frames = 0

func _process(_d: float) -> void:
	frames += 1
	if frames == 20:
		if cur.has_method("call_next_wave"):
			cur.call_next_wave()
	if frames > 40:
		_next()
