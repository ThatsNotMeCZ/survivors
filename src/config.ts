export const GAME_WIDTH = 1920;
export const GAME_HEIGHT = 1080;

/** GPU quads in the smoke test. Measured: 20k @ 1080p holds 60 fps. */
export const SMOKE_DOTS = 20_000;

/** Pass bar after warmup. Below this, the GPU path is not trusted. */
export const SMOKE_PASS_FPS = 55;

export const SMOKE_WARMUP_MS = 3000;

/** Pooled GPU spark members in the arena. */
export const SPARK_CAP = 256;

/** Sim FX events emitted per frame (view consumes, then sim clears). */
export const FX_CAP = 64;

export const FX_HIT = 0;
export const FX_DEATH = 1;
export const FX_MUZZLE = 2;
export const FX_DASH = 3;
