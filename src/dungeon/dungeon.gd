extends Node2D

const TILE := 32
const SPRITE := 48
const HUD_H := 48
const GOLD := Color("E8C872")
const INK := Color(0.94, 0.91, 0.84)
const MUTED := Color(0.70, 0.66, 0.58)

const CLIFF := 0
const GRASS := 1
const STAIRS := 2
const DIRT := 3
const WATER := 4
const TALL_GRASS := 5
const TREE := 6
const FENCE := 7

var tex_cliff: Texture2D
var tex_grass: Texture2D
var tex_grass_alt: Texture2D
var tex_dirt: Texture2D
var tex_water: Texture2D
var tex_stairs: Texture2D
var tex_tall_grass: Texture2D
var tex_tree: Texture2D
var tex_fence_h: Texture2D
var tex_fence_v: Texture2D
var tex_fence_post: Texture2D
var tex_shore_n: Texture2D
var tex_shore_e: Texture2D
var tex_shore_s: Texture2D
var tex_shore_w: Texture2D
var tex_wall: Texture2D
var tex_floor: Texture2D
var tex_floor_alt: Texture2D
var tex_player: Texture2D
var player_facing: Dictionary = {}
var last_dir: String = "down"
var creature_tex: Dictionary = {}
var combat_open := false
var hud: CanvasLayer
var floor_label: Label
var party_label: Label
var log_label: Label
var cam: Camera2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex_wall = _load_tex("cliff", "res://art/tiles/wall.png")
	tex_floor = _load_tex("grass", "res://art/tiles/floor.png")
	tex_floor_alt = _load_tex("grass_alt", "res://art/tiles/floor_alt.png")
	tex_cliff = _load_tex("cliff", "res://art/tiles/wall.png")
	tex_grass = _load_tex("grass", "res://art/tiles/floor.png")
	tex_grass_alt = _load_tex("grass_alt", "res://art/tiles/floor_alt.png")
	tex_dirt = _load_tex("dirt", "res://art/tiles/floor.png")
	tex_water = _load_tex("water", "res://art/tiles/floor.png")
	tex_stairs = _load_tex("stairs", "res://art/tiles/stairs.png")
	tex_tall_grass = _load_tex("tall_grass", "")
	tex_tree = _load_tex("tree", "")
	tex_fence_h = _load_tex("fence_h", "")
	tex_fence_v = _load_tex("fence_v", "")
	tex_fence_post = _load_tex("fence_post", "")
	tex_shore_n = _load_tex("shore_n", "")
	tex_shore_e = _load_tex("shore_e", "")
	tex_shore_s = _load_tex("shore_s", "")
	tex_shore_w = _load_tex("shore_w", "")
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
	_build_camera()
	_build_hud()
	_refresh()


func _load_tex(wilds_name: String, fallback_path: String) -> Texture2D:
	var p := "res://art/tiles/wilds/%s.png" % wilds_name
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	if fallback_path != "" and ResourceLoader.exists(fallback_path):
		return load(fallback_path) as Texture2D
	return null


func _build_camera() -> void:
	cam = Camera2D.new()
	cam.enabled = true
	cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.make_current()


func _update_camera() -> void:
	if cam == null:
		return
	var pp: Vector2i = GameState.player_pos
	cam.position = Vector2(pp.x * TILE + TILE / 2.0, pp.y * TILE + TILE / 2.0)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = GameState.MAP_W * TILE
	cam.limit_bottom = GameState.MAP_H * TILE


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
	_update_camera()
	floor_label.text = "Wilds %d" % GameState.floor_num
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
		log_label.text = "Walking the wilds. Tall grass hides encounters. Gold rift-gate descends."
	queue_redraw()


func _tile_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= GameState.MAP_W or y >= GameState.MAP_H:
		return CLIFF
	if GameState.grid.is_empty():
		return CLIFF
	return int(GameState.grid[y][x])


func _is_water(x: int, y: int) -> bool:
	return _tile_at(x, y) == WATER


func _is_land(t: int) -> bool:
	return t != WATER and t != CLIFF


func _draw() -> void:
	if GameState.grid.is_empty():
		return
	var gw: int = GameState.MAP_W
	var gh: int = GameState.MAP_H

	for y in gh:
		for x in gw:
			var t: int = int(GameState.grid[y][x])
			var dest := Rect2(x * TILE, y * TILE, TILE, TILE)
			match t:
				CLIFF:
					_blit(tex_cliff, dest, tex_wall)
				WATER:
					_blit(tex_water, dest, tex_floor)
				STAIRS:
					_blit(tex_stairs, dest, tex_floor)
				DIRT:
					_blit(tex_dirt, dest, tex_floor)
				_:
					var ft: Texture2D = tex_grass if ((x + y) % 2 == 0) else tex_grass_alt
					if ft == null:
						ft = tex_floor if ((x + y) % 2 == 0) else tex_floor_alt
					if ft:
						draw_texture_rect(ft, dest, false)
			if _is_land(t):
				_draw_shores(x, y, dest)

	for y in gh:
		for x in gw:
			if int(GameState.grid[y][x]) == FENCE:
				_draw_fence(x, y)

	var marks: Array = []
	for w in GameState.wilds:
		var p: Vector2i = w["pos"]
		marks.append({"y": p.y, "kind": 1, "pos": p, "wild": w})
	var pp: Vector2i = GameState.player_pos
	marks.append({"y": pp.y, "kind": 2, "pos": pp})
	for y in gh:
		for x in gw:
			if int(GameState.grid[y][x]) == TREE:
				marks.append({"y": y, "kind": 0, "pos": Vector2i(x, y)})
	marks.sort_custom(_sort_marks)
	for m in marks:
		var kind: int = int(m["kind"])
		if kind == 0:
			var tp: Vector2i = m["pos"]
			if tex_tree:
				draw_texture_rect(tex_tree, Rect2(tp.x * TILE, tp.y * TILE - TILE, TILE, TILE * 2), false)
		elif kind == 1:
			var p: Vector2i = m["pos"]
			var c: WyrdlingCreature = m["wild"]["creature"]
			var tex: Texture2D = creature_tex.get(c.species_id, tex_player)
			draw_texture_rect(tex, _sprite_dest(p), false)
		else:
			var ptex: Texture2D = player_facing.get(last_dir, tex_player)
			draw_texture_rect(ptex, _sprite_dest(pp), false)

	if tex_tall_grass:
		for y in gh:
			for x in gw:
				if int(GameState.grid[y][x]) == TALL_GRASS:
					draw_texture_rect(tex_tall_grass, Rect2(x * TILE, y * TILE, TILE, TILE), false)


func _sort_marks(a: Dictionary, b: Dictionary) -> bool:
	if int(a["y"]) != int(b["y"]):
		return int(a["y"]) < int(b["y"])
	return int(a["kind"]) < int(b["kind"])


func _sprite_dest(p: Vector2i) -> Rect2:
	return Rect2(
		p.x * TILE + (TILE - SPRITE) / 2.0,
		p.y * TILE + TILE - SPRITE,
		SPRITE,
		SPRITE
	)


func _blit(tex: Texture2D, dest: Rect2, fallback: Texture2D) -> void:
	var t: Texture2D = tex if tex else fallback
	if t:
		draw_texture_rect(t, dest, false)


func _draw_shores(x: int, y: int, dest: Rect2) -> void:
	if _is_water(x, y - 1) and tex_shore_n:
		draw_texture_rect(tex_shore_n, dest, false)
	if _is_water(x + 1, y) and tex_shore_e:
		draw_texture_rect(tex_shore_e, dest, false)
	if _is_water(x, y + 1) and tex_shore_s:
		draw_texture_rect(tex_shore_s, dest, false)
	if _is_water(x - 1, y) and tex_shore_w:
		draw_texture_rect(tex_shore_w, dest, false)


func _draw_fence(x: int, y: int) -> void:
	var dest := Rect2(x * TILE, y * TILE, TILE, TILE)
	var n := _tile_at(x, y - 1) == FENCE
	var s := _tile_at(x, y + 1) == FENCE
	var e := _tile_at(x + 1, y) == FENCE
	var w := _tile_at(x - 1, y) == FENCE
	if (e or w) and tex_fence_h:
		draw_texture_rect(tex_fence_h, dest, false)
	if (n or s) and tex_fence_v:
		draw_texture_rect(tex_fence_v, dest, false)
	if tex_fence_post:
		draw_texture_rect(tex_fence_post, dest, false)


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
			GameState.push_log("You slipped back into the wilds.")
		_:
			pass
	_refresh()
