#!/usr/bin/env python3
"""Crop shipped ui/atlas.png from tools/pixelorama/export/gui_agent.png."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools/pixelorama/export/gui_agent.png"
DESTS = [
    ROOT / "web/public/sprites/ui/atlas.png",
    ROOT / "Godot/hermetic-rifts/assets/sprites/ui/atlas.png",
]
JSON_PATHS = [
    ROOT / "web/public/sprites/ui/atlas.json",
    ROOT / "Godot/hermetic-rifts/assets/sprites/ui/atlas.json",
]


def atlas_extent(json_paths: list[Path]) -> tuple[int, int]:
    for p in json_paths:
        if not p.is_file():
            continue
        frames = json.loads(p.read_text())["frames"]
        mx = my = 0
        for entry in frames.values():
            mx = max(mx, int(entry["x"]) + int(entry["w"]))
            my = max(my, int(entry["y"]) + int(entry["h"]))
        return mx, my
    return 1173, 1740


def main() -> int:
    if not SRC.is_file():
        print(f"missing {SRC} — export gui_agent.pxo first", file=sys.stderr)
        return 1
    W, H = atlas_extent(JSON_PATHS)
    from PIL import Image

    sheet = Image.open(SRC).convert("RGBA")
    if sheet.width < W or sheet.height < H:
        print(f"{SRC} {sheet.size} smaller than atlas extent {W}x{H}", file=sys.stderr)
        return 1
    atlas = sheet.crop((0, 0, W, H))
    for dest in DESTS:
        dest.parent.mkdir(parents=True, exist_ok=True)
        atlas.save(dest)
        print(f"wrote {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())