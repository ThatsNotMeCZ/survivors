import type { World } from './world';
import { grantXp } from './level';

export type GemPool = {
  cap: number;
  alive: Uint8Array;
  x: Float32Array;
  y: Float32Array;
  xp: Float32Array;
};

export function createGemPool(cap: number): GemPool {
  return {
    cap,
    alive: new Uint8Array(cap),
    x: new Float32Array(cap),
    y: new Float32Array(cap),
    xp: new Float32Array(cap),
  };
}

export function spawnGem(pool: GemPool, x: number, y: number, xp: number): boolean {
  for (let i = 0; i < pool.cap; i += 1) {
    if (pool.alive[i] !== 0) continue;
    pool.alive[i] = 1;
    pool.x[i] = x;
    pool.y[i] = y;
    pool.xp[i] = xp;
    return true;
  }
  return false;
}

export function clearGems(pool: GemPool): void {
  pool.alive.fill(0);
}

export function stepGems(world: World, dt: number): void {
  const { gems, player } = world;
  const { gemPickup, gemMagnet, gemMagnetSpeed } = world.catalog.loop;
  for (let i = 0; i < gems.cap; i += 1) {
    if (gems.alive[i] === 0) continue;
    const dx = player.x - gems.x[i];
    const dy = player.y - gems.y[i];
    const dist = Math.hypot(dx, dy);
    if (dist <= gemPickup) {
      gems.alive[i] = 0;
      grantXp(world, gems.xp[i]);
      continue;
    }
    if (dist < gemMagnet && dist > 0.001) {
      const step = (gemMagnetSpeed * dt) / dist;
      gems.x[i] += dx * step;
      gems.y[i] += dy * step;
    }
  }
}
