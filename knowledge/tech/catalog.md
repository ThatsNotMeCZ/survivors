# Catalog

Content lives in `src/data/*.json`. Numbers do not belong in `src/sim/` classes.

| File | Contains |
|---|---|
| `world.json` | map size, camera `viewZoom`, border insets, default survivor/enemy, projectile pool (128) |
| `loop.json` | 3 stages (incl. `kicker`, `lore`), director, XP curve (`xpBase` 32, `xpGrowth` 1.30), teleporter, caps, elite/noxious/shielder, `loreDropChance`, rarity weights |
| `obstacles.json` | pillar / hazard / volatile counts, radii, keep-outs, biome display names (Cinder / Rime / Glacial) |
| `survivors.json` | stats, 4 skill slots, starting items, view, optional `unlock` |
| `skills.json` | primary / secondary / utility / special |
| `entities.json` | fodder / elite-host / boss, tags, AI (`chase`, `ranged`, `sniper`, `boss`), contact DPS, rewards, view, `title` + `lore` |
| `items.json` | stackable hooks (`add` / `pct` / `on-kill` / `on-crit`) plus display `name` / `lore` / optional `unlock` |

Schema: `src/data/schema.ts`. Loader: `src/data/catalog.ts` (version check, unique ids, skill refs, stage entity roles, unlock refs).

## Skill slots

`primary` LMB · `secondary` RMB · `utility` Shift/Space · `special` Q

`input`: `hold` or `press` (rising edge).

## Implemented effects

- `projectile` — aimed bolt. Optional `pierce`, `flyOver`, `impactRadius` (mortar lands at cursor, ignores enemies in flight)
- `dash` — move burst + i-frames. Optional `decoyDuration` (fodder-only aggro dummy)
- `self-slow` — player speed mul for a duration
- `delayed-strike` — telegraph, then small-radius AoE at cursor
- `slow-line` — brimstone seam; fodder-only slow
- `tether` — pierces and burns lesser enemies along its path; roots first elite/boss hit with an active burning tether chain. Fodder touching the active chain also burn. Miss wastes the cooldown

Unknown `type` throws at boot. To add one: variant in `schema.ts` → case in `sim/skills.ts` → this list.

## Survivors

| id | Display | Role | Unlock |
|---|---|---|---|
| `runner` | Homunculus | Fast skirmisher. Bolt, Piercing Aether, Phase Step, Crucible Cull | Default |
| `penitent` | The Penitent | Caster/controller. Censer Lob, Brimstone Line, Ash Step, Condemnation Tether | `boss-kill` Frost Sovereign in Rime Dock |

## Items

Hooks only. Common and Uncommon items are purely positive building blocks. Rare and Lunar items are powerful double-edged trade-offs. Equip via `startingItems` or level-up overlay. Slice: **13 items** in `items.json`. Ids stay kebab-case; `name` / `lore` are player-facing Dark Hermetic copy. `on-kill` heals current HP on `killEnemy` (clamped to max); `on-crit` refunds cooldown seconds — neither is a stat in `resolveStats`. Base crit is 5% / ×2 unless a survivor overrides it.

Locked items (`unlock`) stay out of the level-up offer until `records.ts` says the condition is met. 7 items start unbound; 6 are gated.

| id | Display | Rarity | Hook | Unlock |
|---|---|---|---|---|
| `glass-cannon` | Vitriol Veins | rare | +55% damage, −25% max HP | — |
| `goat-hoof` | Cloven Sinew | common | +15% speed | — |
| `brittle-plate` | Slag Carapace | common | +12% armor | — |
| `hair-trigger` | Spasmodic Nerve | uncommon | −15% cooldown | — |
| `overclock` | Bellows Heart | uncommon | +22% AoE radius, +20% projectile speed | Slay the Cinder Heart |
| `wax-wings` | Waxen Pinions | common | +35% hazard ward | — |
| `hungry-clip` | Parasitic Alembic | rare | +2.5 HP/s regen, +35% rite duration, +25% hurtbox | Slay 10 elites |
| `lead-core` | Lead Plumbum | common | +25 max HP | — |
| `mercury-vial` | Quicksilver Draught | uncommon | +35% essence magnet, +15% essence XP | — |
| `calcined-lens` | Astrologer's Ocular | rare | +25% crit chance, −0.25s CD on crit, −15% speed | Slay 300 Dross |
| `salt-ward` | Salt Effigy | common | −12% hurtbox | Clear the Cinder Yard |
| `lunar-tithe` | Pale Moon Covenant | lunar (weight 0.08) | +60% elite & boss damage, +75% crit damage, −25% armor, −25% essence XP | Clear the Rime Dock |
| `cinnabar-leech` | Cinnabar Leech | common | +0.3 HP on kill | Slay 100 Dross |

`unlock` types: `stage-clear` · `boss-kill` · `total-kills` · `elite-kills` · `victories`. Schema in `schema.ts`; progress in `src/ui/records.ts`.

Display names elsewhere: survivor `runner` → **Homunculus**; `penitent` → **The Penitent**; skill `bolt` → **Ignis Bolt**; skill `dash` → **Phase Step**; XP gems → **Mercury Drops** / Essence.

## Entity AI

- `chase` — seek player (fodder peel toward an Ash Step decoy if one is live)
- `ranged` — keep `keep`–`range`, windup telegraph, then `projectile` bolt (enemy team)
- `sniper` — stay at `keep`, 1.5s laser telegraph, hitscan. Pillars block. Directed separately (`sniperCost`, `maxSnipers` 3)
- `boss` — dedicated duel AI. `keep` range, optional `enrage` (`hpPct` + `cooldownMul`), `attacks[]` with per-attack `anim` + windup. Types: `bolt`, `fan`, `meteor` (+ optional lava/frost `pool`), `cone`, `prison`, `pulse`, `laser` (tracking beam + trail pools), `summon` (`entity`, `count`, `maxAlive`). Cases live in `sim/boss.ts` + `sim/boss-hazards.ts`

Elites are not catalog rows. Any non-boss spawn can mutate; the elite then rolls **50/50 Shielder vs Noxious** (`sim/enemies.ts`).

- **Shielder** — regenerating Aether Shield (`shielder.percentHp` 0.30 of max HP, recharges after `delay` 5s unharmed). Azure outline shader.
- **Noxious** — contact slow (`×0.5` for 1.1s). On death, 0.5s corpse telegraph, pop (`r=40`, 8 dmg), then a **temporary acid pool** (`hazard`, `poolDuration` 6s, up to `dynamicHazards` 8 live). Viridian overlay shader.

Unknown `ai.type` is a catalog/schema miss; add the JSON shape then a case in `sim/enemies.ts` (or `sim/boss.ts` for `boss`).

## Boss kits (live)

Director credit spawns halt for the whole duel. Enrage at 50% HP (cooldown ×0.75; Frost Emperor ×0.72).

| Stage | Boss | Attacks |
|---|---|---|
| Cinder Yard | Cinder Heart | Slag Spray (`fan`), Falling Clinker (`meteor` + lava pool), Kiln Brood (`ember-mite` ×3, max 6) |
| Rime Dock | Frost Sovereign | Cryo Lance (`bolt`), Glacial Sweep (`cone`), Rime Prison (`prison`), Rime Brood (`frost-mite` ×3, max 6) |
| Glacial Tomb | Frost Emperor | Glacial Spear (`bolt`), Absolute Zero Pulse (`pulse` r=620), Aether Laser (`laser` + trail pools), Imperial Guard (`frost-mite`), Brine Retinue (`frost-spitter`) |

## Stages

`loop.json` `stages[]`. Each stage points at fodder / elite-host / boss ids. Optional `ranged` fodder id + `rangedChance`. Optional `sniper` id.

| id | Display | Kicker | Fodder / ranged / elite-host / boss |
|---|---|---|---|
| `cinder-yard` | Cinder Yard | Nigredo & Calcination | `ember-mite` / `ember-spitter` 0.22 / `ember-chaser` / `cinder-heart` |
| `rime-dock` | Rime Dock | Albedo & Fixation | `frost-mite` / `frost-spitter` 0.22 / `frost-warden` / `frost-sovereign` |
| `glacial-tomb` | Glacial Tomb | Rubedo & The Great Seal | `frost-mite` / `frost-spitter` 0.28 / `frost-warden` / `frost-emperor` |

Astral Watcher (`enemy-astral-sniper`) is the sniper on every stage.

## Obstacles (sim)

`world.obstacles` pool. Each live item: `{ id, type, x, y, radius, hp, maxHp, state, timer, biomeVariant }`. Types `pillar` (r=28) | `hazard` (r=68) | `volatile` (r=14). Volatile `state`: `intact` | `primed` | `detonated`. Cap = 14+8+9 + `dynamicHazards` 8. Dedicated spatial hash (128px cells) for projectile vs pillar/volatile. Wiped and re-placed in `beginStage`.

Display names: Cinder Yard Obsidian Kiln / Slag Fissure / Brimstone Urn. Rime Dock Frozen Bollard / Brine Pool / Pressurized Rime Cask. Glacial Tomb Glacial Monolith / Permafrost Crevasse / Volatile Ice Chunk.

Rime Dock volatile detonations also apply 2.0s ×0.7 slow (Cinder and Glacial do not).

## Lore drops

Kills may drop a treatise orb (`sim/gems.ts` lore pool, cap 8). Chance in `loop.loreDropChance`: fodder 0.025, elite 0.25, boss 0.6. One live drop per entity id. Pickup writes `records.entityLores` and unlocks that Bestiary entry's lore. Victory auto-collects remaining orbs.

## View

`src/view/procedural-pixel-art.ts` generates cached canvases (16/24/28/32/40/48/64, plus 2560 floor) for anything without a PNG. Entity art is a spritesheet per catalog id (`public/sprites/entities/{id}.png`), not per biome. `ArenaScene.preload` loads `sprites/manifest.json` sheets as `entity-{id}` and plays `idle` / `walk` plus per-attack boss anims. Arena `flipX` for left. Fodder uses one GPU layer per entity id. Hall crops the idle frame (`src/ui/vessel-art.ts`). HUD icons: `sprites/items/{id}.png` (24px source, 32px chips), `sprites/skills/{id}.png`. See `knowledge/tech/sprites.md`.

Arena GLSL (view only): elite affix, boss hazards + Cinder smoke, ambient biome, env hazards, circle charge, brimstone line, condemn tether, skill impact, player hurt, damage FX, motion smear. Hall/menu WebGL lives in `src/ui/` (`hall-backdrop.ts`, `cinder-circle.ts`).

## UI (HTML overlay)

Menus and HUD are `src/ui/`, not Phaser text. Overlay stack: HUD < prompts < pause/level-up/recap < hall/archives.

| Module | Role |
|---|---|
| `theme.css` | Dark Hermetic tokens (brass, ember, mercury, parchment) |
| `hud.css` / `hud.ts` | Objective banner, biome clock, flask HP, 4 skill slots (`sprites/skills/{id}.png`), 32px item grid (`sprites/items/{id}.png`, stack counts), difficulty slider |
| `overlay.ts` | Main menu, The Hall, pause (inventory + Archives), level-up, recap + Copy Summary [C], stings, hold prompt, fullscreen, auto-pause on blur |
| `archives.ts` | Standalone full-screen **The Archives** (`#archives`) with 5 tabs |
| `records.ts` | Persistent player statistics (`localStorage` key `'survivors.records.v1'`), unlock checks, per-run telemetry commit, personal bests, recent 10 runs |
| `entity-art.ts` | Crisp idle-frame canvas preview helper for Bestiary entities and arena props |
| `settings.ts` | `<dialog>`: master/SFX/music, mute, screenshake, reduce-VFX, selected vessel, Fullscreen Chamber |

Display strings come from catalog `name` / `lore`. Settings drive the Web Audio bus (`knowledge/tech/audio.md`). Phaser stays `noAudio`.

## Do

Add a new enemy/item/survivor/stage as JSON. Point slots at existing skill ids. Gate content with `unlock` instead of hiding rows.

## Don't

Hardcode cooldown/damage in `ArenaScene`. Put a new effect in JSON before the sim case exists. Put a new `unlock.type` in JSON before `records.ts` + `catalog.ts` know it.
