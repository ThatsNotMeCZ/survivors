# Stack

**Phaser 4.2 + TypeScript + Vite + Bun.** Agent-first, 60 fps within the performance budget.

Package manager is Bun (`bun.lock`). Never npm.

| Option | Why not (now) |
|---|---|
| Phaser 3 + Arcade | Physics bodies die around a few hundred |
| Bare Pixi v8 | Agent would invent camera/input/scenes |
| Godot 4 | Better native ceiling; slower Cursor loop. Revisit for Steam if web fails. |
| Bevy | Best ECS, compile loop kills vibe |

Desktop later: wrap the same web build in Tauri. Do not rewrite.

## Why this wins for agents

The whole game is text. HMR in ~1s. Phaser 4 skills live in `node_modules/phaser/skills/`.
