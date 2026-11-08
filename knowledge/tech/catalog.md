# Catalog

Content lives in `src/data/*.json`. Numbers do not belong in `src/sim/` classes.

| File | Contains |
|---|---|
| `world.json` | map size, camera `viewZoom`, default survivor/enemy, projectile pool |
| `loop.json` | stages (incl. `kicker`, `lore`), director, XP curve (`xpBase` 32, `xpGrowth` 1.30), teleporter, caps |
| `obstacles.json` | pillar / hazard / volatile counts, radii, keep-outs, biome display names |
| `survivors.json` | stats, 4 skill slots, starting items, view |
| `skills.json` | primary / secondary / utility / special |
| `entities.json` | fodder / elite / boss, tags, AI (`chase` or `ranged`), contact DPS, rewards, view, `title` + `lore` |
| `items.json` | stackable hooks (`add` / `pct` on a stat, `on-kill` heal) plus display `name` / `lore` |

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

Hooks only. Common and Uncommon items are purely positive building blocks. Rare and Lunar items are powerful double-edged trade-offs. Equip via `startingItems` or level-up overlay. Slice: **13 items** in `items.json`. Ids stay kebab-case; `name` / `lore` are player-facing Dark Hermetic copy. `on-kill` heals current HP on `killEnemy` (clamped to max); it is not a stat in `resolveStats`.

| id | Display | Rarity | Hook |
|---|---|---|---|
| `glass-cannon` | Vitriol Veins | rare | +55% damage, −25% max HP |
| `goat-hoof` | Cloven Sinew | common | +15% speed |
| `brittle-plate` | Slag Carapace | common | +12% armor |
| `hair-trigger` | Spasmodic Nerve | uncommon | −15% cooldown |
| `overclock` | Bellows Heart | uncommon | +22% AoE radius, +20% projectile speed |
| `wax-wings` | Waxen Pinions | common | +35% hazard ward |
| `hungry-clip` | Parasitic Alembic | rare | +2.5 HP/s regen, +35% rite duration, +25% hurtbox |
| `lead-core` | Lead Plumbum | common | +25 max HP |
| `mercury-vial` | Quicksilver Draught | uncommon | +35% essence magnet, +15% essence XP |
| `calcined-lens` | Astrologer's Ocular | rare | +25% crit chance, -0.25s CD on crit, −15% speed |
| `salt-ward` | Salt Effigy | common | −12% hurtbox |
| `lunar-tithe` | Pale Moon Covenant | lunar (weight 0.08) | +60% elite & boss damage, +75% crit damage, −25% armor, −25% essence XP |
| `cinnabar-leech` | Cinnabar Leech | common | +0.3 HP on kill |

Display names elsewhere: survivor `runner` → **Homunculus**; `penitent` → **The Penitent**; skill `bolt` → **Ignis Bolt**; skill `dash` → **Phase Step**; XP gems → **Mercury Drops** / Essence.

## Entity AI

- `chase` — seek player (fodder peel toward an Ash Step decoy if one is live)
- `ranged` — keep `keep`–`range`, windup telegraph, then `projectile` bolt (enemy team)
- `sniper` — stay at `keep`, 1.5s laser telegraph, hitscan. Pillars block. Directed separately (`sniperCost`)

Elites spawn with the **Noxious** modifier and regenerating Aether Shield: contact slow, corpse explode, temporary acid `hazard`. Any non-boss enemy can spawn with the Elite modifier based on difficulty coefficient. Normal enemies spawn in clusters of 3–6, while Elite mutations spawn in compact squads of 1–2.

Unknown `ai.type` is a catalog/schema miss; add the JSON shape then a case in `sim/enemies.ts`.

## Stages

`loop.json` `stages[]`. Each stage points at fodder / elite / boss ids. Optional `ranged` fodder id + `rangedChance` (slice: 0.22). Optional `sniper` id. Slice: Cinder Yard → Rime Dock.

## Obstacles (sim)

`world.obstacles` pool. Each live item: `{ id, type, x, y, radius, hp, maxHp, state, timer, biomeVariant }`. Types `pillar` | `hazard` | `volatile`. Volatile `state`: `intact` | `primed` | `detonated`. Dedicated spatial hash (128px cells) for projectile vs pillar/volatile. Wiped and re-placed in `beginStage`.

## View

`src/view/procedural-pixel-art.ts` generates cached canvases (16/24/28/32/40/48/64, plus 2560 floor) for anything without a PNG. Entity art is a spritesheet per catalog id (`public/sprites/entities/{id}.png`), not per biome. `ArenaScene.preload` loads `sprites/manifest.json` sheets as `entity-{id}` and plays `idle` / `walk`. Arena `flipX` for left. Fodder uses one GPU layer per entity id. Hall crops the idle frame (`src/ui/vessel-art.ts`). HUD icons: `sprites/items/{id}.png`, `sprites/skills/{id}.png`. See `knowledge/tech/sprites.md`.

## UI (HTML overlay)

Menus and HUD are `src/ui/`, not Phaser text. One overlay stack: HUD < prompts < pause/level-up < hall.

| Module | Role |
|---|---|
| `theme.css` | Dark Hermetic tokens (brass, ember, mercury, parchment) |
| `hud.css` / `hud.ts` | Objective banner, biome clock, flask HP, 4 skill slots (`sprites/skills/{id}.png`), 32px item grid (`sprites/items/{id}.png`, stack counts) |
| `overlay.ts` | 3-column hall, pause (inventory strip + archives button), level-up, recap, stings, hold prompt |
| `archives.ts` | Standalone full-screen **The Archives** (`#archives`) with 5 tabs: How to Play, Chronicles (World/Vessels/Chambers), Bestiary, Reliquary, and Persistent Ledger |
| `records.ts` | Persistent player statistics (`localStorage` key `'survivors.records.v1'`), per-run telemetry commit, personal bests, recent run history |
| `entity-art.ts` | Crisp idle-frame canvas preview helper for Bestiary entities and arena props |
| `settings.ts` | `<dialog>`: master/SFX/music, mute, screenshake, reduce-VFX, selected vessel |

Display strings come from catalog `name` / `lore`. Settings drive the Web Audio bus (`knowledge/tech/audio.md`). Phaser stays `noAudio`.

## Do

Add a new enemy/item/survivor/stage as JSON. Point slots at existing skill ids.

## Don't

Hardcode cooldown/damage in `ArenaScene`. Put a new effect in JSON before the sim case exists.
