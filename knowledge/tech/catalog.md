# Catalog

Content lives in `src/data/*.json`. Numbers do not belong in `src/sim/` classes.

| File | Contains |
|---|---|
| `world.json` | map size, camera `viewZoom`, default survivor/enemy, projectile pool |
| `loop.json` | stages, director, XP curve, teleporter, caps |
| `survivors.json` | stats, 4 skill slots, starting items, view |
| `skills.json` | primary / secondary / utility / special |
| `entities.json` | fodder / elite / boss, tags, AI (`chase` or `ranged`), contact DPS, rewards, view |
| `items.json` | stackable hooks (`add` / `pct` on a stat) |

Schema: `src/data/schema.ts`. Loader: `src/data/catalog.ts` (version check, unique ids, skill refs, stage entity roles).

## Skill slots

`primary` LMB · `secondary` RMB · `utility` Shift/Space · `special` unused

`input`: `hold` or `press` (rising edge).

## Implemented effects

- `projectile` — aimed bolt
- `dash` — move burst + i-frames

Unknown `type` throws at boot. To add one: variant in `schema.ts` → case in `sim/skills.ts` → this list.

## Items

Hooks only. Every draft item has a tradeoff (no pure screen-clear). Equip via `startingItems` or level-up overlay. Slice: 8 items in `items.json`.

## Entity AI

- `chase` — seek player
- `ranged` — keep `keep`–`range`, windup telegraph, then `projectile` bolt (enemy team)

Unknown `ai.type` is a catalog/schema miss; add the JSON shape then a case in `sim/enemies.ts`.

## Stages

`loop.json` `stages[]`. Each stage points at fodder / elite / boss ids. Optional `ranged` fodder id + `rangedChance` (slice: 0.22). Slice: Cinder Yard → Rime Dock.

## Do

Add a new enemy/item/survivor/stage as JSON. Point slots at existing skill ids.

## Don't

Hardcode cooldown/damage in `ArenaScene`. Put a new effect in JSON before the sim case exists.
