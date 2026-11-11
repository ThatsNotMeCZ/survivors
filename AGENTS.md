# AGENTS

2D survivor-like (Vampire Survivors pacing + Risk of Rain 2 director). Agent-first Phaser 4 + TypeScript.

## Read first

1. `knowledge/README.md` — index
2. `.cursor/rules/` — hard constraints
3. `node_modules/phaser/skills/` — official Phaser 4 skills (`v4-new-features`, `v3-to-v4-migration`)

## Layout

| Path | Role |
|---|---|
| `src/sim/` | CPU simulation, no Phaser |
| `src/view/` | renderer |
| `src/ui/` | HTML overlay |
| `src/data/` | JSON content |
| `knowledge/` | design + tech source of truth |

## Current milestone

GPU smoke **passed**. Combat verb **A locked**. Homunculus kit complete (Bolt / Piercing Aether / Phase Step / Crucible Cull). **The Penitent** unlockable (Frost Sovereign in Rime Dock). Astral Watcher + **Shielder / Noxious** elites (50/50). Boss fight rework live: director paused during boss duel, unique boss ranged kits + summons (Cinder Heart / Frost Sovereign / Frost Emperor), variable per-attack animations & durations, custom GLSL boss hazard + ambient shaders. HTML main menu / Hall / HUD / Archives in `src/ui/`. Run slice: leveling, **13 items** (6 locked), lore drops, persistent ledger, **3 stages** (Cinder Yard → Rime Dock → Glacial Tomb), teleporter, bosses. Content = `src/data/*.json` (`knowledge/tech/catalog.md`). Art = drop-in spritesheets (`knowledge/tech/sprites.md`). Smoke: `/?smoke=1`. Skip hall: `/?dev=1`. Theme: Dark Hermetic (display strings, not ids).

## Commands

```bash
bun install
bun run dev           # http://127.0.0.1:8080
bun run smoke:loop    # 3 stages + bosses, no browser
bun run build
bun run build:itch    # smoke + build + hermetic-rifts-itch.zip
```

## Do not

- npm / npx / yarn / pnpm
- Phaser 3 copy-paste
- Arcade physics on enemies/bullets
- React around the game loop
- Invent weapons/items that delete the screen or enable AFK wins
- Generate sprites in-repo (Comfy / `_ref` / `_in` / `_raw`)
