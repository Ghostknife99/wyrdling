extends RefCounted
## Approved Willowmere HD scenery artwork.
## The detailed source art is carried as a text-safe PNG payload. Terrain cells
## are repaired after decode so the sampled concept art becomes a seamless game
## TileSet rather than showing the borders of the reference-sheet swatches.

const PAYLOAD_PATH := "res://src/dungeon/scenery_payload.txt"
const TILE := 32
const COLS := 16
const PATH_ROW0 := 2
const WATER_ROW0 := 5
const WATER_PER_ROW := 5
const WATER_FRAMES := 3

const N_BIT := 1
const E_BIT := 2
const S_BIT := 4
const W_BIT := 8
const NE_BIT := 16
const SE_BIT := 32
const SW_BIT := 64
const NW_BIT := 128

const GRASS := Color8(132, 156, 66, 255)
const GRASS_2 := Color8(112, 143, 61, 255)
const GRASS_HI := Color8(159, 177, 82, 255)
const GRASS_DARK := Color8(91, 118, 55, 255)
const PATH := Color8(205, 164, 92, 255)
const PATH_2 := Color8(216, 174, 99, 255)
const PATH_HI := Color8(230, 192, 119, 255)
const PATH_DARK := Color8(169, 132, 75, 255)
const PATH_PEBBLE := Color8(188, 146, 82, 255)
const WATER := Color8(43, 121, 193, 255)
const WATER_2 := Color8(32, 103, 172, 255)
const WATER_HI := Color8(110, 194, 229, 255)
const WATER_FOAM := Color8(205, 231, 231, 255)

static func _payload(name: String, next_marker: String) -> String:
	var source: String = FileAccess.get_file_as_string(PAYLOAD_PATH)
	if source.is_empty():
		push_error("Scenery payload could not be read")
		return ""
	var start_marker: String = "const %s :=" % name
	var start: int = source.find(start_marker)
	if start < 0:
		push_error("Scenery payload is missing %s" % name)
		return ""
	var finish: int = source.find(next_marker, start)
	if finish < 0:
		finish = source.length()
	var section: String = source.substr(start, finish - start)
	var regex := RegEx.new()
	regex.compile("\\\"([A-Za-z0-9+/=]+)\\\"")
	var result := ""
	for match: RegExMatch in regex.search_all(section):
		result += match.get_string(1)
	return result

static func _decode_image(encoded: String, expected_size: Vector2i) -> Image:
	if encoded.is_empty():
		return null
	var bytes: PackedByteArray = Marshalls.base64_to_raw(encoded)
	var image := Image.new()
	var err: Error = image.load_png_from_buffer(bytes)
	if err != OK:
		push_error("Scenery PNG decode failed: %s" % err)
		return null
	if image.get_size() != expected_size:
		push_error("Scenery image size mismatch: %s expected %s" % [image.get_size(), expected_size])
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image

static func make_atlas() -> Texture2D:
	var image: Image = _decode_image(_payload("ATLAS_B64", "const PROPS_B64"), Vector2i(512, 480))
	if image == null:
		return null
	_repair_terrain(image)
	return ImageTexture.create_from_image(image)

static func make_props_sheet() -> Texture2D:
	var image: Image = _decode_image(_payload("PROPS_B64", "static func _decode_png"), Vector2i(256, 128))
	if image == null:
		return null
	return ImageTexture.create_from_image(image)

static func _repair_terrain(atlas: Image) -> void:
	_paint_grass(atlas, Vector2i(0, 0), false)
	_paint_grass(atlas, Vector2i(1, 0), true)
	var masks: PackedInt32Array = _blob_masks()
	for i: int in masks.size():
		var path_coord := Vector2i(i % COLS, PATH_ROW0 + int(i / COLS))
		_paint_path(atlas, path_coord, int(masks[i]), i)
	for i: int in masks.size():
		var base_coord := Vector2i((i % WATER_PER_ROW) * WATER_FRAMES, WATER_ROW0 + int(i / WATER_PER_ROW))
		for frame: int in WATER_FRAMES:
			_paint_water(atlas, base_coord + Vector2i(frame, 0), int(masks[i]), i, frame)

static func _paint_grass(atlas: Image, coord: Vector2i, alternate: bool) -> void:
	var ox: int = coord.x * TILE
	var oy: int = coord.y * TILE
	for y: int in TILE:
		for x: int in TILE:
			var noise: int = absi((x + ox) * 37 + (y + oy) * 53 + (211 if alternate else 71))
			var color: Color = GRASS
			if noise % 31 == 0:
				color = GRASS_2
			elif noise % 47 == 0:
				color = GRASS_HI
			atlas.set_pixel(ox + x, oy + y, color)
	# Fine blade clusters instead of a border around every cell.
	var blade_count: int = 8 if alternate else 5
	for n: int in blade_count:
		var bx: int = 2 + ((n * 11 + (7 if alternate else 3)) % 27)
		var by: int = 5 + ((n * 7 + (4 if alternate else 1)) % 24)
		_set(atlas, ox + bx, oy + by, GRASS_DARK)
		_set(atlas, ox + bx + 1, oy + by - 1, GRASS_HI)
		_set(atlas, ox + bx + 1, oy + by - 2, GRASS_HI)
	if alternate:
		_set(atlas, ox + 8, oy + 8, Color8(229, 226, 165, 255))
		_set(atlas, ox + 9, oy + 8, Color8(229, 226, 165, 255))

static func _paint_path(atlas: Image, coord: Vector2i, mask: int, index: int) -> void:
	var ox: int = coord.x * TILE
	var oy: int = coord.y * TILE
	_paint_grass(atlas, coord, false)
	for y: int in TILE:
		for x: int in TILE:
			if not _inside_blob(mask, x, y):
				continue
			var noise: int = absi(x * 29 + y * 43 + index * 61)
			var color: Color = PATH if noise % 5 != 0 else PATH_2
			if _blob_edge(mask, x, y):
				color = PATH_DARK
			elif noise % 37 == 0:
				color = PATH_HI
			elif noise % 23 == 0:
				color = PATH_PEBBLE
			atlas.set_pixel(ox + x, oy + y, color)
	# A few tiny stones make the broad trail read as natural dirt without creating
	# a visible repeating tile frame.
	for n: int in 8:
		var px: int = (n * 13 + index * 7 + 4) % TILE
		var py: int = (n * 19 + index * 3 + 9) % TILE
		if _inside_blob(mask, px, py) and not _blob_edge(mask, px, py):
			_set(atlas, ox + px, oy + py, PATH_PEBBLE)

static func _paint_water(atlas: Image, coord: Vector2i, mask: int, index: int, frame: int) -> void:
	var ox: int = coord.x * TILE
	var oy: int = coord.y * TILE
	_paint_grass(atlas, coord, false)
	for y: int in TILE:
		for x: int in TILE:
			if not _inside_blob(mask, x, y):
				continue
			var noise: int = absi(x * 17 + y * 31 + index * 41 + frame * 13)
			var color: Color = WATER if noise % 4 != 0 else WATER_2
			if _blob_edge(mask, x, y):
				color = WATER_2
			atlas.set_pixel(ox + x, oy + y, color)
	# Animated horizontal ripples. They only occur within the connected water body,
	# so no bright seams appear between adjacent animated tiles.
	for row: int in [6, 14, 22, 28]:
		var start: int = (row + frame * 3 + index * 2) % 10
		for x: int in range(start, TILE, 11):
			for dx: int in 4:
				var px: int = x + dx
				if px < TILE and _inside_blob(mask, px, row) and not _blob_edge(mask, px, row):
					_set(atlas, ox + px, oy + row, WATER_HI)
	# Foam only where the water truly meets land, never along a connected cell edge.
	for y: int in TILE:
		for x: int in TILE:
			if _inside_blob(mask, x, y) and _blob_edge(mask, x, y) and (x + y + frame) % 5 == 0:
				_set(atlas, ox + x, oy + y, WATER_FOAM)

static func _inside_blob(mask: int, x: int, y: int) -> bool:
	if x >= 8 and x <= 23 and y >= 8 and y <= 23:
		return true
	if (mask & N_BIT) and x >= 8 and x <= 23 and y <= 15:
		return true
	if (mask & E_BIT) and x >= 16 and y >= 8 and y <= 23:
		return true
	if (mask & S_BIT) and x >= 8 and x <= 23 and y >= 16:
		return true
	if (mask & W_BIT) and x <= 15 and y >= 8 and y <= 23:
		return true
	if (mask & NE_BIT) and x >= 16 and y <= 15:
		return true
	if (mask & SE_BIT) and x >= 16 and y >= 16:
		return true
	if (mask & SW_BIT) and x <= 15 and y >= 16:
		return true
	if (mask & NW_BIT) and x <= 15 and y <= 15:
		return true
	return false

static func _blob_edge(mask: int, x: int, y: int) -> bool:
	if not _inside_blob(mask, x, y):
		return false
	for delta: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var nx: int = x + delta.x
		var ny: int = y + delta.y
		if nx < 0:
			if (mask & W_BIT) == 0:
				return true
			continue
		if nx >= TILE:
			if (mask & E_BIT) == 0:
				return true
			continue
		if ny < 0:
			if (mask & N_BIT) == 0:
				return true
			continue
		if ny >= TILE:
			if (mask & S_BIT) == 0:
				return true
			continue
		if not _inside_blob(mask, nx, ny):
			return true
	return false

static func _blob_masks() -> PackedInt32Array:
	var masks := PackedInt32Array()
	for card: int in range(16):
		var allowed: Array[int] = []
		if (card & N_BIT) and (card & E_BIT):
			allowed.append(NE_BIT)
		if (card & E_BIT) and (card & S_BIT):
			allowed.append(SE_BIT)
		if (card & S_BIT) and (card & W_BIT):
			allowed.append(SW_BIT)
		if (card & W_BIT) and (card & N_BIT):
			allowed.append(NW_BIT)
		for sub: int in range(1 << allowed.size()):
			var value: int = card
			for i: int in allowed.size():
				if sub & (1 << i):
					value |= allowed[i]
			masks.append(value)
	return masks

static func _set(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)
