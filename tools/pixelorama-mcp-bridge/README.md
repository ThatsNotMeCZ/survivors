# Pixelorama MCP bridge

Cursor stdio wrapper around the [Pixelorama-MCP](https://github.com/abidoo22/pixelorama-mcp) server (git submodule `tools/pixelorama-mcp`).

```
Cursor --stdio--> start.sh --> node mcp-server/dist/index.js --HTTP--> Pixelorama PixMcpBridge :7373
```

Does not share a port with Godot MCP (`ws://127.0.0.1:6505`). Pixelorama listens on `http://127.0.0.1:7373`.

## Run

```bash
cd tools/pixelorama-mcp-bridge
./start.sh
```

`start.sh` inits `npm ci` / `npm run build` in the submodule when `node_modules` or `dist/` is missing. Cursor: `.cursor/mcp.json` runs `bash` with `start.sh` in `args` (the workspace path has a space; putting it in `command` splits on spawn). Reload MCP. Open Pixelorama with **pix-MCP Bridge** enabled.

File import/export is confined to `tools/pixelorama/`, `web/public/sprites/`, and `Godot/hermetic-rifts/assets/sprites/` (`PIXELORAMA_MCP_ALLOWED_DIRS`).

After drawing, publish with `tools/pixelorama/publish-sprite.sh` — there is no extra MCP tool for that. See `knowledge/tech/pixelorama-mcp.md`.
