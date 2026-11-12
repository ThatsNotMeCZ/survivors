# Godot MCP bridge

Cursor stdio MCP server that the Godot MCP Pro **plugin** connects to.

```
Cursor --stdio--> bun src/index.ts --ws:6505--> Godot plugin (client)
```

Replaces the paid Node `server/` from Godot MCP Pro. Wire format is the public plugin JSON-RPC in `tools/godot-mcp-pro/addons/godot_mcp/`.

## Run

```bash
cd tools/godot-mcp-bridge
bun install
bun src/index.ts
```

Cursor: `.cursor/mcp.json` already points here. Reload MCP. Open Godot with **Godot MCP Pro** enabled. Output should show `Connected on port 6505`.

Do not Write `.tscn` as text. Scene tools go through this bridge. See `knowledge/tech/godot.md`.
