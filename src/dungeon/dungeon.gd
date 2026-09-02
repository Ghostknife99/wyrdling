extends Node2D

const TILE := 32
const SPRITE := 48
const HUD_H := 48
const GOLD := Color("E8C872")  # lantern accent, locked hex
const INK := Color(0.94, 0.91, 0.84)
const MUTED := Color(0.70, 0.66, 0.58)

const CLIFF := 0
const GRASS := 1
const STAIRS := 2
const DIRT := 3
const PATH := 3
const WATER := 4
const TALLGRASS := 5
const TALL_GRASS := 5
const TREE := 6
const FENCE := 7

const OW_NAMES: PackedStringArray = [
	"grass", "grass_alt", "path", "water", "tallgrass", "cliff", "cliff_top",
	"cliff_top_w", "cliff_top_e",
	"path_n", "path_e", "path_s", "path_w", "path_ne", "path_nw", "path_se", "path_sw",
	"water_n", "water_e", "water_s", "water_w", "water_ne", "water_nw", "water_se", "water_sw",
	"tallgrass_n", "tallgrass_e", "tallgrass_s", "tallgrass_w",
	"tallgrass_ne", "tallgrass_nw", "tallgrass_se", "tallgrass_sw",
	"cliff_n", "cliff_e", "cliff_s", "cliff_w", "cliff_ne", "cliff_nw", "cliff_se", "cliff_sw",
	"fence_h", "fence_v", "fence_post", "fence_nw", "fence_ne", "fence_sw", "fence_se",
	"tree", "tree_nw", "tree_ne", "tree_sw", "tree_se",
]

var tex: Dictionary = {}
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
var cam: Camera2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for n in OW_NAMES:
		tex[n] = _load_tex(n, "")
	tex_stairs = _load_tex("stairs", "res://art/tiles/stairs.png")
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


func _load_tex(tile_name: String, fallback_path: String) -> Texture2D:
	var aliases := {
		"path": "dirt",
		"tallgrass": "tall_grass",
	}
	var wilds_name: String = str(aliases.get(tile_name, tile_name))
	var wilds_path := "res://art/tiles/wilds/%s.png" % wilds_name
	if ResourceLoader.exists(wilds_path):
		return load(wilds_path) as Texture2D
	var p := "res://art/tiles/overworld/%s.png" % tile_name
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	if fallback_path != "" and ResourceLoader.exists(fallback_path):
		return load(fallback_path) as Texture2D
	if tile_name in ["grass", "grass_alt", "path", "dirt"] and ResourceLoader.exists("res://art/tiles/floor.png"):
		return load("res://art/tiles/floor.png") as Texture2D
	if tile_name in ["cliff", "wall"] and ResourceLoader.exists("res://art/tiles/wall.png"):
		return load("res://art/tiles/wall.png") as Texture2D
	return null


func _ow(tile_name: String) -> Texture2D:
	return tex.get(tile_name, null) as Texture2D


func _blit(tile_name: String, dest: Rect2) -> void:
	var t: Texture2D = _ow(tile_name)
	if t:
		draw_texture_rect(t, dest, false)


func _build_camera() -> void:
	cam = Camera2D.new()
	cam.enabled = true
	cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	cam.position_smoothing_enabled = false
	cam.offset = Vector2.ZERO
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


func _is_pathish(t: int) -> bool:
	return t == PATH or t == STAIRS


func _is_soft(t: int) -> bool:
	return t == GRASS or t == PATH or t == STAIRS or t == TALLGRASS or t == TREE or t == FENCE


func _draw() -> void:
	if GameState.grid.is_empty():
		return
	var gw: int = GameState.MAP_W
	var gh: int = GameState.MAP_H

	# 1. Ground fills + path/water/tallgrass/cliff stitches + tree trunks
	for y in gh:
		for x in gw:
			var t: int = int(GameState.grid[y][x])
			var dest := Rect2(x * TILE, y * TILE, TILE, TILE)
			var role := _tree_role(x, y)
			match t:
				CLIFF:
					_blit("cliff", dest)
					_draw_cliff_edges(x, y, dest)
				WATER:
					_blit("water", dest)
				PATH:
					_blit("path", dest)
				STAIRS:
					_blit("path", dest)
					if tex_stairs:
						draw_texture_rect(tex_stairs, dest, false)
				TREE:
					_blit(_grass_name(x, y), dest)
				FENCE:
					_blit(_grass_name(x, y), dest)
				TALLGRASS:
					_blit(_grass_name(x, y), dest)
				_:
					_blit(_grass_name(x, y), dest)
			if t == GRASS or t == TALLGRASS:
				_draw_stitches(x, y, dest)
			if t == GRASS or t == PATH or t == TALLGRASS or t == STAIRS:
				_draw_cliff_top(x, y, dest)

	for nw in GameState.trees:
		var tp: Vector2i = nw
		_blit("tree_sw", Rect2(tp.x * TILE, (tp.y + 1) * TILE, TILE, TILE))
		_blit("tree_se", Rect2((tp.x + 1) * TILE, (tp.y + 1) * TILE, TILE, TILE))

	# 2. Fence deco from map_gen kinds (h/v/post + yard corners)
	for f in GameState.fence:
		_draw_fence_kind(f["pos"], str(f["kind"]))

	# 3. Y-sort: tree canopy (kind 0), wilds (1), player (2)
	var marks: Array = []
	for nw in GameState.trees:
		var tp: Vector2i = nw
		marks.append({"y": tp.y + 1, "kind": 0, "pos": tp})
	for w in GameState.wilds:
		var p: Vector2i = w["pos"]
		marks.append({"y": p.y, "kind": 1, "pos": p, "wild": w})
	var pp: Vector2i = GameState.player_pos
	marks.append({"y": pp.y, "kind": 2, "pos": pp})
	marks.sort_custom(_sort_marks)
	for m in marks:
		var kind: int = int(m["kind"])
		if kind == 0:
			_draw_tree_canopy(m["pos"])
		elif kind == 1:
			var p: Vector2i = m["pos"]
			var c: WyrdlingCreature = m["wild"]["creature"]
			var ctex: Texture2D = creature_tex.get(c.species_id, tex_player)
			draw_texture_rect(ctex, _sprite_dest(p), false)
		else:
			var ptex: Texture2D = player_facing.get(last_dir, tex_player)
			draw_texture_rect(ptex, _sprite_dest(pp), false)

	# Tall grass last so blades hide feet of delver/wilds on that tile.
	for y in gh:
		for x in gw:
			if int(GameState.grid[y][x]) == TALLGRASS:
				_blit("tallgrass", Rect2(x * TILE, y * TILE, TILE, TILE))


func _grass_name(x: int, y: int) -> String:
	if (x + y) % 2 == 0:
		return "grass"
	return "grass_alt"


func _tree_role(x: int, y: int) -> String:
	if _tile_at(x, y) != TREE:
		return ""
	if _tile_at(x + 1, y) == TREE and _tile_at(x, y + 1) == TREE and _tile_at(x + 1, y + 1) == TREE:
		return "nw"
	if _tile_at(x - 1, y) == TREE and _tile_at(x - 1, y + 1) == TREE and _tile_at(x, y + 1) == TREE:
		return "ne"
	if _tile_at(x + 1, y) == TREE and _tile_at(x, y - 1) == TREE and _tile_at(x + 1, y - 1) == TREE:
		return "sw"
	if _tile_at(x - 1, y) == TREE and _tile_at(x - 1, y - 1) == TREE and _tile_at(x, y - 1) == TREE:
		return "se"
	return "lone"


func _draw_stitches(x: int, y: int, dest: Rect2) -> void:
	var dirs: Array = [
		[Vector2i(0, -1), "n"],
		[Vector2i(1, 0), "e"],
		[Vector2i(0, 1), "s"],
		[Vector2i(-1, 0), "w"],
		[Vector2i(1, -1), "ne"],
		[Vector2i(-1, -1), "nw"],
		[Vector2i(1, 1), "se"],
		[Vector2i(-1, 1), "sw"],
	]
	for pair in dirs:
		var d: Vector2i = pair[0]
		var key: String = str(pair[1])
		var nt: int = _tile_at(x + d.x, y + d.y)
		if nt == WATER:
			_blit("water_" + key, dest)
		if _is_pathish(nt):
			_blit("path_" + key, dest)
	if _tile_at(x, y) == GRASS:
		_blit_ortho_stitches(x, y, dest, TALLGRASS, "tallgrass", false)


func _match_id(t: int, want: int, pathish: bool) -> bool:
	if pathish:
		return _is_pathish(t)
	return t == want


func _blit_ortho_stitches(x: int, y: int, dest: Rect2, want: int, prefix: String, pathish: bool) -> void:
	var n := _match_id(_tile_at(x, y - 1), want, pathish)
	var e := _match_id(_tile_at(x + 1, y), want, pathish)
	var s := _match_id(_tile_at(x, y + 1), want, pathish)
	var w := _match_id(_tile_at(x - 1, y), want, pathish)
	if n and e and not s and not w:
		_blit("%s_ne" % prefix, dest)
	elif n and w and not s and not e:
		_blit("%s_nw" % prefix, dest)
	elif s and e and not n and not w:
		_blit("%s_se" % prefix, dest)
	elif s and w and not n and not e:
		_blit("%s_sw" % prefix, dest)
	else:
		if n:
			_blit("%s_n" % prefix, dest)
		if e:
			_blit("%s_e" % prefix, dest)
		if s:
			_blit("%s_s" % prefix, dest)
		if w:
			_blit("%s_w" % prefix, dest)


func _draw_cliff_edges(x: int, y: int, dest: Rect2) -> void:
	var n := _is_soft(_tile_at(x, y - 1))
	var e := _is_soft(_tile_at(x + 1, y))
	var s := _is_soft(_tile_at(x, y + 1))
	var w := _is_soft(_tile_at(x - 1, y))
	# Occupancy: cliff_{dir} = cliff on that side, grass toward the open neighbor.
	if n and e and not s and not w:
		_blit("cliff_sw", dest)
	elif n and w and not s and not e:
		_blit("cliff_se", dest)
	elif s and e and not n and not w:
		_blit("cliff_nw", dest)
	elif s and w and not n and not e:
		_blit("cliff_ne", dest)
	else:
		if n:
			_blit("cliff_s", dest)
		if e:
			_blit("cliff_w", dest)
		if s:
			_blit("cliff_n", dest)
		if w:
			_blit("cliff_e", dest)


func _draw_cliff_top(x: int, y: int, dest: Rect2) -> void:
	if _tile_at(x, y + 1) != CLIFF:
		return
	var west_n := _tile_at(x - 1, y)
	var east_n := _tile_at(x + 1, y)
	var west_face := _tile_at(x - 1, y + 1) == CLIFF
	var east_face := _tile_at(x + 1, y + 1) == CLIFF
	var west_end := west_n == CLIFF or not west_face
	var east_end := east_n == CLIFF or not east_face
	if west_end and not east_end:
		_blit("cliff_top_w", dest)
	elif east_end and not west_end:
		_blit("cliff_top_e", dest)
	else:
		_blit("cliff_top", dest)


func _draw_fence_kind(fp: Vector2i, kind: String) -> void:
	var dest := Rect2(fp.x * TILE, fp.y * TILE, TILE, TILE)
	match kind:
		"h":
			_blit("fence_h", dest)
		"v":
			_blit("fence_v", dest)
		"nw":
			_blit("fence_nw", dest)
		"ne":
			_blit("fence_ne", dest)
		"sw":
			_blit("fence_sw", dest)
		"se":
			_blit("fence_se", dest)
		_:
			_blit("fence_post", dest)


func _draw_tree_canopy(tp: Vector2i) -> void:
	var nw_tex: Texture2D = _ow("tree_nw")
	var ne_tex: Texture2D = _ow("tree_ne")
	if nw_tex and ne_tex:
		draw_texture_rect(nw_tex, Rect2(tp.x * TILE, tp.y * TILE, TILE, TILE), false)
		draw_texture_rect(ne_tex, Rect2((tp.x + 1) * TILE, tp.y * TILE, TILE, TILE), false)
		return
	var tree_tex: Texture2D = _ow("tree")
	if tree_tex:
		draw_texture_rect(tree_tex, Rect2(tp.x * TILE, tp.y * TILE, TILE * 2, TILE * 2), false)


func _sort_marks(a: Dictionary, b: Dictionary) -> bool:
	if int(a["y"]) != int(b["y"]):
		return int(a["y"]) < int(b["y"])
	return int(a["kind"]) < int(b["kind"])


func _sprite_dest(p: Vector2i) -> Rect2:
	# Bottom-align 48px sprites on the 32px tile so heads overflow north (GBA 3/4).
	return Rect2(
		p.x * TILE + (TILE - SPRITE) / 2.0,
		p.y * TILE + TILE - SPRITE,
		SPRITE,
		SPRITE
	)


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
