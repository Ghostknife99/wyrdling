extends RefCounted
## Text-safe runtime pixel art for the composition landmarks. These two large
## props need custom footprints, so they live outside the compact scenery sheet.

const CLEAR := Color8(0, 0, 0, 0)
const SHADOW := Color8(42, 49, 47, 135)
const WOOD_DARK := Color8(79, 55, 38, 255)
const WOOD := Color8(132, 88, 52, 255)
const WOOD_MID := Color8(161, 108, 61, 255)
const WOOD_HI := Color8(196, 141, 79, 255)
const ROPE := Color8(205, 171, 105, 255)
const MOSS := Color8(78, 119, 59, 255)
const MOSS_HI := Color8(112, 151, 70, 255)
const STONE_DARK := Color8(64, 74, 72, 255)
const STONE := Color8(104, 115, 108, 255)
const STONE_MID := Color8(132, 142, 130, 255)
const STONE_HI := Color8(165, 172, 151, 255)
const RUNE_DARK := Color8(42, 121, 144, 255)
const RUNE := Color8(74, 188, 202, 255)
const RUNE_HI := Color8(164, 239, 220, 255)


static func make_bridge() -> Texture2D:
	var image := Image.create(96, 160, false, Image.FORMAT_RGBA8)
	image.fill(CLEAR)

	# Soft silhouette beneath the deck keeps the bridge readable over animated water.
	_fill_rect(image, Rect2i(17, 7, 62, 149), SHADOW)

	# Main three-plank-wide cedar deck.
	_fill_rect(image, Rect2i(23, 3, 50, 154), WOOD_DARK)
	_fill_rect(image, Rect2i(26, 4, 44, 152), WOOD)
	for y: int in range(7, 154, 14):
		_fill_rect(image, Rect2i(26, y, 44, 2), WOOD_DARK)
		_fill_rect(image, Rect2i(27, y + 2, 42, 2), WOOD_HI)
		# Offset plank joins so it looks hand-built rather than tiled.
		var join_x: int = 39 if int(y / 14) % 2 == 0 else 54
		_fill_rect(image, Rect2i(join_x, y + 2, 2, 10), WOOD_DARK)

	# Worn center strip and little nail heads.
	_fill_rect(image, Rect2i(46, 5, 4, 149), WOOD_MID)
	for y: int in range(11, 151, 18):
		_fill_rect(image, Rect2i(31, y, 2, 2), STONE_DARK)
		_fill_rect(image, Rect2i(63, y + 5, 2, 2), STONE_DARK)

	# Raised rails: stout posts with warm rope between them.
	for x: int in [15, 78]:
		_fill_rect(image, Rect2i(x, 5, 5, 151), WOOD_DARK)
		_fill_rect(image, Rect2i(x + 1, 6, 3, 149), WOOD_MID)
	for y: int in [8, 40, 72, 104, 136, 151]:
		_fill_rect(image, Rect2i(12, y, 11, 5), WOOD_DARK)
		_fill_rect(image, Rect2i(75, y, 11, 5), WOOD_DARK)
		_fill_rect(image, Rect2i(13, y, 9, 2), WOOD_HI)
		_fill_rect(image, Rect2i(76, y, 9, 2), WOOD_HI)
	for y: int in range(13, 147):
		var wobble: int = 1 if int(y / 9) % 2 == 0 else -1
		_pixel(image, 20 + wobble, y, ROPE)
		_pixel(image, 76 - wobble, y, ROPE)

	# Moss at the damp ends ties it back into Willowmere.
	_fill_rect(image, Rect2i(24, 4, 12, 3), MOSS)
	_fill_rect(image, Rect2i(58, 151, 11, 4), MOSS)
	_fill_rect(image, Rect2i(16, 146, 4, 7), MOSS_HI)
	_fill_rect(image, Rect2i(78, 8, 4, 8), MOSS)

	return ImageTexture.create_from_image(image)


static func make_riftstone() -> Texture2D:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(CLEAR)

	# Ground shadow and broken foundation stones.
	_fill_rect(image, Rect2i(17, 81, 63, 8), SHADOW)
	_fill_rect(image, Rect2i(13, 78, 20, 11), STONE_DARK)
	_fill_rect(image, Rect2i(19, 73, 24, 13), STONE)
	_fill_rect(image, Rect2i(54, 75, 25, 12), STONE)
	_fill_rect(image, Rect2i(66, 80, 17, 9), STONE_DARK)
	_fill_rect(image, Rect2i(22, 74, 17, 3), STONE_HI)
	_fill_rect(image, Rect2i(57, 76, 18, 3), STONE_MID)

	# Ancient standing stone with a stepped, chipped crown.
	_fill_rect(image, Rect2i(31, 20, 36, 61), STONE_DARK)
	_fill_rect(image, Rect2i(34, 16, 30, 64), STONE)
	_fill_rect(image, Rect2i(38, 11, 22, 67), STONE_MID)
	_fill_rect(image, Rect2i(42, 8, 14, 8), STONE_HI)
	_fill_rect(image, Rect2i(35, 22, 4, 49), STONE_HI)
	_fill_rect(image, Rect2i(60, 28, 4, 43), STONE_DARK)
	_fill_rect(image, Rect2i(42, 8, 5, 4), CLEAR)
	_fill_rect(image, Rect2i(55, 13, 5, 5), CLEAR)

	# Engraved binding diamond and vertical rift line.
	for i: int in 12:
		_pixel(image, 48 - i, 40 + i, RUNE_DARK)
		_pixel(image, 49 + i, 40 + i, RUNE_DARK)
		_pixel(image, 48 - i, 62 - i, RUNE)
		_pixel(image, 49 + i, 62 - i, RUNE)
	for y: int in range(34, 69):
		_pixel(image, 48, y, RUNE)
		if y % 4 == 0:
			_pixel(image, 49, y, RUNE_HI)
	_fill_rect(image, Rect2i(44, 49, 10, 6), RUNE)
	_fill_rect(image, Rect2i(47, 47, 4, 10), RUNE_HI)

	# Stone cracks and moss reclaiming the base.
	for p: Vector2i in [Vector2i(41, 26), Vector2i(42, 27), Vector2i(43, 28), Vector2i(41, 29), Vector2i(58, 61), Vector2i(57, 62), Vector2i(56, 64)]:
		_pixel(image, p.x, p.y, STONE_DARK)
	_fill_rect(image, Rect2i(27, 69, 15, 5), MOSS)
	_fill_rect(image, Rect2i(34, 73, 20, 6), MOSS_HI)
	_fill_rect(image, Rect2i(54, 70, 13, 5), MOSS)
	_fill_rect(image, Rect2i(61, 74, 7, 5), MOSS_HI)
	_pixel(image, 30, 66, MOSS_HI)
	_pixel(image, 29, 65, MOSS)
	_pixel(image, 64, 67, MOSS_HI)

	return ImageTexture.create_from_image(image)


static func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	var x0: int = maxi(0, rect.position.x)
	var y0: int = maxi(0, rect.position.y)
	var x1: int = mini(image.get_width(), rect.position.x + rect.size.x)
	var y1: int = mini(image.get_height(), rect.position.y + rect.size.y)
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			image.set_pixel(x, y, color)


static func _pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)
