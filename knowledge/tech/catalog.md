# Catalog

Content lives in `src/data/*.json`. Numbers do not belong in `src/sim/` classes.

| File | Contains |
|---|---|
| `world.json` | map size, camera `viewZoom`, default survivor/enemy, projectile pool |
| `loop.json` | stages, director, XP curve (`xpBase` 32, `xpGrowth` 1.30), teleporter, caps |
| `obstacles.json` | pillar / hazard / volatile counts, radii, keep-outs, biome display names |
| `survivors.json` | stats, 4 skill slots, starting items, view |
| `skills.json` | primary / secondary / utility / special |
| `entities.json` | fodder / elite / boss, tags, AI (`chase` or `ranged`), contact DPS, rewards, view |
| `items.json` | stackable hooks (`add` / `pct` on a stat) plus display `name` / `lore` |

Schema: `src/data/schema.ts`. Loader: `src/data/catalog.ts` (version check, unique ids, skill refs, stage entity roles).

## Skill slots

`primary` LMB · `secondary` RMB · `utility` Shift/Space · `special` Q

`input`: `hold` or `press` (rising edge).

## Implemented effects

- `projectile` — aimed bolt. Optional `pierce`, `flyOver`, `impactRadius` (mortar lands at cursor, ignores enemies in flight)
- `dash` — move burst + i-frames. Optional `decoyDuration` (fodder-only aggro dummy)
- `self-slow` — player speed mul for a duration
- `delayed-strike` — telegraph, then small-radius AoE at cursor
- `slow-line` — brimstone seam; fodder-only slow
- `tether` — first elite/boss hit is rooted; fodder touching it burn. Fodder or miss wastes the cooldown

Unknown `type` throws at boot. To add one: variant in `schema.ts` → case in `sim/skills.ts` → this list.

## Survivors

| id | Display | Role |
|---|---|---|
| `runner` | Homunculus | Fast skirmisher. Bolt, Piercing Aether, Phase Step, Crucible Cull |
| `penitent` | The Penitent | Caster/controller. Censer Lob, Brimstone Line, Ash Step, Condemnation Tether |

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

Display names elsewhere: survivor `runner` → **Homunculus**; `penitent` → **The Penitent**; skill `bolt` → **Ignis Bolt**; skill `dash` → **Phase Step**; XP gems → **Mercury Drops** / Essence.

## Entity AI

- `chase` — seek player (fodder peel toward an Ash Step decoy if one is live)
- `ranged` — keep `keep`–`range`, windup telegraph, then `projectile` bolt (enemy team)
- `sniper` — stay at `keep`, 1.5s laser telegraph, hitscan. Pillars block. Directed separately (`sniperCost`)

Elites spawn with the **Noxious** modifier: contact slow, corpse explode, permanent acid `hazard`.

Unknown `ai.type` is a catalog/schema miss; add the JSON shape then a case in `sim/enemies.ts`.

## Stages

`loop.json` `stages[]`. Each stage points at fodder / elite / boss ids. Optional `ranged` fodder id + `rangedChance` (slice: 0.22). Optional `sniper` id. Slice: Cinder Yard → Rime Dock.

## Obstacles (sim)

`world.obstacles` pool. Each live item: `{ id, type, x, y, radius, hp, maxHp, state, timer, biomeVariant }`. Types `pillar` | `hazard` | `volatile`. Volatile `state`: `intact` | `primed` | `detonated`. Dedicated spatial hash (128px cells) for projectile vs pillar/volatile. Wiped and re-placed in `beginStage`.

## View

`src/view/procedural-pixel-art.ts` generates cached canvases (16/24/28/32/40/48/64, plus 2560 floor). `pixel-textures.ts` uploads any key Phaser does not already have (so a destroyed Game can boot again). Player / elites / bosses / obstacles = sprites. Fodder / gems / sparks = `SpriteGPULayer`. Player keys are vessel+biome; other keys are biome+frame so a PNG swap later does not touch combat. Hall portraits seal interior holes (no hall-circle showing through the vessel).

## UI (HTML overlay)

Menus and HUD are `src/ui/`, not Phaser text. One overlay stack: HUD < prompts < pause/level-up < hall.

| Module | Role |
|---|---|
| `theme.css` | Dark Hermetic tokens (brass, ember, mercury, parchment) |
| `hud.css` / `hud.ts` | Objective banner, biome clock, flask HP, 4 skill slots, 24px item grid |
| `overlay.ts` | 3-column hall, how-to, pause, hermetic tablets, recap, stings, hold prompt |
| `settings.ts` | `<dialog>`: master/SFX/music, mute, screenshake, reduce-VFX, selected vessel |

Display strings come from catalog `name` / `lore`. Settings persist even though audio is `noAudio` for now.

## Do

Add a new enemy/item/survivor/stage as JSON. Point slots at existing skill ids.

## Don't

Hardcode cooldown/damage in `ArenaScene`. Put a new effect in JSON before the sim case exists.
