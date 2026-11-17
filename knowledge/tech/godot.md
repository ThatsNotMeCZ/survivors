# Godot client

**Default implementation target** ([clients.md](clients.md)). Unspecified change prompts land here. Do not also edit `web/` unless the prompt names web / Phaser / itch / both.

Godot **4.7** + **typed GDScript**. Agent-first: sim and loaders are code. Packed scenes are authored through the **editor** (Godot MCP bridge), never as text.

itch HTML5 stays Phaser ([clients.md](clients.md)). Godot can export to web; that is not a ship path. Do not add a Godot HTML5 export preset.

Every `.gd` file uses static types (`var x: int`, `-> void`, `Array[InputFrame]`). Untyped GDScript is a bug. Godot 3 APIs (`instance()`, `yield`) are a bug.

## Layout

```
Godot/
  AGENTS.md
  hermetic-rifts/            # Godot project root (keep nested)
    project.godot
    addons/godot_mcp/        # symlink → tools/godot-mcp-pro/addons/godot_mcp
    scenes/
      boot.tscn              # main scene
      arena.tscn
      ui/main_menu.tscn      # title screen (web #main-menu); inspect this in 2D
      ui/hall.tscn           # The Hall / lobby (web #hall); inspect this in 2D
      ui/desk.tscn           # Alchemist's Desk / settings (web #settings-dialog)
      ui/archives.tscn       # The Archives (web #archives); inspect this in 2D
      ui/hud.tscn            # Play HUD (web #hud-play): objective, flask, skills, items
      ui/pause.tscn          # Pause overlay (web #pause-view)
      ui/levelup.tscn        # Tablet select (web #levelup-view)
      ui/recap.tscn          # Run end / game over (web #runend-view)
    assets/ui/               # baked AtlasTexture / StyleBox / Theme from atlas JSON
    locale/en.csv
    data/catalog/            # byte-identical copy of web/src/data/*.json
    src/
      app.gd                 # autoload
      sim/                   # CPU tick; no Node, no Input.*
      view/                  # draws sim state (may attach to scene nodes)
      ui/                    # Control scripts + tr()
      data/                  # JSON catalog loader
      input/                 # device → InputFrame
      net/                   # host-authority stubs only until co-op ships
      workshop/              # IModSource; local folder first
      loc/                   # TranslationServer helpers
      tools/bake_ui_atlas.gd # JSON atlas → res://assets/ui/*.tres
```

Play loop view is `src/view/arena_view.gd`: env-atlas floor stamp (same tile hash as web), `{theme}-pillar` / volatile AtlasTextures, authored `{theme}-circle` plus `circle_charge.gdshader`, skill shaders (`tether`, `brimstone_line`, `skill_impact`, `skill_cd_sweep`), elite affix, biome ambient (`ambient_biome.gdshader` camera-space particles), env/boss hazard shaders. Environment hazards bind `UiAtlas.env_image("{theme}-hazard-*")` (blit, UV 0–1) scaled to `radius * 2`, then `env_hazard.gdshader` feathers the rim (radial + Bayer) into the floor stamp and overlays flow / micro-bubbles on the liquid interior only. Missing frames fall back to a procedural mask. Boss telegraphs stay on `hazard_pool.gdshader` (pulse reads pillar uniforms for Absolute Zero shelter wedges). Aether Laser is `boss_laser.gdshader` on a beam sprite from boss to `laser_end`. Pillars keep sim circle collision at `obs.y` (feet); sprite origin matches web `(frameH - radius) / frameH` and `WorldRoot.y_sort_enabled` occludes the player when standing north of the shaft. Fodder MultiMesh uses Y-flipped QuadMesh and origin-preserving flip. Player sprite faces movement, not aim. The follow camera clamps its center to the arena rect (`world.json` width/height) inset by half the zoomed viewport, and stays centered on an axis when the arena is smaller than the view. Floor tiles use the same per-biome darken as web (`FloorStamp`); walls/borders stay undarkened. HUD IA matches web `#hud-play` (objective fill inside `hud-objective`, flask HP circular well 64px at `(6, 35)` in the 90×104 `hud-flask` sprite matching web `.flask-body`, fill drawn on top of the flask art so the liquid level is visible, 4 skill slots space-between in `hud-skill-dock` with 24px icons centered in the 40px wells). Pause is `scenes/ui/pause.tscn` (inventory panel **340px**, `pause-inventory` inset **70px** so chips sit in the well; item tooltip parchment pad **46/38/46/44** at 300px; rarity splash under chips; plaque buttons **58px** tall; empty-inventory copy centered in the box). Tablet select is `scenes/ui/levelup.tscn` (`sting-banner` 9-slice caps, card name/desc insets match web, no 1/2/3 tip; `offer_1`–`offer_3` still pick). Run end is `scenes/ui/recap.tscn` (web `#runend-view`: sting-banner kicker/title/sub, parchment stats, discoveries, vessel relics, Run Again magma CTA **84px** with 36px flame inset, Return to Hall **58px** plaque, no key hints). Player afterimages spawn on dash **and** fast move (`pspeed > 18`, same as web `stepGhosts`). The Hall seal is centered on the vessel's feet (`u_center` at sprite bottom-center). Daily Rite toggle is 52px and shares its rect with the StyleBox; the seed line sits below, not inside the button. The Daily Rite checkbox is an 18×18 square (`SIZE_SHRINK_CENTER`, matching min/max size) so the HBox cannot stretch it.

Static menu chrome (textures, 9-slice buttons, shaders) lives on the packed scene so the **2D editor shows it without Play**. Runtime scripts keep `tr("KEY")`, vessel idle animation, and signals. Re-bake after `atlas.json` changes:

```bash
godot --headless --path Godot/hermetic-rifts -s res://src/tools/bake_ui_atlas.gd
```

Do not instance `main_menu.tscn` / `hall.tscn` / `desk.tscn` / `archives.tscn` under `boot.tscn` via MCP `add_scene_instance` — that marks children editable and overrides packed textures. `overlay_ui.gd` instantiates the packed scenes at runtime. Open `res://scenes/ui/main_menu.tscn`, `hall.tscn`, `desk.tscn`, or `archives.tscn` in 2D to inspect UI; `boot.tscn` hosts the world in `WorldHost`/`WorldViewport` (1920×1080 nearest-fill) with Overlay as a CanvasLayer sibling. The Hall backdrop is `assets/shaders/hall_backdrop.gdshader` (port of `web/src/ui/hall-backdrop.ts`). Alchemist's Desk is a parchment modal over the current screen (`scenes/ui/desk.tscn`: `Scroll` + `ConfirmBar`). `App._ready` calls `DisplaySettings.apply` after `GameSettings.load_or_default()` so window mode / monitor / resolution / vsync / fps cap persist. Editor Game-tab play skips window mode/size/screen (embedded window cannot move); VSync and FPS still apply. Exported builds apply the full display set. Display changes that can black-screen (mode, monitor, resolution) snapshot then show Keep / Revert for 15s; VSync and FPS save immediately. Web keeps a browser fullscreen toggle.

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

Register autoload `App` (`src/app.gd`) via MCP `add_autoload`. Persistence is `user://records.v1.json` and `user://settings.v1.json` (`windowMode`, `screenIndex`, `resolutionW`/`H`, `vsync`, `maxFps` plus audio / shake / VFX). Native display lives in `src/data/display_settings.gd`, not a browser API.

Default renderer: **Compatibility** (2D, Steam Deck, later mobile). Viewport 1920×1080. Texture filter **Nearest**. Stretch: `canvas_items` / `expand` / `fractional` (UI oversamples glyphs at window size). World lives in `WorldHost` (`SubViewportContainer`, nearest fill, mouse STOP so aim maps into the SubViewport) → `WorldViewport` 1920×1080 with pixel snap; Overlay is a CanvasLayer sibling so text is not baked into the world framebuffer. Overlay root `MOUSE_FILTER_IGNORE` lets empty chrome pass clicks through.

## Godot MCP bridge

Cursor talks to [tools/godot-mcp-bridge](../../tools/godot-mcp-bridge) (stdio). That process listens on `ws://127.0.0.1:6505`. The vendor plugin ([tools/godot-mcp-pro](../../tools/godot-mcp-pro)) is a **WebSocket client** and connects by itself. Config: `.cursor/mcp.json`. Hard rule: `.cursor/rules/godot-mcp.mdc`. Pixelorama art MCP is a separate stdio server on `http://127.0.0.1:7373` ([pixelorama-mcp.md](pixelorama-mcp.md)).

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

Agents print this list and wait. They do not click the editor for the human. Once MCP is connected, use MCP for steps 4–5.

1. Install **Godot 4.7** (standard build, not .NET).
2. Project Manager → Open `Godot/hermetic-rifts/` (nested project root). Renderer: Compatibility. Version-control metadata: Git **files only** (no nested `.git`).
3. First clone: Cursor MCP runs `bash` + `tools/godot-mcp-bridge/start.sh` in `args` (never put the workspace path in `command`; `Disk P` would spawn `/mnt/Disk`). The wrapper `bun install`s the SDK if `node_modules` is missing. Reload MCP after that.
4. Enable plugin **Godot MCP Pro**. Keep the editor open.
5. MCP: `create_scene` `res://scenes/boot.tscn`, set Main Scene, `add_autoload` `App`.
6. Later, not now: export templates, signing, Android SDK, Steam app ID.

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
godot --headless --path Godot/hermetic-rifts -s res://src/smoke/loop_smoke.gd
godot --headless --path Godot/hermetic-rifts --quit-after 60
```

Loop-smoke is the native equivalent of `bun run smoke:loop` (victory, obstacles 14/8/9, no director during boss). Quit-after only checks the editor project loads.
