import { FX_DEATH, FX_MUZZLE } from '../config';
import type { EntityDef, EntityRole, RangedAi } from '../data/schema';
import { circlesOverlap, clamp } from './collision';
import { emitFx } from './fx';
import { spawnGem } from './gems';
import { grantXp } from './level';
import { TEAM_ENEMY, spawnProjectile } from './projectiles';
import type { World } from './world';

export const ROLE_FODDER = 0;
export const ROLE_ELITE = 1;
export const ROLE_BOSS = 2;

const ROLE_CODE: Record<EntityRole, number> = {
  fodder: ROLE_FODDER,
  elite: ROLE_ELITE,
  boss: ROLE_BOSS,
};

export type EnemyPool = {
  cap: number;
  alive: Uint8Array;
  role: Uint8Array;
  x: Float32Array;
  y: Float32Array;
  radius: Float32Array;
  hp: Float32Array;
  maxHp: Float32Array;
  speed: Float32Array;
  contactDps: Float32Array;
  xp: Float32Array;
  credits: Float32Array;
  attackCd: Float32Array;
  windup: Float32Array;
  aimX: Float32Array;
  aimY: Float32Array;
  slowRemain: Float32Array;
  defId: (string | null)[];
};

export function createEnemyPool(cap: number): EnemyPool {
  return {
    cap,
    alive: new Uint8Array(cap),
    role: new Uint8Array(cap),
    x: new Float32Array(cap),
    y: new Float32Array(cap),
    radius: new Float32Array(cap),
    hp: new Float32Array(cap),
    maxHp: new Float32Array(cap),
    speed: new Float32Array(cap),
    contactDps: new Float32Array(cap),
    xp: new Float32Array(cap),
    credits: new Float32Array(cap),
    attackCd: new Float32Array(cap),
    windup: new Float32Array(cap),
    aimX: new Float32Array(cap),
    aimY: new Float32Array(cap),
    slowRemain: new Float32Array(cap),
    defId: new Array<string | null>(cap).fill(null),
  };
}

export function clearEnemies(world: World): void {
  world.enemies.alive.fill(0);
  world.counts.fodder = 0;
  world.counts.elite = 0;
  world.counts.boss = 0;
}

export function spawnEnemy(world: World, def: EntityDef, x: number, y: number): number {
  const role = ROLE_CODE[def.role];
  if (role === ROLE_FODDER && world.counts.fodder >= world.catalog.loop.maxFodder) return -1;
  if (role === ROLE_ELITE && world.counts.elite >= world.catalog.loop.maxElites) return -1;
  if (role === ROLE_BOSS && world.counts.boss >= 1) return -1;

  const { enemies } = world;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] !== 0) continue;
    const coeff = world.coefficient;
    const speedMul = 1 + world.catalog.loop.difficulty.speedPerCoeff * (coeff - 1);
    const hp = def.stats.maxHp * coeff;
    enemies.alive[i] = 1;
    enemies.role[i] = role;
    enemies.x[i] = x;
    enemies.y[i] = y;
    enemies.radius[i] = def.stats.radius;
    enemies.hp[i] = hp;
    enemies.maxHp[i] = hp;
    enemies.speed[i] = def.stats.speed * speedMul;
    enemies.contactDps[i] = def.contact.dps * coeff;
    enemies.xp[i] = def.rewards.xp;
    enemies.credits[i] = def.rewards.credits;
    enemies.attackCd[i] = def.ai.type === 'ranged' ? def.ai.cooldown * Math.random() : 0;
    enemies.windup[i] = 0;
    enemies.aimX[i] = x;
    enemies.aimY[i] = y;
    enemies.slowRemain[i] = 0;
    enemies.defId[i] = def.id;
    if (role === ROLE_FODDER) world.counts.fodder += 1;
    else if (role === ROLE_ELITE) world.counts.elite += 1;
    else world.counts.boss += 1;
    return i;
  }
  return -1;
}

export function spawnAround(world: World, def: EntityDef): number {
  const originX = world.teleporter.state === 'charging' ? world.teleporter.x : world.player.x;
  const originY = world.teleporter.state === 'charging' ? world.teleporter.y : world.player.y;
  const point = ringPoint(world, originX, originY, def.stats.radius);
  return spawnEnemy(world, def, point.x, point.y);
}

export function killEnemy(world: World, index: number): void {
  const { enemies } = world;
  if (enemies.alive[index] === 0) return;
  const role = enemies.role[index];
  const x = enemies.x[index];
  const y = enemies.y[index];
  const xp = enemies.xp[index];
  world.credits += enemies.credits[index];
  emitFx(world.fx, FX_DEATH, x, y, 0xffd35a);
  enemies.alive[index] = 0;
  if (role === ROLE_FODDER) world.counts.fodder -= 1;
  else if (role === ROLE_ELITE) world.counts.elite -= 1;
  else if (role === ROLE_BOSS) {
    world.counts.boss -= 1;
    world.portal.x = x;
    world.portal.y = y;
  }
  if (!spawnGem(world.gems, x, y, xp)) {
    grantXp(world, xp);
  }
}

export function stepEnemies(world: World, dt: number): void {
  const { enemies, player } = world;
  const bounds = world.catalog.world;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    const defId = enemies.defId[i];
    const ai = defId ? world.catalog.entity(defId).ai : { type: 'chase' as const };
    const dx = player.x - enemies.x[i];
    const dy = player.y - enemies.y[i];
    const len = Math.hypot(dx, dy);
    const speed = enemies.speed[i] * localEnemySpeedMul(world, i);
    if (ai.type === 'ranged') {
      stepRanged(world, i, ai, dx, dy, len, dt, speed);
    } else if (len > 0.001) {
      enemies.x[i] += (dx / len) * speed * dt;
      enemies.y[i] += (dy / len) * speed * dt;
    }
    const pad = enemies.radius[i] + 8;
    enemies.x[i] = clamp(enemies.x[i], pad, bounds.width - pad);
    enemies.y[i] = clamp(enemies.y[i], pad, bounds.height - pad);
  }
}

function stepRanged(
  world: World,
  i: number,
  ai: RangedAi,
  dx: number,
  dy: number,
  len: number,
  dt: number,
  speed: number,
): void {
  const { enemies } = world;
  if (len > 0.001) {
    const nx = dx / len;
    const ny = dy / len;
    if (len > ai.range) {
      enemies.x[i] += nx * speed * dt;
      enemies.y[i] += ny * speed * dt;
    } else if (len < ai.keep) {
      enemies.x[i] -= nx * speed * dt;
      enemies.y[i] -= ny * speed * dt;
    } else {
      enemies.x[i] += -ny * speed * 0.45 * dt;
      enemies.y[i] += nx * speed * 0.45 * dt;
    }
  }

  if (enemies.windup[i] > 0) {
    enemies.windup[i] -= dt;
    if (enemies.windup[i] <= 0) {
      fireEnemyBolt(world, i, ai);
      enemies.attackCd[i] = ai.cooldown;
      enemies.windup[i] = 0;
    }
    return;
  }

  enemies.attackCd[i] = Math.max(0, enemies.attackCd[i] - dt);
  if (len <= ai.range && enemies.attackCd[i] <= 0) {
    enemies.windup[i] = ai.windup;
    enemies.aimX[i] = world.player.x;
    enemies.aimY[i] = world.player.y;
  }
}

function localEnemySpeedMul(world: World, index: number): number {
  const cfg = world.catalog.obstacles;
  let mul = 1;
  if (world.enemies.slowRemain[index] > 0) mul *= cfg.volatile.rimeSlowMul;
  const { enemies, obstacles } = world;
  for (let i = 0; i < obstacles.cap; i += 1) {
    if (obstacles.alive[i] === 0) continue;
    const obs = obstacles.items[i];
    if (obs.type !== 'hazard') continue;
    if (circlesOverlap(enemies.x[index], enemies.y[index], enemies.radius[index], obs.x, obs.y, obs.radius)) {
      mul *= cfg.hazard.enemySpeedMul;
      break;
    }
  }
  return mul;
}

function fireEnemyBolt(world: World, i: number, ai: RangedAi): void {
  const { enemies, player } = world;
  const dx = player.x - enemies.x[i];
  const dy = player.y - enemies.y[i];
  const len = Math.hypot(dx, dy);
  if (len <= 0.001) return;
  const nx = dx / len;
  const ny = dy / len;
  const muzzle = enemies.radius[i] + 8;
  const x = enemies.x[i] + nx * muzzle;
  const y = enemies.y[i] + ny * muzzle;
  spawnProjectile(world.projectiles, {
    x,
    y,
    dirX: nx,
    dirY: ny,
    speed: ai.projectile.speed,
    lifetime: ai.projectile.lifetime,
    radius: ai.projectile.radius,
    damage: ai.projectile.damage * world.coefficient,
    team: TEAM_ENEMY,
  });
  emitFx(world.fx, FX_MUZZLE, x, y, 0xff7a3a);
}

export function ringPoint(
  world: World,
  ox: number,
  oy: number,
  radius: number,
): { x: number; y: number } {
  const { spawnMin, spawnMax } = world.catalog.loop.director;
  const bounds = world.catalog.world;
  const pad = radius + 8;
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const dist = spawnMin + Math.random() * (spawnMax - spawnMin);
    const ang = Math.random() * Math.PI * 2;
    const x = clamp(ox + Math.cos(ang) * dist, pad, bounds.width - pad);
    const y = clamp(oy + Math.sin(ang) * dist, pad, bounds.height - pad);
    if (Math.hypot(x - ox, y - oy) >= spawnMin * 0.7) {
      return { x, y };
    }
  }
  return {
    x: clamp(ox + spawnMin, pad, bounds.width - pad),
    y: clamp(oy, pad, bounds.height - pad),
  };
}
