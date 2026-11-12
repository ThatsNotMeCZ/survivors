import { timeoutFor } from "./allowlist";

type Pending = {
  resolve: (value: unknown) => void;
  reject: (err: Error) => void;
  timer: ReturnType<typeof setTimeout>;
};

type JsonRpc = {
  jsonrpc?: string;
  id?: string | number | null;
  method?: string;
  params?: Record<string, unknown>;
  result?: unknown;
  error?: { code?: number; message?: string; data?: unknown };
};

function log(msg: string): void {
  console.error(`[godot-mcp-bridge] ${msg}`);
}

export class GodotWs {
  private peer: { send: (data: string) => void } | null = null;
  private pending = new Map<string | number, Pending>();
  private nextId = 1;
  private authed = true;

  get connected(): boolean {
    return this.peer !== null;
  }

  attach(peer: { send: (data: string) => void }): void {
    this.peer = peer;
    this.authed = true;
    log("Godot plugin connected");
  }

  detach(peer: { send: (data: string) => void }): void {
    if (this.peer !== peer) {
      return;
    }
    this.peer = null;
    for (const [, p] of this.pending) {
      clearTimeout(p.timer);
      p.reject(new Error("Godot plugin disconnected"));
    }
    this.pending.clear();
    log("Godot plugin disconnected");
  }

  handleMessage(raw: string): void {
    let msg: JsonRpc;
    try {
      msg = JSON.parse(raw) as JsonRpc;
    } catch {
      log("non-JSON frame from Godot");
      return;
    }

    if (msg.method === "ping") {
      if (msg.id == null) {
        this.send({ jsonrpc: "2.0", method: "pong", params: {} });
      } else {
        this.send({ jsonrpc: "2.0", id: msg.id, result: { pong: true } });
      }
      return;
    }

    if (msg.method === "pong") {
      return;
    }

    if (msg.method === "auth_required") {
      this.authed = false;
      void this.authenticate();
      return;
    }

    if (msg.id != null && this.pending.has(msg.id)) {
      const p = this.pending.get(msg.id)!;
      this.pending.delete(msg.id);
      clearTimeout(p.timer);
      if (msg.error) {
        p.reject(new Error(msg.error.message ?? JSON.stringify(msg.error)));
      } else {
        p.resolve(msg.result ?? {});
      }
    }
  }

  async call(method: string, params: Record<string, unknown>): Promise<unknown> {
    if (!this.peer) {
      throw new Error(
        "Godot is not connected. Open the Godot editor, enable plugin Godot MCP Pro, keep it running.",
      );
    }
    const id = this.nextId++;
    const timeoutMs = timeoutFor(method);
    const payload = { jsonrpc: "2.0", id, method, params };
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Godot RPC timeout (${timeoutMs}ms): ${method}`));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer });
      this.send(payload);
    });
  }

  private send(obj: unknown): void {
    if (!this.peer) {
      return;
    }
    this.peer.send(JSON.stringify(obj));
  }

  private async authenticate(): Promise<void> {
    const token = process.env.GODOT_MCP_TOKEN ?? (await readGodotToken());
    if (!token) {
      log("auth_required but no GODOT_MCP_TOKEN / user://mcp_auth_token");
      return;
    }
    try {
      await this.call("auth", { token });
      this.authed = true;
      log("authenticated");
    } catch (err) {
      log(`auth failed: ${err instanceof Error ? err.message : String(err)}`);
    }
  }
}

async function readGodotToken(): Promise<string> {
  const home = process.env.HOME;
  if (!home) {
    return "";
  }
  const root = `${home}/Library/Application Support/Godot/app_userdata`;
  const glob = new Bun.Glob("*/mcp_auth_token");
  let newest = "";
  let newestMtime = 0;
  for await (const match of glob.scan({ cwd: root, onlyFiles: true })) {
    const full = `${root}/${match}`;
    const st = await Bun.file(full).stat();
    if (st.mtimeMs > newestMtime) {
      newestMtime = st.mtimeMs;
      newest = full;
    }
  }
  if (!newest) {
    return "";
  }
  return (await Bun.file(newest).text()).trim();
}
