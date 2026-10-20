# Performance budget

Design the sim around these caps. Raising a cap is a conscious change to this file plus a smoke/profile.

Measured 2026-10-20: **20_000 SpriteGPULayer dots @ 1920×1080, 60 fps.** Renderer is not the bottleneck.

| Layer | Cap | How |
|---|---|---|
| Enemies (simulated) | 128 | CPU + spatial hash |
| Projectiles | 256 | pool, AABB, no physics |
| XP gems | 64 | pool |
| Elites / bosses | 2–8 | full sprites |
| VFX particles | ~8_000 | GPU only (arena spark layer 256; 20k measured headroom) |
| Target | 60 fps | 1080p |

Bottlenecks to assume (not the renderer):

- N² collision
- GC from allocating in `update`
- One Phaser object per fodder enemy
- Filters/blend-mode breaking batches
