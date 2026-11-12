# Future platforms

The live slice is solo Phaser on itch. Co-op, Steam Workshop, touch, and extra languages wait for a later change that names that work. Code that ships now must not block the contracts below.

Anti-idle ([anti-idle.md](anti-idle.md)) still wins: no auto-aim on primary for touch or a second player.

Client split: [tech/clients.md](../tech/clients.md). Godot build rules: [tech/godot.md](../tech/godot.md).

## Localization (Godot from day one)

Godot player-facing copy goes through `locale/*.csv`. GDScript calls `tr("KEY")` (or `TranslationServer.translate`). Literal English in UI or sim is a bug.

CSV header: `keys,en`. Add columns (`cs`, …) later. Key shapes:

| Domain | Key |
|---|---|
| Chrome (pause, HUD, menus) | `ui.pause.title`, `ui.hall.commence` |
| Items | `item.{id}.name`, `item.{id}.lore` |
| Entities | `entity.{id}.title`, `entity.{id}.lore` |
| Survivors | `survivor.{id}.name`, `survivor.{id}.title`, `survivor.{id}.lore` |
| Skills | `skill.{id}.name`, `skill.{id}.lore` |

Generate the first `en` column from today's catalog JSON `name`/`lore`/`title` plus current HUD copy. Phaser keeps reading those JSON fields in English. Web does not get an i18n pass in this slice.

## Input

Gameplay reads **actions**, not scancodes. Canonical actions:

`move`, `aim`, `fire_primary`, `fire_secondary`, `utility`, `special`, `pause`, `confirm`, `back`

`move` and `aim` are vectors. Keyboard/mouse and a gamepad right stick both fill `aim`. Default keyboard/mouse binds stay the table in [combat.md](combat.md). Phaser may keep WASD + mouse. Godot maps devices → those actions from the first playable scene.

Rebind UI and prompt-glyph swap wait. The action names do not.

## Online co-op (post-v1)

Shape is locked: **2–4 players, one world, host authority**. Not local split-screen. Not lockstep.

| Rule | Do now | Do not |
|---|---|---|
| Identity | `PlayerId` 0..3; vessels in an array | `Game.Player` singleton |
| Tick | `tick(state, frames, dt)` with `frames: Array[InputFrame]` | `Input.*` or node queries inside sim |
| Net | Host runs sim; clients send input; host sends state | `MultiplayerSynchronizer` on entities |
| Director | Threat vs all living players | Spawn-at-the-one-player |
| Pickups | Magnet per player | One shared vacuum |
| RNG | Sim-owned RNG | `randi()` in view |
| Camera / HUD | Per local player, outside sim | Sim that knows a Camera2D |

Level-up pause is **open**. RoR2 pauses everyone for a draft. Web today pauses the solo run. Leave the web overlay as-is. Godot should not hard-wire "the" paused player into sim state.

v1 is solo. An `Array[InputFrame]` of length 1 is enough. The array is the contract.

## Steam Workshop (post-v1)

`IModSource`: local folder first, Steam later. Game scripts stay in the shipped binary.

Allowed in a pack: JSON catalog patches, sprites, `locale` CSV, audio, plus `mod.json` with `schemaVersion`. Reject `.gd`, `.cs`, `.dll`, and `.so` from Workshop. Validate patches against the same schema as `web/src/data/`.

Do not add a Steamworks dependency until a Steam build exists.

## Controller

Godot reads the action map from day one (see Input). Full rebind, rumble, and last-device glyphs wait. itch "Mobile friendly" stays off ([itch-io-release-plan.md](../itch-io-release-plan.md)).

## Mobile (post-Steam)

Not v1. Godot UI uses `Control` anchors and `DisplayServer.GetDisplaySafeArea()`. Touch is another InputMap device (virtual stick + aim). Verb A stays player-aimed. Do not fall back to auto-fire to "make phones work".

Do not schedule a mobile store page from this file.
