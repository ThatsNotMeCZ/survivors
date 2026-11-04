import { FX_HURT, FX_STRIKE } from '../config';
import { circlesOverlap } from './collision';
import { pillarBlocksShot } from './enemies';
import { emitFx } from './fx';
import { applyRoot, applySlow } from './status';
import type { World } from './world';

export const HAZ_METEOR = 0;
export const HAZ_POOL = 1;
export const HAZ_PRISON = 2;
export const HAZ_CONE = 3;
export const HAZ_PULSE = 4;

export const STYLE_LAVA = 0;
export const STYLE_FROST = 1;
export const STYLE_AETHER = 2;

export const BOSS_HAZARD_CAP = 24;

export type BossHazardPool = {
  cap: number;
  alive: Uint8Array;
  kind: Uint8Array;
  style: Uint8Array;
  state: Uint8Array;
  x: Float32Array;
  y: Float32Array;
  dirX: Float32Array;
  dirY: Float32Array;
  radius: Float32Array;
  angle: Float32Array;
  elapsed: Float32Array;
  duration: Float32Array;
  damage: Float32Array;
  slowMul: Float32Array;
  slowDuration: Float32Array;
  rootDuration: Float32Array;
  poolDuration: Float32Array;
  poolRadius: Float32Array;
  poolDps: Float32Array;
  poolSlow: Float32Array;
};

export function createBossHazardPool(cap = BOSS_HAZARD_CAP): BossHazardPool {
  return {
    cap,
    alive: new Uint8Array(cap),
    kind: new Uint8Array(cap),
    style: new Uint8Array(cap),
    state: new Uint8Array(cap),
    x: new Float32Array(cap),
    y: new Float32Array(cap),
    dirX: new Float32Array(cap),
    dirY: new Float32Array(cap),
    radius: new Float32Array(cap),
    angle: new Float32Array(cap),
    elapsed: new Float32Array(cap),
    duration: new Float32Array(cap),
    damage: new Float32Array(cap),
    slowMul: new Float32Array(cap),
    slowDuration: new Float32Array(cap),
    rootDuration: new Float32Array(cap),
    poolDuration: new Float32Array(cap),
    poolRadius: new Float32Array(cap),
    poolDps: new Float32Array(cap),
    poolSlow: new Float32Array(cap),
  };
}

export function clearBossHazards(pool: BossHazardPool): void {
  pool.alive.fill(0);
}

function allocSlot(pool: BossHazardPool): number {
  for (let i = 0; i < pool.cap; i += 1) {
    if (pool.alive[i] === 0) return i;
  }
  return -1;
}

export function spawnBossMeteor(
  pool: BossHazardPool,
  spec: {
    x: number;
    y: number;
    radius: number;
    delay: number;
    damage: number;
    style: number;
    poolDuration?: number;
    poolRadius?: number;
    poolDps?: number;
    poolSlow?: number;
  },
): number {
  const s = allocSlot(pool);
  if (s < 0) return -1;
  pool.alive[s] = 1;
  pool.kind[s] = HAZ_METEOR;
  pool.style[s] = spec.style;
  pool.state[s] = 0;
  pool.x[s] = spec.x;
  pool.y[s] = spec.y;
  pool.dirX[s] = 1;
  pool.dirY[s] = 0;
  pool.radius[s] = spec.radius;
  pool.angle[s] = 0;
  pool.elapsed[s] = 0;
  pool.duration[s] = spec.delay;
  pool.damage[s] = spec.damage;
  pool.slowMul[s] = 1;
  pool.slowDuration[s] = 0;
  pool.rootDuration[s] = 0;
  pool.poolDuration[s] = spec.poolDuration ?? 0;
  pool.poolRadius[s] = spec.poolRadius ?? spec.radius;
  pool.poolDps[s] = spec.poolDps ?? 0;
  pool.poolSlow[s] = spec.poolSlow ?? 1;
  return s;
}

export function spawnBossPool(
  pool: BossHazardPool,
  spec: {
    x: number;
    y: number;
    radius: number;
    duration: number;
    dps: number;
    slowMul: number;
    style: number;
  },
): number {
  const s = allocSlot(pool);
  if (s < 0) return -1;
  pool.alive[s] = 1;
  pool.kind[s] = HAZ_POOL;
  pool.style[s] = spec.style;
  pool.state[s] = 0;
  pool.x[s] = spec.x;
  pool.y[s] = spec.y;
  pool.dirX[s] = 1;
  pool.dirY[s] = 0;
  pool.radius[s] = spec.radius;
  pool.angle[s] = 0;
  pool.elapsed[s] = 0;
  pool.duration[s] = spec.duration;
  pool.damage[s] = spec.dps;
  pool.slowMul[s] = spec.slowMul;
  pool.slowDuration[s] = 0.25;
  pool.rootDuration[s] = 0;
  pool.poolDuration[s] = 0;
  pool.poolRadius[s] = 0;
  pool.poolDps[s] = 0;
  pool.poolSlow[s] = 1;
  return s;
}

export function spawnBossPrison(
  pool: BossHazardPool,
  spec: {
    x: number;
    y: number;
    radius: number;
    delay: number;
    damage: number;
    rootDuration: number;
  },
): number {
  const s = allocSlot(pool);
  if (s < 0) return -1;
  pool.alive[s] = 1;
  pool.kind[s] = HAZ_PRISON;
  pool.style[s] = STYLE_FROST;
  pool.state[s] = 0;
  pool.x[s] = spec.x;
  pool.y[s] = spec.y;
  pool.dirX[s] = 1;
  pool.dirY[s] = 0;
  pool.radius[s] = spec.radius;
  pool.angle[s] = 0;
  pool.elapsed[s] = 0;
  pool.duration[s] = spec.delay;
  pool.damage[s] = spec.damage;
  pool.slowMul[s] = 1;
  pool.slowDuration[s] = 0;
  pool.rootDuration[s] = spec.rootDuration;
  pool.poolDuration[s] = 0;
  pool.poolRadius[s] = 0;
  pool.poolDps[s] = 0;
  pool.poolSlow[s] = 1;
  return s;
}

export function spawnBossCone(
  pool: BossHazardPool,
  spec: {
    x: number;
    y: number;
    dirX: number;
    dirY: number;
    range: number;
    angleRad: number;
    windup: number;
    lingering: number;
    damage: number;
    slowMul: number;
    slowDuration: number;
  },
): number {
  const s = allocSlot(pool);
  if (s < 0) return -1;
  pool.alive[s] = 1;
  pool.kind[s] = HAZ_CONE;
  pool.style[s] = STYLE_FROST;
  pool.state[s] = 0;
  pool.x[s] = spec.x;
  pool.y[s] = spec.y;
  pool.dirX[s] = spec.dirX;
  pool.dirY[s] = spec.dirY;
  pool.radius[s] = spec.range;
  pool.angle[s] = spec.angleRad;
  pool.elapsed[s] = 0;
  pool.duration[s] = spec.windup;
  pool.damage[s] = spec.damage;
  pool.slowMul[s] = spec.slowMul;
  pool.slowDuration[s] = spec.slowDuration;
  pool.rootDuration[s] = 0;
  pool.poolDuration[s] = spec.lingering;
  pool.poolRadius[s] = 0;
  pool.poolDps[s] = 0;
  pool.poolSlow[s] = 1;
  return s;
}

export function spawnBossPulse(
  pool: BossHazardPool,
  spec: {
    x: number;
    y: number;
    radius: number;
    windup: number;
    damage: number;
    slowMul: number;
    slowDuration: number;
  },
): number {
  const s = allocSlot(pool);
  if (s < 0) return -1;
  pool.alive[s] = 1;
  pool.kind[s] = HAZ_PULSE;
  pool.style[s] = STYLE_AETHER;
  pool.state[s] = 0;
  pool.x[s] = spec.x;
  pool.y[s] = spec.y;
  pool.dirX[s] = 1;
  pool.dirY[s] = 0;
  pool.radius[s] = spec.radius;
  pool.angle[s] = 0;
  pool.elapsed[s] = 0;
  pool.duration[s] = spec.windup;
  pool.damage[s] = spec.damage;
  pool.slowMul[s] = spec.slowMul;
  pool.slowDuration[s] = spec.slowDuration;
  pool.rootDuration[s] = 0;
  pool.poolDuration[s] = 0.45;
  pool.poolRadius[s] = 0;
  pool.poolDps[s] = 0;
  pool.poolSlow[s] = 1;
  return s;
}

export function stepBossHazards(world: World, dt: number): void {
  const { bossHazards: pool, player } = world;
  const bossDead = world.bossDefeated || (world.bossSpawned && world.counts.boss === 0);
  if (bossDead) {
    clearBossHazards(pool);
    return;
  }

  for (let i = 0; i < pool.cap; i += 1) {
    if (pool.alive[i] === 0) continue;
    pool.elapsed[i] += dt;
    const kind = pool.kind[i];

    if (kind === HAZ_METEOR) {
      if (pool.elapsed[i] >= pool.duration[i]) {
        const x = pool.x[i];
        const y = pool.y[i];
        const r = pool.radius[i];
        const tint = pool.style[i] === STYLE_LAVA ? 0xff7a3a : 0x7ad4ff;
        emitFx(world.fx, FX_STRIKE, x, y, tint);
        if (
          player.iframeRemain <= 0 &&
          circlesOverlap(x, y, r, player.x, player.y, player.radius)
        ) {
          emitFx(world.fx, FX_HURT, player.x, player.y, tint);
          player.hp -= pool.damage[i];
          world.damageTaken += pool.damage[i];
        }
        if (pool.poolDuration[i] > 0) {
          pool.kind[i] = HAZ_POOL;
          pool.state[i] = 0;
          pool.radius[i] = pool.poolRadius[i];
          pool.elapsed[i] = 0;
          pool.duration[i] = pool.poolDuration[i];
          pool.damage[i] = pool.poolDps[i];
          pool.slowMul[i] = pool.poolSlow[i];
        } else {
          pool.alive[i] = 0;
        }
      }
      continue;
    }

    if (kind === HAZ_POOL) {
      if (
        player.iframeRemain <= 0 &&
        player.dashRemain <= 0 &&
        circlesOverlap(pool.x[i], pool.y[i], pool.radius[i], player.x, player.y, player.radius)
      ) {
        const dmg = pool.damage[i] * dt;
        player.hp -= dmg;
        world.damageTaken += dmg;
        applySlow(player, pool.slowMul[i], 0.25);
      }
      if (pool.elapsed[i] >= pool.duration[i]) {
        pool.alive[i] = 0;
      }
      continue;
    }

    if (kind === HAZ_PRISON) {
      if (pool.state[i] === 0) {
        if (pool.elapsed[i] >= pool.duration[i]) {
          const x = pool.x[i];
          const y = pool.y[i];
          const r = pool.radius[i];
          emitFx(world.fx, FX_STRIKE, x, y, 0x88eeff);
          if (
            player.iframeRemain <= 0 &&
            circlesOverlap(x, y, r, player.x, player.y, player.radius)
          ) {
            emitFx(world.fx, FX_HURT, player.x, player.y, 0x55ddff);
            player.hp -= pool.damage[i];
            world.damageTaken += pool.damage[i];
            applyRoot(player, pool.rootDuration[i]);
          }
          pool.state[i] = 1;
          pool.elapsed[i] = 0;
          pool.duration[i] = 0.45;
        }
      } else if (pool.elapsed[i] >= pool.duration[i]) {
        pool.alive[i] = 0;
      }
      continue;
    }

    if (kind === HAZ_CONE) {
      if (pool.state[i] === 0) {
        if (pool.elapsed[i] >= pool.duration[i]) {
          if (
            player.iframeRemain <= 0 &&
            pointInCone(
              player.x,
              player.y,
              player.radius,
              pool.x[i],
              pool.y[i],
              pool.dirX[i],
              pool.dirY[i],
              pool.radius[i],
              pool.angle[i],
            )
          ) {
            emitFx(world.fx, FX_HURT, player.x, player.y, 0x7ad4ff);
            player.hp -= pool.damage[i];
            world.damageTaken += pool.damage[i];
            applySlow(player, pool.slowMul[i], pool.slowDuration[i]);
          }
          pool.state[i] = 1;
          pool.elapsed[i] = 0;
          pool.duration[i] = Math.max(0.25, pool.poolDuration[i]);
        }
      } else {
        if (
          player.iframeRemain <= 0 &&
          pointInCone(
            player.x,
            player.y,
            player.radius,
            pool.x[i],
            pool.y[i],
            pool.dirX[i],
            pool.dirY[i],
            pool.radius[i],
            pool.angle[i],
          )
        ) {
          applySlow(player, pool.slowMul[i], 0.35);
        }
        if (pool.elapsed[i] >= pool.duration[i]) {
          pool.alive[i] = 0;
        }
      }
      continue;
    }

    if (kind === HAZ_PULSE) {
      if (pool.state[i] === 0) {
        if (pool.elapsed[i] >= pool.duration[i]) {
          const x = pool.x[i];
          const y = pool.y[i];
          const r = pool.radius[i];
          emitFx(world.fx, FX_STRIKE, x, y, 0x66ddff);
          const dist = Math.hypot(player.x - x, player.y - y);
          if (
            player.iframeRemain <= 0 &&
            dist <= r + player.radius &&
            !pillarBlocksShot(world, x, y, player.x, player.y)
          ) {
            emitFx(world.fx, FX_HURT, player.x, player.y, 0x55ddff);
            player.hp -= pool.damage[i];
            world.damageTaken += pool.damage[i];
            applySlow(player, pool.slowMul[i], pool.slowDuration[i]);
          }
          pool.state[i] = 1;
          pool.elapsed[i] = 0;
          pool.duration[i] = pool.poolDuration[i];
        }
      } else if (pool.elapsed[i] >= pool.duration[i]) {
        pool.alive[i] = 0;
      }
    }
  }
}

export function pointInCone(
  px: number,
  py: number,
  pr: number,
  ox: number,
  oy: number,
  dirX: number,
  dirY: number,
  range: number,
  fullAngleRad: number,
): boolean {
  const dx = px - ox;
  const dy = py - oy;
  const dist = Math.hypot(dx, dy);
  if (dist > range + pr) return false;
  if (dist <= pr + 12) return true;
  const cosHalf = Math.cos(fullAngleRad * 0.5);
  const dot = (dx * dirX + dy * dirY) / dist;
  return dot >= cosHalf;
}
