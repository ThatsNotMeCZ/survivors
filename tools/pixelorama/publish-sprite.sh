#!/usr/bin/env bash
# Copy a staged Pixelorama export into web/public/sprites and sync the Godot copy.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EXPORT_DIR="$ROOT/tools/pixelorama/export"
WEB_SPRITES="$ROOT/web/public/sprites"
CONVERTER="$ROOT/tools/pixelorama/pxo-tags-to-compact.mjs"

usage() {
  echo "usage: $0 <kind> <catalog-id>" >&2
  echo "  kind: entity | item | skill | fx | env-frame" >&2
  echo "  reads tools/pixelorama/export/<id>.png (+ optional .json)" >&2
  exit 1
}

KIND="${1:-}"
ID="${2:-}"
[[ -n "$KIND" && -n "$ID" ]] || usage

case "$KIND" in
  entity) DEST_DIR="$WEB_SPRITES/entities" ;;
  item) DEST_DIR="$WEB_SPRITES/items" ;;
  skill) DEST_DIR="$WEB_SPRITES/skills" ;;
  fx) DEST_DIR="$WEB_SPRITES/fx" ;;
  env-frame) DEST_DIR="$WEB_SPRITES/env" ;;
  *)
    echo "unknown kind '$KIND'" >&2
    usage
    ;;
esac

SRC_PNG="$EXPORT_DIR/${ID}.png"
SRC_JSON="$EXPORT_DIR/${ID}.json"
[[ -f "$SRC_PNG" ]] || {
  echo "missing $SRC_PNG" >&2
  exit 1
}

mkdir -p "$DEST_DIR"
cp "$SRC_PNG" "$DEST_DIR/${ID}.png"
echo "wrote $DEST_DIR/${ID}.png"

if [[ "$KIND" == "entity" && -f "$SRC_JSON" ]]; then
  node "$CONVERTER" "$SRC_JSON" "$DEST_DIR/${ID}.json"
  echo "wrote $DEST_DIR/${ID}.json"
fi

if [[ "$KIND" == "env-frame" ]]; then
  echo "env-frame is a standalone PNG. atlas.json is not updated — see tools/environment.md" >&2
fi

"$ROOT/tools/sync-godot-content"
