# Knowledge base

Canonical notes for humans and agents. Update these when a design decision lands. Do not keep lore only in chat.

## Design

| File | What it answers |
|---|---|
| [design/concept.md](design/concept.md) | What the game is |
| [design/anti-idle.md](design/anti-idle.md) | Why VS goes idle and how we don't |
| [design/gameloop.md](design/gameloop.md) | One run, two-stage slice |
| [design/style.md](design/style.md) | Art and readability |
| [design/combat.md](design/combat.md) | Aimed primary (locked A) |
| [design/open-questions.md](design/open-questions.md) | Settled decisions |

## Tech

| File | What it answers |
|---|---|
| [tech/stack.md](tech/stack.md) | Why Phaser 4 |
| [tech/performance-budget.md](tech/performance-budget.md) | Entity caps |
| [tech/smoke-test.md](tech/smoke-test.md) | What "pass" means |
| [tech/catalog.md](tech/catalog.md) | Items, skills, entities JSON |
| [tech/sprites.md](tech/sprites.md) | Drop-in spritesheets, icons, env later |
| [tech/audio.md](tech/audio.md) | Playlists, SFX, pause overlay |

## Phaser

Official skills ship with the package: `node_modules/phaser/skills/`.
Do not vendor copies. Read them when touching renderer, input, or scenes.
