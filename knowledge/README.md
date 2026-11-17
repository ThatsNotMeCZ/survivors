# Knowledge base

Canonical notes for humans and agents. Update these when a design decision lands. Do not keep lore only in chat.

Live slice (2026-11): **3 compressed stages**, 2 vessels, 13 items (6 locked), Shielder + Noxious elites, dedicated boss duels. **Default implementation target is Godot** (`Godot/hermetic-rifts/`). itch.io still ships Phaser in `web/`; do not edit `web/` unless the prompt names web / Phaser / itch / both ([tech/clients.md](tech/clients.md)). Godot numbers live in `Godot/hermetic-rifts/data/catalog/*.json` (same schema as `web/src/data/*.json`).

## Design

| File | What it answers |
|---|---|
| [design/concept.md](design/concept.md) | What the game is |
| [design/anti-idle.md](design/anti-idle.md) | Why VS goes idle and how we don't |
| [design/gameloop.md](design/gameloop.md) | One run, three-stage slice |
| [design/style.md](design/style.md) | Art and readability |
| [design/combat.md](design/combat.md) | Aimed primary (locked A) |
| [design/future.md](design/future.md) | Co-op, Workshop, loc, controller, mobile — do not block |
| [design/open-questions.md](design/open-questions.md) | Settled decisions |

## Tech

| File | What it answers |
|---|---|
| [tech/stack.md](tech/stack.md) | Phaser web + Godot GDScript native |
| [tech/clients.md](tech/clients.md) | Default Godot; who ships what; when web is allowed |
| [tech/godot.md](tech/godot.md) | Agent-first typed GDScript, MCP scenes, editor checklist |
| [tech/performance-budget.md](tech/performance-budget.md) | Entity caps |
| [tech/smoke-test.md](tech/smoke-test.md) | What "pass" means |
| [tech/catalog.md](tech/catalog.md) | Items, skills, entities JSON |
| [tech/sprites.md](tech/sprites.md) | Drop-in spritesheets, icons, env later |
| [tech/pixelorama-mcp.md](tech/pixelorama-mcp.md) | Agent art in Pixelorama (MCP :7373) |
| [tech/audio.md](tech/audio.md) | Playlists, SFX, pause overlay |

## Release

| File | What it answers |
|---|---|
| [itch-io-release-plan.md](itch-io-release-plan.md) | itch.io demo publish, copy, promo |
| [gx-kong-promo.md](gx-kong-promo.md) | GX.games + Kongregate listing packs (copy + images) |
| [../changelog/README.md](../changelog/README.md) | Player-facing updates → itch.io Devlog source |

## Godot (default)

Read [tech/godot.md](tech/godot.md) and `Godot/AGENTS.md` before touching `Godot/`. Engine skills live in `.cursor/skills/godot-*` (nodes, physics, UI). Agents do not Write `.tscn` as text. Scenes, editor jobs, and playtest go through MCP `godot-mcp-pro` (`.cursor/rules/godot-mcp.mdc`).

## Phaser (opt-in)

Official skills ship with the package: `web/node_modules/phaser/skills/`.
Do not vendor copies. Read them only on a web-named task that touches renderer, input, or scenes.
