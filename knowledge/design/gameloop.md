# Gameloop

Target run: 15–20 minutes. Production: three stages + finale. Current slice: **2 stages + stage boss**, clocks compressed for playtests.

Difficulty coefficient rises with time, not with a flat spawn-more curve. Numbers live in `src/data/loop.json`.

## Shell

HTML overlays in `src/ui/` (not Phaser text). Phaser starts after **Start run**. `/?smoke=1` is the GPU smoke scene (no hall). `/?dev=1` skips the hall and auto-starts a run. Headless loop smoke (`bun run smoke:loop`) never opens a menu.

- Main menu (the hall): title **Hermetic Rifts** across the top. 3-column Dark Hermetic lobby — left nav (Vessel Selection / Archives / Alchemist's Desk), center 32px vessel preview, right dossier + 4 skill tooltips, **Commence Transmutation**. Enter starts.
- Vessel dossier: display name, title, lore, skill icons with hover hooks. No raw ids.
- Pause: Esc during `phase === 'play'` while the overlay is hidden. Copy: **Simulation Paused** · Resume Sequence · Settings · Abandon Vessel. HTML `window` capture keydown owns Escape (`key`/`code` `Escape`); Phaser does not bind it (a second edge-toggle was closing pause on the same press). `preventDefault` so the browser does not consume Esc. Nested pause screens (settings dialog, how-to, abandon confirm) back out first. Level-up and recaps swallow Esc. Resume with Esc or Resume Sequence. Sim does not step, including nested pause screens.
- Cursor: OS pointer is `cursor: none` during an unpaused run (`data-play=1` + overlay hidden). Shown again on hall, pause, settings, how-to, vessel, level-up, abandon, and recaps. Aim still uses mouse position; the world crosshair stays. No pointer lock.
- Level-up: 3 hermetic tablets (rust/copper/silver/cyan rarity). Green/red hook text. Keys 1–3. Backdrop `blur(4px) brightness(30%)`. Same pick pipeline.
- Boss intro sting + stage interstitial: HTML title cards, do **not** pause combat. Skipped when `smoke` or `dev` is set.
- Death: **Vessel Shattered**. Victory: **Transmutation Complete**. Recap: total time, level reached, bosses defeated, final inventory. Run again or Return to Hall.

## Slice clocks (v1)

| Beat | Stage 1 Cinder Yard | Stage 2 Rime Dock |
|---|---|---|
| First elite | 15s | 12s |
| Teleporter on | 55s | 50s |
| Hold | 20s | 22s |
| Boss | after hold | after hold (run end) |

Production clocks stay ~6 min/stage, teleporter ~minute 4, hold ~60s. Change JSON only.

## One stage

1. Drop. Kite fodder (Mercury Drops / Essence, GPU dots). HUD shows `Seal manifests in M:SS`. Obstacles are placed at stage init: **14 pillars, 8 hazards, 9 volatiles** on the 2560×2560 arena.
2. Level-ups: HTML overlay, pick 1 of 3 item hooks plus lore. Pause sim.
3. Director spends credits on the first elite, then more during the hold. ~22% of fodder spawns are ranged spitters (`stage.ranged`).
4. Teleporter on (player-facing: Transmutation Circle). Coords are **reserved at stage start** so obstacle keep-out can run. Charge only while inside the circle. Swarm walks into the zone. HUD: `Channel the Transmutation Circle`. Off-screen chevron points at the zone.
5. Stage boss. HUD: `Slay the [Boss Name]`. Then **Descend the Rift** (chevron + pulsed circle) to the next biome, or victory on the last stage.

## Obstacle placement (stage init)

Seeded placer (`src/sim/obstacles.ts`). Fail by skipping leftovers, never overlap.

Keep-out:

1. ≥160px from arena walls (pass behind pillars).
2. ≥200px from player spawn.
3. Pillars and hazards ≥230px from the reserved Transmutation Circle center (Hold r=160 Cinder / 150 Rime stays clear). Volatiles ≥200px so they do not sit on the ring.
4. ≥190px center-to-center between any two obstacles.

## Stage wipe

`beginStage` clears enemies, gems, projectiles, **and all obstacle state**, then re-places obstacles for the new biome. Same reset as the rest of the world.

## HUD

HTML overlay, not Phaser text. Top center gold objective banner (Hold fills with pulsing gold). Top right biome + run clock. Bottom left alchemical flask HP + numeric + thin XP line and level. Bottom center 4 skill slots (ready / cooldown sweep / i-frame flash). Bottom right 24×24 item grid. Biome tint is subtle (Cinder warmer, Rime colder). FPS stays behind `?debug=1` or F3. Palette tokens live in `src/ui/theme.css`.

## Director (RoR2, not VS)

Spends a credit budget. Credits buy **elites and bosses**, not 2000 bats. Fodder is texture and XP, capped (`maxFodder`). Soft living cap stays in `knowledge/tech/performance-budget.md`.

## Level-up (VS)

XP gems (Mercury Drops). Pause via **HTML overlay**, pick 1 of 3. Fast dopamine stays: first level is ~8–12s of farming, not four mites. Curve in `loop.json`: `round(xpBase * xpGrowth^(level-1))` with **xpBase 32**, **xpGrowth 1.30** (level 1 = 32 XP, Ember Mite = 3 → ~11 mites). The pick must not be a screen-clear.

## Death / win

HP to 0 → **Vessel Shattered** overlay, restart or menu. Last boss dead → **Transmutation Complete**.
