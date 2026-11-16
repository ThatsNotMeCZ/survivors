# Godot MCP bridge

Cursor stdio MCP server that the Godot MCP Pro **plugin** connects to.

```
Cursor --stdio--> start.sh --> bun src/index.ts --ws:6505--> Godot plugin (client)
```

Replaces the paid Node `server/` from Godot MCP Pro. Wire format is the public plugin JSON-RPC in `tools/godot-mcp-pro/addons/godot_mcp/`.

## Run

```bash
cd tools/godot-mcp-bridge
./start.sh
```

`start.sh` runs `bun install` when `@modelcontextprotocol/sdk` is missing. Cursor: `.cursor/mcp.json` runs `bash` with `start.sh` in `args` (the workspace path has a space; putting it in `command` splits on spawn). Reload MCP. Open Godot with **Godot MCP Pro** enabled. Output should show `Connected on port 6505`.

Do not Write `.tscn` as text. Scene tools go through this bridge. See `knowledge/tech/godot.md`.
