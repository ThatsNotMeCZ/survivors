# AGENTS

2D survivor-like (Vampire Survivors pacing + Risk of Rain 2 director). Two clients, one design. **Default work is Godot 4.7 typed GDScript in `Godot/`**. Phaser itch client in `web/` is opt-in (prompt must name web / Phaser / itch / both).

## Read first

1. `knowledge/README.md` — design + tech canon
2. `knowledge/tech/clients.md` — default Godot; who ships what
3. `.cursor/rules/` — hard constraints (`godot-default.mdc`)
4. `Godot/AGENTS.md` + `knowledge/tech/godot.md` — Godot client (typed GDScript, MCP `godot-mcp-pro`)
5. `web/AGENTS.md` — Phaser client (only when the prompt names web)
6. `knowledge/tech/pixelorama-mcp.md` — agent art in Pixelorama (MCP `pixelorama-mcp`)

## Layout

| Path | Role |
|---|---|
| `knowledge/` | design + tech source of truth |
| `changelog/` | player-facing updates |
| `promo/` | store / itch assets |
| `tools/` | art pipeline (Pixelorama + MCP, WIP) |
| `tools/pixelorama-mcp/` | Pixelorama MCP submodule (stdio via `tools/pixelorama-mcp-bridge/`) |
| `sources/` | raw audio packs |
| `Godot/` | Default client. Godot 4.7 typed GDScript. Project root: `Godot/hermetic-rifts/` |
| `web/` | Phaser 4 + TypeScript + Vite itch HTML5. Opt-in only. |

Clone with submodules (`git clone --recurse-submodules` or `git submodule update --init tools/pixelorama-mcp`). Pixelorama MCP: [knowledge/tech/pixelorama-mcp.md](knowledge/tech/pixelorama-mcp.md).

## Commands (Godot, default)

```bash
godot --headless --path Godot/hermetic-rifts -s res://src/smoke/loop_smoke.gd
```

## Commands (Pixelorama MCP)

```bash
git submodule update --init tools/pixelorama-mcp
curl -sf http://127.0.0.1:7373/health   # Pixelorama + pix-MCP Bridge
./tools/pixelorama/publish-sprite.sh entity frost-mite
```

## Commands (web, opt-in)

```bash
cd web
bun install
bun run dev           # http://127.0.0.1:8080
bun run smoke:loop
```

Phaser 4 skills (web-only tasks): `web/node_modules/phaser/skills/` (`v4-new-features`, `v3-to-v4-migration`).
