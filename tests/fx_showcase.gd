extends Node
## Captures every spell and hero ultimate mid-effect (visual QA). Args: <out_dir>
var b
var f := 0
var queue: Array = []
var cur := ""
var t0 := 0.0
var clock := 0.0
var out_dir := ""

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	out_dir = OS.get_cmdline_user_args()[0]
	GameState.current_mode = "sandbox"
	b = load("res://scenes/battle.tscn").instantiate()
	add_child(b)
	for s in GameData.SPELL_ORDER:
		queue.append(["spell", s])
	for h in GameData.HERO_ORDER:
		queue.append(["hero", h])

func _army():
	b.god_kill_all()
	for i in 60:
		var e = b.enemies.spawn(GameData.REGULAR_TYPES[i % 5], i % 3, -34.0 - (i % 6) * 1.5)
		if e: e.speed = 0.6

func _process(d):
	f += 1
	clock += d
	if f < 5:
		return
	b._cam_look_z = -30.0
	if cur == "" and not queue.is_empty():
		var q = queue.pop_front()
		cur = "%s_%s" % [q[0], q[1]]
		_army()
		t0 = clock
		if q[0] == "spell":
			b.spells.force_cast(q[1], Vector3(0, 0, -36))
		else:
			var h := Hero.new()
			b.add_child(h)
			h.global_position = Vector3(0, 3.6, 0)
			h.setup(q[1], b)
			h.cast_ability()
			h.set_meta("tmp", true)
	elif cur != "":
		var wait := 0.3
		if cur.contains("meteor"): wait = 1.0
		if cur.contains("fireball"): wait = 0.75
		if cur.contains("lightning"): wait = 0.1
		if cur.contains("dragon"): wait = 1.6
		if cur.contains("storm_sorcerer") or cur.contains("archer"): wait = 0.8
		if cur.contains("divine_wrath") or cur.contains("firestorm") or cur.contains("fire_mage"): wait = 0.9
		if clock - t0 >= wait:
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("fx_" + cur + ".png"))
			print("saved ", cur)
			for c in b.get_children():
				if c.has_meta("tmp"): c.queue_free()
			cur = ""
	if cur == "" and queue.is_empty():
		get_tree().quit()
