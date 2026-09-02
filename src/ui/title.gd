extends Control

const INK := Color("26333A")
const PAPER := Color("F8F7E8")
const GREEN := Color("3B8D63")
const GREEN_DARK := Color("1E5748")
const SKY := Color("83CBE5")
const GOLD := Color("E8C872")


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build()


func _panel_style(fill: Color, border: Color, width: int = 3) -> StyleBoxFlat:
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
	# Bright route-like title backdrop instead of the old dark PC menu.
	var sky := ColorRect.new()
	sky.color = SKY
	sky.set_anchors_preset(PRESET_FULL_RECT)
	add_child(sky)

	var far := ColorRect.new()
	far.color = Color("589F72")
	far.position = Vector2(0, 118)
	far.size = Vector2(640, 242)
	add_child(far)

	# Layered tree-line bands give the screen a handheld-RPG silhouette using no borrowed assets.
	for i in range(14):
		var crown := Polygon2D.new()
		var x := float(i * 52 - 24)
		crown.polygon = PackedVector2Array([
			Vector2(x, 146), Vector2(x + 28, 86 + (i % 3) * 5), Vector2(x + 56, 146)
		])
		crown.color = Color("2D7558") if i % 2 == 0 else Color("347F5B")
		add_child(crown)

	var lawn := ColorRect.new()
	lawn.color = Color("65B96F")
	lawn.position = Vector2(0, 170)
	lawn.size = Vector2(640, 190)
	add_child(lawn)

	# Decorative path.
	var path := ColorRect.new()
	path.color = Color("D8BC79")
	path.position = Vector2(0, 270)
	path.size = Vector2(640, 90)
	add_child(path)
	for i in range(18):
		var fleck := ColorRect.new()
		fleck.color = Color(0.55, 0.43, 0.24, 0.24)
		fleck.position = Vector2(12 + (i * 47) % 620, 278 + (i * 19) % 66)
		fleck.size = Vector2(4, 2)
		add_child(fleck)

	var logo_panel := Panel.new()
	logo_panel.position = Vector2(96, 34)
	logo_panel.size = Vector2(448, 132)
	logo_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.97, 0.98, 0.91, 0.94), GREEN_DARK, 4))
	add_child(logo_panel)

	var word := TextureRect.new()
	word.texture = load("res://art/ui/wordmark_tight.png")
	word.position = Vector2(36, 16)
	word.size = Vector2(376, 72)
	word.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	word.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	word.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo_panel.add_child(word)

	var subtitle := Label.new()
	subtitle.text = "RIFTBOUND ADVENTURE"
	subtitle.position = Vector2(0, 92)
	subtitle.size = Vector2(448, 24)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", GREEN_DARK)
	logo_panel.add_child(subtitle)

	var start_panel := Panel.new()
	start_panel.position = Vector2(175, 205)
	start_panel.size = Vector2(290, 56)
	start_panel.add_theme_stylebox_override("panel", _panel_style(PAPER, INK, 3))
	add_child(start_panel)

	var begin := Button.new()
	begin.text = "▶  BEGIN ADVENTURE"
	begin.position = Vector2(8, 8)
	begin.size = Vector2(274, 40)
	begin.focus_mode = Control.FOCUS_NONE
	begin.add_theme_font_size_override("font_size", 18)
	begin.add_theme_color_override("font_color", INK)
	begin.add_theme_stylebox_override("normal", _panel_style(PAPER, Color(0, 0, 0, 0), 0))
	begin.add_theme_stylebox_override("hover", _panel_style(Color("E6F3DF"), Color(0, 0, 0, 0), 0))
	begin.add_theme_stylebox_override("pressed", _panel_style(Color("CDE4C5"), Color(0, 0, 0, 0), 0))
	begin.pressed.connect(_begin)
	start_panel.add_child(begin)

	var hint := Label.new()
	hint.text = "ENTER / SPACE"
	hint.position = Vector2(0, 326)
	hint.size = Vector2(640, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("30493B"))
	add_child(hint)

	var version := Label.new()
	version.text = "WYRDLING  •  ORIGINAL IP"
	version.position = Vector2(12, 338)
	version.size = Vector2(616, 18)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.add_theme_font_size_override("font_size", 10)
	version.add_theme_color_override("font_color", Color(0.16, 0.25, 0.20, 0.65))
	add_child(version)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_begin()
		get_viewport().set_input_as_handled()


func _begin() -> void:
	get_tree().change_scene_to_file("res://scenes/starter_select.tscn")
