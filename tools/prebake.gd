extends SceneTree
## Pre-bakes character animation frames and FX textures into res://assets/prebaked/ so
## exported phone builds start without the multi-second first-launch bake.
##   godot --headless -s res://tools/prebake.gd
## (assets/prebaked/ is generated, git-ignored, and refreshed by tools/build_mobile.sh)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(UnitBaker.PREBAKED_DIR)
	DirAccess.make_dir_recursive_absolute(FXTextures.PREBAKED)
	for config in UnitBaker.CONFIGS:
		var frames := UnitBaker._bake(config)
		var holder := Resource.new()
		holder.set_meta("frames", frames)
		var out := UnitBaker.PREBAKED_DIR + "%s_v%d.res" % [config, UnitBaker.BAKE_VERSION]
		print("prebake ", out, " -> ", ResourceSaver.save(holder, out, ResourceSaver.FLAG_COMPRESS))
	for n in FXTextures.NAMES:
		var img := FXTextures._generate(n)
		var out := FXTextures.PREBAKED + "%s_v%d.res" % [n, FXTextures.VERSION]
		print("prebake ", out, " -> ", ResourceSaver.save(img, out))
	quit()
