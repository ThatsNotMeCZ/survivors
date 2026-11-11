# Gameloop

Target run: 15–20 minutes. Production clocks stay ~6 min/stage. **Live slice: 3 stages + finale boss**, clocks compressed for playtests.

Difficulty coefficient rises with time, not with a flat spawn-more curve. Numbers live in `src/data/loop.json`.

## Shell

HTML overlays in `src/ui/` (not Phaser text). Phaser starts after **Start Transmutation** from The Hall. `/?smoke=1` is the GPU smoke scene (no hall). `/?dev=1` skips the hall and auto-starts a run. Headless loop smoke (`bun run smoke:loop`) never opens a menu.

Two menu screens, then the run:

- **Main menu** (`#main-menu`): title **Hermetic Rifts**. Left pillar (Archives / Alchemist's Desk), center authored Transmutation Circle (`src/ui/cinder-circle.ts`), **Commence Transmutation**. Enter opens The Hall.
- **The Hall** (`#hall`): vessel lobby — left vessel portraits (locked vessels print **??? · SEALED**), center WebGL hall backdrop (`src/ui/hall-backdrop.ts`) + 32px vessel preview, right dossier + 4 skill tooltips. CTA: **Commence Working** (or **Vessel Sealed** if the inspected vessel is locked). Hall back returns to the main menu.
- **The Archives** (`#archives`): standalone full-screen codex & ledger from the Main Menu and Pause Screen. 5 tabs: **I. Rites of Motion**, **II. Chronicles** (Great Work / Vessels & Arts / The Three Chambers / Law of Exchange), **III. Bestiary** (10 entities), **IV. Reliquary** (13 items, rarity filters, unlock gates), **V. Ledger** (`localStorage` `'survivors.records.v1'`, personal bests, per-vessel & per-stage breakdowns, recent **10** runs, 2-step Purge Ledger). Unseen names print as **???**.
- Vessel dossier: display name, title, lore, skill icons with hover hooks. Locked vessels show the unsealing rite instead of lore. No raw ids.
- Pause: Esc **or P** during `phase === 'play'` while the overlay is hidden. Copy: **Simulation Paused** · Resume Sequence · The Archives · Settings · Abandon Vessel. Body shows run summary + inventory strip (32px icons + stack counts; empty copy **No augmentations bound yet.**). HTML `window` capture keydown owns Escape and P (`key`/`code`); Phaser does not bind them. `preventDefault` so the browser does not consume Esc / Space / arrows (itch iframe). Nested pause screens (settings dialog, archives, abandon confirm) back out first. Level-up and recaps swallow Esc. Resume with Esc, P, or Resume Sequence. Sim does not step, including nested pause screens. Music: map bed keeps playing (ducked) plus the shared chill overlay — `knowledge/tech/audio.md`. Tab blur / `visibilitychange` auto-pauses an unpaused run. Settings: **Fullscreen Chamber**.
- Cursor: OS pointer is `cursor: none` during an unpaused run (`data-play=1` + overlay hidden). Shown again on hall, pause, settings, archives, vessel, level-up, abandon, and recaps. Aim uses mouse position with a hero-specific world crosshair cursor (quicksilver/aether precision brackets for Homunculus, consecrated liturgical ring for The Penitent); no orbiting weapon sprite around the player. No pointer lock.
- Level-up: 3 hermetic tablets (rust/copper/silver/cyan rarity) as **96px** pixel icons + key 1–3. Name, green/red hooks, rarity, and lore live **on the card**. Keys 1–3 still pick. Backdrop `blur(4px) brightness(35%)`. Same pick pipeline. Locked items never appear in the offer.
- Boss intro sting + stage interstitial: HTML title cards, do **not** pause combat. Skipped when `smoke` or `dev` is set.
- Death: **Vessel Shattered**. Victory: **Transmutation Complete**. Recap: time, level, coefficient, kills, bosses, damage, essence, inventory, **Discoveries & Archives** (new unlocks this run). **Copy Summary [C]** dumps a pasteable ledger line. Run again [Enter] or Return to Hall [Esc].

## Slice clocks (v1 demo)

| Beat | Stage 1 Cinder Yard | Stage 2 Rime Dock | Stage 3 Glacial Tomb |
|---|---|---|---|
| First elite | 25s | 18s | 14s |
| Teleporter on | 55s | 50s | 50s |
| Hold | 20s (r=160) | 22s (r=150) | 25s (r=140) |
| Boss | Cinder Heart | Frost Sovereign | Frost Emperor (run end) |

Production clocks stay ~6 min/stage, teleporter ~minute 4, hold ~60s. Change JSON only.

## One stage

1. Drop. Kite fodder (Mercury Drops / Essence, GPU dots). HUD shows **The Seal Manifests** with a fill %. Obstacles are placed at stage init: **14 pillars, 8 hazards, 9 volatiles** on the 2560×2560 arena (plus up to 8 dynamic acid pools).
2. Level-ups: HTML overlay, pick 1 of 3 item hooks plus lore. Pause sim. Offer is filtered to **unlocked** items.
3. Director spends credits on fodder packs, snipers, and (after `firstEliteAt`) elite mutations. ~22% of fodder spawns are ranged spitters (`stage.ranged`; Glacial Tomb 0.28).
4. Teleporter on (player-facing: Transmutation Circle). Coords are **reserved at stage start** so obstacle keep-out can run. Charge only while inside the circle. Swarm walks into the zone. HUD: `Channel the Transmutation Circle`. Off-screen chevron points at the zone.
5. Stage boss duel. Spawning the boss immediately halts Director credit spawns (no new fodder, spitters, snipers, or elites). Living enemies finish naturally. The boss commands the arena via unique ranged kits and summons its own brood. HUD: `Slay the [Boss Name]`. Slaying the boss opens **Descend the Rift** (stand in the portal 1.4s, r=70) to the next biome, or grants victory on the final stage. Leftover lore drops auto-collect on victory.

## Obstacle placement (stage init)

Seeded placer (`src/sim/obstacles.ts`). Fail by skipping leftovers, never overlap.

Keep-out:

1. ≥160px from arena walls (pass behind pillars). Walkable pad also subtracts `world.borderInsetX` 21 / `borderInsetY` 34.
2. ≥200px from player spawn.
3. Pillars and hazards ≥230px from the reserved Transmutation Circle center (Hold r=160 Cinder / 150 Rime / 140 Glacial stays clear). Volatiles ≥200px so they do not sit on the ring.
4. ≥190px center-to-center between any two obstacles.

## Stage wipe

`beginStage` clears enemies, gems, lore drops, projectiles, zones, boss hazards, **and all obstacle state**, then re-places obstacles for the new biome. Same reset as the rest of the world.

## HUD

HTML overlay, not Phaser text. Top center gold objective banner (Hold fills with pulsing gold). Top right biome + run clock and RoR2-style scrolling difficulty slider (Dormant → Stirring → Tempered → Calcined → Volatile → Cataclysm in Resurrect 64 palette). Bottom left alchemical flask HP + numeric + thin XP line and level. Bottom center 4 skill slots (ready / cooldown sweep / i-frame flash). Bottom right **32×32** item grid (6 columns, stack count on every chip). Biome tint is subtle (Cinder warmer, Rime/Glacial colder). FPS stays behind `?debug=1` or F3. Palette tokens live in `src/ui/theme.css`.

## Director (RoR2, not VS)

Spends a credit budget. Spawns enemies in localized clusters (pack size 3–6 normal entities). Every spawn roll has a difficulty-scaled chance to mutate into an Elite (pack size **1**; `eliteGroupSizeMin/Max` 1). Any non-boss enemy (Mite, Spitter, Sniper, Warden) can roll the Elite modifier and then split **50/50 Shielder vs Noxious**. Before the teleporter appears, living elites are capped at 1; during Hold the cap is `maxElites` (6). Elite mutations cost `eliteCostMul` × base (3×). Fodder is texture and XP, tightly capped (`maxFodder` 24). Soft living cap stays in `knowledge/tech/performance-budget.md`. Director **does not spend** while `bossSpawned` or `bossDefeated`.

## Level-up (VS)

XP gems (Mercury Drops). Pause via **HTML overlay**, pick 1 of 3. Fast dopamine stays: first level is ~8–12s of farming, not four mites. Curve in `loop.json`: `round(xpBase * xpGrowth^(level-1))` with **xpBase 32**, **xpGrowth 1.30** (level 1 = 32 XP, Ember Mite = 3 → ~11 mites). The pick must not be a screen-clear. Unlocked-only pool; if that pool is empty the draft falls back to every item.

## Death / win

HP to 0 → **Vessel Shattered** overlay, restart or menu. Last boss dead → **Transmutation Complete**. Recap also lists unlocks earned this run.
