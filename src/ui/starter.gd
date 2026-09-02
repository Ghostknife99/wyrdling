extends Control

const INK := Color("26333A")
const PAPER := Color("F8F7E8")
const GREEN := Color("3B8D63")
const GREEN_DARK := Color("1E5748")
const MUTED := Color("718078")

var _ids: Array[String] = []


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_ids = DataDB.starters.duplicate()
	if _ids.is_empty():
		_ids = ["glimmerling", "cobbleback", "briarseed"]
	_build()


func _style(fill: Color, border: Color, width: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	return sb


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("7ACB88")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Simple laboratory / camp floor framing.
	var floor := ColorRect.new()
	floor.color = Color("D9C99A")
	floor.position = Vector2(0, 76)
	floor.size = Vector2(640, 284)
	add_child(floor)
	for y in range(5):
		var seam := ColorRect.new()
		seam.color = Color(0.32, 0.27, 0.18, 0.15)
		seam.position = Vector2(0, 112 + y * 52)
		seam.size = Vector2(640, 2)
		add_child(seam)

	var header := Panel.new()
	header.position = Vector2(18, 14)
	header.size = Vector2(604, 52)
	header.add_theme_stylebox_override("panel", _style(PAPER, GREEN_DARK, 3))
	add_child(header)

	var title := Label.new()
	title.text = "Choose your first Wyrdling"
	title.position = Vector2(18, 8)
	title.size = Vector2(568, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", INK)
	header.add_child(title)

	var hint := Label.new()
	hint.text = "1 / 2 / 3 or click"
	hint.position = Vector2(18, 30)
	hint.size = Vector2(568, 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", MUTED)
	header.add_child(hint)

	var n: int = _ids.size()
	var card_w := 176.0
	var gap := 18.0
	var total: float = n * card_w + (n - 1) * gap
	var x0: float = (640.0 - total) / 2.0
	for i in n:
		var id: String = _ids[i]
		var d: Dictionary = DataDB.creatures[id]
		var panel := _make_card(i, id, d)
		panel.position = Vector2(x0 + i * (card_w + gap), 92)
		panel.size = Vector2(card_w, 238)
		add_child(panel)

	var back := Label.new()
	back.text = "ESC  BACK"
	back.position = Vector2(18, 336)
	back.size = Vector2(120, 18)
	back.add_theme_font_size_override("font_size", 10)
	back.add_theme_color_override("font_color", Color("594E35"))
	add_child(back)


func _make_card(index: int, id: String, d: Dictionary) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var primary: String = str(d.get("type", ""))
	var tcol: Color = DataDB.type_color(primary)
	panel.add_theme_stylebox_override("panel", _style(PAPER, tcol.darkened(0.28), 3))

	var key := Label.new()
	key.text = str(index + 1)
	key.position = Vector2(8, 6)
	key.size = Vector2(24, 20)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 12)
	key.add_theme_color_override("font_color", MUTED)
	panel.add_child(key)

	var tex: Texture2D = load("res://art/creatures/%s.png" % id)
	var sprite := TextureRect.new()
	sprite.texture = tex
	sprite.position = Vector2(30, 20)
	sprite.size = Vector2(116, 104)
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(sprite)

	var name_l := Label.new()
	name_l.text = str(d["name"])
	name_l.position = Vector2(8, 122)
	name_l.size = Vector2(160, 28)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", INK)
	panel.add_child(name_l)

	var type_l := Label.new()
	var type_bits: PackedStringArray = PackedStringArray()
	if d.has("types") and typeof(d["types"]) == TYPE_ARRAY:
		for t in d["types"]:
			type_bits.append(str(t))
	type_l.text = " / ".join(type_bits) if type_bits.size() > 0 else primary
	type_l.position = Vector2(8, 150)
	type_l.size = Vector2(160, 20)
	type_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_l.add_theme_font_size_override("font_size", 12)
	type_l.add_theme_color_override("font_color", tcol.darkened(0.18))
	panel.add_child(type_l)

	var stats := Label.new()
	stats.text = "HP %d   ATK %d\nDEF %d  SPD %d" % [int(d["hp"]), int(d["atk"]), int(d["def"]), int(d["spd"])]
	stats.position = Vector2(10, 176)
	stats.size = Vector2(156, 38)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 10)
	stats.add_theme_color_override("font_color", MUTED)
	panel.add_child(stats)

	var btn := Button.new()
	btn.text = "CHOOSE"
	btn.position = Vector2(18, 208)
	btn.size = Vector2(140, 24)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", INK)
	btn.add_theme_stylebox_override("normal", _style(Color("E9F3E5"), tcol.darkened(0.25), 2))
	btn.add_theme_stylebox_override("hover", _style(Color("D7EED1"), tcol.darkened(0.25), 2))
	btn.pressed.connect(func() -> void: _pick(id))
	panel.add_child(btn)

	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_pick(id)
	)
	return panel


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				if _ids.size() > 0:
					_pick(_ids[0])
			KEY_2, KEY_KP_2:
				if _ids.size() > 1:
					_pick(_ids[1])
			KEY_3, KEY_KP_3:
				if _ids.size() > 2:
					_pick(_ids[2])
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/title.tscn")


func _pick(id: String) -> void:
	GameState.start_run(id)
	get_tree().change_scene_to_file("res://scenes/dungeon.tscn")
