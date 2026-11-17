# Clients

Two clients share one design. **Default implementation target is Godot.** **Phaser in `web/`** ships itch.io HTML5 and stays frozen unless a prompt names it. **Godot 4.7 typed GDScript in `Godot/hermetic-rifts/`** is the native Steam/desktop sibling and the client agents change. Do not rewrite the web client in Godot. Godot web export is possible; itch is not that build.

## Default target

Every implement / fix / change / playtest prompt applies to **Godot only**, unless the user writes **web**, **Phaser**, **itch**, or **both clients**.

| Prompt | Touch |
|---|---|
| Unspecified ("fix dash", "add item", "HUD is wrong") | `Godot/hermetic-rifts/` + matching `knowledge/` |
| Names web / Phaser / itch | `web/` (and knowledge if design changes) |
| Names both clients | Godot first, then Phaser; keep catalog schema aligned |

Godot catalog is `Godot/hermetic-rifts/data/catalog/*.json` (same schema as `web/src/data/*.json`). A Godot-default number change edits the Godot copy, not Phaser sim/view/UI. Do not invent a second schema. Syncing `web/src/data/*.json` waits until the user names web / both.

Anti-idle ([design/anti-idle.md](../design/anti-idle.md)) binds both clients. Locked verb A stays aimed primary. Do not add auto-aim for touch or co-op.

Product constraints that wait (online co-op, Workshop, controller glyphs, mobile) live in [design/future.md](../design/future.md). Godot engineering rules live in [godot.md](godot.md).

## Parallel work

| Track | May change | Must not |
|---|---|---|
| Godot (default) | GDScript sim, MCP-authored `.tscn`, `locale/*.csv`, input actions, native window/export, Godot catalog JSON | Hardcoded player-facing strings, text patches of `.tscn`, C#, Phaser files unless named |
| Web (opt-in) | JSON balance, bugfixes, sprites/audio, itch changelog, English UI copy in `web/src/ui/` | A second catalog schema, a new combat verb, an i18n rewrite, Godot-only systems, a design fork kept only in chat |

A design change (combat, director, item hook, loop beat) updates the matching `knowledge/` file in the same change, then the **named** client — Godot when unnamed.

## Ownership

| Concern | Canon |
|---|---|
| Design, anti-idle, loop, combat | `knowledge/design/` |
| Balance, ids, skill effect shapes (default) | `Godot/hermetic-rifts/data/catalog/*.json` |
| Balance schema on web (opt-in) | `web/src/data/*.json` + `schema.ts` |
| Web HUD/menus | HTML/CSS in `web/src/ui/` (opt-in) |
| Godot HUD/menus | Control scenes via MCP + loc keys |
| Web display names | JSON `name` / `lore` / `title` (English) |
| Godot display names | `locale/*.csv` via `tr("KEY")` |
| Sprites | `web/public/sprites/` until Godot imports a copy; do not author a second sheet set |
| itch.io demo | Phaser only ([itch-io-release-plan.md](../itch-io-release-plan.md)); agents touch it only when named |

## Web ship window

itch stays the live demo. Agents do not patch it unless the prompt names web / Phaser / itch. Small itch updates (when named) are catalog numbers, copy, art, audio, and bugfixes. Do not block those on Godot scaffolding, localization, or netcode.
