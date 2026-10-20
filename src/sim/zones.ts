import { FX_HIT, FX_STRIKE } from '../config';
import { circlesOverlap } from './collision';
import { ROLE_FODDER, startEnemyDeath } from './enemies';
import { emitFx } from './fx';
import { applyEnemySlow } from './status';
import type { World } from './world';

export const ZONE_LINE = 0;
export const ZONE_STRIKE = 1;

export type DecoyState = {
  active: boolean;
  x: number;
  y: number;
  remain: number;
};

export type ZonePool = {
  cap: number;
  alive: Uint8Array;
  kind: Uint8Array;
  x: Float32Array;
  y: Float32Array;
  dirX: Float32Array;
  dirY: Float32Array;
  length: Float32Array;
  width: Float32Array;
  radius: Float32Array;
  remain: Float32Array;
  damage: Float32Array;
  slowMul: Float32Array;
  fodderOnly: Uint8Array;
};

export function createZonePool(cap = 8): ZonePool {
  return {
    cap,
    alive: new Uint8Array(cap),
    kind: new Uint8Array(cap),
    x: new Float32Array(cap),
    y: new Float32Array(cap),
    dirX: new Float32Array(cap),
    dirY: new Float32Array(cap),
    length: new Float32Array(cap),
    width: new Float32Array(cap),
    radius: new Float32Array(cap),
    remain: new Float32Array(cap),
    damage: new Float32Array(cap),
    slowMul: new Float32Array(cap),
    fodderOnly: new Uint8Array(cap),
  };
}

export function emptyDecoy(): DecoyState {
  return { active: false, x: 0, y: 0, remain: 0 };
}

export function spawnDecoy(decoy: DecoyState, x: number, y: number, duration: number): void {
  if (duration <= 0) return;
  decoy.active = true;
  decoy.x = x;
  decoy.y = y;
  decoy.remain = duration;
}

export function spawnSlowLine(
  pool: ZonePool,
  spec: {
    x: number;
    y: number;
    dirX: number;
    dirY: number;
    length: number;
    width: number;
    duration: number;
    slowMul: number;
    damage: number;
    fodderOnly: boolean;
  },
): boolean {
  const slot = freeZone(pool);
  if (slot < 0) return false;
  pool.alive[slot] = 1;
  pool.kind[slot] = ZONE_LINE;
  pool.x[slot] = spec.x;
  pool.y[slot] = spec.y;
  pool.dirX[slot] = spec.dirX;
  pool.dirY[slot] = spec.dirY;
  pool.length[slot] = spec.length;
  pool.width[slot] = spec.width;
  pool.radius[slot] = 0;
  pool.remain[slot] = spec.duration;
  pool.damage[slot] = spec.damage;
  pool.slowMul[slot] = spec.slowMul;
  pool.fodderOnly[slot] = spec.fodderOnly ? 1 : 0;
  return true;
}

export function spawnDelayedStrike(
  pool: ZonePool,
  spec: { x: number; y: number; radius: number; delay: number; damage: number },
): boolean {
  const slot = freeZone(pool);
  if (slot < 0) return false;
  pool.alive[slot] = 1;
  pool.kind[slot] = ZONE_STRIKE;
  pool.x[slot] = spec.x;
  pool.y[slot] = spec.y;
  pool.dirX[slot] = 0;
  pool.dirY[slot] = 0;
  pool.length[slot] = 0;
  pool.width[slot] = 0;
  pool.radius[slot] = spec.radius;
  pool.remain[slot] = spec.delay;
  pool.damage[slot] = spec.damage;
  pool.slowMul[slot] = 1;
  pool.fodderOnly[slot] = 0;
  return true;
}

export function clearZones(pool: ZonePool): void {
  pool.alive.fill(0);
}

export function stepZones(world: World, dt: number): void {
  const { zones, decoy } = world;
  if (decoy.active) {
    decoy.remain -= dt;
    if (decoy.remain <= 0) {
      decoy.active = false;
      decoy.remain = 0;
    }
  }
  for (let i = 0; i < zones.cap; i += 1) {
    if (zones.alive[i] === 0) continue;
    zones.remain[i] -= dt;
    if (zones.kind[i] === ZONE_LINE) {
      tickSlowLine(world, i, dt);
      if (zones.remain[i] <= 0) zones.alive[i] = 0;
      continue;
    }
    if (zones.remain[i] <= 0) {
      detonateStrike(world, i);
      zones.alive[i] = 0;
    }
  }
}

function tickSlowLine(world: World, index: number, dt: number): void {
  const { zones, enemies } = world;
  const half = zones.length[index] * 0.5;
  const width = zones.width[index] * 0.5;
  const fodderOnly = zones.fodderOnly[index] !== 0;
  const dps = zones.damage[index];
  for (let e = 0; e < enemies.cap; e += 1) {
    if (enemies.alive[e] === 0) continue;
    if (fodderOnly && enemies.role[e] !== ROLE_FODDER) continue;
    if (!onLine(zones, index, enemies.x[e], enemies.y[e], enemies.radius[e] + width, half)) continue;
    applyEnemySlow(enemies, e, zones.slowMul[index], 0.2);
    if (dps > 0) {
      enemies.hp[e] -= dps * dt;
      if (enemies.hp[e] <= 0) startEnemyDeath(world, e);
    }
  }
}

function detonateStrike(world: World, index: number): void {
  const { zones, enemies } = world;
  const x = zones.x[index];
  const y = zones.y[index];
  const radius = zones.radius[index];
  const damage = zones.damage[index];
  emitFx(world.fx, FX_STRIKE, x, y, 0xffc070);
  for (let e = 0; e < enemies.cap; e += 1) {
    if (enemies.alive[e] === 0) continue;
    if (!circlesOverlap(x, y, radius, enemies.x[e], enemies.y[e], enemies.radius[e])) continue;
    emitFx(world.fx, FX_HIT, enemies.x[e], enemies.y[e], 0xfff4c8);
    enemies.hp[e] -= damage;
    if (enemies.hp[e] <= 0) startEnemyDeath(world, e);
  }
}

function onLine(
  zones: ZonePool,
  index: number,
  x: number,
  y: number,
  reach: number,
  half: number,
): boolean {
  const dx = x - zones.x[index];
  const dy = y - zones.y[index];
  const along = dx * zones.dirX[index] + dy * zones.dirY[index];
  if (along < -half || along > half) return false;
  const px = dx - along * zones.dirX[index];
  const py = dy - along * zones.dirY[index];
  return px * px + py * py <= reach * reach;
}

function freeZone(pool: ZonePool): number {
  for (let i = 0; i < pool.cap; i += 1) {
    if (pool.alive[i] === 0) return i;
  }
  return -1;
}
