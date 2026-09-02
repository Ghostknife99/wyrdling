extends "res://src/dungeon/dungeon.gd"
## 16x16 overworld presentation layer.
## Terrain stays on a proven 32px TileSet rendered at 0.5x; the world camera is
## 2x so final pixels stay crisp. This layer also owns the polished Delver and
## the Willowmere scenery presentation.

const TILE_16 := 16
const TERRAIN_SCALE := 0.5
const CAMERA_SCALE := 2.0
const ACTOR_MAX_W := 20.0
const ACTOR_MAX_H := 28.0
const PLAYER_MAX_W := 20.0
const PLAYER_MAX_H := 28.0
const PROP_SOURCE_SCALE := 0.5

const PLAYER_FRAME_W := 24
const PLAYER_FRAME_H := 34
const WALK_FRAME_MS := 35
const PLAYER_ART = preload("res://src/dungeon/delver_art.gd")
const SCENERY_ART = preload("res://src/dungeon/scenery_art_v2.gd")

var polished_player_idle: Dictionary = {}
var polished_player_walk: Dictionary = {}
var scenery_sheet: Texture2D
var scenery_sprites: Array[Sprite2D] = []


func _ready() -> void:
	_load_polished_player()
	super._ready()

	if not polished_player_idle.is_empty():
		for facing in ["down", "up", "left", "right"]:
			player_facing[facing] = polished_player_idle[facing]
		tex_player = polished_player_idle["down"]
		_sync_actors()

	_load_polished_scenery()
	_render_world_props()


func _load_polished_player() -> void:
	var sheet: Texture2D = PLAYER_ART.make_sheet()
	if sheet == null:
		return
	var rows := {"down": 0, "left": 1, "right": 2, "up": 3}
	for facing in rows:
		var row: int = int(rows[facing])
		var frames: Array[Texture2D] = []
		for column in 4:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(column * PLAYER_FRAME_W, row * PLAYER_FRAME_H, PLAYER_FRAME_W, PLAYER_FRAME_H)
			frames.append(frame)
		polished_player_walk[facing] = frames
		polished_player_idle[facing] = frames[0]


func _load_polished_scenery() -> void:
	scenery_sheet = SCENERY_ART.make_props_sheet()
	if scenery_sheet == null:
		return
	var regions := {
		"lodge": Rect2(0, 0, 96, 96),
		"cave": Rect2(96, 0, 96, 64),
		"sign": Rect2(192, 0, 32, 32),
		"bush": Rect2(224, 0, 32, 32),
		"flowers_a": Rect2(192, 32, 32, 32),
		"flowers_b": Rect2(224, 32, 32, 32),
		"rock": Rect2(192, 64, 32, 32),
		"stump": Rect2(224, 64, 32, 32),
		"mushrooms": Rect2(192, 96, 32, 32),
		"fallen_log": Rect2(0, 96, 64, 32),
	}
	for key in regions:
		var frame := AtlasTexture.new()
		frame.atlas = scenery_sheet
		frame.region = regions[key]
		prop_textures[key] = frame


func _current_player_frame() -> Texture2D:
	if polished_player_idle.is_empty():
		return tex_player
	if moving and polished_player_walk.has(last_dir):
		var frames: Array = polished_player_walk[last_dir]
		if not frames.is_empty():
			var frame_index := int(Time.get_ticks_msec() / WALK_FRAME_MS) % frames.size()
			return frames[frame_index] as Texture2D
	return polished_player_idle.get(last_dir, polished_player_idle["down"]) as Texture2D


func _process(_delta: float) -> void:
	if player_sprite == null or polished_player_idle.is_empty():
		return
	var frame := _current_player_frame()
	if frame != null and player_sprite.texture != frame:
		_fit_texture(player_sprite, frame, PLAYER_MAX_W, PLAYER_MAX_H)


func _ensure_world() -> void:
	super._ensure_world()
	for layer in [ground, deco, overlay]:
		layer.scale = Vector2(TERRAIN_SCALE, TERRAIN_SCALE)
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _fit_sprite(spr: Sprite2D, tex: Texture2D) -> void:
	if spr == player_sprite and not polished_player_idle.is_empty():
		_fit_texture(spr, _current_player_frame(), PLAYER_MAX_W, PLAYER_MAX_H)
		return
	_fit_texture(spr, tex, ACTOR_MAX_W, ACTOR_MAX_H)


func _fit_texture(spr: Sprite2D, tex: Texture2D, max_width: float, max_height: float) -> void:
	if tex == null:
		return
	spr.texture = tex
	spr.centered = false
	var tw := float(maxi(tex.get_width(), 1))
	var th := float(maxi(tex.get_height(), 1))
	var scale_factor: float = minf(max_width / tw, max_height / th)
	spr.scale = Vector2(scale_factor, scale_factor)
	spr.offset = Vector2(-tw / 2.0, -th)


func _actor_pos(p: Vector2i) -> Vector2:
	return Vector2(p.x * TILE_16 + TILE_16 / 2.0, p.y * TILE_16 + TILE_16)


func _build_camera() -> void:
	super._build_camera()
	cam.zoom = Vector2(CAMERA_SCALE, CAMERA_SCALE)
	cam.position_smoothing_speed = 14.0


func _update_camera() -> void:
	if cam == null:
		return
	var pp: Vector2i = GameState.player_pos
	cam.position = Vector2(pp.x * TILE_16 + TILE_16 / 2.0, pp.y * TILE_16 + TILE_16 / 2.0)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = GameState.MAP_W * TILE_16
	cam.limit_bottom = GameState.MAP_H * TILE_16


func _render_world_props() -> void:
	for sprite in prop_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	prop_sprites.clear()
	for sprite in scenery_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	scenery_sprites.clear()

	for prop in GameState.world_props:
		var kind: String = str(prop.get("kind", ""))
		var tex_key: String = kind
		if kind == "npc":
			tex_key = "npc_%d" % int(prop.get("variant", 0))
		if not prop_textures.has(tex_key):
			continue

		var tex: Texture2D = prop_textures[tex_key]
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false

		var p: Vector2i = prop.get("pos", Vector2i.ZERO)
		var logical_w := 1
		var logical_h := 1
		var blocks: Array = prop.get("blocks", [])
		if not blocks.is_empty():
			var min_x: int = p.x
			var max_x: int = p.x
			var min_y: int = p.y
			var max_y: int = p.y
			for cell_variant in blocks:
				var cell: Vector2i = cell_variant
				min_x = mini(min_x, cell.x)
				max_x = maxi(max_x, cell.x)
				min_y = mini(min_y, cell.y)
				max_y = maxi(max_y, cell.y)
			p = Vector2i(min_x, min_y)
			logical_w = max_x - min_x + 1
			logical_h = max_y - min_y + 1

		var tw := float(maxi(tex.get_width(), 1))
		var th := float(maxi(tex.get_height(), 1))
		var scale_factor := PROP_SOURCE_SCALE
		if kind == "npc":
			scale_factor = minf(16.0 / tw, 24.0 / th)
		else:
			var target_w := float(logical_w * TILE_16)
			var target_h := float(logical_h * TILE_16)
			scale_factor = minf(target_w / tw, target_h / th)

		spr.scale = Vector2(scale_factor, scale_factor)
		spr.position = Vector2((float(p.x) + float(logical_w) / 2.0) * TILE_16, (float(p.y) + float(logical_h)) * TILE_16)
		spr.offset = Vector2(-tw / 2.0, -th)
		world.add_child(spr)
		prop_sprites.append(spr)

	_render_scenery_details()


func _render_scenery_details() -> void:
	if scenery_sheet == null or GameState.grid.is_empty():
		return
	if not prop_textures.has("mushrooms") or not prop_textures.has("fallen_log"):
		return

	var occupied: Dictionary = {}
	for prop in GameState.world_props:
		var blocks: Array = prop.get("blocks", [])
		for cell_variant in blocks:
			occupied[cell_variant] = true
	for nw in GameState.trees:
		var tp: Vector2i = nw
		for dy in 2:
			for dx in 2:
				occupied[tp + Vector2i(dx, dy)] = true
	occupied[GameState.player_pos] = true
	occupied[GameState.stairs_pos] = true

	for y in range(3, GameState.MAP_H - 3):
		for x in range(3, GameState.MAP_W - 3):
			var p := Vector2i(x, y)
			if occupied.has(p) or int(GameState.grid[y][x]) != GRASS:
				continue
			var seed: int = abs(x * 73 + y * 37 + GameState.floor_num * 101)
			var mark: int = seed % 233
			if mark == 0:
				_spawn_scenery_detail(prop_textures["flowers_a"], p, 1, 1)
			elif mark == 1:
				_spawn_scenery_detail(prop_textures["flowers_b"], p, 1, 1)
			elif mark == 2:
				_spawn_scenery_detail(prop_textures["mushrooms"], p, 1, 1)
			elif seed % 521 == 9:
				var right := p + Vector2i(1, 0)
				if not occupied.has(right) and int(GameState.grid[right.y][right.x]) == GRASS:
					_spawn_scenery_detail(prop_textures["fallen_log"], p, 2, 1)
					occupied[right] = true


func _spawn_scenery_detail(tex: Texture2D, p: Vector2i, logical_w: int, logical_h: int) -> void:
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	var tw := float(maxi(tex.get_width(), 1))
	var th := float(maxi(tex.get_height(), 1))
	var scale_factor := minf(float(logical_w * TILE_16) / tw, float(logical_h * TILE_16) / th)
	spr.scale = Vector2(scale_factor, scale_factor)
	spr.position = Vector2((float(p.x) + float(logical_w) / 2.0) * TILE_16, (float(p.y) + float(logical_h)) * TILE_16)
	spr.offset = Vector2(-tw / 2.0, -th)
	world.add_child(spr)
	scenery_sprites.append(spr)
