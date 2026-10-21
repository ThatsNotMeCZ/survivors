# survivors

Phaser 4 aimed-combat slice (obstacles + 32px hermetic pixel art) for a VS × RoR2 hybrid.

```bash
bun install
bun run dev
bun run art:comfy       # start ComfyUI on 127.0.0.1:8188
bun run art:download    # Pixel Art XL LoRA into ~/ComfyUI
bun run art:ref -- runner
bun run art:item -- glass-cannon
bun run art:generate    # character refs → public/sprites/_ref/ (512px); icons → public/sprites/
```

Open `http://127.0.0.1:8080` — hall menu, then WASD, mouse aim, hold LMB, Shift Phase Step. Skip hall: `/?dev=1`. GPU smoke: `/?smoke=1`. Content: `src/data/*.json`. Art pipeline: [`knowledge/tech/comfy.md`](knowledge/tech/comfy.md).

Design and engineering notes: [`knowledge/README.md`](knowledge/README.md). Agent entry: [`AGENTS.md`](AGENTS.md).
