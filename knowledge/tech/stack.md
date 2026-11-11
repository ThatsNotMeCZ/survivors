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

## WebGL gate

Gameplay is WebGL-only (`Phaser.WEBGL` + `SpriteGPULayer`). There is no Canvas fallback.

`src/ui/webgl-gate.ts` probes before Phaser boots: context with `failIfMajorPerformanceCaveat`, then `ANGLE_instanced_arrays` and `OES_vertex_array_object`. Fail → HTML overlay card (`showWebglBlocker`), Phaser never starts. Same card on `losewebgl` mid-run. Reload only; do not offer "play anyway". Force the card with `/?nowebgl=1`.

## Why this wins for agents

The whole game is text. HMR in ~1s. Phaser 4 skills live in `node_modules/phaser/skills/`.
