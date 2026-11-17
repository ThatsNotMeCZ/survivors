# Pixelorama MCP

Agent-driven pixel art through [Pixelorama-MCP](https://github.com/abidoo22/pixelorama-mcp) (submodule `tools/pixelorama-mcp`). Cursor talks stdio to [`tools/pixelorama-mcp-bridge/start.sh`](../../tools/pixelorama-mcp-bridge/start.sh). That process HTTP-calls Pixelorama's **pix-MCP Bridge** on `http://127.0.0.1:7373`.

Does not share a port with Godot MCP (`ws://127.0.0.1:6505`, namespace `godot-mcp-pro`). Art jobs use namespace `pixelorama-mcp`. Scenes and GDScript stay on Godot.

Authored `.pxo` projects live in [`tools/pixelorama/`](../../tools/pixelorama/). Finished PNGs ship from `web/public/sprites/` (shared sheet set; Godot copies via [`tools/sync-godot-content`](../../tools/sync-godot-content)). Layout and sidecars: [sprites.md](sprites.md). Style: [design/style.md](../design/style.md).

Upstream drawing recipes: [AGENTIC_DRAWING_PLAYBOOK.md](https://github.com/abidoo22/pixelorama-mcp/blob/main/AGENTIC_DRAWING_PLAYBOOK.md). Entity Gemini prompts in [`tools/enemy-spritesheet-prompt.md`](../../tools/enemy-spritesheet-prompt.md) are a reference; the primary path is MCP.

## Prerequisites

- Pixelorama **v1.1.10–v1.2.4+**
- Node.js **≥ 18**
- Submodule: `git submodule update --init tools/pixelorama-mcp` (or clone with `--recurse-submodules`)

## Human editor checklist

Agents print this list and wait. They do not click Pixelorama for the human. Once the bridge answers `/health`, continue via MCP.

1. Install Pixelorama (standard build is enough; no extra Godot compile).
2. First clone: `git submodule update --init tools/pixelorama-mcp`. Cursor MCP runs `bash` + `tools/pixelorama-mcp-bridge/start.sh` in `args` (never put the workspace path in `command`; `Disk P` would spawn `/mnt/Disk`).
3. Open Pixelorama → **Edit → Preferences** (`Ctrl+,`) → **Extensions** → **Add Extension** → `tools/pixelorama-mcp/pixelorama-plugin/PixMcpBridge.pck` (or the copy at the submodule root). Enable **pix-MCP Bridge**. Restart Pixelorama.
4. Confirm `curl http://127.0.0.1:7373/health` returns `"status":"ok"`.
5. Reload Cursor MCP. Tools such as `create_canvas`, `draw_pixels_fast`, and `capture_canvas_image` should appear.

Do not commit `PixMcpBridge.pck` into survivors; it ships in the submodule.

## Disconnected checklist

If MCP tools time out or `start.sh` prints that `:7373` is unreachable:

1. Pixelorama is open.
2. **pix-MCP Bridge** is enabled under Extensions (re-add the `.pck` after a submodule update).
3. Pixelorama was restarted after enabling.
4. **Flatpak Pixelorama** (`com.orama_interactive.Pixelorama`): sandbox blocks host loopback (`network` missing) and `/mnt/Disk P`:
   `flatpak override --user --share=network --filesystem="/mnt/Disk P/Work/survivors" com.orama_interactive.Pixelorama` (then restart Pixelorama).
5. `curl http://127.0.0.1:7373/health` works.
6. Cursor MCP was reloaded after `git submodule update --init`.
7. Port **7373** is Pixelorama. Port **6505** is Godot. Do not swap them.

Print this list and stop. Do not invent PNG pixels with file Write.

## Hermetic Rifts playbook

Agent workflow: [`.agents/skills/pixelorama-survivors/SKILL.md`](../../.agents/skills/pixelorama-survivors/SKILL.md). Cursor rule: [`.cursor/rules/pixelorama-survivors-art.mdc`](../../.cursor/rules/pixelorama-survivors-art.mdc).

- Palette: [`tools/pixelorama/resurrect-64.pal`](../../tools/pixelorama/resurrect-64.pal) plus **`#000000`**. No other hex (including legacy `#120a0d`).
- Outline `#000000`. Silhouette over micro-detail. Arena camera is 3/4 top-down; creatures face **right** (`flipX` for left in game).
- Keep authored **noise**: bodies are clustered 2–4 adjacent palette shades, not large single-color fills. On existing sheets, patch a tight bbox with `draw_pixels_fast`; do not `fill_area`, `remap_to_palette`, global `color_replace`, or `clean_isolated_pixels` (they flatten noise).
- Entity frame sizes ([design/style.md](../design/style.md)): mite **24**, spitter **28**, vessel **32×48** (Homunculus), elite **40**, boss **64**. Icons **24**. FX stills typically **32** facing +X.
- Horizontal strip of equal frames. Pixelorama animation tags are **1-based**. Use lowercase names that match [sprites.md](sprites.md): `idle`, `walk`, `attack`, or `attack-*` (boss kits). `repeat` is `-1` for idle/walk and `0` for attacks after compact conversion.
- Prefer `draw_pixels_fast` and layers. Use `capture_canvas_image` (magnify) at most 1–2 times before export. `eval_gdscript` only for procedural tiles inside `tools/pixelorama/` — not for writing game code.
- Open `tools/pixelorama/{id}.pxo` when it exists instead of creating a blank canvas.

**Do not** generate art in `procedural-pixel-art.ts`, Comfy, or `_ref` / `_in` / `_raw` folders. Do not author a second Godot-only sheet set. Do not auto-rebuild `env/atlas.png`; env atlas frames stay in `world.pxo` and [`tools/environment.md`](../../tools/environment.md).

## Export flow

1. MCP `export_image` → `tools/pixelorama/export/{id}.png` (keep the `.pxo` next to it under `tools/pixelorama/{id}.pxo`).
2. Optional Pixelorama JSON export beside the PNG.
3. Publish:

```bash
./tools/pixelorama/publish-sprite.sh entity frost-mite
# kind: entity | item | skill | fx | env-frame
```

That copies into `web/public/sprites/{kind}/`, converts Pixelorama project JSON to compact sidecars for entities, and runs `tools/sync-godot-content`.

`env-frame` writes a standalone `web/public/sprites/env/{id}.png`. It does **not** stamp `env/atlas.json` — update atlas coordinates by hand if the frame belongs in the packed atlas.

There is no MCP publish tool. After export, run the shell script.

## Smoke

```bash
git submodule update --init tools/pixelorama-mcp
curl -sf http://127.0.0.1:7373/health
# Pixelorama must be open with pix-MCP Bridge enabled.

./tools/pixelorama-mcp-bridge/start.sh
# Ctrl-C after it stays up. Cursor reload MCP should list create_canvas / draw_pixels_fast / capture_canvas_image.

node tools/pixelorama/pxo-tags-to-compact.mjs tools/pixelorama/export/frost-mite.json
# Prints compact anims (idle frame 0, walk 1-3, attack 4-5 at 24×24).
```

A live draw test is optional: 16×16 in Pixelorama → `tools/pixelorama/export/_mcp-smoke.png` → `publish-sprite.sh fx _mcp-smoke` → delete the test PNG from `web/public/sprites/fx/` and re-run `tools/sync-godot-content`.
