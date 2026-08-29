extends Node

var TYPES: Array[String] = ["Light", "Void", "Flame", "Tide", "Nature", "Terra", "Gale", "Storm", "Frost", "Blood", "Spirit", "Mind", "Metal", "Primal", "Blight", "Arcane"]
var super_mult: float = 1.5
var resist_mult: float = 0.7
var type_beats: Dictionary = {}
var type_colors: Dictionary = {}

var creatures: Dictionary = {}
var moves: Dictionary = {}
var creature_order: Array[String] = []
var starters: Array[String] = []


func _ready() -> void:
	_load_data()


func _load_data() -> void:
	creatures.clear()
	moves.clear()
	creature_order.clear()
	starters.clear()
	_load_types()
	_ingest_table(FileAccess.get_file_as_string("res://data/creatures.json"), true)
	_ingest_table(FileAccess.get_file_as_string("res://data/moves.json"), false)


func _load_types() -> void:
	if not FileAccess.file_exists("res://data/types.json"):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/types.json"))
	if typeof(data) != TYPE_DICTIONARY:
		return
	if data.has("order"):
		TYPES.clear()
		for t in data["order"]:
			TYPES.append(str(t))
	super_mult = float(data.get("super", 1.5))
	resist_mult = float(data.get("resist", 0.7))
	if data.has("colors"):
		for k in data["colors"]:
			type_colors[str(k)] = Color(str(data["colors"][k]))
	type_beats.clear()
	if data.has("beats"):
		for k in data["beats"]:
			var arr: Array = []
			for v in data["beats"][k]:
				arr.append(str(v))
			type_beats[str(k)] = arr


func _ingest_table(text: String, is_creatures: bool) -> void:
	var parsed: Variant = JSON.parse_string(text)
	var items: Array = []
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.has("creatures") and typeof(parsed["creatures"]) == TYPE_ARRAY:
			items = parsed["creatures"]
		elif parsed.has("moves") and typeof(parsed["moves"]) == TYPE_ARRAY:
			items = parsed["moves"]
		else:
			for k in parsed.keys():
				var v: Variant = parsed[k]
				if typeof(v) == TYPE_DICTIONARY:
					if not v.has("id"):
						v["id"] = str(k)
					items.append(v)
	elif typeof(parsed) == TYPE_ARRAY:
		items = parsed
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id: String = str(item.get("id", ""))
		if id.is_empty():
			continue
		if is_creatures:
			creatures[id] = item
			creature_order.append(id)
			if bool(item.get("starter", false)):
				starters.append(id)
		else:
			moves[id] = item


func type_mod(atk_type: String, def_type: String) -> float:
	if atk_type == def_type:
		return 1.0
	var atk_list: Array = type_beats.get(atk_type, [])
	if def_type in atk_list:
		return super_mult
	var def_list: Array = type_beats.get(def_type, [])
	if atk_type in def_list:
		return resist_mult
	return 1.0


func type_color(t: String) -> Color:
	if type_colors.has(t):
		return type_colors[t]
	return Color(0.85, 0.85, 0.85)


func type_icon(t: String) -> Texture2D:
	var key := t.to_lower()
	var path := "res://art/ui/icon_%s.png" % key
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func move_name(move_id: String) -> String:
	if moves.has(move_id):
		return str(moves[move_id]["name"])
	return move_id
