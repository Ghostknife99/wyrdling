extends "res://src/dungeon/dungeon.gd"
## 16x16 overworld presentation layer.
## Keeps the 640x360 UI canvas intact while rendering the world at a 2x camera zoom.

const TILE_16 := 16
const ACTOR_MAX_W := 24.0
const ACTOR_MAX_H := 24.0
const PROP_SOURCE_SCALE := 0.5


func _ensure_world() -> void:
	super._ensure_world()
	var builder = load("res://src/dungeon/wilds_tileset_16.gd")
	tileset = builder.build()
	for layer in [ground, deco, overlay]:
		layer.tile_set = tileset
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _fit_sprite(spr: Sprite2D, tex: Texture2D) -> void:
	if tex == null:
		return
	spr.texture = tex
	spr.centered = false
	var tw := float(maxi(tex.get_width(), 1))
	var th := float(maxi(tex.get_height(), 1))
	var scale_factor: float = minf(ACTOR_MAX_W / tw, ACTOR_MAX_H / th)
	spr.scale = Vector2(scale_factor, scale_factor)
	spr.offset = Vector2(-tw / 2.0, -th)


func _actor_pos(p: Vector2i) -> Vector2:
	return Vector2(p.x * TILE_16 + TILE_16 / 2.0, p.y * TILE_16 + TILE_16)


func _build_camera() -> void:
	super._build_camera()
	cam.zoom = Vector2(2.0, 2.0)
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
