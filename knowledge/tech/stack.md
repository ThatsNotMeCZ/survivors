# Stack

Two clients, one design ([clients.md](clients.md)).

| Client | Stack | Ships |
|---|---|---|
| `web/` | Phaser 4.2.1 + TypeScript + Vite + Bun | itch.io HTML5 (live) |
| `Godot/` | Godot **4.7** + typed GDScript | Native desktop (Steam later). itch stays Phaser. |

Web package manager is Bun (`web/bun.lock`). Never npm. Godot rules: [godot.md](godot.md).

| Option | Why not (now) |
|---|---|
| Phaser 3 + Arcade | Physics bodies die around a few hundred |
| Bare Pixi v8 | Agent would invent camera/input/scenes |
| Godot C# / .NET | Typed GDScript is locked. Faster editor loop, matches engine skills. |
| Godot HTML5 as a second web ship | itch stays the Phaser client. |
| Wrap Phaser in Tauri | Desktop is the Godot client, not a web wrapper. |
| Bevy | Best ECS, compile loop kills vibe |

## WebGL gate

Gameplay is WebGL-only (`Phaser.WEBGL` + `SpriteGPULayer`). There is no Canvas fallback.

`web/src/ui/webgl-gate.ts` probes before Phaser boots: context with `failIfMajorPerformanceCaveat`, then `ANGLE_instanced_arrays` and `OES_vertex_array_object`. Fail → HTML overlay card (`showWebglBlocker`), Phaser never starts. Same card on `losewebgl` mid-run. Reload only; do not offer "play anyway". Force the card with `/?nowebgl=1`.

## Why this wins for agents

The web game is text. HMR in ~1s. Phaser 4 skills live in `web/node_modules/phaser/skills/`. Godot is typed GDScript + one boot scene. The Cursor loop is still slower than Phaser, which is why itch stays on Phaser.
