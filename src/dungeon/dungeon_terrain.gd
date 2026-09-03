extends "res://src/dungeon/dungeon_lush.gd"
## Adds a small number of authored-looking interior ledges after foliage density.
## These break up the last large flat meadows without touching the main trail,
## water crossings, landmarks, NPCs or existing tree masses.

const TERRAIN_CLIFF := 0
const TERRAIN_GRASS := 1
const TERRAIN_DIRT := 3
const TERRAIN_WATER := 4
const RIDGE_TARGET := 5


func _apply_density_pass() -> void:
	super._apply_density_pass()
	_add_terrain_ridges()


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
	# Ridges belong in genuinely empty meadow, not on top of existing detail.
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

	# A couple of foot-of-ledge accents make the formation read as a composed
	# feature rather than a bare brown obstruction.
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
