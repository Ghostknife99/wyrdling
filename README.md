# Wyrdling

**Bind the stray. Descend the undercroft.**

An original 2D creature-collecting dungeon crawler (v0). Pick a starter, walk a generated floor, bump wild wyrds into turn-based combat, and Strike, Bind, Swap, or Flee. Permadeath if the whole party falls. Stairs descend to the next floor.

Original IP. Not affiliated with Nintendo, Game Freak, or Pokémon. Do not drop in Nintendo assets or Pokémon names.

## How to run

**Godot 4.3+** (built against 4.4.1 standard / non-.NET). Window is 1280×720.

1. Install Godot 4.3 or 4.4 from [godotengine.org](https://godotengine.org/download) (standard editor, not the .NET build).
2. Open Godot → **Import** → choose `/workspace/wyrdling/project.godot`.
3. Press **F5**. Main scene is `res://scenes/title.tscn`.

From a terminal, if the Linux editor is already on this machine:

```bash
/workspace/tools/godot/godot --path /workspace/wyrdling
```

Headless smoke test (no window):

```bash
/workspace/tools/godot/godot --headless --path /workspace/wyrdling -s res://src/smoke/smoke_test.gd
```

## Controls

**Title** — Enter / Space / click **Begin a Run**

**Starter** — `1` Glimmerling (Wisp) · `2` Cobbleback (Iron) · `3` Briarseed (Bloom), or click a card

**Dungeon**
- `WASD` or arrow keys — one tile per press (turn-based)
- Walk into a wild wyrd to clash
- Walk onto the gold stairs to descend (party mends 30% of max HP)

**Combat** (one screen, overlaid on the floor)
- `1` Strike · `2` Bind · `3` Swap · `4` Flee
- Click the buttons, or arrows/WASD to move the cursor and Enter/Space to confirm
- After Strike, pick a move the same way
- Bind chance rises as the wild’s HP falls: `(1 − hp/max) × 0.7 + 0.1` (10% at full, 80% at 0)

## How a run works

- Autoload run state (`GameState`) plus data tables (`DataDB`). Creatures and moves live in JSON, not scene nodes.
- Party of **3**. Bind during the run. There is no box and no dex.
- If the party is full, a successful Bind **replaces** a chosen member. The released wyrd is gone for this run.
- Rooms + corridors grid, **4–8** wanderers, stairs always visible.
- You step, then wilds wander (or chase if close). Bump starts combat.
- If every party member is KO, the run ends and you return to the title (permadeath).

## Type chart

Pentagon. Super-effective **1.5×**, reverse **0.7×**, otherwise **1.0×** (including same-type).

```
Wisp > Iron > Bloom > Dusk > Tide > Wisp
```

| Attacker | Beats (1.5×) | Resisted by (0.7×) |
|----------|----------------|---------------------|
| Wisp     | Iron           | Tide                |
| Iron     | Bloom          | Wisp                |
| Bloom    | Dusk           | Iron                |
| Dusk     | Tide           | Bloom               |
| Tide     | Wisp           | Dusk                |

Placeholder type colors: Wisp `#F4E4A6` · Iron `#6B7280` · Bloom `#3F6B3A` · Dusk `#2D1B4E` · Tide `#0F4C5C`.

## Roster

| Wyrd        | Type  | Role |
|-------------|-------|------|
| Glimmerling | Wisp  | Starter. A moth-sprite whose wings cup a cold, living flame. |
| Wickmoth    | Wisp  | Soot-winged and oil-slick, it coughs cinders when startled. |
| Cobbleback  | Iron  | Starter. A squat beetle of packed cobbles and rusted nail-heads. |
| Nailbit     | Iron  | A fidget of wire that chews metal and spits bright filings. |
| Briarseed   | Bloom | Starter. A walking seed-hull, thorns for a coat and roots for toes. |
| Marrowl     | Dusk  | Bone-pale owl that hunts in the hush between heartbeats. |
| Veilcrawler | Dusk  | A shroud-long crawler that peels darkness off the walls. |
| Brinekit    | Tide  | A slick kit with gill-frills and a pouch of black-water brine. |

Each has 2–3 moves and HP / Atk / Def / Spd in `data/creatures.json` and `data/moves.json`.

## Art folders (Arthur)

Drop finished sprites over these placeholders. Keep the folders and lowercase_underscore names:

```
art/player/delver_idle_down.png   (also _up _left _right)     64×64
art/creatures/glimmerling.png cobbleback.png briarseed.png
               marrowl.png brinekit.png wickmoth.png
               nailbit.png veilcrawler.png                    64×64
art/tiles/floor.png floor_alt.png wall.png stairs.png         32×32
art/ui/wordmark.png hp_frame.png hp_fill.png btn_panel.png
      icon_wisp.png icon_iron.png icon_bloom.png
      icon_dusk.png icon_tide.png
```

The delver is a small brass-lantern humanoid blob. Creature art is geometric silhouettes in the type colors.

## Project layout

```
project.godot                 Godot 4.3+ / 4.4, main scene = title
scenes/title.tscn             title
scenes/starter_select.tscn    pick Glimmerling / Cobbleback / Briarseed
scenes/dungeon.tscn           generated floor
scenes/combat.tscn            Strike / Bind / Swap / Flee
src/autoload/data_db.gd       JSON tables + type chart
src/autoload/game_state.gd    run / party / floor (autoload)
src/dungeon/                  rooms+corridors generator + explore
src/combat/                   one-screen clash
data/                         creatures.json, moves.json, types.json
art/                          placeholders listed above
```

Regenerate placeholders:

```bash
python3 tools/generate_placeholders.py
```

## Leftover (not in v0)

No XP or levels, no evolution, no dex, no overworld hub, no sound, no items. Floors continue indefinitely; there is no final boss. Art is geometric placeholders. `first-slice/` is unused scratch from an earlier pass.
