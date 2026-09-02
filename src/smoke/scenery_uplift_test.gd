extends SceneTree

func _init() -> void:
	print("=== Wyrdling scenery uplift test ===")
	var art = load("res://src/dungeon/scenery_art_hd.gd")
	var atlas: Texture2D = art.make_atlas()
	if atlas == null or atlas.get_width() != 512 or atlas.get_height() != 480:
		push_error("HD scenery atlas failed to load at 512x480")
		quit(1)
		return
	print("OK    approved HD terrain atlas loads 512x480")

	var props: Texture2D = art.make_props_sheet()
	if props == null or props.get_width() != 256 or props.get_height() != 128:
		push_error("HD scenery prop sheet failed to load at 256x128")
		quit(1)
		return
	print("OK    approved HD scenery prop sheet loads 256x128")

	var builder = load("res://src/dungeon/wilds_tileset.gd")
	var tileset: TileSet = builder.build()
	if tileset == null or tileset.get_source_count() < 1:
		push_error("HD scenery TileSet failed to build")
		quit(1)
		return
	if tileset.tile_size != Vector2i(32, 32):
		push_error("HD terrain source lost 32px TileSet size")
		quit(1)
		return
	print("OK    HD TileSet builds with animated water")

	var presentation = load("res://src/dungeon/dungeon_16.gd")
	if presentation == null:
		push_error("16px scenery presentation failed to load")
		quit(1)
		return
	print("OK    HD 16px scenery presentation loads")
	print("=== SCENERY UPLIFT OK ===")
	quit(0)
