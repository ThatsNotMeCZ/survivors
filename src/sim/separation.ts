import { aabbOverlap, clamp } from './collision';
import { hashClear, hashInsert, hashQuery } from './spatial-hash';
import type { World } from './world';

const ITERATIONS = 2;
const PLAYER_SHARE = 0.35;
const ENEMY_SHARE = 0.65;

export function resolveBodyOverlaps(world: World): void {
  for (let iter = 0; iter < ITERATIONS; iter += 1) {
    rehashEnemies(world);
    resolveEnemyPairs(world);
    if (world.player.dashRemain <= 0) {
      resolvePlayerEnemies(world);
    }
    clampActors(world);
  }
}

function rehashEnemies(world: World): void {
  hashClear(world.hash);
  const { enemies } = world;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    hashInsert(world.hash, enemies.x[i], enemies.y[i], i);
  }
}

function resolveEnemyPairs(world: World): void {
  const { enemies, hash, scratch } = world;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    const n = hashQuery(hash, enemies.x[i], enemies.y[i], enemies.radius[i] + 48, scratch);
    for (let k = 0; k < n; k += 1) {
      const j = scratch[k];
      if (j <= i || enemies.alive[j] === 0) continue;
      if (
        !aabbOverlap(
          enemies.x[i],
          enemies.y[i],
          enemies.radius[i],
          enemies.x[j],
          enemies.y[j],
          enemies.radius[j],
        )
      ) {
        continue;
      }
      const split = separateAxis(
        enemies.x[i],
        enemies.y[i],
        enemies.radius[i],
        enemies.x[j],
        enemies.y[j],
        enemies.radius[j],
        0.5,
        0.5,
      );
      enemies.x[i] = split.ax;
      enemies.y[i] = split.ay;
      enemies.x[j] = split.bx;
      enemies.y[j] = split.by;
    }
  }
}

function resolvePlayerEnemies(world: World): void {
  const { player, enemies, hash, scratch } = world;
  const n = hashQuery(hash, player.x, player.y, player.radius + 48, scratch);
  for (let k = 0; k < n; k += 1) {
    const i = scratch[k];
    if (enemies.alive[i] === 0) continue;
    if (!aabbOverlap(player.x, player.y, player.radius, enemies.x[i], enemies.y[i], enemies.radius[i])) {
      continue;
    }
    const split = separateAxis(
      player.x,
      player.y,
      player.radius,
      enemies.x[i],
      enemies.y[i],
      enemies.radius[i],
      PLAYER_SHARE,
      ENEMY_SHARE,
    );
    player.x = split.ax;
    player.y = split.ay;
    enemies.x[i] = split.bx;
    enemies.y[i] = split.by;
  }
}

function clampActors(world: World): void {
  const bounds = world.catalog.world;
  const { player, enemies } = world;
  player.x = clamp(player.x, player.radius, bounds.width - player.radius);
  player.y = clamp(player.y, player.radius, bounds.height - player.radius);
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    const pad = enemies.radius[i] + 8;
    enemies.x[i] = clamp(enemies.x[i], pad, bounds.width - pad);
    enemies.y[i] = clamp(enemies.y[i], pad, bounds.height - pad);
  }
}

function separateAxis(
  ax: number,
  ay: number,
  ar: number,
  bx: number,
  by: number,
  br: number,
  weightA: number,
  weightB: number,
): { ax: number; ay: number; bx: number; by: number } {
  const overlapX = ar + br - Math.abs(ax - bx);
  const overlapY = ar + br - Math.abs(ay - by);
  if (overlapX <= 0 || overlapY <= 0) {
    return { ax, ay, bx, by };
  }
  if (overlapX < overlapY) {
    const sign = ax >= bx ? 1 : -1;
    return {
      ax: ax + overlapX * weightA * sign,
      ay,
      bx: bx - overlapX * weightB * sign,
      by,
    };
  }
  const sign = ay >= by ? 1 : -1;
  return {
    ax,
    ay: ay + overlapY * weightA * sign,
    bx,
    by: by - overlapY * weightB * sign,
  };
}
