# Gameloop

Target run: 15–20 minutes. Production: three stages + finale. Current slice: **2 stages + stage boss**, clocks compressed for playtests.

Difficulty coefficient rises with time, not with a flat spawn-more curve. Numbers live in `src/data/loop.json`.

## Shell

HTML overlays in `src/ui/`. Phaser starts after **Start run**. `/?smoke=1` skips the menu.

- Main menu: Start run, controls hint. Enter starts.
- Pause: Esc during `phase === 'play'`. Resume or Quit to menu. Sim does not step.
- Level-up / victory / defeat still use the same overlay. Level-up keys 1–3. Run end: Run again or Menu.

## Slice clocks (v1)

| Beat | Stage 1 Cinder Yard | Stage 2 Rime Dock |
|---|---|---|
| First elite | 15s | 12s |
| Teleporter on | 55s | 50s |
| Hold | 20s | 22s |
| Boss | after hold | after hold (run end) |

Production clocks stay ~6 min/stage, teleporter ~minute 4, hold ~60s. Change JSON only.

## One stage

1. Drop. Kite fodder (XP gems, GPU dots). HUD shows `Teleporter in M:SS`.
2. Level-ups: HTML overlay, pick 1 of 3 item hooks. Pause sim.
3. Director spends credits on the first elite, then more during the hold. ~22% of fodder spawns are ranged spitters (`stage.ranged`).
4. Teleporter on. Charge only while inside the circle. Swarm walks into the zone. HUD: Hold the teleporter. Off-screen chevron points at the zone.
5. Stage boss. HUD: Kill the boss. Then **Enter the portal** (chevron + pulsed circle) to the next biome, or victory on the last stage.

## HUD

Player HUD is HP / XP / dash / stage clock plus a center **objective**. FPS and coefficient stay behind `?debug=1` or F3.

## Director (RoR2, not VS)

Spends a credit budget. Credits buy **elites and bosses**, not 2000 bats. Fodder is texture and XP, capped (`maxFodder`). Soft living cap stays in `knowledge/tech/performance-budget.md`.

## Level-up (VS)

XP gems. Pause via **HTML overlay**, pick 1 of 3. Fast dopamine stays. The pick must not be a screen-clear.

## Death / win

HP to 0 → defeat overlay, restart or menu. Last boss dead → victory overlay.
