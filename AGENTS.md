# AGENTS

2D survivor-like (Vampire Survivors pacing + Risk of Rain 2 director). Two clients, one design: live Phaser itch client in `web/`, Godot 4.7 typed GDScript native sibling in `Godot/`.

## Read first

1. `knowledge/README.md` — design + tech canon
2. `knowledge/tech/clients.md` — who ships what
3. `.cursor/rules/` — hard constraints
4. `web/AGENTS.md` — Phaser client
5. `Godot/AGENTS.md` + `knowledge/tech/godot.md` — Godot client (typed GDScript, MCP scenes)

## Layout

| Path | Role |
|---|---|
| `knowledge/` | design + tech source of truth |
| `changelog/` | player-facing updates |
| `promo/` | store / itch assets |
| `tools/` | art pipeline (Pixelorama, WIP) |
| `sources/` | raw audio packs |
| `web/` | Phaser 4 + TypeScript + Vite client (itch HTML5) |
| `Godot/` | Godot 4.7 typed GDScript client (empty until the project is created) |

## Commands (web)

```bash
cd web
bun install
bun run dev           # http://127.0.0.1:8080
bun run smoke:loop
```

Phaser 4 skills: `web/node_modules/phaser/skills/` (`v4-new-features`, `v3-to-v4-migration`).

Godot smoke (once `project.godot` exists): `godot --headless --path Godot --quit-after 60`.
