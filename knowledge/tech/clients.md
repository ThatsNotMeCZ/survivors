# Clients

Two clients share one design. **Phaser in `web/`** ships itch.io HTML5. **Godot 4.7 typed GDScript in `Godot/`** is the native Steam/desktop sibling. Do not rewrite the web client in Godot. Godot web export is possible; itch is not that build.

Numbers live in `web/src/data/*.json`. Godot deserializes that schema (or a byte-identical copy). A second balance sheet is a fork.

Anti-idle ([design/anti-idle.md](../design/anti-idle.md)) binds both clients. Locked verb A stays aimed primary. Do not add auto-aim for touch or co-op.

Product constraints that wait (online co-op, Workshop, controller glyphs, mobile) live in [design/future.md](../design/future.md). Godot engineering rules live in [godot.md](godot.md).

## Parallel work

| Track | May change | Must not |
|---|---|---|
| Web | JSON balance, bugfixes, sprites/audio, itch changelog, English UI copy in `web/src/ui/` | A second catalog, a new combat verb, an i18n rewrite, Godot-only systems, a design fork kept only in chat |
| Godot | GDScript sim, MCP-authored `.tscn`, `locale/*.csv`, input actions, native window/export | Different item/enemy/director numbers than `web/src/data/*.json`, hardcoded player-facing strings, text patches of `.tscn`, C# |

A design change (combat, director, item hook, loop beat) updates the matching `knowledge/` file in the same change, then both clients. Web can ship the number first. Godot follows the same JSON.

## Ownership

| Concern | Canon |
|---|---|
| Design, anti-idle, loop, combat | `knowledge/design/` |
| Balance, ids, skill effect shapes | `web/src/data/*.json` + `schema.ts` |
| Web HUD/menus | HTML/CSS in `web/src/ui/` |
| Godot HUD/menus | Control scenes via MCP + loc keys |
| Web display names | JSON `name` / `lore` / `title` (English) |
| Godot display names | `locale/*.csv` via `tr("KEY")` |
| Sprites | `web/public/sprites/` until Godot imports a copy; do not author a second sheet set |
| itch.io demo | Phaser only ([itch-io-release-plan.md](../itch-io-release-plan.md)) |

## Web ship window

itch stays the live demo. Small updates are catalog numbers, copy, art, audio, and bugfixes. Do not block those on Godot scaffolding, localization, or netcode.
