# survivors

2D survivor-like (VS pacing × RoR2 director). Live client is Phaser 4 in [`web/`](web/). Design notes: [`knowledge/README.md`](knowledge/README.md). Agent entry: [`AGENTS.md`](AGENTS.md).

```bash
cd web
bun install
bun run dev
```

Open `http://127.0.0.1:8080` — hall menu, then WASD, mouse aim, hold LMB, Shift Phase Step. Skip hall: `/?dev=1`. GPU smoke: `/?smoke=1`. Content: `web/src/data/*.json`. Art: drop PNGs into `web/public/sprites/` ([`knowledge/tech/sprites.md`](knowledge/tech/sprites.md)).
