# Performance budget

Design the sim around these caps. Raising a cap is a conscious change to this file plus `loop.json` / `world.json` / `obstacles.json` plus a smoke/profile.

Measured 2026-10-20: **20_000 SpriteGPULayer dots @ 1920×1080, 60 fps.** Renderer is not the bottleneck.

Live pools (2026-11):

| Layer | Cap | How |
|---|---|---|
| Fodder | 24 | `loop.maxFodder`, CPU + spatial hash |
| Elites | 6 (1 before teleporter) | `loop.maxElites`; full sprites |
| Boss | 1 | full sprite + `boss-hazards` pool 24 |
| Enemies (total simulated) | 31 | `maxFodder + maxElites + 1` |
| Projectiles | 128 | `world.maxProjectiles`, AABB, no physics |
| XP gems | 999 | GPU layer; magnetized pickup |
| Lore drops | 8 | CPU pool, one live per entity id |
| Obstacles | 39 | 14 pillars + 8 hazards + 9 volatiles + 8 dynamic acid pools |
| VFX particles | ~8_000 | GPU only (arena spark layer 256; 20k measured headroom) |
| Target | 60 fps | 1080p |

Bottlenecks to assume (not the renderer):

- N² collision
- GC from allocating in `update`
- One Phaser object per fodder enemy
- Filters/blend-mode breaking batches
