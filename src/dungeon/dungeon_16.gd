extends "res://src/dungeon/dungeon.gd"
## 16x16 overworld presentation layer.
##
## The underlying terrain source stays on the proven 32px TileSet so all blob
## terrain and water animation metadata remains intact. Terrain layers render at
## an exact 0.5 scale, making every map cell occupy 16 logical world pixels.
## The camera renders the world at 2x, so the final screen remains crisp and the
## route framing stays close to the previous 32px presentation.
##
## The Delver uses a dedicated 24x34 polished sprite sheet with four directional
## walk frames. The sheet is reconstructed at runtime from a text-safe palette
## asset so connector uploads cannot corrupt the PNG.

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

var polished_player_idle: Dictionary = {}
var polished_player_walk: Dictionary = {}


func _ready() -> void:
	_load_polished_player()
	super._ready()

	# Keep the base movement/facing code pointed at the new artwork too. This
	# prevents even a single old-frame flash when a tile step starts.
	if not polished_player_idle.is_empty():
		for facing in ["down", "up", "left", "right"]:
			player_facing[facing] = polished_player_idle[facing]
		tex_player = polished_player_idle["down"]
		_sync_actors()


func _load_polished_player() -> void:
	var sheet: Texture2D = PLAYER_ART.make_sheet()
	if sheet == null:
		return
	var rows := {
		"down": 0,
		"left": 1,
		"right": 2,
		"up": 3,
	}

	for facing in rows:
		var row: int = int(rows[facing])
		var frames: Array[Texture2D] = []
		for column in 4:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(
				column * PLAYER_FRAME_W,
				row * PLAYER_FRAME_H,
				PLAYER_FRAME_W,
				PLAYER_FRAME_H
			)
			frames.append(frame)
		polished_player_walk[facing] = frames
		polished_player_idle[facing] = frames[0]


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
	# Build the already-tested 32px terrain set, then render each terrain layer at
	# exactly half scale. Tile cell coordinates remain unchanged, so route logic,
	# collision, autotiling and animated water do not need a second implementation.
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
		spr.position = Vector2(
			(float(p.x) + float(logical_w) / 2.0) * TILE_16,
			(float(p.y) + float(logical_h)) * TILE_16
		)
		spr.offset = Vector2(-tw / 2.0, -th)
		world.add_child(spr)
		prop_sprites.append(spr)
