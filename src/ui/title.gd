extends Control

const GOLD := Color("E8C872")  # lantern accent, locked hex
const INK := Color(0.94, 0.91, 0.84)
const MUTED := Color(0.70, 0.66, 0.58)


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.078, 0.067, 0.098)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.offset_left = 80
	root.offset_right = -80
	root.offset_top = 40
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var word := TextureRect.new()
	word.texture = load("res://art/ui/wordmark.png")
	word.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	word.custom_minimum_size = Vector2(720, 150)
	word.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(word)

	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", 18)
	for tid in ["Wisp", "Iron", "Bloom", "Dusk", "Tide"]:
		var ic := TextureRect.new()
		ic.texture = load("res://art/ui/icon_%s.png" % tid.to_lower())
		ic.custom_minimum_size = Vector2(32, 32)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icons.add_child(ic)
	root.add_child(icons)

	var sub := Label.new()
	sub.text = "Delve rifts, bind Wyrdlings."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", INK)
	root.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	root.add_child(spacer)

	var begin := Button.new()
	begin.text = "  Begin a Run  "
	begin.custom_minimum_size = Vector2(280, 56)
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	begin.add_theme_font_size_override("font_size", 22)
	begin.focus_mode = Control.FOCUS_NONE
	begin.pressed.connect(_begin)
	root.add_child(begin)

	var hint := Label.new()
	hint.text = "Press Enter or Space"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", MUTED)
	root.add_child(hint)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", INK)
	body.text = "A rift-delver binds living shards of other worlds. Party of three. Permadeath.\n\nTypes (pentagon):  Wisp beats Iron  ·  Iron beats Bloom  ·  Bloom beats Dusk  ·  Dusk beats Tide  ·  Tide beats Wisp\nSuper-effective 1.5×   ·   Resist 0.7×   ·   Otherwise 1.0×\n\nWASD / arrows to walk. Bump a wild Wyrdling to clash.  1 Strike  2 Bind  3 Swap  4 Flee.\nReach the gold stairs to descend. If the whole party falls, the run ends."
	root.add_child(body)

	var roster := Label.new()
	roster.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roster.add_theme_font_size_override("font_size", 16)
	roster.add_theme_color_override("font_color", MUTED)
	roster.text = "Roster:  Glimmerling (Wisp) · Wickmoth (Wisp) · Cobbleback (Iron) · Nailbit (Iron) · Briarseed (Bloom) · Marrowl (Dusk) · Veilcrawler (Dusk) · Brinekit (Tide)"
	root.add_child(roster)

	var orig := Label.new()
	orig.text = "Original IP. Not affiliated with Nintendo or Pokémon."
	orig.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orig.add_theme_font_size_override("font_size", 14)
	orig.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38))
	root.add_child(orig)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_begin()
		get_viewport().set_input_as_handled()


func _begin() -> void:
	get_tree().change_scene_to_file("res://scenes/starter_select.tscn")
