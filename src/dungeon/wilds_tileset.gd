extends RefCounted
## Builds the 2D-HD overworld TileSet from hd_atlas.png (47-tile blob terrains).

const TILE := 32
const T_GRASS := 0
const T_PATH := 1
const T_WATER := 2

const N_BIT := 1
const E_BIT := 2
const S_BIT := 4
const W_BIT := 8
const NE_BIT := 16
const SE_BIT := 32
const SW_BIT := 64
const NW_BIT := 128

const COLS := 16
const PATH_ROW0 := 2
const WATER_ROW0 := 5
const WATER_PER_ROW := 5
const WATER_FRAMES := 3

const ATLAS := "res://art/tiles/overworld/hd_atlas.png"
const SAVE_PATH := "res://art/tiles/overworld/wilds_tileset.tres"

const SRC_COORDS := {
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


static func blob_masks() -> PackedInt32Array:
	var masks := PackedInt32Array()
	for card in range(16):
		var allowed: Array[int] = []
		if (card & N_BIT) and (card & E_BIT):
			allowed.append(NE_BIT)
		if (card & E_BIT) and (card & S_BIT):
			allowed.append(SE_BIT)
		if (card & S_BIT) and (card & W_BIT):
			allowed.append(SW_BIT)
		if (card & W_BIT) and (card & N_BIT):
			allowed.append(NW_BIT)
		var n: int = allowed.size()
		for sub in range(1 << n):
			var m: int = card
			for i in n:
				if sub & (1 << i):
					m |= int(allowed[i])
			masks.append(m)
	return masks


static func path_coords(index: int) -> Vector2i:
	return Vector2i(index % COLS, PATH_ROW0 + int(index / COLS))


static func water_coords(index: int) -> Vector2i:
	return Vector2i((index % WATER_PER_ROW) * WATER_FRAMES, WATER_ROW0 + int(index / WATER_PER_ROW))


static func build() -> TileSet:
	var tex: Texture2D = load(ATLAS)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(0)
	ts.set_terrain_name(0, T_GRASS, "grass")
	ts.set_terrain_color(0, T_GRASS, Color(0.16, 0.28, 0.14))
	ts.add_terrain(0)
	ts.set_terrain_name(0, T_PATH, "path")
	ts.set_terrain_color(0, T_PATH, Color(0.42, 0.32, 0.20))
	ts.add_terrain(0)
	ts.set_terrain_name(0, T_WATER, "water")
	ts.set_terrain_color(0, T_WATER, Color(0.08, 0.32, 0.34))

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	src.use_texture_padding = true
	ts.add_source(src, 0)

	_ensure_tile(src, SRC_COORDS["grass"])
	_grass_peering(src.get_tile_data(SRC_COORDS["grass"], 0))
	_ensure_tile(src, SRC_COORDS["grass_alt"])
	_grass_peering(src.get_tile_data(SRC_COORDS["grass_alt"], 0))

	for key in ["cliff", "cliff_top", "stairs", "fence_h", "fence_v", "fence_post",
			"fence_nw", "fence_ne", "fence_sw", "fence_se"]:
		_ensure_tile(src, SRC_COORDS[key])

	_ensure_tile(src, SRC_COORDS["tallgrass"])
	src.get_tile_data(SRC_COORDS["tallgrass"], 0).y_sort_origin = 40
	_ensure_tile(src, SRC_COORDS["tallgrass_rustle"])
	src.get_tile_data(SRC_COORDS["tallgrass_rustle"], 0).y_sort_origin = 40

	_ensure_tile(src, SRC_COORDS["tree_nw"])
	src.get_tile_data(SRC_COORDS["tree_nw"], 0).y_sort_origin = 56
	_ensure_tile(src, SRC_COORDS["tree_ne"])
	src.get_tile_data(SRC_COORDS["tree_ne"], 0).y_sort_origin = 56
	_ensure_tile(src, SRC_COORDS["tree_sw"])
	src.get_tile_data(SRC_COORDS["tree_sw"], 0).y_sort_origin = 16
	_ensure_tile(src, SRC_COORDS["tree_se"])
	src.get_tile_data(SRC_COORDS["tree_se"], 0).y_sort_origin = 16

	for key in ["fence_h", "fence_v", "fence_post", "fence_nw", "fence_ne", "fence_sw", "fence_se"]:
		src.get_tile_data(SRC_COORDS[key], 0).y_sort_origin = 24
	src.get_tile_data(SRC_COORDS["stairs"], 0).y_sort_origin = 8
	src.get_tile_data(SRC_COORDS["cliff_top"], 0).y_sort_origin = 20

	var masks: PackedInt32Array = blob_masks()
	for i in masks.size():
		var coords := path_coords(i)
		_ensure_tile(src, coords)
		_apply_peering(src.get_tile_data(coords, 0), int(masks[i]), T_PATH, T_GRASS)

	for i in masks.size():
		var coords := water_coords(i)
		_ensure_tile(src, coords)
		_apply_peering(src.get_tile_data(coords, 0), int(masks[i]), T_WATER, T_GRASS)
		src.set_tile_animation_columns(coords, WATER_FRAMES)
		src.set_tile_animation_frames_count(coords, WATER_FRAMES)
		src.set_tile_animation_speed(coords, 3.0)
		src.set_tile_animation_separation(coords, Vector2i.ZERO)
		for f in WATER_FRAMES:
			src.set_tile_animation_frame_duration(coords, f, 1.0)

	var index_of := {}
	for i in masks.size():
		index_of[int(masks[i])] = i
	for raw in range(256):
		var can: int = canonical_mask(raw)
		if raw == can:
			continue
		var idx: int = int(index_of[can])
		var pcoords := path_coords(idx)
		var palt: int = src.create_alternative_tile(pcoords)
		_apply_peering(src.get_tile_data(pcoords, palt), raw, T_PATH, T_GRASS)
		var wcoords := water_coords(idx)
		var walt: int = src.create_alternative_tile(wcoords)
		_apply_peering(src.get_tile_data(wcoords, walt), raw, T_WATER, T_GRASS)

	return ts



static func canonical_mask(mask: int) -> int:
	var card: int = mask & 15
	var m: int = card
	if (card & N_BIT) and (card & E_BIT) and (mask & NE_BIT):
		m |= NE_BIT
	if (card & E_BIT) and (card & S_BIT) and (mask & SE_BIT):
		m |= SE_BIT
	if (card & S_BIT) and (card & W_BIT) and (mask & SW_BIT):
		m |= SW_BIT
	if (card & W_BIT) and (card & N_BIT) and (mask & NW_BIT):
		m |= NW_BIT
	return m


static func atlas_index(mask: int) -> int:
	var can: int = canonical_mask(mask)
	var masks: PackedInt32Array = blob_masks()
	for i in masks.size():
		if int(masks[i]) == can:
			return i
	return masks.size() - 1


static func _ensure_tile(src: TileSetAtlasSource, coords: Vector2i) -> void:
	if not src.has_tile(coords):
		src.create_tile(coords)


static func _grass_peering(data: TileData) -> void:
	data.terrain_set = 0
	data.terrain = T_GRASS
	for bit in [
		TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
		TileSet.CELL_NEIGHBOR_LEFT_SIDE,
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
		TileSet.CELL_NEIGHBOR_TOP_SIDE,
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	]:
		data.set_terrain_peering_bit(bit, T_GRASS)


static func _apply_peering(data: TileData, mask: int, self_t: int, other_t: int) -> void:
	data.terrain_set = 0
	data.terrain = self_t
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, self_t if (mask & N_BIT) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, self_t if (mask & E_BIT) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, self_t if (mask & S_BIT) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, self_t if (mask & W_BIT) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, self_t if (mask & NE_BIT) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, self_t if (mask & SE_BIT) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, self_t if (mask & SW_BIT) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, self_t if (mask & NW_BIT) else other_t)
