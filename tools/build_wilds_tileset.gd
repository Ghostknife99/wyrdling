extends SceneTree

func _initialize() -> void:
	var builder = load("res://src/dungeon/wilds_tileset.gd")
	var ts: TileSet = builder.build()
	var err := ResourceSaver.save(ts, "res://art/tiles/overworld/wilds_tileset.tres")
	print("saved wilds_tileset.tres err=", err, " sources=", ts.get_source_count())
	quit(0 if err == OK else 1)
