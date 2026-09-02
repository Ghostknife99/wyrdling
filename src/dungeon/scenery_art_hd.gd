extends RefCounted
## Loads the approved high-definition Willowmere scenery assets.

const ATLAS_PATH := "res://art/tiles/overworld/hd_target_atlas.png"
const PROPS_PATH := "res://art/world/hd_target_props.png"

static func make_atlas() -> Texture2D:
	return load(ATLAS_PATH) as Texture2D

static func make_props_sheet() -> Texture2D:
	return load(PROPS_PATH) as Texture2D
