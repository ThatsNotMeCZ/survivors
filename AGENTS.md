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

GPU smoke **passed**. Combat verb **A locked**. Dash live. Run slice: leveling, 8 items, 2 stages, teleporter, bosses. Content = `src/data/*.json` (`knowledge/tech/catalog.md`). Smoke: `/?smoke=1`.

## Commands

```bash
bun install
bun run dev         # http://127.0.0.1:8080
bun run smoke:loop  # 2 stages + boss, no browser
bun run build
```

## Do not

- npm / npx / yarn / pnpm
- Phaser 3 copy-paste
- Arcade physics on enemies/bullets
- React around the game loop
- Invent weapons/items that delete the screen or enable AFK wins
