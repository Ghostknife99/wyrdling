extends RefCounted
## Compatibility wrapper for the approved HD Willowmere runtime art.
const ART = preload("res://src/dungeon/scenery_art_v2.gd")

static func make_atlas() -> Texture2D:
	return ART.make_atlas()

static func make_props_sheet() -> Texture2D:
	return ART.make_props_sheet()
