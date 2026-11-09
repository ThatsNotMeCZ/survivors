import { FX_GEM } from '../config';
import type { World } from './world';
import { emitFx } from './fx';
import { grantXp } from './level';

export const MAX_LORE_DROPS = 8;

export type GemPool = {
  cap: number;
  alive: Uint8Array;
  x: Float32Array;
  y: Float32Array;
  xp: Float32Array;
};

export type LorePool = {
  cap: number;
  alive: Uint8Array;
  x: Float32Array;
  y: Float32Array;
  entityId: (string | null)[];
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

export function createLorePool(cap = MAX_LORE_DROPS): LorePool {
  return {
    cap,
    alive: new Uint8Array(cap),
    x: new Float32Array(cap),
    y: new Float32Array(cap),
    entityId: new Array<string | null>(cap).fill(null),
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

export function hasActiveLoreDrop(pool: LorePool, entityId: string): boolean {
  for (let i = 0; i < pool.cap; i += 1) {
    if (pool.alive[i] !== 0 && pool.entityId[i] === entityId) return true;
  }
  return false;
}

export function spawnLoreDrop(pool: LorePool, x: number, y: number, entityId: string): boolean {
  if (hasActiveLoreDrop(pool, entityId)) return false;
  for (let i = 0; i < pool.cap; i += 1) {
    if (pool.alive[i] !== 0) continue;
    pool.alive[i] = 1;
    pool.x[i] = x;
    pool.y[i] = y;
    pool.entityId[i] = entityId;
    return true;
  }
  return false;
}

export function clearGems(pool: GemPool): void {
  pool.alive.fill(0);
}

export function clearLores(pool: LorePool): void {
  pool.alive.fill(0);
  pool.entityId.fill(null);
}

export function stepGems(world: World, dt: number): void {
  const { gems, player } = world;
  const { gemPickup, gemMagnet, gemMagnetBonus = 88, gemMagnetSpeed } = world.catalog.loop;
  const pickup = gemPickup * world.stats.pickupRadiusMul;
  const baseMagnet = world.stats.pickupRadiusMul > 1 ? gemMagnetBonus : gemMagnet;
  const magnet = baseMagnet * world.stats.pickupRadiusMul;
  const magnetSpeed = gemMagnetSpeed * Math.max(1, world.stats.pickupRadiusMul);
  for (let i = 0; i < gems.cap; i += 1) {
    if (gems.alive[i] === 0) continue;
    const dx = player.x - gems.x[i];
    const dy = player.y - gems.y[i];
    const dist = Math.hypot(dx, dy);
    if (dist <= pickup) {
      gems.alive[i] = 0;
      world.gemsCollected += 1;
      emitFx(world.fx, FX_GEM, gems.x[i], gems.y[i], 0x88ddff);
      grantXp(world, gems.xp[i] * world.stats.xpMul);
      continue;
    }
    if (dist < magnet && dist > 0.001) {
      const step = (magnetSpeed * dt) / dist;
      gems.x[i] += dx * step;
      gems.y[i] += dy * step;
    }
  }
}

export function stepLores(world: World, dt: number): void {
  const { lores, player } = world;
  const { gemPickup, gemMagnet, gemMagnetBonus = 88, gemMagnetSpeed } = world.catalog.loop;
  const pickup = gemPickup * world.stats.pickupRadiusMul;
  const baseMagnet = world.stats.pickupRadiusMul > 1 ? gemMagnetBonus : gemMagnet;
  const magnet = baseMagnet * world.stats.pickupRadiusMul;
  const magnetSpeed = gemMagnetSpeed * Math.max(1, world.stats.pickupRadiusMul);
  for (let i = 0; i < lores.cap; i += 1) {
    if (lores.alive[i] === 0) continue;
    const dx = player.x - lores.x[i];
    const dy = player.y - lores.y[i];
    const dist = Math.hypot(dx, dy);
    if (dist <= pickup) {
      const entityId = lores.entityId[i];
      lores.alive[i] = 0;
      lores.entityId[i] = null;
      emitFx(world.fx, FX_GEM, lores.x[i], lores.y[i], 0xffd35a);
      if (entityId && !world.collectedLores.has(entityId)) {
        world.collectedLores.add(entityId);
        world.newlyCollectedLores.push(entityId);
      }
      continue;
    }
    if (dist < magnet && dist > 0.001) {
      const step = (magnetSpeed * dt) / dist;
      lores.x[i] += dx * step;
      lores.y[i] += dy * step;
    }
  }
}
