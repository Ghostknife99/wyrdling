# Wyrdling overworld tiles (32×32)

Open overworld kit. Folklore-granite. Original IP. Route-1 *function* — wander, not dungeon rooms.

## Ground fills
- `grass.png` / `grass_alt.png`
- `path.png` — packed grit
- `water.png` — deep teal
- `tallgrass.png` — encounter patch
- `cliff.png` / `cliff_top.png` — outdoor ledge (not a room wall)

## Stitches (same wrap-noise as fills)
- grass↔path: `path_{n,e,s,w,ne,nw,se,sw}`
- grass↔water: `water_*` (foam on shore)
- grass↔tallgrass: `tallgrass_*`
- cliff↔grass: `cliff_{n,e,s,w}` + corners; `cliff_top_w` / `cliff_top_e`

Naming: `{terrain}_{dir}` means that terrain occupies the named side of the tile (so `path_s` is the northern edge of a path).

## Fence overlays (RGBA)
`fence_h`, `fence_v`, `fence_post`, plus corners `fence_nw/ne/sw/se` (rails leave the post toward the far sides of a yard).

## Trees sit on grass
Keep `tree.png` (64×64 overlay) if you want a prop.
Prefer the 2×2:
- `tree_nw` / `tree_ne` — canopy overlay
- `tree_sw` / `tree_se` — trunk + roots composited onto grass (ground tiles)

Nearest-neighbor. Indoor dungeon palettes reused so the two biomes sit together.
