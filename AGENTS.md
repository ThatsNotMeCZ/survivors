# AGENTS

2D survivor-like (Vampire Survivors pacing + Risk of Rain 2 director). Monorepo: live Phaser client in `web/`, Godot sibling in `Godot/`.

## Read first

1. `knowledge/README.md` — design + tech canon
2. `.cursor/rules/` — hard constraints
3. `web/AGENTS.md` — Phaser client (layout, milestone, commands)

## Layout

| Path | Role |
|---|---|
| `knowledge/` | design + tech source of truth |
| `changelog/` | player-facing updates |
| `promo/` | store / itch assets |
| `tools/` | art pipeline (Pixelorama, WIP) |
| `sources/` | raw audio packs |
| `web/` | Phaser 4 + TypeScript + Vite client |
| `Godot/` | Godot client (empty until the project is created) |

## Commands (web)

```bash
cd web
bun install
bun run dev           # http://127.0.0.1:8080
bun run smoke:loop
```

Phaser 4 skills: `web/node_modules/phaser/skills/` (`v4-new-features`, `v3-to-v4-migration`).
