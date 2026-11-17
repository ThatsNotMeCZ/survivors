#!/usr/bin/env bash
set -euo pipefail
BRIDGE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$BRIDGE/../.." && pwd)"
SERVER="$REPO/tools/pixelorama-mcp/mcp-server"
HEALTH_URL="http://127.0.0.1:7373/health"

if [[ ! -f "$SERVER/package.json" ]]; then
  echo "[pixelorama-mcp] missing submodule at tools/pixelorama-mcp" >&2
  echo "[pixelorama-mcp] run: git submodule update --init tools/pixelorama-mcp" >&2
  exit 1
fi

cd "$SERVER"

if [[ ! -e node_modules/@modelcontextprotocol/sdk/package.json ]]; then
  if [[ -f package-lock.json ]]; then
    npm ci
  else
    npm install
  fi
fi

if [[ ! -f dist/index.js ]]; then
  npm run build
fi

# Always pin from the repo root. mcp.json documents the same dirs; workspace paths contain a space.
export PIXELORAMA_MCP_ALLOWED_DIRS="$REPO/tools/pixelorama,$REPO/web/public/sprites,$REPO/Godot/hermetic-rifts/assets/sprites"

if ! curl -sf --max-time 1 "$HEALTH_URL" >/dev/null 2>&1; then
  echo "[pixelorama-mcp] Pixelorama bridge not reachable at $HEALTH_URL" >&2
  echo "[pixelorama-mcp] Enable PixMcpBridge.pck (Edit → Preferences → Extensions), restart Pixelorama, then curl $HEALTH_URL" >&2
  echo "[pixelorama-mcp] Checklist: knowledge/tech/pixelorama-mcp.md" >&2
fi

exec node --max-old-space-size=4096 dist/index.js
