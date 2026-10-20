# Catalog

Content lives in `src/data/*.json`. Numbers do not belong in `src/sim/` classes.

| File | Contains |
|---|---|
| `world.json` | map size, camera `viewZoom`, default survivor/enemy, projectile pool |
| `loop.json` | stages, director, XP curve, teleporter, caps |
| `obstacles.json` | pillar / hazard / volatile counts, radii, keep-outs, biome display names |
| `survivors.json` | stats, 4 skill slots, starting items, view |
| `skills.json` | primary / secondary / utility / special |
| `entities.json` | fodder / elite / boss, tags, AI (`chase` or `ranged`), contact DPS, rewards, view |
| `items.json` | stackable hooks (`add` / `pct` on a stat) plus display `name` / `lore` |

Schema: `src/data/schema.ts`. Loader: `src/data/catalog.ts` (version check, unique ids, skill refs, stage entity roles).

## Skill slots

`primary` LMB · `secondary` RMB · `utility` Shift/Space · `special` unused

`input`: `hold` or `press` (rising edge).

## Implemented effects

- `projectile` — aimed bolt
- `dash` — move burst + i-frames

Unknown `type` throws at boot. To add one: variant in `schema.ts` → case in `sim/skills.ts` → this list.

## Items

Hooks only. Every draft item has a tradeoff (no pure screen-clear). Equip via `startingItems` or level-up overlay. Slice: **12 items** in `items.json`. Ids stay kebab-case; `name` / `lore` are player-facing Dark Hermetic copy.

| id | Display | Rarity | Hook |
|---|---|---|---|
| `glass-cannon` | Vitriol Veins | uncommon | +40% damage, −15% max HP |
| `goat-hoof` | Cloven Sinew | common | +14% speed, −6% max HP |
| `brittle-plate` | Slag Carapace | common | +28% max HP, −12% speed |
| `hair-trigger` | Spasmodic Nerve | uncommon | −15% cooldown, +12% hurtbox |
| `overclock` | Bellows Heart | uncommon | +22% damage, +12% cooldown |
| `wax-wings` | Waxen Pinions | common | +16% speed, −8% max HP |
| `hungry-clip` | Parasitic Alembic | rare | +28% damage, +14% hurtbox |
| `lead-core` | Lead Plumbum | common | +18 max HP, −8% damage |
| `mercury-vial` | Quicksilver Draught | uncommon | −18% cooldown, −12% max HP |
| `calcined-lens` | Astrologer's Ocular | rare | +32% damage, −10% speed |
| `salt-ward` | Salt Effigy | common | −15% hurtbox, −10% damage |
| `lunar-tithe` | Pale Moon Covenant | lunar (weight 0.08) | +75% damage, −35% max HP, +18% hurtbox |

Display names elsewhere: survivor `runner` → **Homunculus**; skill `bolt` → **Ignis Bolt**; skill `dash` → **Phase Step**; XP gems → **Mercury Drops** / Essence.

## Entity AI

- `chase` — seek player
- `ranged` — keep `keep`–`range`, windup telegraph, then `projectile` bolt (enemy team)

Unknown `ai.type` is a catalog/schema miss; add the JSON shape then a case in `sim/enemies.ts`.

## Stages

`loop.json` `stages[]`. Each stage points at fodder / elite / boss ids. Optional `ranged` fodder id + `rangedChance` (slice: 0.22). Slice: Cinder Yard → Rime Dock.

## Obstacles (sim)

`world.obstacles` pool. Each live item: `{ id, type, x, y, radius, hp, maxHp, state, timer, biomeVariant }`. Types `pillar` | `hazard` | `volatile`. Volatile `state`: `intact` | `primed` | `detonated`. Dedicated spatial hash (128px cells) for projectile vs pillar/volatile. Wiped and re-placed in `beginStage`.

## View

`src/view/procedural-pixel-art.ts` generates cached canvases (16/24/28/32/40/48/64, plus 2560 floor). `pixel-textures.ts` uploads them once. Player / elites / bosses / obstacles = sprites. Fodder / gems / sparks = `SpriteGPULayer`. Keys are biome+frame so a PNG swap later does not touch combat.

## UI (HTML overlay)

Menus and HUD are `src/ui/`, not Phaser text. One overlay stack: HUD < prompts < pause/level-up < hall.

| Module | Role |
|---|---|
| `theme.css` | Dark Hermetic tokens (brass, ember, mercury, parchment) |
| `hud.css` / `hud.ts` | In-run vitals, dash seal, items, objective |
| `overlay.ts` | Hall, vessel, how-to, settings, pause, level-up, recap, stings, hold prompt |
| `settings.ts` | localStorage volume/mute/screenshake/reduce-VFX + selected vessel |

Display strings come from catalog `name` / `lore`. Settings persist even though audio is `noAudio` for now.

## Do

Add a new enemy/item/survivor/stage as JSON. Point slots at existing skill ids.

## Don't

Hardcode cooldown/damage in `ArenaScene`. Put a new effect in JSON before the sim case exists.
