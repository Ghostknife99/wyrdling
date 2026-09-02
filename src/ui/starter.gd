extends Control

const GOLD := Color("E8C872")  # lantern accent, locked hex
const INK := Color(0.94, 0.91, 0.84)
const MUTED := Color(0.70, 0.66, 0.58)

var _ids: Array[String] = []


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_ids = DataDB.starters.duplicate()
	if _ids.is_empty():
		_ids = ["glimmerling", "cobbleback", "briarseed"]
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.078, 0.067, 0.098)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "Choose a starter"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 28)
	title.size = Vector2(1280, 48)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", GOLD)
	add_child(title)

	var hint := Label.new()
	hint.text = "Press 1 / 2 / 3  or click a card"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 76)
	hint.size = Vector2(1280, 28)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", MUTED)
	add_child(hint)

	var n: int = _ids.size()
	var card_w := 340.0
	var gap := 36.0
	var total: float = n * card_w + (n - 1) * gap
	var x0: float = (1280.0 - total) / 2.0
	for i in n:
		var id: String = _ids[i]
		var d: Dictionary = DataDB.creatures[id]
		var panel := _make_card(i, id, d)
		panel.position = Vector2(x0 + i * (card_w + gap), 120)
		panel.size = Vector2(card_w, 540)
		add_child(panel)


func _make_card(index: int, id: String, d: Dictionary) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var primary: String = str(d.get("type", ""))
	var tcol: Color = DataDB.type_color(primary)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.16, 1)
	sb.border_color = tcol
	sb.set_border_width_all(3)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.set_anchors_preset(PRESET_FULL_RECT)
	v.offset_left = 20
	v.offset_right = -20
	v.offset_top = 16
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var key := Label.new()
	key.text = str(index + 1)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 18)
	key.add_theme_color_override("font_color", MUTED)
	v.add_child(key)

	var tex: Texture2D = load("res://art/creatures/%s.png" % id)
	var sprite := TextureRect.new()
	sprite.texture = tex
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = Vector2(160, 160)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.add_child(sprite)

	var name_l := Label.new()
	name_l.text = str(d["name"])
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 28)
	name_l.add_theme_color_override("font_color", INK)
	v.add_child(name_l)

	var type_l := Label.new()
	var type_bits: PackedStringArray = PackedStringArray()
	if d.has("types") and typeof(d["types"]) == TYPE_ARRAY:
		for t in d["types"]:
			type_bits.append(str(t))
	type_l.text = " / ".join(type_bits) if type_bits.size() > 0 else str(d.get("type", ""))
	type_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_l.add_theme_font_size_override("font_size", 20)
	type_l.add_theme_color_override("font_color", tcol)
	v.add_child(type_l)

	var stats := Label.new()
	stats.text = "HP %d   Atk %d   Def %d   Spd %d" % [int(d["hp"]), int(d["atk"]), int(d["def"]), int(d["spd"])]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_color_override("font_color", MUTED)
	v.add_child(stats)

	var desc := Label.new()
	desc.text = str(d["description"])
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", INK)
	v.add_child(desc)

	var move_names: PackedStringArray = PackedStringArray()
	for m in d["moves"]:
		move_names.append(DataDB.move_name(str(m)))
	var mv := Label.new()
	mv.text = "Moves: " + ", ".join(move_names)
	mv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_theme_font_size_override("font_size", 16)
	mv.add_theme_color_override("font_color", GOLD)
	v.add_child(mv)

	var btn := Button.new()
	btn.text = "Bind this one"
	btn.custom_minimum_size = Vector2(0, 44)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func() -> void: _pick(id))
	v.add_child(btn)

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
