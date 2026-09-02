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
	var source_path := "res://art/tiles/overworld/hd_atlas.png"
	_check(ResourceLoader.exists(source_path), "validated source atlas exists")
	var source: Texture2D = load(source_path)
	_check(source != null, "source atlas loads")

	var builder = preload("res://src/dungeon/wilds_tileset_16.gd")
	var runtime_tex: Texture2D = builder._make_16px_texture()
	_check(runtime_tex != null, "runtime 16px atlas builds")
	if runtime_tex != null:
		_check(runtime_tex.get_width() == 256 and runtime_tex.get_height() == 240, "runtime atlas is 256x240")

	var tileset: TileSet = builder.build()
	_check(tileset != null, "16px tileset builds")
	if tileset != null:
		_check(tileset.tile_size == Vector2i(16, 16), "logical tile size is 16x16")

	var packed: PackedScene = load("res://scenes/dungeon.tscn")
	_check(packed != null, "dungeon scene loads")
	if packed != null:
		var node: Node = packed.instantiate()
		var script: Script = node.get_script()
		_check(script != null and script.resource_path == "res://src/dungeon/dungeon_16.gd", "dungeon uses 16px presentation script")
		node.free()

	if failures > 0:
		printerr("16px world test failed: %d checks" % failures)
		quit(1)
	else:
		print("16px world test passed")
		quit(0)
