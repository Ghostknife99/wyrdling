extends "res://src/dungeon/dungeon_lush.gd"
## Adds authored-looking interior ledges and guaranteed mid-sized vegetation
## pockets after foliage density. These break up the last large flat meadows
## without touching the main trail, water crossings, landmarks or tree masses.

const TERRAIN_CLIFF := 0
const TERRAIN_GRASS := 1
const TERRAIN_DIRT := 3
const TERRAIN_WATER := 4
const TERRAIN_TALLGRASS := 5
const RIDGE_TARGET := 5
const SHRUB_POCKET_TARGET := 18


func _apply_density_pass() -> void:
	super._apply_density_pass()
	_add_terrain_ridges()
	_add_meadow_pockets()


func _add_terrain_ridges() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC11FF + GameState.floor_num * 6151
	var protected: Dictionary = _build_protected_cells(2, true)
	var centers: Array[Vector2i] = []
	var attempts := 0

	while centers.size() < RIDGE_TARGET and attempts < 1000:
		attempts += 1
		var center := Vector2i(
			rng.randi_range(7, GameState.MAP_W - 8),
			rng.randi_range(7, GameState.MAP_H - 9)
		)
		if _near_tile(center, TERRAIN_DIRT, 4) or _near_tile(center, TERRAIN_WATER, 2):
			continue
		var spaced := true
		for other: Vector2i in centers:
			if center.distance_to(other) < 11.0:
				spaced = false
				break
		if not spaced:
			continue

		var width := rng.randi_range(5, 8)
		var height := rng.randi_range(2, 3)
		if not _ridge_area_clear(center, width, height, protected):
			continue
		_stamp_ridge(center, width, height, rng)
		centers.append(center)

	print("lush terrain structure added ", centers.size(), " interior ridges")


func _add_meadow_pockets() -> void:
	var protected: Dictionary = _build_protected_cells(1, true)
	var placed := 0
	var pocket_index := 0

	# Scan regularly rather than randomly. If a 6x6-ish slice is still mostly
	# plain grass after all previous passes, it is guaranteed a small composition.
	for y: int in range(5, GameState.MAP_H - 5, 6):
		for x: int in range(5, GameState.MAP_W - 5, 6):
			if placed >= SHRUB_POCKET_TARGET:
				break
			var center := Vector2i(x, y)
			if not _pocket_area_clear(center, protected):
				continue

			var changed := 0
			# A small 3x2 undergrowth bed is the visual base of each pocket.
			for dy: int in range(-1, 1):
				for dx: int in range(-1, 2):
					var p := center + Vector2i(dx, dy)
					if not _inside(p) or protected.has(p):
						continue
					if int(GameState.grid[p.y][p.x]) != TERRAIN_GRASS:
						continue
					if _near_tile(p, TERRAIN_DIRT, 0) or _near_tile(p, TERRAIN_WATER, 0):
						continue
					GameState.grid[p.y][p.x] = TERRAIN_TALLGRASS
					changed += 1
			if changed < 4:
				continue

			# Layer two different silhouettes around the grass bed so it reads as one
			# composed feature rather than another isolated flower spawn.
			var left := center + Vector2i(-2, 1)
			var right := center + Vector2i(2, 0)
			if _small_prop_clear(left, protected, 1):
				var solid_kind := "bush" if pocket_index % 3 != 1 else "rock"
				GameState.world_props.append({"kind": solid_kind, "pos": left, "blocks": [left]})
				protected[left] = true
			if _small_prop_clear(right, protected, 0):
				var soft_kind := "flowers_a" if pocket_index % 2 == 0 else "flowers_b"
				GameState.world_props.append({"kind": soft_kind, "pos": right, "blocks": []})
				protected[right] = true

			placed += 1
			pocket_index += 1

	print("lush meadow layer added ", placed, " shrub pockets")


func _pocket_area_clear(center: Vector2i, protected: Dictionary) -> bool:
	if not _inside(center):
		return false
	if _near_tile(center, TERRAIN_DIRT, 1) or _near_tile(center, TERRAIN_WATER, 1):
		return false
	var grass := 0
	for dy: int in range(-2, 3):
		for dx: int in range(-3, 4):
			var p := center + Vector2i(dx, dy)
			if not _inside(p) or protected.has(p):
				continue
			if int(GameState.grid[p.y][p.x]) == TERRAIN_GRASS:
				grass += 1
	# Only fill genuinely plain areas. Existing detailed pockets are left alone.
	return grass >= 23


func _small_prop_clear(p: Vector2i, protected: Dictionary, path_buffer: int) -> bool:
	if not _inside(p) or protected.has(p):
		return false
	if int(GameState.grid[p.y][p.x]) != TERRAIN_GRASS:
		return false
	if path_buffer > 0 and _near_tile(p, TERRAIN_DIRT, path_buffer):
		return false
	if _near_tile(p, TERRAIN_WATER, 0):
		return false
	return true


func _ridge_area_clear(center: Vector2i, width: int, height: int, protected: Dictionary) -> bool:
	var x0 := center.x - int(width / 2) - 1
	var x1 := center.x + int(width / 2) + 1
	var y0 := center.y - 1
	var y1 := center.y + height + 1
	var grass_cells := 0
	var total_cells := 0
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var p := Vector2i(x, y)
			if not _inside(p) or protected.has(p):
				return false
			total_cells += 1
			if int(GameState.grid[y][x]) == TERRAIN_GRASS:
				grass_cells += 1
	return grass_cells >= int(float(total_cells) * 0.88)


func _stamp_ridge(center: Vector2i, width: int, height: int, rng: RandomNumberGenerator) -> void:
	var half := int(width / 2)
	for row: int in height:
		var inset_left := 1 if row == height - 1 and rng.randf() < 0.55 else 0
		var inset_right := 1 if row == 0 and rng.randf() < 0.45 else 0
		for x: int in range(center.x - half + inset_left, center.x + half + 1 - inset_right):
			var p := Vector2i(x, center.y + row)
			if _inside(p) and int(GameState.grid[p.y][p.x]) == TERRAIN_GRASS:
				GameState.grid[p.y][p.x] = TERRAIN_CLIFF

	var accents: Array[Vector2i] = [
		Vector2i(center.x - half - 1, center.y + height),
		Vector2i(center.x + half + 1, center.y + height - 1),
	]
	for i: int in accents.size():
		var p: Vector2i = accents[i]
		if _inside(p) and int(GameState.grid[p.y][p.x]) == TERRAIN_GRASS:
			GameState.world_props.append({
				"kind": "rock" if i == 0 else "flowers_b",
				"pos": p,
				"blocks": [p] if i == 0 else [],
			})
