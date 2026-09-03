extends RefCounted
## Shared metadata for the polished overworld NPC set.
## The atlas has one row per NPC type and four directional frames per row.

const FRAME_W := 20
const FRAME_H := 28
const TYPE_COUNT := 20
const DIRECTIONS: Array[String] = ["down", "left", "right", "up"]

const TYPES: Array[Dictionary] = [
	{
		"id": "trail_ranger",
		"name": "Trail Ranger",
		"role": "ranger",
		"text": "Fresh tracks cross the verge here. Keep your Wyrdling close when the grass goes quiet.",
	},
	{
		"id": "rift_wayfarer",
		"name": "Rift Wayfarer",
		"role": "traveller",
		"text": "I follow the old lantern marks. They move after every rift-gate crossing, but they never lie.",
	},
	{
		"id": "herbalist",
		"name": "Willowmere Herbalist",
		"role": "gatherer",
		"text": "Riftbloom folds its petals when a wild Wyrdling is near. Useful little warning, if you know it.",
	},
	{
		"id": "riftguard_knight",
		"name": "Riftguard Knight",
		"role": "warden",
		"text": "The bridge is clear. Echo Cave is another matter — I heard something answering the stone today.",
	},
	{
		"id": "river_fisher",
		"name": "River Fisher",
		"role": "fisher",
		"text": "Wild Wyrdlings come down to drink at dusk. Sit still long enough and the river shows you plenty.",
	},
	{
		"id": "blacksmith",
		"name": "Travelling Blacksmith",
		"role": "smith",
		"text": "Riftstone dust ruins a good edge faster than rust. Bring your gear by the lodge if it starts to sing.",
	},
	{
		"id": "tavern_keeper",
		"name": "Lodge Keeper",
		"role": "innkeeper",
		"text": "You look road-worn. The lodge fire is hot, the kettle is on, and nobody asks questions before supper.",
	},
	{
		"id": "scholar",
		"name": "Rift Scholar",
		"role": "scholar",
		"text": "The route is not changing randomly. I think the gate is rebuilding it from memories of older paths.",
	},
	{
		"id": "village_youth",
		"name": "Village Youth",
		"role": "villager",
		"text": "I saw a Glimmerling jump the stream yesterday! Nobody believes me, but I know what I saw.",
	},
	{
		"id": "flower_gatherer",
		"name": "Flower Gatherer",
		"role": "gatherer",
		"text": "The blue flowers grow brightest beside old riftstone. I leave the brightest ones alone.",
	},
	{
		"id": "elder",
		"name": "Willowmere Elder",
		"role": "elder",
		"text": "This road remembers more travellers than any of us do. Treat its old stones with respect.",
	},
	{
		"id": "druid",
		"name": "Rift Druid",
		"role": "druid",
		"text": "Listen before you enter the tall grass. The wilds always speak first; most delvers simply never listen.",
	},
	{
		"id": "wyrdling_archer",
		"name": "Wyrdling Archer",
		"role": "hunter",
		"text": "If the reeds move once, it is wind. Twice, prey. Three times? Walk the other way.",
	},
	{
		"id": "rift_miner",
		"name": "Rift Miner",
		"role": "miner",
		"text": "Echo Cave has a new crack in the eastern wall. Blue light behind it, too. I am not touching it alone.",
	},
	{
		"id": "rift_priestess",
		"name": "Rift Priestess",
		"role": "priest",
		"text": "The old binding stones are waking. Whatever they once held, the rift has begun remembering it.",
	},
	{
		"id": "noble_delver",
		"name": "Noble Delver",
		"role": "delver",
		"text": "A polished coat does not make the wilds polite. Believe me, I have paid dearly for that lesson.",
	},
	{
		"id": "hooded_rogue",
		"name": "Hooded Rogue",
		"role": "rogue",
		"text": "Keep your eyes on the path and your hand on your coin. Not every danger out here has claws.",
	},
	{
		"id": "woodsman",
		"name": "Willowmere Woodsman",
		"role": "woodsman",
		"text": "These pines grow back wrong after a gate opens — thicker, closer, like the forest is closing ranks.",
	},
	{
		"id": "farmer",
		"name": "Route Farmer",
		"role": "farmer",
		"text": "Tall grass is good soil and terrible company. I lost three baskets to curious Wyrdlings this morning.",
	},
	{
		"id": "falconer",
		"name": "Rift Falconer",
		"role": "falconer",
		"text": "My hawk sees the route before I do. When she refuses to fly north, I have learned not to argue.",
	},
]


static func definition(index: int) -> Dictionary:
	if index < 0 or index >= TYPES.size():
		return TYPES[0]
	return TYPES[index]


static func direction_column(facing: String) -> int:
	var index := DIRECTIONS.find(facing)
	return index if index >= 0 else 0
