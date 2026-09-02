extends RefCounted
## 16x16 overworld TileSet. Uses the same 47-tile blob layout as wilds_tileset.gd.

const BASE = preload("res://src/dungeon/wilds_tileset.gd")
const TILE := 16
const T_GRASS := 0
const T_PATH := 1
const T_WATER := 2
const WATER_FRAMES := 3
const ATLAS := "res://art/tiles/overworld/wilds_atlas_16.png"

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


static func build() -> TileSet:
	var tex: Texture2D = load(ATLAS)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	for name in ["grass", "path", "water"]:
		ts.add_terrain(0)
	var grass_id := 0
	var path_id := 1
	var water_id := 2
	ts.set_terrain_name(0, grass_id, "grass")
	ts.set_terrain_name(0, path_id, "path")
	ts.set_terrain_name(0, water_id, "water")
	ts.set_terrain_color(0, grass_id, Color(0.16, 0.28, 0.14))
	ts.set_terrain_color(0, path_id, Color(0.42, 0.32, 0.20))
	ts.set_terrain_color(0, water_id, Color(0.08, 0.32, 0.34))

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	src.use_texture_padding = true
	ts.add_source(src, 0)

	_ensure_tile(src, SRC_COORDS["grass"])
	_grass_peering(src.get_tile_data(SRC_COORDS["grass"], 0))
	_ensure_tile(src, SRC_COORDS["grass_alt"])
	_grass_peering(src.get_tile_data(SRC_COORDS["grass_alt"], 0))

	for key in ["cliff", "cliff_top", "stairs", "fence_h", "fence_v", "fence_post", "fence_nw", "fence_ne", "fence_sw", "fence_se"]:
		_ensure_tile(src, SRC_COORDS[key])

	_ensure_tile(src, SRC_COORDS["tallgrass"])
	src.get_tile_data(SRC_COORDS["tallgrass"], 0).y_sort_origin = 20
	_ensure_tile(src, SRC_COORDS["tallgrass_rustle"])
	src.get_tile_data(SRC_COORDS["tallgrass_rustle"], 0).y_sort_origin = 20

	_ensure_tile(src, SRC_COORDS["tree_nw"])
	src.get_tile_data(SRC_COORDS["tree_nw"], 0).y_sort_origin = 28
	_ensure_tile(src, SRC_COORDS["tree_ne"])
	src.get_tile_data(SRC_COORDS["tree_ne"], 0).y_sort_origin = 28
	_ensure_tile(src, SRC_COORDS["tree_sw"])
	src.get_tile_data(SRC_COORDS["tree_sw"], 0).y_sort_origin = 8
	_ensure_tile(src, SRC_COORDS["tree_se"])
	src.get_tile_data(SRC_COORDS["tree_se"], 0).y_sort_origin = 8

	for key in ["fence_h", "fence_v", "fence_post", "fence_nw", "fence_ne", "fence_sw", "fence_se"]:
		src.get_tile_data(SRC_COORDS[key], 0).y_sort_origin = 12
	src.get_tile_data(SRC_COORDS["stairs"], 0).y_sort_origin = 4
	src.get_tile_data(SRC_COORDS["cliff_top"], 0).y_sort_origin = 10

	var masks: PackedInt32Array = BASE.blob_masks()
	for i in masks.size():
		var coords: Vector2i = BASE.path_coords(i)
		_ensure_tile(src, coords)
		_apply_peering(src.get_tile_data(coords, 0), int(masks[i]), T_PATH, T_GRASS)

	for i in masks.size():
		var coords: Vector2i = BASE.water_coords(i)
		_ensure_tile(src, coords)
		_apply_peering(src.get_tile_data(coords, 0), int(masks[i]), T_WATER, T_GRASS)
		src.set_tile_animation_columns(coords, WATER_FRAMES)
		src.set_tile_animation_frames_count(coords, WATER_FRAMES)
		src.set_tile_animation_speed(coords, 3.0)
		src.set_tile_animation_separation(coords, Vector2i.ZERO)
		for f in WATER_FRAMES:
			src.set_tile_animation_frame_duration(coords, f, 1.0)

	var index_of: Dictionary = {}
	for i in masks.size():
		index_of[int(masks[i])] = i
	for raw in range(256):
		var canonical: int = BASE.canonical_mask(raw)
		if raw == canonical:
			continue
		var idx: int = int(index_of[canonical])
		var pcoords: Vector2i = BASE.path_coords(idx)
		var palt: int = src.create_alternative_tile(pcoords)
		_apply_peering(src.get_tile_data(pcoords, palt), raw, T_PATH, T_GRASS)
		var wcoords: Vector2i = BASE.water_coords(idx)
		var walt: int = src.create_alternative_tile(wcoords)
		_apply_peering(src.get_tile_data(wcoords, walt), raw, T_WATER, T_GRASS)

	return ts


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
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, self_t if (mask & 1) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, self_t if (mask & 2) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, self_t if (mask & 4) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, self_t if (mask & 8) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, self_t if (mask & 16) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, self_t if (mask & 32) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, self_t if (mask & 64) else other_t)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, self_t if (mask & 128) else other_t)
