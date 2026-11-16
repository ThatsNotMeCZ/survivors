#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
if [[ ! -e node_modules/@modelcontextprotocol/sdk/package.json ]]; then
  bun install
fi
exec bun src/index.ts
