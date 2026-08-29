extends SceneTree

func _initialize() -> void:
	var gs: Node = root.get_node("GameState")
	gs.start_run("briarseed")
	var d = load("res://scenes/dungeon.tscn")
	var c = load("res://scenes/combat.tscn")
	var s = load("res://scenes/starter.tscn")
	var t = load("res://main.tscn")
	if d == null or c == null or s == null or t == null:
		print("FAIL pack")
		quit(1)
		return
	var dungeon = d.instantiate()
	root.add_child(dungeon)
	print("OK dungeon instanced, wilds=", gs.wilds.size())
	if gs.wilds.size() > 0:
		var combat = c.instantiate()
		combat.setup(gs.wilds[0]["creature"])
		root.add_child(combat)
		print("OK combat instanced")
	print("=== BOOT OK ===")
	quit(0)
