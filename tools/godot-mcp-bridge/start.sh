#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
if [[ ! -e node_modules/@modelcontextprotocol/sdk/package.json ]]; then
  bun install
fi

PORT="${GODOT_MCP_PORT:-6505}"
# Cursor restarts MCP by closing stdio; Bun.serve can keep the old process on this port.
free_leftover() {
  local pid cmd
  pid="$(lsof -t -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -n1 || true)"
  [[ -z "$pid" ]] && return 0
  cmd="$(ps -p "$pid" -o args= 2>/dev/null || true)"
  if [[ "$cmd" == *"src/index.ts"* ]]; then
    echo "[godot-mcp-bridge] killing leftover pid $pid on $PORT" >&2
    kill "$pid" 2>/dev/null || true
    sleep 0.2
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  else
    echo "[godot-mcp-bridge] port $PORT busy by pid $pid ($cmd)" >&2
    exit 1
  fi
}
free_leftover

exec bun src/index.ts
