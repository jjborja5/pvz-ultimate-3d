extends Node
## Loads and compiles every game script; exits 1 on any failure.
##   godot --headless res://tests/compile_check.tscn
func _ready() -> void:
	var failed := 0
	var count := 0
	for dir in ["res://scripts/autoload", "res://scripts/core", "res://scripts/battle", "res://scripts/ui"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				count += 1
				var s: GDScript = load(dir + "/" + f)
				if s == null or s.reload(true) != OK:
					print("FAIL ", dir, "/", f)
					failed += 1
	print("COMPILE CHECK: %d scripts, %s" % [count, "OK" if failed == 0 else "%d FAILED" % failed])
	get_tree().quit(1 if failed else 0)
