import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { ALLOWED_NAMES, ALLOWLIST, assertScriptPath } from "./allowlist";
import { GodotWs } from "./godot-ws";

const PORT = Number(process.env.GODOT_MCP_PORT ?? "6505");

function log(msg: string): void {
  console.error(`[godot-mcp-bridge] ${msg}`);
}

const godot = new GodotWs();

const mcp = new Server(
  { name: "godot-mcp-bridge", version: "0.1.0" },
  { capabilities: { tools: {} } },
);

mcp.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: ALLOWLIST.map((t) => ({
    name: t.name,
    description: t.description,
    inputSchema: {
      type: "object" as const,
      additionalProperties: true,
    },
  })),
}));

mcp.setRequestHandler(CallToolRequestSchema, async (request) => {
  const name = request.params.name;
  const args = (request.params.arguments ?? {}) as Record<string, unknown>;
  if (!ALLOWED_NAMES.has(name)) {
    return {
      isError: true,
      content: [{ type: "text" as const, text: `Tool not allowlisted: ${name}` }],
    };
  }
  try {
    assertScriptPath(name, args);
    const result = await godot.call(name, args);
    return {
      content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return {
      isError: true,
      content: [{ type: "text" as const, text: message }],
    };
  }
});

Bun.serve({
  port: PORT,
  fetch(req, server) {
    const ok = server.upgrade(req);
    if (ok) {
      return undefined;
    }
    return new Response("godot-mcp-bridge: wait for Godot plugin on this port\n", {
      headers: { "content-type": "text/plain" },
    });
  },
  websocket: {
    open(ws) {
      godot.attach(ws);
    },
    message(ws, message) {
      const text = typeof message === "string" ? message : new TextDecoder().decode(message);
      godot.handleMessage(text);
    },
    close(ws) {
      godot.detach(ws);
    },
  },
});

log(`listening ws://127.0.0.1:${PORT} (Godot plugin connects here)`);

const transport = new StdioServerTransport();
await mcp.connect(transport);
log("MCP stdio ready");
