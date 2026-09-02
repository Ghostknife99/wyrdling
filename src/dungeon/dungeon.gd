extends Node2D

const TILE := 32
const SPRITE := 42
const INK := Color("26333A")
const PAPER := Color("F8F7E8")
const GREEN_DARK := Color("245C49")
const MUTED := Color("66766F")

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

const T_GRASS := 0
const T_PATH := 1
const T_WATER := 2

const C := {
	"grass": Vector2i(0, 0),
	"grass_alt": Vector2i(1, 0),
	"cliff": Vector2i(2, 0),
	"cliff_top": Vector2i(3, 0),
	"stairs": Vector2i(4, 0),
	"tallgrass": Vector2i(5, 0),
	"tallgrass_rustle": Vector2i(6, 0),
	"fence_h": Vector2i(7, 0),
	"fence_v": Vector2i(8, 0),
	"fence_post": Vector2i(9, 0),
	"fence_nw": Vector2i(10, 0),
	"fence_ne": Vector2i(11, 0),
	"fence_sw": Vector2i(12, 0),
	"fence_se": Vector2i(13, 0),
	"tree_nw": Vector2i(14, 0),
	"tree_ne": Vector2i(15, 0),
	"tree_sw": Vector2i(0, 1),
	"tree_se": Vector2i(1, 1),
}

var tex_player: Texture2D
var player_facing: Dictionary = {}
var last_dir: String = "down"
var creature_tex: Dictionary = {}
var combat_open := false
var moving := false

var hud: CanvasLayer
var floor_label: Label
var location_panel: Panel
var location_timer: Timer
var toast_panel: Panel
var log_label: Label
var toast_timer: Timer
var last_toast := ""
var cam: Camera2D

var world: Node2D
var ground: TileMapLayer
var deco: TileMapLayer
var overlay: TileMapLayer
var player_sprite: Sprite2D
var wild_sprites: Array[Sprite2D] = []
var tileset: TileSet
var rustle_cell := Vector2i(-999, -999)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_ensure_world()
	_build_camera()
	_build_hud()
	_paint_map()
	_refresh()
	_show_location()


func _style(fill: Color, border: Color = GREEN_DARK, width: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	return sb


func _ensure_world() -> void:
	var builder = load("res://src/dungeon/wilds_tileset.gd")
	tileset = builder.build()
	world = get_node_or_null("World") as Node2D
	if world == null:
		world = Node2D.new()
		world.name = "World"
		add_child(world)
	world.y_sort_enabled = true
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	ground = world.get_node_or_null("Ground") as TileMapLayer
	if ground == null:
		ground = TileMapLayer.new()
		ground.name = "Ground"
		world.add_child(ground)
	deco = world.get_node_or_null("Deco") as TileMapLayer
	if deco == null:
		deco = TileMapLayer.new()
		deco.name = "Deco"
		world.add_child(deco)
	overlay = world.get_node_or_null("Overlay") as TileMapLayer
	if overlay == null:
		overlay = TileMapLayer.new()
		overlay.name = "Overlay"
		world.add_child(overlay)
	player_sprite = world.get_node_or_null("Player") as Sprite2D
	if player_sprite == null:
		player_sprite = Sprite2D.new()
		player_sprite.name = "Player"
		world.add_child(player_sprite)

	for layer in [ground, deco, overlay]:
		layer.tile_set = tileset
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.y_sort_enabled = false
	deco.y_sort_enabled = true
	overlay.y_sort_enabled = true
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_sprite.centered = false
	player_sprite.texture = tex_player
	_fit_sprite(player_sprite, tex_player)


func _fit_sprite(spr: Sprite2D, tex: Texture2D) -> void:
	if tex == null:
		return
	spr.texture = tex
	spr.centered = false
	var tw := float(maxi(tex.get_width(), 1))
	var th := float(maxi(tex.get_height(), 1))
	spr.scale = Vector2(float(SPRITE) / tw, float(SPRITE) / th)
	spr.offset = Vector2(-tw / 2.0, -th)


func _actor_pos(p: Vector2i) -> Vector2:
	return Vector2(p.x * TILE + TILE / 2.0, p.y * TILE + TILE)


func _build_camera() -> void:
	cam = get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		cam = Camera2D.new()
		cam.name = "Camera2D"
		add_child(cam)
	cam.enabled = true
	cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 11.0
	cam.zoom = Vector2.ONE
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

	location_panel = Panel.new()
	location_panel.position = Vector2(14, 14)
	location_panel.size = Vector2(212, 44)
	location_panel.add_theme_stylebox_override("panel", _style(Color(0.97, 0.98, 0.91, 0.96), GREEN_DARK, 3))
	hud.add_child(location_panel)

	floor_label = Label.new()
	floor_label.position = Vector2(12, 8)
	floor_label.size = Vector2(188, 28)
	floor_label.add_theme_font_size_override("font_size", 16)
	floor_label.add_theme_color_override("font_color", INK)
	floor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	location_panel.add_child(floor_label)

	location_timer = Timer.new()
	location_timer.one_shot = true
	location_timer.wait_time = 2.4
	location_timer.timeout.connect(func() -> void: location_panel.visible = false)
	hud.add_child(location_timer)

	toast_panel = Panel.new()
	toast_panel.position = Vector2(14, 312)
	toast_panel.size = Vector2(392, 34)
	toast_panel.visible = false
	toast_panel.add_theme_stylebox_override("panel", _style(Color(0.97, 0.98, 0.91, 0.94), Color("6B776F"), 2))
	hud.add_child(toast_panel)

	log_label = Label.new()
	log_label.position = Vector2(10, 5)
	log_label.size = Vector2(372, 24)
	log_label.add_theme_font_size_override("font_size", 11)
	log_label.add_theme_color_override("font_color", MUTED)
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_panel.add_child(log_label)

	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 2.2
	toast_timer.timeout.connect(func() -> void: toast_panel.visible = false)
	hud.add_child(toast_timer)


func _show_location() -> void:
	floor_label.text = "RIFT WILDS  •  AREA %02d" % GameState.floor_num
	location_panel.visible = true
	location_timer.start()


func _show_toast(text: String) -> void:
	if text.is_empty() or text == last_toast:
		return
	last_toast = text
	log_label.text = text
	toast_panel.visible = true
	toast_timer.start()


func _paint_map() -> void:
	if ground == null or GameState.grid.is_empty():
		return
	ground.clear()
	deco.clear()
	overlay.clear()
	var gw: int = GameState.MAP_W
	var gh: int = GameState.MAP_H
	var WT = preload("res://src/dungeon/wilds_tileset.gd")

	for y in gh:
		for x in gw:
			var t: int = int(GameState.grid[y][x])
			var c := Vector2i(x, y)
			if t == CLIFF:
				ground.set_cell(c, 0, C["cliff"])
			elif t == WATER:
				var idx: int = int(WT.atlas_index(_blob_mask(x, y, WATER, false)))
				ground.set_cell(c, 0, WT.water_coords(idx))
			elif t == PATH or t == STAIRS:
				var idx2: int = int(WT.atlas_index(_blob_mask(x, y, PATH, true)))
				ground.set_cell(c, 0, WT.path_coords(idx2))
			else:
				ground.set_cell(c, 0, C["grass_alt"] if (x + y) % 5 == 0 else C["grass"])

	deco.set_cell(GameState.stairs_pos, 0, C["stairs"])
	for y in gh:
		for x in gw:
			var t: int = int(GameState.grid[y][x])
			if t == CLIFF:
				continue
			if y + 1 < gh and int(GameState.grid[y + 1][x]) == CLIFF:
				deco.set_cell(Vector2i(x, y), 0, C["cliff_top"])

	for f in GameState.fence:
		var kind := str(f["kind"])
		var key := "fence_post"
		match kind:
			"h": key = "fence_h"
			"v": key = "fence_v"
			"nw": key = "fence_nw"
			"ne": key = "fence_ne"
			"sw": key = "fence_sw"
			"se": key = "fence_se"
			_: key = "fence_post"
		deco.set_cell(f["pos"], 0, C[key])

	for y in gh:
		for x in gw:
			if int(GameState.grid[y][x]) == TALLGRASS:
				overlay.set_cell(Vector2i(x, y), 0, C["tallgrass"])

	for nw in GameState.trees:
		var tp: Vector2i = nw
		overlay.set_cell(tp, 0, C["tree_nw"])
		overlay.set_cell(tp + Vector2i(1, 0), 0, C["tree_ne"])
		deco.set_cell(tp + Vector2i(0, 1), 0, C["tree_sw"])
		deco.set_cell(tp + Vector2i(1, 1), 0, C["tree_se"])
		overlay.erase_cell(tp + Vector2i(0, 1))
		overlay.erase_cell(tp + Vector2i(1, 1))

	rustle_cell = Vector2i(-999, -999)
	_apply_rustle()


func _apply_rustle() -> void:
	if overlay == null or GameState.grid.is_empty():
		return
	if rustle_cell.x >= 0:
		if _tile_at(rustle_cell.x, rustle_cell.y) == TALLGRASS:
			overlay.set_cell(rustle_cell, 0, C["tallgrass"])
		rustle_cell = Vector2i(-999, -999)
	var pp: Vector2i = GameState.player_pos
	if _tile_at(pp.x, pp.y) == TALLGRASS and not _is_tree_cell(pp):
		overlay.set_cell(pp, 0, C["tallgrass_rustle"])
		rustle_cell = pp


func _blob_mask(x: int, y: int, want: int, pathish: bool) -> int:
	var n := _blob_match(_tile_at(x, y - 1), want, pathish)
	var e := _blob_match(_tile_at(x + 1, y), want, pathish)
	var s := _blob_match(_tile_at(x, y + 1), want, pathish)
	var w := _blob_match(_tile_at(x - 1, y), want, pathish)
	var ne := _blob_match(_tile_at(x + 1, y - 1), want, pathish)
	var se := _blob_match(_tile_at(x + 1, y + 1), want, pathish)
	var sw := _blob_match(_tile_at(x - 1, y + 1), want, pathish)
	var nw := _blob_match(_tile_at(x - 1, y - 1), want, pathish)
	var m := 0
	if n: m |= 1
	if e: m |= 2
	if s: m |= 4
	if w: m |= 8
	if n and e and ne: m |= 16
	if e and s and se: m |= 32
	if s and w and sw: m |= 64
	if w and n and nw: m |= 128
	return m


func _blob_match(t: int, want: int, pathish: bool) -> bool:
	if pathish:
		return t == PATH or t == STAIRS
	return t == want


func _is_tree_cell(p: Vector2i) -> bool:
	for nw in GameState.trees:
		var tpos: Vector2i = nw
		if p.x >= tpos.x and p.x <= tpos.x + 1 and p.y >= tpos.y and p.y <= tpos.y + 1:
			return true
	return false


func _tile_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= GameState.MAP_W or y >= GameState.MAP_H:
		return CLIFF
	if GameState.grid.is_empty():
		return CLIFF
	return int(GameState.grid[y][x])


func _refresh() -> void:
	_update_camera()
	_sync_actors()
	_apply_rustle()
	if GameState.dungeon_log.size() > 0:
		_show_toast(str(GameState.dungeon_log[GameState.dungeon_log.size() - 1]))


func _sync_actors() -> void:
	if player_sprite == null:
		return
	var pp: Vector2i = GameState.player_pos
	if not moving:
		player_sprite.position = _actor_pos(pp)
	var ptex: Texture2D = player_facing.get(last_dir, tex_player)
	_fit_sprite(player_sprite, ptex)

	while wild_sprites.size() < GameState.wilds.size():
		var s := Sprite2D.new()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		world.add_child(s)
		wild_sprites.append(s)
	for i in wild_sprites.size():
		if i >= GameState.wilds.size():
			wild_sprites[i].visible = false
			continue
		var w: Dictionary = GameState.wilds[i]
		var p: Vector2i = w["pos"]
		var cr: WyrdlingCreature = w["creature"]
		var ctex: Texture2D = creature_tex.get(cr.species_id, tex_player)
		wild_sprites[i].visible = true
		wild_sprites[i].position = _actor_pos(p)
		_fit_sprite(wild_sprites[i], ctex)


func _unhandled_input(event: InputEvent) -> void:
	if combat_open or moving:
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

	var start_pos := player_sprite.position
	GameState.player_pos = np
	moving = true
	_update_camera()
	var ptex: Texture2D = player_facing.get(last_dir, tex_player)
	_fit_sprite(player_sprite, ptex)
	player_sprite.position = start_pos
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(player_sprite, "position", _actor_pos(np), 0.12)
	await tween.finished
	moving = false

	if np == GameState.stairs_pos:
		GameState.descend()
		_paint_map()
		_refresh()
		_show_location()
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
	location_panel.visible = false
	toast_panel.visible = false
	var wild: WyrdlingCreature = GameState.wilds[wild_index]["creature"]
	GameState.push_log("A wild %s bars the way." % wild.display_name)
	var combat: Control = preload("res://scenes/combat.tscn").instantiate()
	combat.setup(wild)
	combat.combat_over.connect(_on_combat_over)
	hud.add_child(combat)


func _on_combat_over(result: String) -> void:
	combat_open = false
	if result == "wiped":
		GameState.end_run()
		get_tree().change_scene_to_file("res://scenes/title.tscn")
		return
	match result:
		"won": GameState.push_log("The wild Wyrdling scattered into rift-dust.")
		"caught": GameState.push_log("Bound. The party shifts.")
		"fled": GameState.push_log("You slipped back into the wilds.")
		_: pass
	_refresh()
