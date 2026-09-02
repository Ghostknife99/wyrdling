extends RefCounted
## Text-safe runtime pixel art for the Willowmere scenery uplift.
## No external binary atlas is required: Godot builds the final 512x480 terrain
## atlas and 256x128 prop sheet from deterministic pixel primitives.

const GRASS := Color8(85, 168, 91, 255)
const GRASS_2 := Color8(77, 156, 84, 255)
const GRASS_HI := Color8(107, 187, 103, 255)
const GRASS_DARK := Color8(53, 122, 70, 255)
const PATH := Color8(216, 181, 116, 255)
const PATH_HI := Color8(238, 208, 142, 255)
const PATH_DARK := Color8(183, 141, 86, 255)
const PATH_PEB := Color8(159, 120, 73, 255)
const WATER := Color8(45, 123, 199, 255)
const WATER_HI := Color8(94, 182, 229, 255)
const WATER_DARK := Color8(29, 86, 142, 255)
const WATER_DEEP := Color8(31, 104, 173, 255)
const BARK := Color8(118, 82, 51, 255)
const BARK_DARK := Color8(74, 52, 38, 255)
const BARK_HI := Color8(164, 118, 73, 255)
const LEAF := Color8(46, 117, 64, 255)
const LEAF_MID := Color8(63, 143, 73, 255)
const LEAF_HI := Color8(99, 173, 86, 255)
const LEAF_DARK := Color8(30, 86, 54, 255)
const CLIFF := Color8(159, 116, 80, 255)
const CLIFF_HI := Color8(185, 140, 95, 255)
const CLIFF_DARK := Color8(100, 71, 50, 255)
const FENCE := Color8(154, 112, 69, 255)
const FENCE_HI := Color8(192, 139, 85, 255)
const FENCE_DARK := Color8(96, 69, 45, 255)
const ROOF := Color8(45, 110, 111, 255)
const ROOF_HI := Color8(62, 134, 131, 255)
const ROOF_DARK := Color8(30, 77, 84, 255)
const WALL := Color8(140, 96, 63, 255)
const WALL_HI := Color8(178, 124, 76, 255)
const CLEAR := Color8(0, 0, 0, 0)

const N_BIT := 1
const E_BIT := 2
const S_BIT := 4
const W_BIT := 8
const NE_BIT := 16
const SE_BIT := 32
const SW_BIT := 64
const NW_BIT := 128


static func make_atlas() -> Texture2D:
	var atlas := Image.create(512, 480, false, Image.FORMAT_RGBA8)
	atlas.fill(CLEAR)
	_blit(atlas, _grass_tile(false), 0, 0)
	_blit(atlas, _grass_tile(true), 32, 0)
	_blit(atlas, _cliff_tile(), 64, 0)
	_blit(atlas, _cliff_top_tile(), 96, 0)
	_blit(atlas, _gate_tile(), 128, 0)
	_blit(atlas, _tallgrass_tile(false), 160, 0)
	_blit(atlas, _tallgrass_tile(true), 192, 0)

	var fence_keys := ["h", "v", "post", "nw", "ne", "sw", "se"]
	for i in fence_keys.size():
		_blit(atlas, _fence_tile(fence_keys[i]), (7 + i) * 32, 0)

	var pine := _pine_tree()
	_blit_part(atlas, pine, Rect2i(0, 0, 32, 32), Vector2i(14 * 32, 0))
	_blit_part(atlas, pine, Rect2i(32, 0, 32, 32), Vector2i(15 * 32, 0))
	_blit_part(atlas, pine, Rect2i(0, 32, 32, 32), Vector2i(0, 32))
	_blit_part(atlas, pine, Rect2i(32, 32, 32, 32), Vector2i(32, 32))

	var masks: PackedInt32Array = _blob_masks()
	for i in masks.size():
		var px := (i % 16) * 32
		var py := (2 + int(i / 16)) * 32
		_blit(atlas, _path_tile(int(masks[i]), i), px, py)

	for i in masks.size():
		var bx := (i % 5) * 3 * 32
		var by := (5 + int(i / 5)) * 32
		for frame in 3:
			_blit(atlas, _water_tile(int(masks[i]), i, frame), bx + frame * 32, by)

	return ImageTexture.create_from_image(atlas)


static func make_props_sheet() -> Texture2D:
	var sheet := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	sheet.fill(CLEAR)
	_blit(sheet, _lodge(), 0, 0)
	_blit(sheet, _cave(), 96, 0)
	_blit(sheet, _sign(), 192, 0)
	_blit(sheet, _bush(), 224, 0)
	_blit(sheet, _flowers(false), 192, 32)
	_blit(sheet, _flowers(true), 224, 32)
	_blit(sheet, _rock(), 192, 64)
	_blit(sheet, _stump(), 224, 64)
	_blit(sheet, _mushrooms(), 192, 96)
	_blit(sheet, _fallen_log(), 0, 96)
	return ImageTexture.create_from_image(sheet)


static func _blank(w: int, h: int, color: Color = CLEAR) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img


static func _blit(dst: Image, src: Image, x: int, y: int) -> void:
	dst.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(x, y))


static func _blit_part(dst: Image, src: Image, rect: Rect2i, pos: Vector2i) -> void:
	dst.blit_rect(src, rect, pos)


static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), color)


static func _pixel(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, color)


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var x := x0
	var y := y0
	while true:
		_pixel(img, x, y, color)
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, color: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var nx := float(x - cx) / float(rx)
			var ny := float(y - cy) / float(ry)
			if nx * nx + ny * ny <= 1.0:
				_pixel(img, x, y, color)


static func _triangle(img: Image, a: Vector2i, b: Vector2i, c: Vector2i, color: Color) -> void:
	var min_x := mini(a.x, mini(b.x, c.x))
	var max_x := maxi(a.x, maxi(b.x, c.x))
	var min_y := mini(a.y, mini(b.y, c.y))
	var max_y := maxi(a.y, maxi(b.y, c.y))
	var area := float((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x))
	if is_zero_approx(area):
		return
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var w0 := float((b.x - a.x) * (y - a.y) - (b.y - a.y) * (x - a.x)) / area
			var w1 := float((c.x - b.x) * (y - b.y) - (c.y - b.y) * (x - b.x)) / area
			var w2 := float((a.x - c.x) * (y - c.y) - (a.y - c.y) * (x - c.x)) / area
			if (w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0) or (w0 <= 0.0 and w1 <= 0.0 and w2 <= 0.0):
				_pixel(img, x, y, color)


static func _grass_tile(alt: bool) -> Image:
	var img := _blank(32, 32, GRASS)
	for y in 32:
		for x in 32:
			var h := abs(x * 31 + y * 17 + (71 if alt else 13))
			if h % 67 == 0:
				_pixel(img, x, y, GRASS_2)
			elif h % 89 == 0:
				_pixel(img, x, y, GRASS_HI)
	for i in (8 if alt else 5):
		var x := 3 + ((i * 11 + (5 if alt else 2)) % 26)
		var y := 6 + ((i * 7 + (3 if alt else 1)) % 22)
		_line(img, x, y, x + 1, y - 2, GRASS_DARK)
		_pixel(img, x + 1, y - 2, GRASS_HI)
	if alt:
		_pixel(img, 7, 8, Color8(220, 239, 181, 255))
		_pixel(img, 8, 8, Color8(220, 239, 181, 255))
		_pixel(img, 23, 20, Color8(242, 208, 106, 255))
	return img


static func _in_blob(mask: int, x: int, y: int) -> bool:
	if x >= 8 and x <= 23 and y >= 8 and y <= 23: return true
	if (mask & N_BIT) and x >= 8 and x <= 23 and y <= 15: return true
	if (mask & E_BIT) and x >= 16 and y >= 8 and y <= 23: return true
	if (mask & S_BIT) and x >= 8 and x <= 23 and y >= 16: return true
	if (mask & W_BIT) and x <= 15 and y >= 8 and y <= 23: return true
	if (mask & NE_BIT) and x >= 16 and y <= 15: return true
	if (mask & SE_BIT) and x >= 16 and y >= 16: return true
	if (mask & SW_BIT) and x <= 15 and y >= 16: return true
	if (mask & NW_BIT) and x <= 15 and y <= 15: return true
	return false


static func _inner_blob(mask: int, x: int, y: int, margin: int) -> bool:
	return _in_blob(mask, x, y) and _in_blob(mask, x + margin, y) and _in_blob(mask, x - margin, y) and _in_blob(mask, x, y + margin) and _in_blob(mask, x, y - margin)


static func _path_tile(mask: int, index: int) -> Image:
	var img := _grass_tile(false)
	for y in 32:
		for x in 32:
			if _in_blob(mask, x, y):
				_pixel(img, x, y, PATH_DARK)
			if _inner_blob(mask, x, y, 2):
				_pixel(img, x, y, PATH)
	for n in 18:
		var x := (n * 17 + index * 7 + 3) % 32
		var y := (n * 11 + index * 5 + 9) % 32
		if _inner_blob(mask, x, y, 2):
			_pixel(img, x, y, PATH_HI if n % 3 == 0 else PATH_PEB)
	return img


static func _water_tile(mask: int, index: int, frame: int) -> Image:
	var img := _grass_tile(false)
	for y in 32:
		for x in 32:
			if _in_blob(mask, x, y):
				_pixel(img, x, y, WATER_DARK)
			if _inner_blob(mask, x, y, 1):
				_pixel(img, x, y, WATER)
	for y in [6, 13, 20, 27]:
		var start := (y + frame * 3 + index) % 9
		for x in range(start, 32, 10):
			if _inner_blob(mask, x, y, 1):
				for dx in 4:
					if x + dx < 32 and _inner_blob(mask, x + dx, y, 1):
						_pixel(img, x + dx, y, WATER_HI)
				if y + 1 < 32:
					_pixel(img, x + 1, y + 1, WATER_DEEP)
	return img


static func _blob_masks() -> PackedInt32Array:
	var masks := PackedInt32Array()
	for card in range(16):
		var allowed: Array[int] = []
		if (card & N_BIT) and (card & E_BIT): allowed.append(NE_BIT)
		if (card & E_BIT) and (card & S_BIT): allowed.append(SE_BIT)
		if (card & S_BIT) and (card & W_BIT): allowed.append(SW_BIT)
		if (card & W_BIT) and (card & N_BIT): allowed.append(NW_BIT)
		for sub in range(1 << allowed.size()):
			var mask := card
			for i in allowed.size():
				if sub & (1 << i): mask |= allowed[i]
			masks.append(mask)
	return masks


static func _cliff_tile() -> Image:
	var img := _blank(32, 32, CLIFF)
	_rect(img, 0, 0, 32, 5, GRASS_DARK)
	_rect(img, 0, 0, 32, 2, GRASS_HI)
	for y in range(8, 31, 7): _line(img, 2, y, 29, y, CLIFF_DARK)
	for p in [Vector2i(6, 10), Vector2i(20, 15), Vector2i(11, 25), Vector2i(27, 6)]:
		_line(img, p.x, p.y, p.x + 2, p.y + 4, CLIFF_HI)
	return img


static func _cliff_top_tile() -> Image:
	var img := _grass_tile(false)
	_rect(img, 0, 24, 32, 8, CLIFF_DARK)
	_line(img, 0, 23, 31, 23, Color8(130, 189, 98, 255))
	_line(img, 0, 24, 31, 24, CLIFF_HI)
	return img


static func _gate_tile() -> Image:
	var img := _grass_tile(false)
	_rect(img, 8, 8, 16, 20, Color8(91, 91, 98, 255))
	_rect(img, 10, 6, 12, 20, Color8(133, 134, 143, 255))
	_rect(img, 12, 5, 8, 19, Color8(42, 61, 82, 255))
	_rect(img, 13, 7, 6, 16, Color8(78, 195, 215, 255))
	_rect(img, 14, 8, 4, 14, Color8(124, 231, 231, 255))
	_rect(img, 11, 24, 10, 4, Color8(66, 67, 75, 255))
	return img


static func _tallgrass_tile(rustle: bool) -> Image:
	var img := _grass_tile(false)
	for x in range(1, 32, 3):
		var h := 8 + ((x * 5) % 6)
		var base_y := 31 - ((x * 3) % 3)
		var col := LEAF_DARK if x % 2 == 0 else LEAF
		_line(img, x, base_y, x - 1, base_y - h, col)
		_line(img, x + 1, base_y, x + 2, base_y - h + 2, LEAF_HI)
	if rustle:
		for x in range(8, 25, 2):
			var y := 7 + absi(x - 16) / 3
			_pixel(img, x, y, Color8(205, 233, 157, 255))
	return img


static func _fence_tile(kind: String) -> Image:
	var img := _blank(32, 32)
	if kind == "h":
		_rect(img, 0, 14, 32, 6, FENCE_DARK); _rect(img, 0, 12, 32, 5, FENCE); _line(img, 0, 12, 31, 12, FENCE_HI)
	elif kind == "v":
		_rect(img, 13, 0, 6, 32, FENCE_DARK); _rect(img, 11, 0, 5, 32, FENCE); _line(img, 11, 0, 11, 31, FENCE_HI)
	elif kind == "post":
		_rect(img, 10, 6, 12, 25, FENCE_DARK); _rect(img, 9, 4, 11, 25, FENCE); _triangle(img, Vector2i(9, 4), Vector2i(14, 0), Vector2i(19, 4), FENCE_HI)
	else:
		_rect(img, 0, 12, 32, 6, FENCE); _rect(img, 11, 0, 6, 32, FENCE); _rect(img, 10, 5, 11, 25, FENCE_DARK); _rect(img, 9, 3, 10, 25, FENCE); _triangle(img, Vector2i(9, 3), Vector2i(13, 0), Vector2i(18, 3), FENCE_HI)
	return img


static func _pine_tree() -> Image:
	var img := _blank(64, 64)
	_ellipse(img, 32, 58, 15, 4, Color8(32, 60, 38, 150))
	_rect(img, 28, 43, 9, 19, BARK_DARK); _rect(img, 30, 43, 5, 19, BARK)
	_triangle(img, Vector2i(32, 2), Vector2i(10, 35), Vector2i(54, 35), LEAF_DARK)
	_triangle(img, Vector2i(32, 10), Vector2i(7, 44), Vector2i(57, 44), LEAF)
	_triangle(img, Vector2i(32, 20), Vector2i(4, 54), Vector2i(60, 54), LEAF_MID)
	_triangle(img, Vector2i(31, 5), Vector2i(18, 30), Vector2i(31, 24), LEAF_HI)
	_triangle(img, Vector2i(20, 18), Vector2i(11, 39), Vector2i(25, 33), LEAF_HI)
	_triangle(img, Vector2i(41, 19), Vector2i(54, 42), Vector2i(37, 34), LEAF_DARK)
	_triangle(img, Vector2i(24, 33), Vector2i(8, 49), Vector2i(28, 46), LEAF_HI)
	_triangle(img, Vector2i(40, 34), Vector2i(58, 51), Vector2i(34, 48), LEAF_DARK)
	return img


static func _lodge() -> Image:
	var img := _blank(96, 96)
	_ellipse(img, 48, 90, 40, 6, Color8(25, 55, 32, 100))
	_rect(img, 14, 43, 69, 46, WALL); _rect(img, 18, 46, 61, 41, WALL_HI)
	for y in range(50, 86, 8): _line(img, 18, y, 78, y, BARK_DARK)
	_triangle(img, Vector2i(8, 45), Vector2i(48, 16), Vector2i(88, 45), ROOF_DARK)
	_triangle(img, Vector2i(13, 42), Vector2i(48, 19), Vector2i(83, 42), ROOF)
	_line(img, 16, 37, 80, 37, ROOF_HI)
	_rect(img, 66, 11, 10, 21, Color8(93, 85, 78, 255)); _rect(img, 64, 9, 14, 5, Color8(129, 118, 108, 255))
	_rect(img, 40, 61, 17, 28, Color8(90, 58, 40, 255)); _rect(img, 43, 64, 11, 14, Color8(52, 122, 145, 255)); _rect(img, 44, 65, 9, 8, Color8(123, 197, 213, 255))
	for wx in [20, 61]:
		_rect(img, wx, 58, 16, 16, Color8(58, 95, 98, 255)); _rect(img, wx + 2, 60, 12, 10, Color8(142, 214, 208, 255))
	_rect(img, 19, 72, 18, 5, BARK_DARK)
	for p in [Vector2i(22, 69), Vector2i(27, 68), Vector2i(32, 69)]: _ellipse(img, p.x, p.y, 2, 2, Color8(240, 126, 140, 255))
	_triangle(img, Vector2i(48, 27), Vector2i(53, 35), Vector2i(48, 43), Color8(65, 165, 216, 255))
	_triangle(img, Vector2i(48, 27), Vector2i(43, 35), Vector2i(48, 43), Color8(65, 165, 216, 255))
	_line(img, 48, 27, 48, 43, Color8(142, 227, 240, 255))
	return img


static func _cave() -> Image:
	var img := _blank(96, 64)
	_triangle(img, Vector2i(0, 58), Vector2i(24, 8), Vector2i(48, 58), CLIFF_DARK)
	_triangle(img, Vector2i(48, 58), Vector2i(72, 7), Vector2i(96, 58), CLIFF_DARK)
	_rect(img, 14, 28, 68, 31, CLIFF)
	_triangle(img, Vector2i(7, 56), Vector2i(28, 12), Vector2i(48, 56), CLIFF)
	_triangle(img, Vector2i(48, 56), Vector2i(68, 11), Vector2i(90, 56), CLIFF)
	_triangle(img, Vector2i(10, 26), Vector2i(24, 10), Vector2i(70, 10), GRASS_DARK)
	_triangle(img, Vector2i(70, 10), Vector2i(84, 26), Vector2i(10, 26), GRASS_DARK)
	_ellipse(img, 48, 41, 21, 24, Color8(20, 35, 43, 255)); _rect(img, 28, 40, 41, 24, Color8(20, 35, 43, 255)); _ellipse(img, 48, 43, 14, 16, Color8(9, 20, 24, 255))
	_line(img, 31, 55, 65, 55, Color8(56, 71, 75, 255)); _line(img, 35, 58, 61, 58, Color8(75, 85, 82, 255))
	return img


static func _sign() -> Image:
	var img := _blank(32, 32)
	_rect(img, 14, 15, 4, 17, FENCE_DARK); _rect(img, 4, 5, 24, 14, FENCE_DARK); _rect(img, 6, 6, 20, 11, Color8(199, 149, 87, 255)); _line(img, 10, 11, 21, 11, Color8(105, 73, 46, 255))
	return img


static func _bush() -> Image:
	var img := _blank(32, 32)
	_ellipse(img, 16, 21, 14, 9, LEAF_DARK); _ellipse(img, 12, 15, 8, 8, LEAF); _ellipse(img, 21, 15, 8, 9, LEAF_MID); _ellipse(img, 12, 13, 3, 3, LEAF_HI); _ellipse(img, 21, 13, 3, 3, LEAF_HI)
	return img


static func _flowers(blue: bool) -> Image:
	var img := _blank(32, 32)
	var color_a := Color8(114, 169, 239, 255) if blue else Color8(242, 242, 221, 255)
	var color_b := Color8(215, 123, 234, 255) if blue else Color8(240, 142, 170, 255)
	var points := [Vector2i(8, 18), Vector2i(16, 12), Vector2i(23, 19)]
	for i in points.size():
		var p: Vector2i = points[i]
		_line(img, p.x, p.y + 2, p.x, p.y + 10, GRASS_DARK)
		_ellipse(img, p.x, p.y, 2, 2, color_b if i == 1 else color_a)
		_pixel(img, p.x, p.y, Color8(243, 215, 110, 255))
	return img


static func _rock() -> Image:
	var img := _blank(32, 32)
	_triangle(img, Vector2i(4, 24), Vector2i(14, 7), Vector2i(29, 21), Color8(80, 70, 63, 255)); _triangle(img, Vector2i(4, 24), Vector2i(29, 21), Vector2i(24, 28), Color8(80, 70, 63, 255)); _triangle(img, Vector2i(8, 20), Vector2i(16, 9), Vector2i(26, 19), Color8(120, 104, 94, 255)); _triangle(img, Vector2i(11, 12), Vector2i(16, 9), Vector2i(20, 12), Color8(155, 138, 121, 255))
	return img


static func _stump() -> Image:
	var img := _blank(32, 32)
	_rect(img, 8, 13, 17, 17, BARK_DARK); _rect(img, 10, 12, 13, 16, BARK); _ellipse(img, 16, 13, 9, 5, BARK_DARK); _ellipse(img, 16, 12, 7, 3, Color8(189, 138, 86, 255)); _ellipse(img, 16, 12, 3, 1, Color8(129, 91, 56, 255))
	return img


static func _mushrooms() -> Image:
	var img := _blank(32, 32)
	for spec in [[8, 20, 6], [18, 16, 8], [25, 22, 5]]:
		var x: int = spec[0]; var y: int = spec[1]; var s: int = spec[2]
		_rect(img, x - 1, y, 3, 7, Color8(229, 212, 181, 255)); _ellipse(img, x, y, maxi(2, int(s / 2)), maxi(2, int(s / 3)), Color8(201, 77, 66, 255)); _pixel(img, x - 1, y - 1, Color8(242, 196, 168, 255))
	return img


static func _fallen_log() -> Image:
	var img := _blank(64, 32)
	_ellipse(img, 12, 19, 8, 8, BARK_DARK); _rect(img, 12, 11, 43, 17, BARK_DARK); _ellipse(img, 54, 19, 8, 8, BARK_DARK); _rect(img, 12, 10, 41, 14, BARK); _line(img, 14, 12, 45, 12, BARK_HI); _ellipse(img, 56, 19, 5, 7, Color8(183, 130, 82, 255)); _ellipse(img, 56, 19, 2, 5, Color8(106, 72, 47, 255)); _rect(img, 20, 7, 5, 7, LEAF_DARK)
	return img
