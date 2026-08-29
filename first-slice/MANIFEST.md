# Wyrdling first-slice — player + five creatures

Original IP pixel art. Unstable rifts under wet granite. PNG RGBA, real alpha (magenta knocked out).
Godot import: Filter = Nearest, mipmaps off.

Canonical paths for this batch live under `art/`. Do not treat root-level duplicates (if present) as this run.

## Design notes

- **Delver** — Hooded humanoid, wet slate coat (`#2A2F38`/`#1A1E24`), brass lantern (`#E8C872`) in the right hand, feet on the bottom row, face a cowl-void. Silhouette: tall A-line cloak + lantern bump, not a knight. Do not plate-mail, gym-trainer, chibi, or two-dot eyes.
- **Glimmerling** (Wisp) — Small living spark: lantern-belly, six harvestman legs, wick not a face. Palette `#F4E4A6` pale gold / `#A8D4E8` cold glow. Silhouette: bright core on thin insect stilts. Do not moth-wings, cute firefly, or electric-mouse.
- **Cobbleback** (Iron) — Squat beetle-golem, cobble carapace, rust joints, visor slit with one lantern glint at the front. Palette `#6B7280` slate / `#8B5A3C` rust. Silhouette: wide low dome, not the player. Do not stand it upright or give a mascot face.
- **Briarseed** (Bloom) — Walking thorn-seed: brown husk, green spikes, root-feet, burst-split not a face. Palette `#3F6B3A` thorn / `#8B6914` seed-brown. Silhouette: one burr. Do not flower-child, petals, or a smile.
- **Marrowl** (Dusk) — Owl of bone-fog: unmatched hollow sockets, jagged tufts, triangular wings, fog drips instead of legs. Palette `#2D1B4E` violet-black / `#6B3FA0` bruise / bone. Silhouette: skull + wings, floating. Do not pupils, cute-owl, or a solid bird body.
- **Brinekit** (Tide) — Slick eel-fox, always wet: long muzzle, slit eye, two forepaws, eel tail. Palette `#0F4C5C` deep teal / `#2A9D8F` wet green. Silhouette: horizontal, low. Do not stand it like a fox-pet or fluff a tail.

## Files (this run)

| Path | Size | Notes |
|---|---|---|
| `style_frame.png` | 256×256 | Lantern-lit wet granite rift, brass sconce, purple tear, type-palette living-things. Opaque reference plate. |
| `art/player/delver_idle_down.png` | 64×64 | Front, lantern on viewer's left (character's right). ~54px tall, feet y=61. |
| `art/player/delver_idle_up.png` | 64×64 | Back, bedroll, lantern on viewer's right. |
| `art/player/delver_idle_left.png` | 64×64 | Profile, lantern leading left. |
| `art/player/delver_idle_right.png` | 64×64 | Profile, lantern leading right. |
| `art/creatures/glimmerling.png` | 64×64 | Wisp. Small. |
| `art/creatures/cobbleback.png` | 64×64 | Iron. Wide/low. |
| `art/creatures/briarseed.png` | 64×64 | Bloom. Burr + roots. |
| `art/creatures/marrowl.png` | 64×64 | Dusk. Bone-fog owl. |
| `art/creatures/brinekit.png` | 64×64 | Tide. Horizontal eel-fox. |

Not in this run: tiles, UI, Wickmoth, Nailbit, Veilcrawler.
