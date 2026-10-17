extends Node
## Visual QA for the four boss encounters: intro, signature attack, enrage, death.
## Args: <out_dir>
var b
var out := ""
var bosses := ["boss_molten", "boss_lich", "boss_colossus", "boss_warlord"]
var i := 0
var stage := 0
var t0 := 0
var boss

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	out = OS.get_cmdline_user_args()[0]
	GameState.current_mode = "sandbox"
	b = load("res://scenes/battle.tscn").instantiate()
	add_child(b)
	t0 = Time.get_ticks_msec()

func _ms() -> int:
	return Time.get_ticks_msec() - t0

func _snap(tag: String):
	get_viewport().get_texture().get_image().save_png(out.path_join("boss_%s_%s.png" % [bosses[i], tag]))
	print("saved ", bosses[i], " ", tag)
	t0 = Time.get_ticks_msec()
	stage += 1

func _process(_d):
	if i >= bosses.size():
		get_tree().quit()
		return
	for h in b.heroes:
		h.process_mode = Node.PROCESS_MODE_DISABLED
	match stage:
		0:
			if _ms() > 800:
				b.god_kill_all()
				for k in 30:
					var e = b.enemies.spawn("orc", k % 3, -30.0 - k * 0.5)
					if e: e.speed = 0.3
				boss = b.enemies.spawn(bosses[i], 1, -26.0)
				boss.speed = 0.0
				t0 = Time.get_ticks_msec()
				stage = 1
		1:
			if _ms() > 1300: _snap("intro")
		2:
			if _ms() > 1800:
				match bosses[i]:
					"boss_molten": b.bosses._slam(boss)
					"boss_lich":
						b.bosses._summon(boss)
						b.bosses._soul_shield(boss)
					"boss_colossus": b.bosses._bone_spikes(boss)
					"boss_warlord": b.bosses._rally(boss)
				t0 = Time.get_ticks_msec()
				stage = 3
		3:
			if _ms() > 700: _snap("attack")
		4:
			if _ms() > 1500:
				b.enemies.damage(boss, boss.max_hp * 0.55, "physical", false, "god")
				boss.immune_t = 0.0
				t0 = Time.get_ticks_msec()
				stage = 5
		5:
			if _ms() > 900: _snap("enrage")
		6:
			if _ms() > 1500:
				boss.immune_t = 0.0
				b.enemies.damage(boss, 1e9, "physical", false, "god")
				t0 = Time.get_ticks_msec()
				stage = 7
		7:
			if _ms() > 1500: _snap("death")
		8:
			if _ms() > 2500:
				i += 1
				stage = 0
				t0 = Time.get_ticks_msec()
