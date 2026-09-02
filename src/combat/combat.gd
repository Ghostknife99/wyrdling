extends Control

signal combat_over(result: String)

enum State { ACTION, MOVE, SWAP, REPLACE, END }

const INK := Color("26333A")
const PAPER := Color("FBFAEA")
const BORDER := Color("40535D")
const GREEN := Color("4FAF62")
const GREEN_DARK := Color("276447")
const MUTED := Color("738087")
const GOLD := Color("D69B36")
var ACTIONS: PackedStringArray = PackedStringArray(["STRIKE", "BIND", "PARTY", "FLEE"])

var wild: WyrdlingCreature
var state: State = State.ACTION
var cursor := 0
var pending_result: String = ""
var log_lines: PackedStringArray = PackedStringArray()

var you_name: Label
var you_type: Label
var you_hp: Label
var you_bar: ColorRect
var you_bar_bg: ColorRect
var you_sprite: TextureRect
var foe_name: Label
var foe_type: Label
var foe_hp: Label
var foe_bar: ColorRect
var foe_bar_bg: ColorRect
var foe_sprite: TextureRect
var prompt: Label
var log_label: Label
var bind_hint: Label
var menu_grid: GridContainer


func setup(w: WyrdlingCreature) -> void:
	wild = w


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_log("A wild %s appeared!" % wild.display_name)
	_log("What will %s do?" % GameState.active().display_name)
	_refresh()


func _style(fill: Color, border: Color = BORDER, width: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


func _build() -> void:
	# Bright outdoor battle field inspired by the readable GBA-era composition,
	# while keeping all Wyrdling names, mechanics and artwork original.
	var sky := ColorRect.new()
	sky.color = Color("9CD7EA")
	sky.set_anchors_preset(PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sky)

	var horizon := ColorRect.new()
	horizon.color = Color("5DAA70")
	horizon.position = Vector2(0, 84)
	horizon.size = Vector2(640, 172)
	add_child(horizon)

	for i in range(13):
		var tree := Polygon2D.new()
		var x := float(i * 54 - 24)
		tree.polygon = PackedVector2Array([
			Vector2(x, 104), Vector2(x + 27, 56 + (i % 3) * 6), Vector2(x + 54, 104)
		])
		tree.color = Color("357A58") if i % 2 == 0 else Color("2E6D52")
		add_child(tree)

	var field := ColorRect.new()
	field.color = Color("78BE68")
	field.position = Vector2(0, 118)
	field.size = Vector2(640, 138)
	add_child(field)

	var foe_pad := Panel.new()
	foe_pad.position = Vector2(382, 126)
	foe_pad.size = Vector2(206, 52)
	foe_pad.add_theme_stylebox_override("panel", _style(Color("6BB55C"), Color("4B8E4B"), 2))
	add_child(foe_pad)

	var you_pad := Panel.new()
	you_pad.position = Vector2(34, 212)
	you_pad.size = Vector2(238, 38)
	you_pad.add_theme_stylebox_override("panel", _style(Color("65A95A"), Color("438248"), 2))
	add_child(you_pad)

	foe_sprite = TextureRect.new()
	foe_sprite.position = Vector2(430, 56)
	foe_sprite.size = Vector2(118, 112)
	foe_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foe_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	foe_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(foe_sprite)

	you_sprite = TextureRect.new()
	you_sprite.position = Vector2(62, 126)
	you_sprite.size = Vector2(154, 126)
	you_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	you_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	you_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(you_sprite)

	_make_foe_status()
	_make_you_status()

	var dialogue := Panel.new()
	dialogue.position = Vector2(0, 256)
	dialogue.size = Vector2(318, 104)
	dialogue.add_theme_stylebox_override("panel", _style(PAPER, BORDER, 4))
	add_child(dialogue)

	prompt = Label.new()
	prompt.position = Vector2(18, 13)
	prompt.size = Vector2(282, 48)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", 17)
	prompt.add_theme_color_override("font_color", INK)
	dialogue.add_child(prompt)

	log_label = Label.new()
	log_label.position = Vector2(18, 61)
	log_label.size = Vector2(282, 34)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("font_size", 10)
	log_label.add_theme_color_override("font_color", MUTED)
	dialogue.add_child(log_label)

	var command := Panel.new()
	command.position = Vector2(318, 256)
	command.size = Vector2(322, 104)
	command.add_theme_stylebox_override("panel", _style(Color("F4F3E7"), BORDER, 4))
	add_child(command)

	menu_grid = GridContainer.new()
	menu_grid.columns = 2
	menu_grid.position = Vector2(10, 9)
	menu_grid.size = Vector2(302, 86)
	menu_grid.add_theme_constant_override("h_separation", 6)
	menu_grid.add_theme_constant_override("v_separation", 6)
	command.add_child(menu_grid)

	bind_hint = Label.new()
	bind_hint.position = Vector2(330, 235)
	bind_hint.size = Vector2(300, 18)
	bind_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bind_hint.add_theme_font_size_override("font_size", 9)
	bind_hint.add_theme_color_override("font_color", Color(0.12, 0.24, 0.16, 0.72))
	add_child(bind_hint)


func _make_foe_status() -> void:
	var p := Panel.new()
	p.position = Vector2(20, 22)
	p.size = Vector2(270, 78)
	p.add_theme_stylebox_override("panel", _style(PAPER, BORDER, 3))
	add_child(p)

	foe_name = _label_in(p, Vector2(14, 8), Vector2(150, 22), 18, INK)
	foe_type = _label_in(p, Vector2(170, 10), Vector2(84, 18), 11, GREEN_DARK, HORIZONTAL_ALIGNMENT_RIGHT)
	var hp_tag := _label_in(p, Vector2(16, 38), Vector2(30, 16), 10, GOLD)
	hp_tag.text = "HP"
	foe_bar_bg = _bar_in(p, Vector2(47, 40), Vector2(204, 10))
	foe_bar = _bar_fill(foe_bar_bg)
	foe_hp = _label_in(p, Vector2(90, 55), Vector2(160, 16), 10, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)


func _make_you_status() -> void:
	var p := Panel.new()
	p.position = Vector2(348, 166)
	p.size = Vector2(276, 82)
	p.add_theme_stylebox_override("panel", _style(PAPER, BORDER, 3))
	add_child(p)

	you_name = _label_in(p, Vector2(14, 8), Vector2(156, 22), 18, INK)
	you_type = _label_in(p, Vector2(176, 10), Vector2(84, 18), 11, GREEN_DARK, HORIZONTAL_ALIGNMENT_RIGHT)
	var hp_tag := _label_in(p, Vector2(16, 39), Vector2(30, 16), 10, GOLD)
	hp_tag.text = "HP"
	you_bar_bg = _bar_in(p, Vector2(47, 41), Vector2(210, 10))
	you_bar = _bar_fill(you_bar_bg)
	you_hp = _label_in(p, Vector2(86, 58), Vector2(170, 16), 10, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)


func _label_in(parent: Control, pos: Vector2, sz: Vector2, font_size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _bar_in(parent: Control, pos: Vector2, sz: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color("49545A")
	r.position = pos
	r.size = sz
	parent.add_child(r)
	return r


func _bar_fill(bg: ColorRect) -> ColorRect:
	var r := ColorRect.new()
	r.color = GREEN
	r.position = Vector2(2, 2)
	r.size = Vector2(bg.size.x - 4, bg.size.y - 4)
	bg.add_child(r)
	return r


func _creature_tex(species_id: String) -> Texture2D:
	var path := "res://art/creatures/%s.png" % species_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _log(msg: String) -> void:
	log_lines.append(msg)
	if log_lines.size() > 3:
		log_lines = log_lines.slice(log_lines.size() - 3)


func _refresh() -> void:
	var you: WyrdlingCreature = GameState.active()
	you_sprite.texture = _creature_tex(you.species_id)
	you_name.text = you.display_name
	you_type.text = you.type_label()
	you_type.add_theme_color_override("font_color", DataDB.type_color(you.type_id).darkened(0.18))
	you_hp.text = "%d / %d" % [you.hp, you.max_hp]
	_set_bar(you_bar, you_bar_bg, you.hp_ratio())

	foe_sprite.texture = _creature_tex(wild.species_id)
	foe_name.text = wild.display_name
	foe_type.text = wild.type_label()
	foe_type.add_theme_color_override("font_color", DataDB.type_color(wild.type_id).darkened(0.18))
	foe_hp.text = "%d / %d" % [wild.hp, wild.max_hp]
	_set_bar(foe_bar, foe_bar_bg, wild.hp_ratio())

	var chance: int = int(round(GameState.bind_chance(wild) * 100.0))
	bind_hint.text = "BIND CHANCE %d%%" % chance
	log_label.text = str(log_lines[log_lines.size() - 1]) if not log_lines.is_empty() else ""
	_refresh_menu()


func _set_bar(fill: ColorRect, bg: ColorRect, ratio: float) -> void:
	var r: float = clampf(ratio, 0.0, 1.0)
	fill.size = Vector2((bg.size.x - 4) * r, bg.size.y - 4)
	if r > 0.5:
		fill.color = Color("55B968")
	elif r > 0.25:
		fill.color = Color("D3B347")
	else:
		fill.color = Color("D75B54")


func _menu_items() -> PackedStringArray:
	match state:
		State.ACTION:
			return ACTIONS
		State.MOVE:
			var you: WyrdlingCreature = GameState.active()
			var items: PackedStringArray = PackedStringArray()
			for mid in you.moves:
				var md: Dictionary = DataDB.moves.get(mid, {"name": mid, "type": you.type_id, "power": 0})
				items.append("%s  %d" % [str(md["name"]).to_upper(), int(md["power"])])
			return items
		State.SWAP, State.REPLACE:
			var items2: PackedStringArray = PackedStringArray()
			for i in GameState.party.size():
				var c: WyrdlingCreature = GameState.party[i]
				var tag := "KO" if c.is_ko() else "%d/%d" % [c.hp, c.max_hp]
				items2.append("%s  %s" % [c.display_name.to_upper(), tag])
			return items2
		State.END:
			return PackedStringArray(["CONTINUE"])
	return PackedStringArray()


func _refresh_menu() -> void:
	var items: PackedStringArray = _menu_items()
	if items.is_empty():
		cursor = 0
	else:
		cursor = clampi(cursor, 0, items.size() - 1)

	match state:
		State.ACTION:
			prompt.text = "What will\n%s do?" % GameState.active().display_name
		State.MOVE:
			prompt.text = "Choose a strike."
		State.SWAP:
			prompt.text = "Choose a party member."
		State.REPLACE:
			prompt.text = "Party full. Choose one to release."
		State.END:
			prompt.text = "The clash is over."

	for child in menu_grid.get_children():
		child.queue_free()

	for i in items.size():
		var idx := i
		var b := Button.new()
		var mark := "▶ " if i == cursor else "  "
		b.text = mark + items[i]
		b.custom_minimum_size = Vector2(145, 37 if items.size() <= 4 else 26)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13 if items.size() <= 4 else 10)
		b.add_theme_color_override("font_color", INK)
		var fill := Color("E5EFE1") if i == cursor else PAPER
		b.add_theme_stylebox_override("normal", _style(fill, Color("A3B0A6"), 2))
		b.add_theme_stylebox_override("hover", _style(Color("D5E9CF"), GREEN_DARK, 2))
		b.add_theme_stylebox_override("pressed", _style(Color("C5DFBF"), GREEN_DARK, 2))
		b.pressed.connect(func() -> void: _choose(idx))
		menu_grid.add_child(b)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.keycode
	get_viewport().set_input_as_handled()
	if k == KEY_LEFT or k == KEY_A or k == KEY_UP:
		_nudge(-1)
		return
	if k == KEY_RIGHT or k == KEY_D or k == KEY_DOWN:
		_nudge(1)
		return
	if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		_choose(cursor)
		return
	match k:
		KEY_1, KEY_KP_1:
			_choose(0)
		KEY_2, KEY_KP_2:
			_choose(1)
		KEY_3, KEY_KP_3:
			_choose(2)
		KEY_4, KEY_KP_4:
			_choose(3)


func _nudge(delta: int) -> void:
	var items: PackedStringArray = _menu_items()
	if items.is_empty():
		return
	cursor = posmod(cursor + delta, items.size())
	_refresh_menu()


func _choose(index: int) -> void:
	var items: PackedStringArray = _menu_items()
	if index < 0 or index >= items.size():
		return
	cursor = index
	match state:
		State.ACTION:
			_do_action(index)
		State.MOVE:
			_do_strike(index)
		State.SWAP:
			_do_swap(index)
		State.REPLACE:
			_do_replace(index)
		State.END:
			_close()


func _do_action(index: int) -> void:
	match index:
		0:
			state = State.MOVE
			cursor = 0
			_refresh()
		1:
			_do_bind()
		2:
			if GameState.living_count() <= 1:
				_log("No ally stands ready to swap in.")
				_refresh()
				return
			state = State.SWAP
			cursor = 0
			_refresh()
		3:
			_do_flee()


func _do_strike(move_index: int) -> void:
	var you: WyrdlingCreature = GameState.active()
	if move_index < 0 or move_index >= you.moves.size():
		return
	var move_id: String = you.moves[move_index]
	var player_first: bool = you.spd >= wild.spd
	if player_first:
		_resolve_hit(you, wild, move_id, true)
		if wild.is_ko():
			_victory()
			return
		_enemy_strike()
		if _check_wipe_or_switch():
			return
	else:
		_enemy_strike()
		if _check_wipe_or_switch():
			return
		if wild.is_ko():
			_victory()
			return
		_resolve_hit(you, wild, move_id, true)
		if wild.is_ko():
			_victory()
			return
	state = State.ACTION
	cursor = 0
	_refresh()


func _resolve_hit(attacker: WyrdlingCreature, defender: WyrdlingCreature, move_id: String, _is_player: bool) -> void:
	var info: Dictionary = GameState.calc_damage(attacker, defender, move_id)
	var md: Dictionary = info["move"]
	var dmg: int = int(info["damage"])
	defender.take_damage(dmg)
	_log("%s used %s! %d damage.%s" % [attacker.display_name, str(md["name"]), dmg, _mod_text(float(info["mod"]))])
	if defender.is_ko():
		_log("%s fell." % defender.display_name)


func _mod_text(mod: float) -> String:
	if mod > 1.05:
		return " Super effective!"
	if mod < 0.95:
		return " Not very effective."
	return ""


func _enemy_strike() -> void:
	if wild.is_ko():
		return
	var you: WyrdlingCreature = GameState.active()
	if you == null or you.is_ko():
		return
	var mid: String = wild.moves[GameState.rng.randi_range(0, wild.moves.size() - 1)]
	_resolve_hit(wild, you, mid, false)


func _check_wipe_or_switch() -> bool:
	if GameState.all_ko():
		_log("The whole party is lost. The rift closes.")
		_end_with("wiped")
		return true
	var cur: WyrdlingCreature = GameState.party[GameState.active_index]
	if cur.is_ko():
		GameState.active_index = GameState.first_living_index()
		_log("%s steps forward." % GameState.active().display_name)
		state = State.ACTION
		cursor = 0
		_refresh()
		return true
	return false


func _do_bind() -> void:
	var chance: float = GameState.bind_chance(wild)
	_log("You weave a bind... %.0f%%" % (chance * 100.0))
	if GameState.rng.randf() <= chance:
		_log("The bind takes! %s is yours." % wild.display_name)
		if GameState.party.size() < 3:
			GameState.bind_into_party(wild)
			GameState.remove_wild_creature(wild)
			_end_with("caught")
		else:
			state = State.REPLACE
			cursor = 0
			_refresh()
		return
	_log("The bind slips. %s lashes back." % wild.display_name)
	_enemy_strike()
	if _check_wipe_or_switch():
		return
	state = State.ACTION
	cursor = 0
	_refresh()


func _do_replace(index: int) -> void:
	if index < 0 or index >= GameState.party.size():
		return
	var dropped: String = GameState.replace_member(index, wild)
	GameState.remove_wild_creature(wild)
	if GameState.active().species_id == wild.species_id and GameState.party[index] == wild:
		GameState.active_index = index
	_log("Released %s. Bound %s." % [dropped, wild.display_name])
	_end_with("caught")


func _do_swap(index: int) -> void:
	if index < 0 or index >= GameState.party.size():
		return
	if index == GameState.active_index:
		_log("Already in the clash.")
		_refresh()
		return
	if GameState.party[index].is_ko():
		_log("That Wyrdling cannot stand.")
		_refresh()
		return
	GameState.active_index = index
	_log("%s switches in." % GameState.active().display_name)
	_enemy_strike()
	if _check_wipe_or_switch():
		return
	state = State.ACTION
	cursor = 0
	_refresh()


func _do_flee() -> void:
	var you: WyrdlingCreature = GameState.active()
	var chance: float = GameState.flee_chance(you, wild)
	_log("You try to slip away... %.0f%%" % (chance * 100.0))
	if GameState.rng.randf() <= chance:
		_log("You break from the clash.")
		_end_with("fled")
		return
	_log("The wild cuts you off.")
	_enemy_strike()
	if _check_wipe_or_switch():
		return
	state = State.ACTION
	cursor = 0
	_refresh()


func _victory() -> void:
	GameState.remove_wild_creature(wild)
	_end_with("won")


func _end_with(result: String) -> void:
	pending_result = result
	state = State.END
	cursor = 0
	match result:
		"wiped":
			_log("Your run is over.")
		"caught":
			_log("Bound successfully.")
		"won":
			_log("The wild Wyrdling fell.")
		"fled":
			_log("You escaped safely.")
	_refresh()


func _close() -> void:
	combat_over.emit(pending_result)
	queue_free()
