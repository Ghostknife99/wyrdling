extends SceneTree

func _init() -> void:
	var sheet_path := "res://art/player/delver_polished_sheet.png"
	if not ResourceLoader.exists(sheet_path):
		push_error("Missing polished Delver sprite sheet")
		quit(1)
		return
	var tex: Texture2D = load(sheet_path)
	if tex.get_width() != 96 or tex.get_height() != 136:
		push_error("Unexpected polished Delver sheet size: %dx%d" % [tex.get_width(), tex.get_height()])
		quit(1)
		return
	var script_text := FileAccess.get_file_as_string("res://src/dungeon/dungeon_16.gd")
	for required in ["delver_polished_sheet.png", "WALK_FRAME_MS", "polished_player_walk", "_current_player_frame"]:
		if script_text.find(required) < 0:
			push_error("Missing Delver animation hook: %s" % required)
			quit(1)
			return
	print("DELVER_ANIMATION_OK")
	quit(0)
