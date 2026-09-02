extends Control

signal combat_over(result: String)

enum State { ACTION, MOVE, SWAP, REPLACE, END }

const GOLD := Color("E8C872")  # lantern accent, locked hex
const INK := Color(0.94, 0.91, 0.84)
const MUTED := Color(0.70, 0.66, 0.58)
var ACTIONS: PackedStringArray = PackedStringArray(["Strike", "Bind", "Swap", "Flee"])

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
var options: Label
var log_label: Label
var bind_hint: Label
var btn_row: HBoxContainer


func setup(w: WyrdlingCreature) -> void:
	wild = w


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_log("A wild %s emerges from the rift." % wild.display_name)
	_log("What will %s do?" % GameState.active().display_name)
	_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.09, 0.96)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var title := Label.new()
	title.text = "Rift clash — Floor %d" % GameState.floor_num
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 16)
	title.size = Vector2(1280, 36)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GOLD)
	add_child(title)

	you_sprite = TextureRect.new()
	you_sprite.position = Vector2(160, 70)
	you_sprite.size = Vector2(192, 192)
	you_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	you_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(you_sprite)

	foe_sprite = TextureRect.new()
	foe_sprite.position = Vector2(928, 70)
	foe_sprite.size = Vector2(192, 192)
	foe_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foe_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(foe_sprite)

	var vs := Label.new()
	vs.text = "VS"
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.position = Vector2(540, 140)
	vs.size = Vector2(200, 50)
	vs.add_theme_font_size_override("font_size", 36)
	vs.add_theme_color_override("font_color", MUTED)
	add_child(vs)

	you_name = _mk_label(Vector2(80, 270), Vector2(400, 32), 24, INK, HORIZONTAL_ALIGNMENT_CENTER)
	you_type = _mk_label(Vector2(80, 302), Vector2(400, 26), 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	you_bar_bg = _mk_bar_bg(Vector2(120, 338), Vector2(320, 18))
	you_bar = _mk_bar_fill(you_bar_bg)
	you_hp = _mk_label(Vector2(80, 360), Vector2(400, 24), 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	foe_name = _mk_label(Vector2(800, 270), Vector2(400, 32), 24, INK, HORIZONTAL_ALIGNMENT_CENTER)
	foe_type = _mk_label(Vector2(800, 302), Vector2(400, 26), 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	foe_bar_bg = _mk_bar_bg(Vector2(840, 338), Vector2(320, 18))
	foe_bar = _mk_bar_fill(foe_bar_bg)
	foe_hp = _mk_label(Vector2(800, 360), Vector2(400, 24), 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	bind_hint = _mk_label(Vector2(80, 396), Vector2(1120, 24), 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	prompt = _mk_label(Vector2(80, 430), Vector2(1120, 28), 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	options = _mk_label(Vector2(80, 462), Vector2(1120, 36), 22, INK, HORIZONTAL_ALIGNMENT_CENTER)

	btn_row = HBoxContainer.new()
	btn_row.position = Vector2(200, 508)
	btn_row.size = Vector2(880, 52)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	add_child(btn_row)

	var log_bg := ColorRect.new()
	log_bg.color = Color(0.04, 0.03, 0.06, 0.9)
	log_bg.position = Vector2(80, 572)
	log_bg.size = Vector2(1120, 128)
	add_child(log_bg)
	log_label = Label.new()
	log_label.position = Vector2(96, 580)
	log_label.size = Vector2(1088, 112)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("font_size", 16)
	log_label.add_theme_color_override("font_color", INK)
	add_child(log_label)



func _creature_tex(species_id: String) -> Texture2D:
	var path := "res://art/creatures/%s.png" % species_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _mk_label(pos: Vector2, sz: Vector2, font_size: int, col: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


func _mk_bar_bg(pos: Vector2, sz: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.18, 0.16, 0.2)
	r.position = pos
	r.size = sz
	add_child(r)
	return r


func _mk_bar_fill(bg: ColorRect) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.42, 0.78, 0.48)
	r.position = Vector2(0, 0)
	r.size = bg.size
	bg.add_child(r)
	return r


func _log(msg: String) -> void:
	log_lines.append(msg)
	if log_lines.size() > 6:
		log_lines = log_lines.slice(log_lines.size() - 6)


func _refresh() -> void:
	var you: WyrdlingCreature = GameState.active()
	you_sprite.texture = _creature_tex(you.species_id)
	you_name.text = you.display_name
	you_type.text = you.type_label()
	you_type.add_theme_color_override("font_color", DataDB.type_color(you.type_id))
	you_hp.text = "HP %d / %d" % [you.hp, you.max_hp]
	_set_bar(you_bar, you_bar_bg, you.hp_ratio())
	foe_sprite.texture = _creature_tex(wild.species_id)
	foe_name.text = "Wild " + wild.display_name
	foe_type.text = wild.type_label()
	foe_type.add_theme_color_override("font_color", DataDB.type_color(wild.type_id))
	foe_hp.text = "HP %d / %d" % [wild.hp, wild.max_hp]
	_set_bar(foe_bar, foe_bar_bg, wild.hp_ratio())
	var chance: int = int(round(GameState.bind_chance(wild) * 100.0))
	bind_hint.text = "Bind chance %d%%  (rises as their HP falls)" % chance
	log_label.text = "\n".join(log_lines)
	_refresh_menu()


func _set_bar(fill: ColorRect, bg: ColorRect, ratio: float) -> void:
	var r: float = clampf(ratio, 0.0, 1.0)
	fill.size = Vector2(bg.size.x * r, bg.size.y)
	if r > 0.5:
		fill.color = Color(0.42, 0.78, 0.48)
	elif r > 0.25:
		fill.color = Color(0.86, 0.72, 0.28)
	else:
		fill.color = Color(0.82, 0.32, 0.32)


func _menu_items() -> PackedStringArray:
	match state:
		State.ACTION:
			return ACTIONS
		State.MOVE:
			var you: WyrdlingCreature = GameState.active()
			var items: PackedStringArray = PackedStringArray()
			for mid in you.moves:
				var md: Dictionary = DataDB.moves.get(mid, {"name": mid, "type": you.type_id, "power": 0})
				items.append("%s  (%s %d)" % [str(md["name"]), str(md["type"]), int(md["power"])])
			return items
		State.SWAP, State.REPLACE:
			var items2: PackedStringArray = PackedStringArray()
			for i in GameState.party.size():
				var c: WyrdlingCreature = GameState.party[i]
				var tag := "KO" if c.is_ko() else "%d/%d" % [c.hp, c.max_hp]
				items2.append("%s [%s] %s" % [c.display_name, c.type_label(), tag])
			return items2
		State.END:
			return PackedStringArray(["Continue"])
	return PackedStringArray()


func _refresh_menu() -> void:
	var items: PackedStringArray = _menu_items()
	if items.is_empty():
		cursor = 0
	else:
		cursor = clampi(cursor, 0, items.size() - 1)
	match state:
		State.ACTION:
			prompt.text = "Choose an action"
		State.MOVE:
			prompt.text = "Choose a strike"
		State.SWAP:
			prompt.text = "Swap in whom? (cannot swap to a fallen Wyrdling or yourself)"
		State.REPLACE:
			prompt.text = "Party full — choose a member to release. They are gone this run."
		State.END:
			prompt.text = "Press Enter or 1"
	var parts: PackedStringArray = PackedStringArray()
	for i in items.size():
		var mark := ">" if i == cursor else " "
		parts.append("%s %d %s" % [mark, i + 1, items[i]])
	options.text = "    ".join(parts)
	for child in btn_row.get_children():
		child.queue_free()
	var action_keys: PackedStringArray = PackedStringArray(["strike", "bind", "swap", "flee"])
	for i in items.size():
		var idx := i
		if state == State.ACTION and i < action_keys.size() and ResourceLoader.exists("res://art/ui/btn_%s.png" % action_keys[i]):
			var tb := TextureButton.new()
			tb.texture_normal = load("res://art/ui/btn_%s.png" % action_keys[i])
			tb.custom_minimum_size = Vector2(160, 44)
			tb.ignore_texture_size = true
			tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			tb.focus_mode = Control.FOCUS_NONE
			tb.pressed.connect(func() -> void: _choose(idx))
			btn_row.add_child(tb)
		else:
			var b := Button.new()
			b.text = "%d  %s" % [i + 1, items[i]]
			b.custom_minimum_size = Vector2(180, 44)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 16)
			b.pressed.connect(func() -> void: _choose(idx))
			btn_row.add_child(b)


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
		return " It sears through!"
	if mod < 0.95:
		return " It barely bites."
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
	_log("You weave a bind... (%.0f%%)" % (chance * 100.0))
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
	_log("You try to slip away... (%.0f%%)" % (chance * 100.0))
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
			prompt.text = "Permadeath. The run is over."
		"caught":
			prompt.text = "Bound. Press Enter to return to the rift."
		"won":
			prompt.text = "The wild fell. Press Enter to return to the rift."
		"fled":
			prompt.text = "You fled. Press Enter to return to the rift."
	_refresh()


func _close() -> void:
	combat_over.emit(pending_result)
	queue_free()
