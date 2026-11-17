# AGENTS — Godot client

**Default implementation target.** Native sibling of the Phaser itch client. Godot **4.7** + typed GDScript. Canon project root is `Godot/hermetic-rifts/` (`Godot/hermetic-rifts/project.godot`). Checklist: `knowledge/tech/godot.md`. Unspecified change prompts land here; do not also edit `web/` unless named.

## Read first

1. `../knowledge/README.md` — index
2. `../knowledge/tech/godot.md` — GDScript, MCP scenes, editor checklist
3. `../knowledge/tech/clients.md` — default Godot; web only when named
4. `../knowledge/design/future.md` — loc keys, `InputFrame`, Workshop, controller, mobile
5. `../.cursor/rules/godot.mdc` — hard constraints
6. `../tools/godot-mcp-bridge/` — Cursor MCP stdio → plugin WS 6505

## Layout

Paths are relative to `Godot/hermetic-rifts/`.

| Path | Role |
|---|---|
| `scenes/*.tscn` | Packed scenes. Author via MCP, never as text. |
| `scenes/boot.tscn` | Main scene. |
| `src/app.gd` | Autoload. |
| `src/sim/` | CPU tick. No `Node`, no `Input.*`. `tick(state, frames, dt)`. |
| `src/view/` | Draws sim state. |
| `src/ui/` | Control scripts + `tr("KEY")`. |
| `src/data/` | Loads `res://data/catalog/*.json` (same schema as `web/src/data/*.json`). |
| `src/input/` | Devices → `InputFrame`. |
| `src/net/` | Host-authority stubs until co-op ships. |
| `src/workshop/` | `IModSource`. Data packs only. |
| `locale/*.csv` | All player-facing copy. |

## Do not

- Write or patch `.tscn` as text. Use MCP namespace `godot-mcp-pro` for scenes, nodes, InputMap, autoloads, Project Settings, playtest, and editor errors. If MCP is down, print the human checklist and stop.
- Hardcode player-facing English. Use `tr("KEY")`.
- Ship untyped GDScript or Godot 3 APIs (`instance()`, `yield`).
- Fork a second catalog schema. Godot numbers live in `data/catalog/*.json` (same shape as `web/src/data/*.json`). A default task does not also patch Phaser.
- Read `Input` scancodes or `randi()` inside `src/sim/`.
- Add a Godot HTML5 export. itch stays Phaser.
- Load `.gd` / `.dll` / `.cs` from Workshop packs.

## Commands (once the project exists)

```bash
godot --headless --path Godot/hermetic-rifts -s res://src/smoke/loop_smoke.gd
godot --headless --path Godot/hermetic-rifts --quit-after 60
```
