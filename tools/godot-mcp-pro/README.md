# Godot MCP Pro (editor plugin)

Vendor copy of the **Godot 4 editor plugin** (v1.16). It is a WebSocket **client** on ports 6505–6514.

Cursor does **not** use the paid Node `server/`. The stdio MCP is [../godot-mcp-bridge](../godot-mcp-bridge).

```
Cursor  --stdio-->  tools/godot-mcp-bridge  --ws:6505-->  this plugin
```

Enable in the open Godot project: Project → Project Settings → Plugins → Godot MCP Pro. Keep the editor open.

Scenes: MCP `create_scene` / `add_node` / `save_scene`. Do not patch `.tscn` as text. Rules: `knowledge/tech/godot.md`.
