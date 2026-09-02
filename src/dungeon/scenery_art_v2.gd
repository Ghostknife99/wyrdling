extends RefCounted
## Approved Willowmere HD scenery artwork.
## The payload is kept as plain text so GitHub never has to transport the PNG as
## a repository binary. We reconstruct both textures at runtime from the exact
## approved palette PNG data.

const PAYLOAD_PATH := "res://src/dungeon/scenery_payload.txt"

static func _payload(name: String, next_marker: String) -> String:
	var source := FileAccess.get_file_as_string(PAYLOAD_PATH)
	if source.is_empty():
		push_error("Scenery payload could not be read")
		return ""
	var start_marker := "const %s :=" % name
	var start := source.find(start_marker)
	if start < 0:
		push_error("Scenery payload is missing %s" % name)
		return ""
	var finish := source.find(next_marker, start)
	if finish < 0:
		finish = source.length()
	var section := source.substr(start, finish - start)
	var regex := RegEx.new()
	regex.compile("\\\"([A-Za-z0-9+/=]+)\\\"")
	var result := ""
	for match in regex.search_all(section):
		result += match.get_string(1)
	return result

static func _decode_png(encoded: String, expected_size: Vector2i) -> Texture2D:
	if encoded.is_empty():
		return null
	var bytes: PackedByteArray = Marshalls.base64_to_raw(encoded)
	var image := Image.new()
	var err := image.load_png_from_buffer(bytes)
	if err != OK:
		push_error("Scenery PNG decode failed: %s" % err)
		return null
	if image.get_size() != expected_size:
		push_error("Scenery image size mismatch: %s expected %s" % [image.get_size(), expected_size])
		return null
	return ImageTexture.create_from_image(image)

static func make_atlas() -> Texture2D:
	return _decode_png(_payload("ATLAS_B64", "const PROPS_B64"), Vector2i(512, 480))

static func make_props_sheet() -> Texture2D:
	return _decode_png(_payload("PROPS_B64", "static func _decode_png"), Vector2i(256, 128))
