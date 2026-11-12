# Godot client

Godot **4.7** + **typed GDScript**. Agent-first: sim and loaders are code. Packed scenes are authored through the **editor** (Godot MCP bridge), never as text.

itch HTML5 stays Phaser ([clients.md](clients.md)). Godot can export to web; that is not a ship path. Do not add a Godot HTML5 export preset.

Every `.gd` file uses static types (`var x: int`, `-> void`, `Array[InputFrame]`). Untyped GDScript is a bug. Godot 3 APIs (`instance()`, `yield`) are a bug.

## Layout

```
Godot/
  AGENTS.md
  project.godot          # human creates once
  addons/godot_mcp/      # symlink → tools/godot-mcp-pro/addons/godot_mcp
  scenes/
    boot.tscn            # main scene
    player.tscn          # MCP-authored packed scenes
  locale/en.csv
  src/
    app.gd               # autoload
    sim/                 # CPU tick; no Node, no Input.*
    view/                # draws sim state (may attach to scene nodes)
    ui/                  # Control scripts + tr()
    data/                # JSON catalog loader
    input/               # device → InputFrame
    net/                 # host-authority stubs only until co-op ships
    workshop/            # IModSource; local folder first
    loc/                 # TranslationServer helpers
```

`sim` takes `frames: Array[InputFrame]` and `dt: float`. It does not read `Input`, `randi()`, or node paths. View and UI sit outside the tick. Future netcode and Workshop contracts are in [design/future.md](../design/future.md).

## Allowed files

| Write | Do not write |
|---|---|
| `.gd` (typed) via Cursor file tools | `.tscn` as text (Write / StrReplace) |
| `project.godot` (INI, after it exists) | `.godot/` cache |
| `.tres`, catalog JSON copies, `locale/*.csv` | hardcoded player-facing strings |
| `export_presets.cfg` (no secrets) | `.cs`, `.csproj`, `.sln`, `.godot/export_credentials.cfg` |

Scenes: MCP `create_scene` / `add_node` / `save_scene` / `attach_script` / `update_property`. Godot writes valid `uid://` and `ExtResource`. Do not invent a `.tscn` by hand.

`.gd` scripts live under `src/` or next to a scene under `scenes/`. Prefer Cursor file tools for script bodies (types). MCP `create_script` / `edit_script` only for `res://src/**` or `res://scenes/**`.

Register autoload `App` (`src/app.gd`) via MCP `add_autoload` once the project exists.

Default renderer: **Compatibility** (2D, Steam Deck, later mobile). Viewport 1920×1080. Texture filter **Nearest**. Stretch: `canvas_items` / `expand` / `integer`.

## Godot MCP bridge

Cursor talks to [tools/godot-mcp-bridge](../../tools/godot-mcp-bridge) (stdio). That process listens on `ws://127.0.0.1:6505`. The vendor plugin ([tools/godot-mcp-pro](../../tools/godot-mcp-pro)) is a **WebSocket client** and connects by itself. Config: `.cursor/mcp.json`. Hard rule: `.cursor/rules/godot-mcp.mdc`.

Godot must be **open** with plugin **Godot MCP Pro** enabled, or tools return disconnected. Namespace: `godot-mcp-pro`. Inspect the tool schema, then call it. Do not skip MCP because file tools are easier. Do not ask the human to click the editor for a job on this list.

| Job | MCP | Not this |
|---|---|---|
| Packed scenes / nodes | `create_scene`, `open_scene`, `add_node`, `save_scene`, `attach_script`, `update_property`, `get_scene_tree` | Write/StrReplace `*.tscn` |
| Project Settings, autoload, InputMap | `set_project_setting`, `add_autoload`, `set_input_action` | Hand-edit `project.godot` for those keys unless MCP is down |
| Playtest | `play_scene`, `stop_scene`, `get_game_screenshot`, `capture_frames`, `simulate_action` | Guess from logs only |
| Compile / Output | `validate_script` (game scripts), `get_editor_errors`, `get_output_log` | `validate_script` on `res://addons/godot_mcp/**` while the plugin runs |

Cursor file tools stay for typed `.gd` bodies, `locale/*.csv`, and catalog JSON. MCP `create_script` / `edit_script` only under `res://src/` or `res://scenes/`.

Vendor `skills.md` in the addon may still say "prefer inspector"; that is fine **when the mutation goes through MCP**, not when an agent patches the file.

## Human editor checklist

Agents print this list and wait. They do not click the editor for the human. Once MCP is connected, use MCP for steps 3–4.

1. Install **Godot 4.7** (standard build, not .NET).
2. Project Manager → New. Path: this repo's `Godot/` folder (the project root is `Godot/`, not `Godot/<name>/`). Renderer: Compatibility. Version-control metadata: Git **files only** (no nested `.git`).
3. Enable plugin **Godot MCP Pro**. Keep the editor open.
4. MCP: `create_scene` `res://scenes/boot.tscn`, set Main Scene, `add_autoload` `App`.
5. Later, not now: export templates, signing, Android SDK, Steam app ID.

After the human finishes a step that MCP cannot do, continue via MCP + GDScript.

## Git ignore

Keep these out of version control (root `.gitignore`):

```
Godot/**/.godot/
Godot/**/export_credentials.cfg
tools/godot-mcp-bridge/node_modules/
```

Commit `project.godot`, `locale/`, `.gd` scripts, MCP-saved `.tscn`, and `export_presets.cfg` without credentials.

## Smoke (once the project exists)

```bash
godot --headless --path Godot --quit-after 60
```

Headless quit-after is the native equivalent of `bun run smoke:loop`.
