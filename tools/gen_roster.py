#!/usr/bin/env python3
"""Generate the locked 170-creature Wyrdling roster, extra moves, ROSTER.md, and placeholders."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
ART = ROOT / "art" / "creatures"

SKIP_SPRITES = {
    "glimmerling", "wickmoth", "cobbleback", "nailbit",
    "briarseed", "marrowl", "veilcrawler", "brinekit",
    "solcairn", "eidolith", "kethraan", "gelvra",
    "ithriel", "sigildra", "veskara", "mycarion",
    "vinculith", "pyrehollow", "threnodyr",
}

EXISTING_IDS = [
    "glimmerling", "wickmoth", "cobbleback", "nailbit",
    "briarseed", "marrowl", "veilcrawler", "brinekit",
]

EXISTING_PATCH = {
    "glimmerling": {"types": ["Light"], "rarity": "common", "role": "starter"},
    "wickmoth": {"types": ["Light"], "rarity": "common", "role": "wild"},
    "cobbleback": {"types": ["Metal"], "rarity": "common", "role": "starter"},
    "nailbit": {"types": ["Metal"], "rarity": "common", "role": "wild"},
    "briarseed": {"types": ["Nature"], "rarity": "common", "role": "starter"},
    "marrowl": {"types": ["Spirit"], "rarity": "common", "role": "wild"},
    "veilcrawler": {"types": ["Void"], "rarity": "common", "role": "wild"},
    "brinekit": {"types": ["Tide"], "rarity": "common", "role": "wild"},
}

STAT_RANGES = {
    "common": {"hp": (30, 48), "atk": (10, 16), "def": (6, 16), "spd": (6, 17)},
    "uncommon": {"hp": (40, 56), "atk": (12, 18), "def": (8, 16), "spd": (8, 18)},
    "rare": {"hp": (50, 64), "atk": (15, 20), "def": (10, 18), "spd": (10, 18)},
    "legendary": {"hp": (72, 88), "atk": (18, 24), "def": (16, 22), "spd": (14, 20)},
    "mythical": {"hp": (66, 80), "atk": (17, 22), "def": (14, 20), "spd": (13, 19)},
}

TYPE_MOVES = {
    "Light": ["gleam", "lantern_veil", "spark_pinch", "halo_cut"],
    "Void": ["shroud_creep", "peel_light", "null_pinch"],
    "Flame": ["cinder_peck", "kiln_breath"],
    "Tide": ["salt_spray", "pouch_slap", "undertow", "brine_lash"],
    "Nature": ["thorn_shot", "root_tether", "leaf_gnash", "pollen_sting"],
    "Terra": ["stone_nudge", "fault_line"],
    "Gale": ["gust_cut", "shear"],
    "Storm": ["spark_arc", "thunder_tap"],
    "Frost": ["rime_bite", "hail_peck"],
    "Blood": ["ichor_sip", "vein_snap"],
    "Spirit": ["bone_hoot", "shadow_stoop", "quiet_talon", "hush_cut"],
    "Mind": ["mind_sting", "trance_pinch"],
    "Metal": ["rivet", "shell_grind", "file_bite", "cog_smash"],
    "Primal": ["fang_rush", "wild_slam"],
    "Blight": ["spore_cough", "rot_touch"],
    "Arcane": ["glyph_peck", "rune_lash"],
}

NEW_MOVES = {
    "cinder_peck": {"id": "cinder_peck", "name": "Cinder Peck", "type": "Flame", "power": 12, "desc": "A beak of live coal nips a spark from the hide."},
    "kiln_breath": {"id": "kiln_breath", "name": "Kiln Breath", "type": "Flame", "power": 14, "desc": "Oven-heat rolled into a short, scalding gust."},
    "stone_nudge": {"id": "stone_nudge", "name": "Stone Nudge", "type": "Terra", "power": 11, "desc": "A packed-earth shoulder that pretends to be polite."},
    "fault_line": {"id": "fault_line", "name": "Fault Line", "type": "Terra", "power": 14, "desc": "The floor remembers a crack and opens it again."},
    "gust_cut": {"id": "gust_cut", "name": "Gust Cut", "type": "Gale", "power": 12, "desc": "A thin blade of wind drawn across the throat of the air."},
    "shear": {"id": "shear", "name": "Shear", "type": "Gale", "power": 14, "desc": "Two winds scissor past each other through the foe."},
    "spark_arc": {"id": "spark_arc", "name": "Spark Arc", "type": "Storm", "power": 13, "desc": "A needle of lightning that hops the shortest gap."},
    "thunder_tap": {"id": "thunder_tap", "name": "Thunder Tap", "type": "Storm", "power": 15, "desc": "A knuckle of thunder laid against the ribs."},
    "rime_bite": {"id": "rime_bite", "name": "Rime Bite", "type": "Frost", "power": 12, "desc": "Teeth of hoar-ice that stick and then snap."},
    "hail_peck": {"id": "hail_peck", "name": "Hail Peck", "type": "Frost", "power": 14, "desc": "A hard white bead driven like a nail of winter."},
    "ichor_sip": {"id": "ichor_sip", "name": "Ichor Sip", "type": "Blood", "power": 12, "desc": "A polite little drink taken from a fresh nick."},
    "vein_snap": {"id": "vein_snap", "name": "Vein Snap", "type": "Blood", "power": 14, "desc": "A cord of living red pulled taut and loosed."},
    "mind_sting": {"id": "mind_sting", "name": "Mind Sting", "type": "Mind", "power": 12, "desc": "A thought that arrives already wearing a barb."},
    "trance_pinch": {"id": "trance_pinch", "name": "Trance Pinch", "type": "Mind", "power": 13, "desc": "A fold in attention, pinched until it bruises."},
    "fang_rush": {"id": "fang_rush", "name": "Fang Rush", "type": "Primal", "power": 14, "desc": "Old teeth remembering how to close."},
    "wild_slam": {"id": "wild_slam", "name": "Wild Slam", "type": "Primal", "power": 15, "desc": "A body thrown like a first animal inventing force."},
    "spore_cough": {"id": "spore_cough", "name": "Spore Cough", "type": "Blight", "power": 11, "desc": "A lungful of pale dust that takes root in the wound."},
    "rot_touch": {"id": "rot_touch", "name": "Rot Touch", "type": "Blight", "power": 13, "desc": "Fingers that age a patch of hide in a heartbeat."},
    "glyph_peck": {"id": "glyph_peck", "name": "Glyph Peck", "type": "Arcane", "power": 12, "desc": "A mark pecked into the air that bites when read."},
    "rune_lash": {"id": "rune_lash", "name": "Rune Lash", "type": "Arcane", "power": 14, "desc": "A written line that uncoils and strikes."},
    "halo_cut": {"id": "halo_cut", "name": "Halo Cut", "type": "Light", "power": 13, "desc": "A ring of lantern-edge drawn tight and released."},
    "null_pinch": {"id": "null_pinch", "name": "Null Pinch", "type": "Void", "power": 13, "desc": "A fold of anti-light that nips a hole in the world."},
    "pollen_sting": {"id": "pollen_sting", "name": "Pollen Sting", "type": "Nature", "power": 10, "desc": "A gold grain that buries itself and itches like a barb."},
    "cog_smash": {"id": "cog_smash", "name": "Cog Smash", "type": "Metal", "power": 13, "desc": "A toothed wheel driven into whatever is nearest."},
    "hush_cut": {"id": "hush_cut", "name": "Hush Cut", "type": "Spirit", "power": 12, "desc": "A slice placed in the pause after a name is spoken."},
    "brine_lash": {"id": "brine_lash", "name": "Brine Lash", "type": "Tide", "power": 13, "desc": "A whip of black water that leaves a salt welt."},
    "sol_mane": {"id": "sol_mane", "name": "Sol Mane", "type": "Light", "power": 18, "desc": "The lantern-mane unfurls and the room forgets night."},
    "void_howl": {"id": "void_howl", "name": "Void Howl", "type": "Void", "power": 18, "desc": "A cry from too many angles at once."},
    "storm_crown": {"id": "storm_crown", "name": "Storm Crown", "type": "Storm", "power": 19, "desc": "A circlet of thunder settled on the foe's skull."},
    "rime_maw": {"id": "rime_maw", "name": "Rime Maw", "type": "Frost", "power": 18, "desc": "An abyssal jaw of ice that closes without sound."},
    "rift_aegis": {"id": "rift_aegis", "name": "Rift Aegis", "type": "Light", "power": 16, "desc": "A wing of lantern-glass that cuts as it shields."},
    "sigil_burst": {"id": "sigil_burst", "name": "Sigil Burst", "type": "Arcane", "power": 18, "desc": "Every rune on the chassis fires at once."},
    "abyssal_bite": {"id": "abyssal_bite", "name": "Abyssal Bite", "type": "Tide", "power": 19, "desc": "A deep-sea mouth that was never meant for air."},
    "plague_bloom": {"id": "plague_bloom", "name": "Plague Bloom", "type": "Blight", "power": 18, "desc": "A fruiting body opens and the air goes sweet-wrong."},
    "bind_knot": {"id": "bind_knot", "name": "Bind Knot", "type": "Arcane", "power": 17, "desc": "The first knot that holds a Wyrdling, pulled tight."},
    "rift_heart": {"id": "rift_heart", "name": "Rift Heart", "type": "Flame", "power": 18, "desc": "A burning hole offered like a gift, then slammed shut."},
    "threnody": {"id": "threnody", "name": "Threnody", "type": "Blood", "power": 18, "desc": "A hymn with teeth, sung from a wound that will not close."},
}

# (id, name, types, rarity, role, description, extra_moves)
# extra_moves prepended (signatures). Other moves filled from type pools.
NEW = [
    # Legendaries
    ("solcairn", "Solcairn", ["Light", "Primal"], "legendary", "legendary",
     "A celestial lion whose mane is a ring of hanging lanterns.", ["sol_mane"]),
    ("eidolith", "Eidolith", ["Void", "Mind"], "legendary", "legendary",
     "An eldritch nightmare folded from too many angles to count.", ["void_howl"]),
    ("kethraan", "Kethraan", ["Storm", "Primal"], "legendary", "legendary",
     "A thunder dragon that wears the rift's weather like a hide.", ["storm_crown"]),
    ("gelvra", "Gelvra", ["Void", "Frost"], "legendary", "legendary",
     "An abyssal ice wolf whose breath is a hole in the warm world.", ["rime_maw"]),
    ("ithriel", "Ithriel", ["Light", "Spirit"], "legendary", "legendary",
     "A guardian angel of the rift, lantern-winged and unblinking.", ["rift_aegis"]),
    ("sigildra", "Sigildra", ["Metal", "Arcane"], "legendary", "legendary",
     "A rune-powered construct whose joints spark with written law.", ["sigil_burst"]),
    ("veskara", "Veskara", ["Tide", "Blood"], "legendary", "legendary",
     "A monstrous deep-sea predator that hunts by the pulse of ships.", ["abyssal_bite"]),
    ("mycarion", "Mycarion", ["Blight", "Nature"], "legendary", "legendary",
     "A fungal plague-beast whose cap is a forest of other mouths.", ["plague_bloom"]),
    # Mythicals
    ("vinculith", "Vinculith", ["Arcane", "Spirit"], "mythical", "mythical",
     "The bind-origin: the first knot that holds a Wyrdling in the world.", ["bind_knot"]),
    ("pyrehollow", "Pyrehollow", ["Flame", "Void"], "mythical", "mythical",
     "A rift-heart: a burning hole that walks as if it had a body.", ["rift_heart"]),
    ("threnodyr", "Threnodyr", ["Blood", "Primal"], "mythical", "mythical",
     "A sacrifice-beast, a hymn with teeth, still singing from the altar.", ["threnody"]),
    # Specified rares
    ("vesperghast", "Vesperghast", ["Blood", "Gale"], "rare", "wild",
     "A vampire bat that drinks the dusk before it drinks the blood.", []),
    ("boughwight", "Boughwight", ["Nature", "Spirit"], "rare", "wild",
     "A haunted treant whose hollows still remember the hanged.", []),
    # Light fill
    ("lampkin", "Lampkin", ["Light"], "common", "wild",
     "A pocket lantern on jointed legs, always looking for a shelf to claim.", []),
    ("aurelune", "Aurelune", ["Light", "Frost"], "uncommon", "wild",
     "A moth whose glow ices the air a hand's breadth from the wing.", []),
    ("haloshard", "Haloshard", ["Light"], "uncommon", "wild",
     "An orbiting stained-glass splinter that cuts rainbows from lanterns.", []),
    ("sunmote", "Sunmote", ["Light"], "common", "wild",
     "A drifting mote that scalds when it lands, then pretends to be dust.", []),
    ("dawncowl", "Dawncowl", ["Light", "Spirit"], "uncommon", "wild",
     "A hooded pilgrim of first light, face never quite inside the cowl.", []),
    ("lucentail", "Lucentail", ["Light", "Gale"], "common", "wild",
     "A fox-shape whose tail is a lantern wick, smoking when it runs.", []),
    ("prismite", "Prismite", ["Light"], "rare", "wild",
     "A crystal that splits one lantern into seven and keeps the brightest.", []),
    # Void fill
    ("umbrite", "Umbrite", ["Void"], "common", "wild",
     "A pebble of condensed dark that is heavier than the room around it.", []),
    ("netherick", "Netherick", ["Void"], "common", "wild",
     "A stick-thin crawler that comes up through under-floor gaps.", []),
    ("gapehusk", "Gapehusk", ["Void"], "uncommon", "wild",
     "An empty-skin that walks, holding its own absence like a lantern.", []),
    ("riftleech", "Riftleech", ["Void", "Blood"], "uncommon", "wild",
     "A sucker that drinks from tears in the world, not from veins.", []),
    ("nullspire", "Nullspire", ["Void", "Arcane"], "rare", "wild",
     "A needle of anti-light that writes holes instead of runes.", []),
    ("duskthread", "Duskthread", ["Void"], "common", "wild",
     "A filament that stitches shadows together when the lanterns fail.", []),
    ("eclipseel", "Eclipseel", ["Void", "Tide"], "uncommon", "wild",
     "An eel that swallows lanterns and swims on the dark they leave.", []),
    ("gnomon", "Gnomon", ["Void", "Terra"], "uncommon", "wild",
     "A sundial-creature that casts a shadow pointing at the wrong hour.", []),
    # Flame fill
    ("cinderling", "Cinderling", ["Flame"], "common", "wild",
     "A thumb-sized ember with legs, always looking for a dry nest.", []),
    ("kilnbeetle", "Kilnbeetle", ["Flame", "Metal"], "common", "wild",
     "A beetle fired in some forgotten kiln, still ticking with heat.", []),
    ("ashgnarl", "Ashgnarl", ["Flame"], "common", "wild",
     "A charred knot that still smolders, muttering in old wood-speech.", []),
    ("pyrewyrm", "Pyrewyrm", ["Flame"], "uncommon", "wild",
     "A ribbon of living fire that prefers chimneys to sky.", []),
    ("coalheart", "Coalheart", ["Flame", "Terra"], "uncommon", "wild",
     "A lump of earth with a furnace where a heart should be.", []),
    ("sparkmite", "Sparkmite", ["Flame"], "common", "wild",
     "A mite that lives in tinder and coughs sparks when squeezed.", []),
    ("hearthkin", "Hearthkin", ["Flame"], "common", "wild",
     "A squat familiar of the grate, loyal to whoever feeds it kindling.", []),
    ("sootdrake", "Sootdrake", ["Flame"], "rare", "wild",
     "A small dragon of chimney-black, leaving fingerprints of ash.", []),
    ("flarefin", "Flarefin", ["Flame", "Tide"], "uncommon", "wild",
     "A fish that burns underwater, oil-bright along the gill.", []),
    ("embergale", "Embergale", ["Flame", "Gale"], "uncommon", "wild",
     "A gust that learned to carry coals and will not put them down.", []),
    # Tide fill
    ("kelpling", "Kelpling", ["Tide"], "common", "wild",
     "A child of kelp that walks as if the floor were still a current.", []),
    ("saltback", "Saltback", ["Tide"], "common", "wild",
     "A hunched crustacean whose carapace is a crust of old brine.", []),
    ("tidewhelp", "Tidewhelp", ["Tide"], "common", "wild",
     "A whelp that howls when the hidden sea turns, even inland.", []),
    ("barnaclaw", "Barnaclaw", ["Tide", "Metal"], "uncommon", "wild",
     "A claw grown around a rusted hook, barnacles for knuckles.", []),
    ("mistgill", "Mistgill", ["Tide", "Gale"], "uncommon", "wild",
     "A gill-thing that breathes fog and leaves the air tasting of docks.", []),
    ("blackbrine", "Blackbrine", ["Tide"], "uncommon", "wild",
     "A slick that stands up, dark as the water under rotting piers.", []),
    ("foamling", "Foamling", ["Tide"], "common", "wild",
     "A handful of sea-foam that refuses to collapse on stone.", []),
    ("riptail", "Riptail", ["Tide", "Primal"], "rare", "wild",
     "A riptide given a spine and a tail that pulls toward no shore.", []),
    ("coralith", "Coralith", ["Tide", "Terra"], "uncommon", "wild",
     "A walking reef-knuckle, polyps blinking in the cracks.", []),
    # Nature fill
    ("mossgrub", "Mossgrub", ["Nature"], "common", "wild",
     "A grub in a coat of damp moss, chewing stone as if it were leaf.", []),
    ("thornkit", "Thornkit", ["Nature"], "common", "wild",
     "A kit of briar and ear-tufts, every step a small snag.", []),
    ("fernwisp", "Fernwisp", ["Nature", "Spirit"], "uncommon", "wild",
     "A fern that uncurls into a face when no one is supposed to look.", []),
    ("oakmite", "Oakmite", ["Nature"], "common", "wild",
     "A mite that lives in heartwood and ticks like a slow clock.", []),
    ("vinecoil", "Vinecoil", ["Nature"], "uncommon", "wild",
     "A coil of vine that remembers wrists and does not forget them.", []),
    ("pollenid", "Pollenid", ["Nature", "Gale"], "common", "wild",
     "A puff of gold that steers itself, looking for a lung to settle in.", []),
    ("rootwight", "Rootwight", ["Nature"], "uncommon", "wild",
     "A tangle of roots that stands, soil still clinging like a shroud.", []),
    ("brambleox", "Brambleox", ["Nature", "Terra"], "rare", "wild",
     "An ox-shape of thorn and packed dirt, horns like hedge-hooks.", []),
    ("dewspore", "Dewspore", ["Nature", "Tide"], "uncommon", "wild",
     "A spore that travels in dew-drops and hatches when the drop falls.", []),
    # Terra fill
    ("pebblet", "Pebblet", ["Terra"], "common", "wild",
     "A pebble that decided to have legs and a very small grudge.", []),
    ("clayurn", "Clayurn", ["Terra"], "common", "wild",
     "A walking urn of unfired clay, always thirsty for a maker's mark.", []),
    ("shaleback", "Shaleback", ["Terra"], "common", "wild",
     "A low beast plated in shale that sheds when it turns too fast.", []),
    ("gritling", "Gritling", ["Terra"], "common", "wild",
     "A handful of grit given appetite, sand in every joint.", []),
    ("cairnworm", "Cairnworm", ["Terra"], "uncommon", "wild",
     "A worm that stacks itself into cairns and waits for offerings.", []),
    ("loamhound", "Loamhound", ["Terra"], "uncommon", "wild",
     "A hound of dark loam, panting spores instead of steam.", []),
    ("quartzite", "Quartzite", ["Terra", "Metal"], "uncommon", "wild",
     "A crystal-shouldered burrower that rings when struck.", []),
    ("dunehopper", "Dunehopper", ["Terra", "Gale"], "common", "wild",
     "A hopper that carries a dune on its back and will not share the shade.", []),
    ("faultwyrm", "Faultwyrm", ["Terra"], "rare", "wild",
     "A wyrm that sleeps in faults and wakes when the floor argues.", []),
    ("mudlark", "Mudlark", ["Terra", "Tide"], "uncommon", "wild",
     "A lark of river-mud, singing with a mouth full of silt.", []),
    ("stalagling", "Stalagling", ["Terra"], "common", "wild",
     "A baby stalagmite that pulled free and now looks for a ceiling.", []),
    # Gale fill
    ("gustling", "Gustling", ["Gale"], "common", "wild",
     "A fist of wind that learned to hold together for a few rooms.", []),
    ("zephyrkit", "Zephyrkit", ["Gale"], "common", "wild",
     "A kit of drafts and whiskers, always on the wrong side of a door.", []),
    ("kestrelite", "Kestrelite", ["Gale"], "uncommon", "wild",
     "A kestrel of pale wind-stone, hovering where there is no sky.", []),
    ("windthorn", "Windthorn", ["Gale", "Nature"], "uncommon", "wild",
     "A thorn that travels on gusts and plants itself in whoever blinks.", []),
    ("draftmoth", "Draftmoth", ["Gale"], "common", "wild",
     "A moth that is mostly the draft under a door, wings optional.", []),
    ("skyneedle", "Skyneedle", ["Gale"], "uncommon", "wild",
     "A needle of high air, too thin to see until it has already passed.", []),
    ("cirruswisp", "Cirruswisp", ["Gale", "Spirit"], "uncommon", "wild",
     "A wisp of cirrus that drifted down and forgot how to be weather.", []),
    ("squallpup", "Squallpup", ["Gale", "Storm"], "uncommon", "wild",
     "A pup that is a pocket squall, barking thunder in miniature.", []),
    ("aetherfin", "Aetherfin", ["Gale"], "rare", "wild",
     "A finned thing that swims the air as if it were a colder sea.", []),
    ("leafskiff", "Leafskiff", ["Gale", "Nature"], "common", "wild",
     "A leaf that learned to be a boat, then a bird, then a nuisance.", []),
    ("shearwing", "Shearwing", ["Gale"], "uncommon", "wild",
     "A wing-pair that shears the air and leaves a whistling cut.", []),
    # Storm fill
    ("sparkcloud", "Sparkcloud", ["Storm"], "common", "wild",
     "A palm-cloud that crackles, smelling of rain that has not arrived.", []),
    ("voltmite", "Voltmite", ["Storm"], "common", "wild",
     "A mite that nests in static and bites with a tiny blue tooth.", []),
    ("thunderling", "Thunderling", ["Storm"], "common", "wild",
     "A child of thunder, still practicing how loud a small thing can be.", []),
    ("hailvolt", "Hailvolt", ["Storm", "Frost"], "uncommon", "wild",
     "A hailstone with a spark in it, looking for a skull to land on.", []),
    ("stormbeetle", "Stormbeetle", ["Storm", "Metal"], "uncommon", "wild",
     "A beetle that stores weather under its carapace and leaks it.", []),
    ("staticurl", "Staticurl", ["Storm"], "uncommon", "wild",
     "A curl of standing hair and lightning, never quite a body.", []),
    ("nimbusnake", "Nimbusnake", ["Storm"], "rare", "wild",
     "A snake of stormcloud, shedding rain like an old skin.", []),
    ("rainwyrm", "Rainwyrm", ["Storm", "Tide"], "uncommon", "wild",
     "A wyrm that is a rainstorm given a spine and a bad temper.", []),
    ("lodestoneel", "Lodestoneel", ["Storm", "Metal"], "uncommon", "wild",
     "An eel of lodestone, pulling nails and compasses off true.", []),
    # Frost fill
    ("rimekit", "Rimekit", ["Frost"], "common", "wild",
     "A kit furred in rime, leaving melt-prints that freeze again.", []),
    ("hoarling", "Hoarling", ["Frost"], "common", "wild",
     "A hoar-frost that stood up and decided it was a person, almost.", []),
    ("icemite", "Icemite", ["Frost"], "common", "wild",
     "A mite of clear ice, clicking like a glass bead in a pocket.", []),
    ("glaceling", "Glaceling", ["Frost"], "uncommon", "wild",
     "A shard of glacier that still believes it is a mountain's foot.", []),
    ("frostback", "Frostback", ["Frost"], "common", "wild",
     "A low beast plated in frost, breath hanging like a second hide.", []),
    ("hailhound", "Hailhound", ["Frost"], "uncommon", "wild",
     "A hound that coughs hail and sleeps in the coldest corner.", []),
    ("snowmoth", "Snowmoth", ["Frost", "Gale"], "uncommon", "wild",
     "A moth of dry snow, wings that do not melt until they land.", []),
    ("rimeplate", "Rimeplate", ["Frost", "Terra"], "uncommon", "wild",
     "A plate of frozen ground that walks, lichen still underneath.", []),
    ("crystalynx", "Crystalynx", ["Frost"], "rare", "wild",
     "A lynx of living crystal, tufted ears ringing when it hunts.", []),
    ("freezehusk", "Freezehusk", ["Frost", "Void"], "uncommon", "wild",
     "A husk flash-frozen around an absence, still reaching.", []),
    ("sleetling", "Sleetling", ["Frost"], "common", "wild",
     "A sleet that learned to huddle, wet and mean in the lantern-light.", []),
    # Blood fill
    ("ichorling", "Ichorling", ["Blood"], "common", "wild",
     "A drop of ichor that grew legs rather than dry.", []),
    ("leechmite", "Leechmite", ["Blood"], "common", "wild",
     "A mite with one long siphon, polite until it is not.", []),
    ("clotpup", "Clotpup", ["Blood"], "common", "wild",
     "A pup of clotted red, loyal to whoever it has already tasted.", []),
    ("veinwyrm", "Veinwyrm", ["Blood"], "uncommon", "wild",
     "A wyrm that thinks it is a vein and tries to join a larger map.", []),
    ("crimsonoth", "Crimsonoth", ["Blood"], "uncommon", "wild",
     "A moth whose wings are thin scabs, beating a pulse instead of air.", []),
    ("heartgnat", "Heartgnat", ["Blood"], "common", "wild",
     "A gnat that aims for the beat and is very patient.", []),
    ("gorecap", "Gorecap", ["Blood", "Blight"], "uncommon", "wild",
     "A cap of wet fungus that weeps red when stepped on.", []),
    ("sanguineel", "Sanguineel", ["Blood", "Tide"], "uncommon", "wild",
     "An eel of living blood, thicker than water and twice as cold.", []),
    # Spirit fill
    ("wispkin", "Wispkin", ["Spirit"], "common", "wild",
     "A kin of wisps, no bigger than a held breath.", []),
    ("hauntling", "Hauntling", ["Spirit"], "common", "wild",
     "A haunt that has not decided whose house it is yet.", []),
    ("gravekit", "Gravekit", ["Spirit"], "common", "wild",
     "A kit that sleeps in the lip of graves and dreams of names.", []),
    ("echoform", "Echoform", ["Spirit"], "uncommon", "wild",
     "A shape that is only the echo of a shape, a breath late.", []),
    ("lanternsoul", "Lanternsoul", ["Spirit", "Light"], "uncommon", "wild",
     "The soul a lantern keeps after the flame has been pinched out.", []),
    ("bonewisp", "Bonewisp", ["Spirit"], "common", "wild",
     "A wisp nested in a knuckle-bone, rattling when it is pleased.", []),
    ("hushling", "Hushling", ["Spirit"], "common", "wild",
     "A small hush with eyes, offended by any word above a whisper.", []),
    ("specterfin", "Specterfin", ["Spirit", "Tide"], "uncommon", "wild",
     "A fin of drowned light, swimming the air over dry stone.", []),
    ("knellhound", "Knellhound", ["Spirit"], "rare", "wild",
     "A hound that arrives with the knell, never before, never late.", []),
    # Mind fill
    ("thoughtmite", "Thoughtmite", ["Mind"], "common", "wild",
     "A mite that nests in half-finished thoughts and finishes them wrong.", []),
    ("dreamgrub", "Dreamgrub", ["Mind"], "common", "wild",
     "A grub that feeds on leftover dreams and leaves the sour rind.", []),
    ("mindleech", "Mindleech", ["Mind"], "uncommon", "wild",
     "A leech for attention, plump on names you were about to say.", []),
    ("puzzlebeetle", "Puzzlebeetle", ["Mind", "Metal"], "uncommon", "wild",
     "A beetle whose carapace is a lock, clicking when you look away.", []),
    ("hypnomoth", "Hypnomoth", ["Mind"], "uncommon", "wild",
     "A moth that beats in time with blinks until the blinks stop.", []),
    ("ideaspore", "Ideaspore", ["Mind", "Blight"], "uncommon", "wild",
     "A spore of a bad idea, looking for a warm skull to fruit in.", []),
    ("cortexling", "Cortexling", ["Mind"], "common", "wild",
     "A fold of grey thought that crawled out and wants back in.", []),
    ("trancekit", "Trancekit", ["Mind"], "common", "wild",
     "A kit that stares until you forget which of you is dreaming.", []),
    ("oraclefly", "Oraclefly", ["Mind"], "rare", "wild",
     "A fly that lands on the true answer and will not be waved off.", []),
    ("synaptick", "Synaptick", ["Mind", "Arcane"], "uncommon", "wild",
     "A tick of sparking sigils, bridging two thoughts that should not meet.", []),
    ("memorymoth", "Memorymoth", ["Mind", "Spirit"], "uncommon", "wild",
     "A moth that lays its eggs in memories and hatches as someone else.", []),
    # Metal fill
    ("rustmite", "Rustmite", ["Metal"], "common", "wild",
     "A mite that farms rust and wears the flakes like a coat.", []),
    ("cogmite", "Cogmite", ["Metal"], "common", "wild",
     "A walking cog, always seeking a larger machine to vanish into.", []),
    ("scrapkit", "Scrapkit", ["Metal"], "common", "wild",
     "A kit of offcuts and wire-whiskers, chewing nails for comfort.", []),
    ("anvilbeetle", "Anvilbeetle", ["Metal"], "uncommon", "wild",
     "A beetle heavy as a hand-anvil, ringing when it sets a foot.", []),
    ("wirewyrm", "Wirewyrm", ["Metal"], "uncommon", "wild",
     "A wyrm of live wire, shedding copper like old skin.", []),
    ("tinmoth", "Tinmoth", ["Metal"], "common", "wild",
     "A moth of stamped tin, wings that ping when they beat.", []),
    ("alloyhound", "Alloyhound", ["Metal"], "rare", "wild",
     "A hound poured of mixed metals, each paw a different ore.", []),
    # Primal fill
    ("beastling", "Beastling", ["Primal"], "common", "wild",
     "The idea of a beast, small, unfinished, already hungry.", []),
    ("fangkit", "Fangkit", ["Primal"], "common", "wild",
     "A kit that is mostly fang, still learning what the rest is for.", []),
    ("hornmite", "Hornmite", ["Primal"], "common", "wild",
     "A mite with a horn too large for it, charging anyway.", []),
    ("ancientail", "Ancientail", ["Primal"], "uncommon", "wild",
     "A tail that remembers a larger animal and will not admit it is gone.", []),
    ("protohulk", "Protohulk", ["Primal"], "uncommon", "wild",
     "A first draft of a giant, all shoulder and unfinished face.", []),
    ("wildheart", "Wildheart", ["Primal"], "common", "wild",
     "A heart that ran out of a chest and kept running.", []),
    ("stonefang", "Stonefang", ["Primal", "Terra"], "uncommon", "wild",
     "A fang of living stone, still trying to belong to a jaw.", []),
    ("thunderpaw", "Thunderpaw", ["Primal", "Storm"], "uncommon", "wild",
     "A paw that lands like weather, looking for the rest of the beast.", []),
    ("elderwyrm", "Elderwyrm", ["Primal"], "rare", "wild",
     "A wyrm older than the rift's first lantern, coiled in first hunger.", []),
    ("hidekin", "Hidekin", ["Primal"], "common", "wild",
     "A walking hide that has not yet agreed to contain anything.", []),
    ("clawback", "Clawback", ["Primal"], "common", "wild",
     "A back that is all claw, scuttling toward whatever moved last.", []),
    # Blight fill
    ("rotling", "Rotling", ["Blight"], "common", "wild",
     "A thumb of rot with a smile of fruiting bodies.", []),
    ("moldmite", "Moldmite", ["Blight"], "common", "wild",
     "A mite the color of old bread, leaving prints that bloom.", []),
    ("sporekit", "Sporekit", ["Blight"], "common", "wild",
     "A kit that sneezes spores and looks proud of the cloud.", []),
    ("blightgrub", "Blightgrub", ["Blight"], "common", "wild",
     "A grub that prefers living wood and will not be reasoned with.", []),
    ("cankerwyrm", "Cankerwyrm", ["Blight"], "uncommon", "wild",
     "A wyrm of canker, burrowing along the grain of whatever it meets.", []),
    ("rustcap", "Rustcap", ["Blight", "Metal"], "uncommon", "wild",
     "A mushroom that fruits on iron and tastes of old blood and rain.", []),
    ("plaguefly", "Plaguefly", ["Blight"], "uncommon", "wild",
     "A fly that carries a weather of sickness under its wings.", []),
    ("festerling", "Festerling", ["Blight"], "common", "wild",
     "A fester that stood up, warm and wrong, looking for a host.", []),
    ("toxinoth", "Toxinoth", ["Blight"], "rare", "wild",
     "A moth whose dust is a quiet poison, pretty until you breathe.", []),
    # Arcane fill
    ("glyphling", "Glyphling", ["Arcane"], "common", "wild",
     "A living glyph, still wet, looking for a wall to finish itself.", []),
    ("runemite", "Runemite", ["Arcane"], "common", "wild",
     "A mite that engraves tiny runes wherever it rests.", []),
    ("hexkit", "Hexkit", ["Arcane"], "common", "wild",
     "A kit with hexes for whiskers, sneezing small unluck.", []),
    ("sigilwisp", "Sigilwisp", ["Arcane"], "uncommon", "wild",
     "A wisp that is a sigil, drifting until someone reads it aloud.", []),
    ("wardbeetle", "Wardbeetle", ["Arcane", "Metal"], "uncommon", "wild",
     "A beetle etched with wards, ticking when a curse comes near.", []),
    ("spellmoth", "Spellmoth", ["Arcane"], "common", "wild",
     "A moth that sheds incomplete spells, dangerous if finished.", []),
    ("quillith", "Quillith", ["Arcane"], "uncommon", "wild",
     "A living quill that writes on air and will not be sheathed.", []),
    ("cipherling", "Cipherling", ["Arcane"], "common", "wild",
     "A cipher that crawled off a page and refuses to be solved.", []),
    ("leyshard", "Leyshard", ["Arcane"], "rare", "wild",
     "A shard of ley-line, humming, cutting whoever holds it too long.", []),
]


def _h(s: str) -> int:
    return int(hashlib.md5(s.encode()).hexdigest()[:8], 16)


def stat_of(cid: str, key: str, lo: int, hi: int) -> int:
    return lo + (_h(f"{cid}:{key}") % (hi - lo + 1))


def pick_moves(cid: str, types: list[str], rarity: str, extra: list[str]) -> list[str]:
    moves: list[str] = []
    for m in extra:
        if m not in moves:
            moves.append(m)
    primary, *rest = types
    pool_p = TYPE_MOVES[primary]
    # always at least one primary-type move
    if not any(m in pool_p or NEW_MOVES.get(m, {}).get("type") == primary for m in moves):
        moves.append(pool_p[_h(cid + ":p0") % len(pool_p)])
    if rest:
        sec = rest[0]
        pool_s = TYPE_MOVES[sec]
        if not any(NEW_MOVES.get(m, {}).get("type") == sec or m in pool_s for m in moves):
            cand = pool_s[_h(cid + ":s0") % len(pool_s)]
            if cand not in moves:
                moves.append(cand)
    want = 3 if rarity in ("uncommon", "rare", "legendary", "mythical") else 2
    idx = 0
    pools = [TYPE_MOVES[t] for t in types]
    while len(moves) < want:
        pool = pools[idx % len(pools)]
        cand = pool[_h(f"{cid}:m{idx}") % len(pool)]
        if cand not in moves:
            moves.append(cand)
        idx += 1
        if idx > 12:
            break
    return moves[:3]


def hex_to_rgba(h: str, a: int = 255) -> tuple[int, int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a


def draw_placeholder(cid: str, types: list[str], colors: dict[str, str]) -> Image.Image:
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    primary = hex_to_rgba(colors.get(types[0], "#888888"))
    secondary = hex_to_rgba(colors.get(types[1], colors.get(types[0], "#888888"))) if len(types) > 1 else tuple(
        min(255, c + 40) if i < 3 else 255 for i, c in enumerate(primary)
    )
    seed = _h(cid)
    shape = seed % 6
    d = ImageDraw.Draw(img)
    cx, cy = 32, 34
    body = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    if shape == 0:
        bd.ellipse([10, 12, 54, 56], fill=primary)
    elif shape == 1:
        bd.polygon([(32, 8), (56, 50), (8, 50)], fill=primary)
    elif shape == 2:
        bd.polygon([(32, 8), (56, 32), (32, 56), (8, 32)], fill=primary)
    elif shape == 3:
        r = 22
        pts = []
        for i in range(6):
            a = math.radians(-90 + i * 60)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        bd.polygon(pts, fill=primary)
    elif shape == 4:
        bd.rounded_rectangle([12, 14, 52, 54], radius=8, fill=primary)
    else:
        bd.ellipse([16, 10, 48, 50], fill=primary)
        bd.ellipse([8, 22, 28, 48], fill=primary)
        bd.ellipse([36, 22, 56, 48], fill=primary)
    glow = body.filter(ImageFilter.GaussianBlur(1.2))
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, body)
    d = ImageDraw.Draw(img)
    # eyes
    eye_y = 28 + (seed % 5)
    d.ellipse([22, eye_y, 28, eye_y + 6], fill=secondary)
    d.ellipse([36, eye_y, 42, eye_y + 6], fill=secondary)
    ink = (12, 10, 16, 255)
    d.ellipse([24, eye_y + 2, 26, eye_y + 5], fill=ink)
    d.ellipse([38, eye_y + 2, 40, eye_y + 5], fill=ink)
    # accent mark hashed from id
    accent_kind = (seed // 6) % 4
    if accent_kind == 0:
        d.polygon([(32, 8), (36, 18), (28, 18)], fill=secondary)
    elif accent_kind == 1:
        d.arc([14, 40, 50, 58], 20, 160, fill=secondary, width=2)
    elif accent_kind == 2:
        d.ellipse([28, 46, 36, 56], fill=secondary)
    else:
        d.line([(18, 20), (46, 20)], fill=secondary, width=2)
    return img


def build_creature(row: tuple) -> dict:
    cid, name, types, rarity, role, desc, extra = row
    rng = STAT_RANGES[rarity]
    rec = {
        "id": cid,
        "name": name,
        "type": types[0],
        "types": types,
        "rarity": rarity,
        "role": role,
        "starter": False,
        "hp": stat_of(cid, "hp", *rng["hp"]),
        "atk": stat_of(cid, "atk", *rng["atk"]),
        "def": stat_of(cid, "def", *rng["def"]),
        "spd": stat_of(cid, "spd", *rng["spd"]),
        "moves": pick_moves(cid, types, rarity, extra),
        "description": desc,
    }
    return rec


def write_roster_md(creatures: dict) -> None:
    order_rarity = ["legendary", "mythical", "rare", "uncommon", "common"]
    type_order = [
        "Light", "Void", "Flame", "Tide", "Nature", "Terra", "Gale", "Storm",
        "Frost", "Blood", "Spirit", "Mind", "Metal", "Primal", "Blight", "Arcane",
    ]
    lines = [
        "# Wyrdling roster",
        "",
        "170 original Wyrdlings. Sixteen types. Grouped by rarity, then primary type.",
        "",
    ]
    by_r: dict[str, list[dict]] = {r: [] for r in order_rarity}
    for rec in creatures.values():
        by_r.setdefault(rec["rarity"], []).append(rec)
    for rarity in order_rarity:
        recs = by_r.get(rarity, [])
        if not recs:
            continue
        lines.append(f"## {rarity.title()} ({len(recs)})")
        lines.append("")
        recs.sort(key=lambda r: (type_order.index(r["type"]) if r["type"] in type_order else 99, r["id"]))
        current = None
        for rec in recs:
            if rec["type"] != current:
                current = rec["type"]
                lines.append(f"### {current}")
                lines.append("")
            types = " / ".join(rec["types"])
            lines.append(
                f"- `{rec['id']}` **{rec['name']}** — {types} · {rec['rarity']} · {rec['role']} — {rec['description']}"
            )
        lines.append("")
    (DATA / "ROSTER.md").write_text("\n".join(lines), encoding="utf-8")
    print("wrote data/ROSTER.md")


def main() -> None:
    existing = json.loads((DATA / "creatures.json").read_text(encoding="utf-8"))
    types_data = json.loads((DATA / "types.json").read_text(encoding="utf-8"))
    colors = types_data["colors"]
    moves = json.loads((DATA / "moves.json").read_text(encoding="utf-8"))

    out: dict = {}
    # existing 8 first, patched
    for cid in EXISTING_IDS:
        rec = dict(existing[cid])
        rec.update(EXISTING_PATCH[cid])
        rec["id"] = cid
        rec["starter"] = bool(existing[cid].get("starter", False))
        rec["hp"] = existing[cid]["hp"]
        rec["atk"] = existing[cid]["atk"]
        rec["def"] = existing[cid]["def"]
        rec["spd"] = existing[cid]["spd"]
        rec["moves"] = list(existing[cid]["moves"])
        rec["description"] = existing[cid]["description"]
        rec["type"] = existing[cid]["type"]
        out[cid] = rec

    seen_ids = set(out)
    seen_names = {r["name"] for r in out.values()}
    for row in NEW:
        rec = build_creature(row)
        if rec["id"] in seen_ids:
            raise SystemExit(f"duplicate id {rec['id']}")
        if rec["name"] in seen_names:
            raise SystemExit(f"duplicate name {rec['name']}")
        seen_ids.add(rec["id"])
        seen_names.add(rec["name"])
        out[rec["id"]] = rec

    if len(out) != 170:
        raise SystemExit(f"expected 170 creatures, got {len(out)}")

    for mid, md in NEW_MOVES.items():
        if mid not in moves:
            moves[mid] = md

    # validate moves referenced exist
    missing = []
    for rec in out.values():
        for m in rec["moves"]:
            if m not in moves:
                missing.append((rec["id"], m))
    if missing:
        raise SystemExit(f"missing moves: {missing}")

    (DATA / "creatures.json").write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
    (DATA / "moves.json").write_text(json.dumps(moves, indent=2) + "\n", encoding="utf-8")
    print(f"wrote data/creatures.json ({len(out)})")
    print(f"wrote data/moves.json ({len(moves)})")

    write_roster_md(out)

    ART.mkdir(parents=True, exist_ok=True)
    written = 0
    skipped = 0
    for cid, rec in out.items():
        path = ART / f"{cid}.png"
        if cid in SKIP_SPRITES or path.exists():
            skipped += 1
            continue
        img = draw_placeholder(cid, rec["types"], colors)
        img.save(path, "PNG")
        written += 1
    print(f"placeholders written={written} skipped={skipped}")

    # histogram
    from collections import Counter
    prim = Counter(r["type"] for r in out.values())
    print("primary histogram:", dict(sorted(prim.items())))
    for t, n in prim.items():
        if not (8 <= n <= 12):
            raise SystemExit(f"primary count for {t} is {n}, want 8-12")
    print("legendary", sum(1 for r in out.values() if r["rarity"] == "legendary"))
    print("mythical", sum(1 for r in out.values() if r["rarity"] == "mythical"))
    print("duals", sum(1 for r in out.values() if len(r["types"]) == 2))
    print("starters", sum(1 for r in out.values() if r.get("starter")))


if __name__ == "__main__":
    main()
