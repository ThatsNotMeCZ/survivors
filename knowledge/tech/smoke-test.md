# GPU smoke test

First gate before gameplay. **Passed** 2026-10-20: 20k dots, 1080p, WebGL, 60 fps.

## What it is

`SmokeScene` fills a `SpriteGPULayer` with `SMOKE_DOTS` (20_000) GPU-tweened dots at 1920×1080. HTML HUD reports fps / renderer / pass|fail.

Pass: **≥ 55 fps** after 3s warmup, renderer **webgl**.

## What it is not

Not the combat loop. Dots are not entities. Do not collide them, pool them as enemies, or drive them from `src/sim/`.

## If it fails

1. Confirm WebGL (HUD renderer). Canvas cannot run SpriteGPULayer.
2. Do not "fix" it by switching to N `this.add.sprite` calls.
3. Only then profile; the architecture is the test.

## Next after pass

Done. Default scene is the run. `/?smoke=1` keeps this GPU test. CPU loop slice: `bun run smoke:loop`.
