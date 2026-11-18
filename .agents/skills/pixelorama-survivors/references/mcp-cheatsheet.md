# Pixelorama MCP cheatsheet (Survivors)

Namespace `pixelorama-mcp`. Inspect schema before calling. Palette swatches: `get_palette_colors` or [`tools/pixelorama/resurrect-64.pal`](../../../../tools/pixelorama/resurrect-64.pal) — do not paste all 64 hex here.

## Task → tool

| Task | Tool |
|---|---|
| Open existing art | `open_project` (absolute `.pxo` path) |
| Study sibling style | `capture_canvas_image` + small `get_region` on a completed sibling |
| First look / after tag change | `describe_canvas` once |
| Later dimensions / active frame | `get_canvas_info` |
| Active palette | `list_palettes` → `switch_palette` `name` Resurrect 64 |
| Read pixels in bbox | `get_region` (tight rect only) |
| Write pixels | `draw_pixels_fast` stride 3 `[x, y, '#hex', ...]` |
| Clone frame for anim | `copy_cel` then patch delta |
| QA holes / orphans / bbox | `validate_sprite` |
| Color histogram | `get_palette_usage` |
| Visual check & gate | `capture_canvas_image` crop + `scale` 4–8 (1–2 edits, up to 3–4 new art); reject & fix if flat or off-style |
| Stage PNG | `export_image` → `tools/pixelorama/export/{id}.png` |
| Ship | shell `./tools/pixelorama/publish-sprite.sh <kind> <id>` |

`draw_pixels` (object array) only when a handful of pixels need named blend. Prefer `draw_pixels_fast`. Safe batch ~300k elements (~100k pixels). Split larger passes.

## Do not

| Tool / action | Why |
|---|---|
| `fill_area`, large `draw_rect` on bodies | Flatten noise into single-color blocks |
| `remap_to_palette` on finished entities | Global quantize kills authored noise |
| `color_replace` of a fill color | Wipes shade variation |
| `clean_isolated_pixels` | Treats noise as orphans |
| `generate_sprite` without `get_region` | Invents flat fills, ignores existing art |
| `apply_gradient` on creature shapes | Smooth ramps, not palette clusters |
| Full-frame `get_region` / extra `describe_canvas` | Burns tokens |
| `capture_canvas_image` every stroke | Image payloads dominate context |
| File `Write` of PNG | Bypass Pixelorama; forbidden |
| Hex outside Resurrect 64 + `#000000` | Includes legacy `#120a0d` |

## Allowed flatten (narrow)

- `eval_gdscript` procedural tiles in `world.pxo` only.
- Inner stretchable 9-slice content well of a UI panel in `gui*.pxo` (frames, corners, dividers, and icons must still be multi-tone shaded).
- Tiny 1–3 px solids: pupils, 1px outline `#000000`, UI dots.
