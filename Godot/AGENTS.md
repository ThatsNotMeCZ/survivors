# AGENTS — Godot client

Native sibling of the Phaser itch client. Godot **4.7** + typed GDScript. Canon project root is `Godot/` (`Godot/project.godot`), not a nested `Godot/<name>/`. Checklist: `knowledge/tech/godot.md`.

## Read first

1. `../knowledge/README.md` — index
2. `../knowledge/tech/godot.md` — GDScript, MCP scenes, editor checklist
3. `../knowledge/tech/clients.md` — what web vs Godot may change
4. `../knowledge/design/future.md` — loc keys, `InputFrame`, Workshop, controller, mobile
5. `../.cursor/rules/godot.mdc` — hard constraints
6. `../tools/godot-mcp-bridge/` — Cursor MCP stdio → plugin WS 6505

## Layout (once scaffolded)

| Path | Role |
|---|---|
| `scenes/*.tscn` | Packed scenes. Author via MCP, never as text. |
| `scenes/boot.tscn` | Main scene. |
| `src/app.gd` | Autoload. |
| `src/sim/` | CPU tick. No `Node`, no `Input.*`. `tick(state, frames, dt)`. |
| `src/view/` | Draws sim state. |
| `src/ui/` | Control scripts + `tr("KEY")`. |
| `src/data/` | Loads `web/src/data/*.json` (or a byte-identical copy). |
| `src/input/` | Devices → `InputFrame`. |
| `src/net/` | Host-authority stubs until co-op ships. |
| `src/workshop/` | `IModSource`. Data packs only. |
| `locale/*.csv` | All player-facing copy. |

## Do not

- Write or patch `.tscn` as text. Use MCP namespace `godot-mcp-pro` for scenes, nodes, InputMap, autoloads, Project Settings, playtest, and editor errors. If MCP is down, print the human checklist and stop.
- Hardcode player-facing English. Use `tr("KEY")`.
- Ship untyped GDScript or Godot 3 APIs (`instance()`, `yield`).
- Fork catalog numbers. Canon is `web/src/data/*.json`.
- Read `Input` scancodes or `randi()` inside `src/sim/`.
- Add a Godot HTML5 export. itch stays Phaser.
- Load `.gd` / `.dll` / `.cs` from Workshop packs.

## Commands (once the project exists)

```bash
godot --headless --path Godot --quit-after 60
```
