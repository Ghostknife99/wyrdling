extends Node2D

const TILE := 32
const SPRITE := 48
const HUD_H := 48
const GOLD := Color("E8C872")  # lantern accent, locked hex
const INK := Color(0.94, 0.91, 0.84)
const MUTED := Color(0.70, 0.66, 0.58)

var tex_wall: Texture2D
var tex_floor: Texture2D
var tex_floor_alt: Texture2D
var tex_stairs: Texture2D
var tex_player: Texture2D
var player_facing: Dictionary = {}
var last_dir: String = "down"
var creature_tex: Dictionary = {}
var combat_open := false
var hud: CanvasLayer
var floor_label: Label
var party_label: Label
var log_label: Label


func _ready() -> void:
	tex_wall = load("res://art/tiles/wall.png")
	tex_floor = load("res://art/tiles/floor.png")
	tex_floor_alt = load("res://art/tiles/floor_alt.png")
	tex_stairs = load("res://art/tiles/stairs.png")
	for facing in ["down", "up", "left", "right"]:
		var path := "res://art/player/delver_idle_%s.png" % facing
		if ResourceLoader.exists(path):
			player_facing[facing] = load(path)
	if ResourceLoader.exists("res://art/player/delver_idle_down.png"):
		tex_player = load("res://art/player/delver_idle_down.png")
	else:
		tex_player = load("res://art/player/player.png")
	for id in DataDB.creatures.keys():
		var cpath := "res://art/creatures/%s.png" % id
		if ResourceLoader.exists(cpath):
			creature_tex[id] = load(cpath)
	_build_hud()
	_refresh()


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var bar := ColorRect.new()
	bar.color = Color(0.06, 0.05, 0.08, 0.94)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1280, HUD_H)
	hud.add_child(bar)
	floor_label = Label.new()
	floor_label.position = Vector2(12, 8)
	floor_label.size = Vector2(280, 32)
	floor_label.add_theme_font_size_override("font_size", 20)
	floor_label.add_theme_color_override("font_color", GOLD)
	hud.add_child(floor_label)
	party_label = Label.new()
	party_label.position = Vector2(300, 8)
	party_label.size = Vector2(960, 32)
	party_label.add_theme_font_size_override("font_size", 18)
	party_label.add_theme_color_override("font_color", INK)
	hud.add_child(party_label)
	var bot := ColorRect.new()
	bot.color = Color(0.06, 0.05, 0.08, 0.88)
	bot.position = Vector2(0, 672)
	bot.size = Vector2(1280, 48)
	hud.add_child(bot)
	log_label = Label.new()
	log_label.position = Vector2(12, 676)
	log_label.size = Vector2(1256, 40)
	log_label.add_theme_font_size_override("font_size", 16)
	log_label.add_theme_color_override("font_color", MUTED)
	hud.add_child(log_label)


func _refresh() -> void:
	floor_label.text = "Floor %d" % GameState.floor_num
	var bits: PackedStringArray = PackedStringArray()
	for i in GameState.party.size():
		var c: WyrdlingCreature = GameState.party[i]
		if c == null:
			continue
		var mark := ">" if i == GameState.active_index else " "
		bits.append("%s%s %d/%d" % [mark, c.display_name, c.hp, c.max_hp])
	party_label.text = "  ·  ".join(bits)
	if GameState.dungeon_log.size() > 0:
		log_label.text = str(GameState.dungeon_log[GameState.dungeon_log.size() - 1])
	else:
		log_label.text = "WASD / arrows to walk. Gold tiles are stairs. Bump a wild to clash."
	queue_redraw()


func _draw() -> void:
	if GameState.grid.is_empty():
		return
	var yoff := HUD_H
	for y in GameState.MAP_H:
		for x in GameState.MAP_W:
			var t: int = int(GameState.grid[y][x])
			var dest := Rect2(x * TILE, y * TILE + yoff, TILE, TILE)
			match t:
				0:
					draw_texture_rect(tex_wall, dest, false)
				2:
					draw_texture_rect(tex_stairs, dest, false)
				_:
					var ft: Texture2D = tex_floor if ((x + y) % 2 == 0) else tex_floor_alt
					draw_texture_rect(ft, dest, false)
	for w in GameState.wilds:
		var p: Vector2i = w["pos"]
		var c: WyrdlingCreature = w["creature"]
		var tex: Texture2D = creature_tex.get(c.species_id, tex_player)
		var dest := Rect2(p.x * TILE + (TILE - SPRITE) / 2.0, p.y * TILE + yoff + (TILE - SPRITE) / 2.0, SPRITE, SPRITE)
		draw_texture_rect(tex, dest, false)
	var pp: Vector2i = GameState.player_pos
	var ptex: Texture2D = player_facing.get(last_dir, tex_player)
	draw_texture_rect(ptex, Rect2(pp.x * TILE + (TILE - SPRITE) / 2.0, pp.y * TILE + yoff + (TILE - SPRITE) / 2.0, SPRITE, SPRITE), false)


func _unhandled_input(event: InputEvent) -> void:
	if combat_open:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var dir := Vector2i.ZERO
	match event.keycode:
		KEY_W, KEY_UP:
			dir = Vector2i(0, -1)
			last_dir = "up"
		KEY_S, KEY_DOWN:
			dir = Vector2i(0, 1)
			last_dir = "down"
		KEY_A, KEY_LEFT:
			dir = Vector2i(-1, 0)
			last_dir = "left"
		KEY_D, KEY_RIGHT:
			dir = Vector2i(1, 0)
			last_dir = "right"
		_:
			return
	get_viewport().set_input_as_handled()
	_try_step(dir)


func _try_step(dir: Vector2i) -> void:
	var np: Vector2i = GameState.player_pos + dir
	var wi: int = GameState.wild_at(np)
	if wi >= 0:
		_open_combat(wi)
		return
	if not GameState.walkable(np):
		return
	GameState.player_pos = np
	if np == GameState.stairs_pos:
		GameState.descend()
		_refresh()
		return
	_wild_turn()
	_refresh()


func _wild_turn() -> void:
	var player: Vector2i = GameState.player_pos
	for i in GameState.wilds.size():
		var pos: Vector2i = GameState.wilds[i]["pos"]
		var nxt: Vector2i = pos
		if pos.distance_to(player) <= 6.0:
			nxt = _step_toward(pos, player)
			if not GameState.walkable(nxt) or GameState.occupied_by_wild(nxt, i):
				nxt = pos
		else:
			var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			dirs.shuffle()
			nxt = pos
			for d in dirs:
				var cand: Vector2i = pos + d
				if GameState.walkable(cand) and not GameState.occupied_by_wild(cand, i) and cand != player:
					nxt = cand
					break
		if nxt == player:
			GameState.wilds[i]["pos"] = pos
			_open_combat(i)
			return
		GameState.wilds[i]["pos"] = nxt


func _step_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	var d: Vector2i = to - from
	if absi(d.x) >= absi(d.y):
		return from + Vector2i(signi(d.x), 0)
	return from + Vector2i(0, signi(d.y))


func _open_combat(wild_index: int) -> void:
	if combat_open:
		return
	combat_open = true
	var wild: WyrdlingCreature = GameState.wilds[wild_index]["creature"]
	GameState.push_log("A wild %s bars the way." % wild.display_name)
	var combat: Control = preload("res://scenes/combat.tscn").instantiate()
	combat.setup(wild)
	combat.combat_over.connect(_on_combat_over)
	hud.add_child(combat)
	_refresh()


func _on_combat_over(result: String) -> void:
	combat_open = false
	if result == "wiped":
		GameState.end_run()
		get_tree().change_scene_to_file("res://scenes/title.tscn")
		return
	match result:
		"won":
			GameState.push_log("The wild Wyrdling scattered into rift-dust.")
		"caught":
			GameState.push_log("Bound. The party shifts.")
		"fled":
			GameState.push_log("You slipped back into the dark.")
		_:
			pass
	_refresh()
