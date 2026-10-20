# Gameloop

Target run: 15–20 minutes. Production: three stages + finale. Current slice: **2 stages + stage boss**, clocks compressed for playtests.

Difficulty coefficient rises with time, not with a flat spawn-more curve. Numbers live in `src/data/loop.json`.

## Shell

HTML overlays in `src/ui/` (not Phaser text). Phaser starts after **Start run**. `/?smoke=1` is the GPU smoke scene (no hall). `/?dev=1` skips the hall and auto-starts a run. Headless loop smoke (`bun run smoke:loop`) never opens a menu.

- Main menu (the hall): Start run, The Vessel, How to play, Settings. Enter starts.
- Vessel dossier: display name + starting skill names (Ignis Bolt / Phase Step), no raw ids.
- Pause: Esc during `phase === 'play'` while the overlay is hidden. HTML `window` capture keydown owns Escape (`key`/`code` `Escape`); Phaser does not bind it (a second edge-toggle was closing pause on the same press). `preventDefault` so the browser does not consume Esc. Nested pause screens (settings, how-to, abandon confirm) back out first. Level-up and recaps swallow Esc. Resume with Esc or Resume. Sim does not step, including nested pause screens.
- Cursor: OS pointer is `cursor: none` during an unpaused run (`data-play=1` + overlay hidden). Shown again on hall, pause, settings, how-to, vessel, level-up, abandon, and recaps. Aim still uses mouse position; the world crosshair stays. No pointer lock.
- Level-up: 3 hermetic tablets. Keys 1–3. Same pick pipeline.
- Boss intro sting + stage interstitial: HTML title cards, do **not** pause combat. Skipped when `smoke` or `dev` is set.
- Death: **Vessel Shattered**. Victory: **Transmutation Complete**. Recap + Run again or hall.

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

Corner-anchored HTML: HP / XP / Phase Step seal / stage clock / difficulty / items / center **objective**. Biome tint is subtle (Cinder warmer, Rime colder). FPS stays behind `?debug=1` or F3. Palette tokens live in `src/ui/theme.css`.

## Director (RoR2, not VS)

Spends a credit budget. Credits buy **elites and bosses**, not 2000 bats. Fodder is texture and XP, capped (`maxFodder`). Soft living cap stays in `knowledge/tech/performance-budget.md`.

## Level-up (VS)

XP gems. Pause via **HTML overlay**, pick 1 of 3. Fast dopamine stays. The pick must not be a screen-clear.

## Death / win

HP to 0 → **Vessel Shattered** overlay, restart or menu. Last boss dead → **Transmutation Complete**.
