extends SceneTree

var failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK    " + label)
	else:
		print("FAIL  " + label)
		failures += 1


func _initialize() -> void:
	print("=== Wyrdling 16px world test ===")

	var packed: PackedScene = load("res://scenes/dungeon.tscn")
	_check(packed != null, "dungeon scene loads")
	if packed != null:
		var node: Node = packed.instantiate()
		var script: Script = node.get_script()
		_check(script != null and script.resource_path == "res://src/dungeon/dungeon_dense.gd", "dungeon uses dense 16px presentation script")

		# Density is a thin wrapper around the validated presentation layer. Read
		# scale constants from the base script so this smoke test remains explicit
		# about the 16px contract rather than depending on inherited constant maps.
		var base_script: Script = load("res://src/dungeon/dungeon_16.gd")
		_check(base_script != null, "base 16px presentation script loads")
		if base_script != null:
			var constants: Dictionary = base_script.get_script_constant_map()
			_check(int(constants.get("TILE_16", 0)) == 16, "logical world tile is 16px")
			_check(is_equal_approx(float(constants.get("TERRAIN_SCALE", 0.0)), 0.5), "terrain renders at half scale")
			_check(is_equal_approx(float(constants.get("CAMERA_SCALE", 0.0)), 2.0), "world camera is integer 2x")

		# Build the terrain layer without entering the scene tree. This confirms the
		# inherited, proven 32px TileSet still builds and is presented as an effective
		# 16px cell through exact half scaling.
		node.call("_ensure_world")
		var ground: TileMapLayer = node.get_node("World/Ground") as TileMapLayer
		_check(ground != null and ground.tile_set != null, "terrain TileSet builds")
		if ground != null and ground.tile_set != null:
			_check(ground.tile_set.tile_size == Vector2i(32, 32), "source terrain remains validated 32px")
			_check(ground.scale == Vector2(0.5, 0.5), "terrain cell renders as effective 16x16")
		node.free()

	if failures > 0:
		printerr("16px world test failed: %d checks" % failures)
		quit(1)
	else:
		print("16px world test passed")
		quit(0)
