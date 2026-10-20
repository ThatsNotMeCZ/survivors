import { FX_DEATH, FX_HIT } from '../config';
import type { Obstacle, ObstacleKind } from '../data/schema';
import { aabbOverlap, circlesOverlap, pushCircles } from './collision';
import { ROLE_BOSS, killEnemy } from './enemies';
import { emitFx } from './fx';
import { TEAM_PLAYER, killProjectile } from './projectiles';
import { hashString, mulberry32 } from './rng';
import { createHash, hashClear, hashInsert, hashQuery, type SpatialHash } from './spatial-hash';
import type { World } from './world';

export type ObstaclePool = {
  cap: number;
  alive: Uint8Array;
  items: Obstacle[];
  hash: SpatialHash;
  scratch: number[];
  nextId: number;
};

export function obstacleCap(counts: Record<ObstacleKind, number>): number {
  return counts.pillar + counts.hazard + counts.volatile;
}

export function createObstaclePool(cap: number, cell: number): ObstaclePool {
  const items: Obstacle[] = [];
  for (let i = 0; i < cap; i += 1) {
    items.push(emptyObstacle());
  }
  return {
    cap,
    alive: new Uint8Array(cap),
    items,
    hash: createHash(cell),
    scratch: new Array<number>(Math.max(cap, 8)).fill(0),
    nextId: 1,
  };
}

export function clearObstacles(pool: ObstaclePool): void {
  pool.alive.fill(0);
  hashClear(pool.hash);
}

export function countObstacles(pool: ObstaclePool, type?: ObstacleKind): number {
  let n = 0;
  for (let i = 0; i < pool.cap; i += 1) {
    if (pool.alive[i] === 0) continue;
    if (type && pool.items[i].type !== type) continue;
    n += 1;
  }
  return n;
}

export function playerPhasing(world: World): boolean {
  return world.player.dashRemain > 0 || world.player.iframeRemain > 0;
}

export function playerSpeedMul(world: World): number {
  let mul = 1;
  if (world.player.slowRemain > 0) mul *= world.catalog.obstacles.volatile.rimeSlowMul;
  if (!playerPhasing(world) && overlappingHazard(world, world.player.x, world.player.y, world.player.radius)) {
    mul *= world.catalog.obstacles.hazard.playerSpeedMul;
  }
  return mul;
}

export function enemySpeedMul(world: World, index: number): number {
  let mul = 1;
  if (world.enemies.slowRemain[index] > 0) mul *= world.catalog.obstacles.volatile.rimeSlowMul;
  if (overlappingHazard(world, world.enemies.x[index], world.enemies.y[index], world.enemies.radius[index])) {
    mul *= world.catalog.obstacles.hazard.enemySpeedMul;
  }
  return mul;
}

export function placeStageObstacles(world: World): void {
  const cfg = world.catalog.obstacles;
  clearObstacles(world.obstacles);
  const stage = world.catalog.loop.stages[world.stageIndex];
  const names = cfg.biomes[stage.id];
  const rng = mulberry32(hashString(stage.id) ^ ((world.stageIndex + 1) * 0x9e3779b9) ^ (world.stageGen * 0x85ebca6b));
  const order: ObstacleKind[] = [
    ...repeatKind('pillar', cfg.counts.pillar),
    ...repeatKind('hazard', cfg.counts.hazard),
    ...repeatKind('volatile', cfg.counts.volatile),
  ];
  const placed: { x: number; y: number }[] = [];
  for (const type of order) {
    const point = tryPlace(world, type, rng, placed);
    if (!point) continue;
    spawnObstacle(world, type, point.x, point.y, names[type]);
    placed.push(point);
  }
  rebuildObstacleHash(world);
}

export function resolveObstacleBodies(world: World): void {
  const { obstacles, player, enemies } = world;
  for (let i = 0; i < obstacles.cap; i += 1) {
    if (obstacles.alive[i] === 0) continue;
    const obs = obstacles.items[i];
    if (obs.type === 'hazard') continue;
    pushActorFromObstacle(player.x, player.y, player.radius, obs, (x, y) => {
      player.x = x;
      player.y = y;
    });
    for (let e = 0; e < enemies.cap; e += 1) {
      if (enemies.alive[e] === 0) continue;
      if (enemies.role[e] === ROLE_BOSS && obs.type === 'pillar') continue;
      pushActorFromObstacle(enemies.x[e], enemies.y[e], enemies.radius[e], obs, (x, y) => {
        enemies.x[e] = x;
        enemies.y[e] = y;
      });
    }
  }
}

export function hitObstacleProjectiles(world: World): void {
  const { projectiles, obstacles } = world;
  const reachPad = 56;
  for (let i = 0; i < projectiles.alive.length; i += 1) {
    if (projectiles.alive[i] === 0) continue;
    const n = hashQuery(
      obstacles.hash,
      projectiles.x[i],
      projectiles.y[i],
      projectiles.radius[i] + reachPad,
      obstacles.scratch,
    );
    let hit = -1;
    let best = Infinity;
    for (let k = 0; k < n; k += 1) {
      const idx = obstacles.scratch[k];
      if (obstacles.alive[idx] === 0) continue;
      const obs = obstacles.items[idx];
      if (obs.type === 'hazard') continue;
      if (
        !aabbOverlap(
          projectiles.x[i],
          projectiles.y[i],
          projectiles.radius[i],
          obs.x,
          obs.y,
          obs.radius,
        )
      ) {
        continue;
      }
      if (!circlesOverlap(projectiles.x[i], projectiles.y[i], projectiles.radius[i], obs.x, obs.y, obs.radius)) {
        continue;
      }
      const dist = (obs.x - projectiles.x[i]) ** 2 + (obs.y - projectiles.y[i]) ** 2;
      if (dist < best) {
        best = dist;
        hit = idx;
      }
    }
    if (hit < 0) continue;
    const obs = obstacles.items[hit];
    emitFx(world.fx, FX_HIT, projectiles.x[i], projectiles.y[i], 0xfff4c8);
    if (projectiles.team[i] === TEAM_PLAYER && obs.type === 'volatile' && obs.state === 'intact') {
      obs.hp -= projectiles.damage[i];
      if (obs.hp <= 0) {
        obs.hp = 0;
        obs.state = 'primed';
        obs.timer = world.catalog.obstacles.volatile.prime;
      }
    }
    killProjectile(projectiles, i);
  }
}

export function stepObstacles(world: World, dt: number): void {
  const { player, obstacles } = world;
  if (player.slowRemain > 0) player.slowRemain = Math.max(0, player.slowRemain - dt);
  const { enemies } = world;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    if (enemies.slowRemain[i] > 0) enemies.slowRemain[i] = Math.max(0, enemies.slowRemain[i] - dt);
  }

  if (!playerPhasing(world) && overlappingHazard(world, player.x, player.y, player.radius)) {
    player.hp -= world.catalog.obstacles.hazard.dps * world.coefficient * dt;
  }

  let detonated = false;
  for (let i = 0; i < obstacles.cap; i += 1) {
    if (obstacles.alive[i] === 0) continue;
    const obs = obstacles.items[i];
    if (obs.type !== 'volatile' || obs.state !== 'primed') continue;
    obs.timer -= dt;
    if (obs.timer > 0) continue;
    detonateVolatile(world, i);
    detonated = true;
  }
  if (detonated) rebuildObstacleHash(world);
}

export function overlappingHazard(world: World, x: number, y: number, radius: number): boolean {
  const { obstacles } = world;
  const n = hashQuery(obstacles.hash, x, y, radius + world.catalog.obstacles.hazard.radius, obstacles.scratch);
  for (let k = 0; k < n; k += 1) {
    const idx = obstacles.scratch[k];
    if (obstacles.alive[idx] === 0) continue;
    const obs = obstacles.items[idx];
    if (obs.type !== 'hazard') continue;
    if (circlesOverlap(x, y, radius, obs.x, obs.y, obs.radius)) return true;
  }
  return false;
}

function detonateVolatile(world: World, index: number): void {
  const cfg = world.catalog.obstacles.volatile;
  const obs = world.obstacles.items[index];
  const rime = world.catalog.loop.stages[world.stageIndex].id === 'rime-dock';
  const blast = cfg.explosionRadius;
  const enemyDmg = cfg.enemyDamage * world.coefficient;
  emitFx(world.fx, FX_DEATH, obs.x, obs.y, 0xff8844);
  const { enemies } = world;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    if (!circlesOverlap(obs.x, obs.y, blast, enemies.x[i], enemies.y[i], enemies.radius[i])) continue;
    enemies.hp[i] -= enemyDmg;
    if (rime) enemies.slowRemain[i] = Math.max(enemies.slowRemain[i], cfg.rimeSlowDuration);
    if (enemies.hp[i] <= 0) killEnemy(world, i);
  }
  const { player } = world;
  if (circlesOverlap(obs.x, obs.y, blast, player.x, player.y, player.radius)) {
    if (player.iframeRemain <= 0) player.hp -= cfg.playerDamage;
    if (rime) player.slowRemain = Math.max(player.slowRemain, cfg.rimeSlowDuration);
  }
  obs.state = 'detonated';
  obs.timer = 0;
  world.obstacles.alive[index] = 0;
}

function pushActorFromObstacle(
  x: number,
  y: number,
  radius: number,
  obs: Obstacle,
  apply: (x: number, y: number) => void,
): void {
  if (!circlesOverlap(x, y, radius, obs.x, obs.y, obs.radius)) return;
  const split = pushCircles(x, y, radius, obs.x, obs.y, obs.radius, 1, 0);
  apply(split.ax, split.ay);
}

function spawnObstacle(world: World, type: ObstacleKind, x: number, y: number, biomeVariant: string): void {
  const { obstacles } = world;
  for (let i = 0; i < obstacles.cap; i += 1) {
    if (obstacles.alive[i] !== 0) continue;
    const cfg = world.catalog.obstacles;
    const radius = type === 'pillar' ? cfg.pillar.radius : type === 'hazard' ? cfg.hazard.radius : cfg.volatile.radius;
    const hp = type === 'volatile' ? cfg.volatile.hp * world.coefficient : 0;
    const item = obstacles.items[i];
    item.id = obstacles.nextId;
    obstacles.nextId += 1;
    item.type = type;
    item.x = x;
    item.y = y;
    item.radius = radius;
    item.hp = hp;
    item.maxHp = hp;
    item.state = 'intact';
    item.timer = 0;
    item.biomeVariant = biomeVariant;
    obstacles.alive[i] = 1;
    return;
  }
}

function tryPlace(
  world: World,
  type: ObstacleKind,
  rng: () => number,
  placed: { x: number; y: number }[],
): { x: number; y: number } | null {
  const cfg = world.catalog.obstacles;
  const { width, height } = world.catalog.world;
  const telKeep = type === 'volatile' ? cfg.volatileTeleporterKeepOut : cfg.teleporterKeepOut;
  for (let attempt = 0; attempt < cfg.placeRetries; attempt += 1) {
    const x = cfg.borderPad + rng() * (width - cfg.borderPad * 2);
    const y = cfg.borderPad + rng() * (height - cfg.borderPad * 2);
    if (Math.hypot(x - world.player.x, y - world.player.y) < cfg.playerKeepOut) continue;
    if (Math.hypot(x - world.teleporter.x, y - world.teleporter.y) < telKeep) continue;
    let blocked = false;
    for (let i = 0; i < placed.length; i += 1) {
      if (Math.hypot(x - placed[i].x, y - placed[i].y) < cfg.minSpacing) {
        blocked = true;
        break;
      }
    }
    if (blocked) continue;
    return { x, y };
  }
  return null;
}

function rebuildObstacleHash(world: World): void {
  const { obstacles } = world;
  hashClear(obstacles.hash);
  for (let i = 0; i < obstacles.cap; i += 1) {
    if (obstacles.alive[i] === 0) continue;
    hashInsert(obstacles.hash, obstacles.items[i].x, obstacles.items[i].y, i);
  }
}

function repeatKind(type: ObstacleKind, count: number): ObstacleKind[] {
  const out: ObstacleKind[] = [];
  for (let i = 0; i < count; i += 1) pendingPush(out, type);
  return out;
}

function pendingPush(out: ObstacleKind[], type: ObstacleKind): void {
  out.push(type);
}

function emptyObstacle(): Obstacle {
  return {
    id: 0,
    type: 'pillar',
    x: 0,
    y: 0,
    radius: 0,
    hp: 0,
    maxHp: 0,
    state: 'detonated',
    timer: 0,
    biomeVariant: '',
  };
}
