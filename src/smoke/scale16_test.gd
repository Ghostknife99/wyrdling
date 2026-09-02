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
	var atlas_path := "res://art/tiles/overworld/wilds_atlas_16.png"
	_check(ResourceLoader.exists(atlas_path), "16px atlas exists")
	var atlas: Texture2D = load(atlas_path)
	_check(atlas != null, "16px atlas loads")
	if atlas != null:
		_check(atlas.get_width() == 256 and atlas.get_height() == 240, "atlas is 256x240")

	var tileset: TileSet = preload("res://src/dungeon/wilds_tileset_16.gd").build()
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
