import { FX_DEATH, FX_HIT, FX_MUZZLE } from '../config';
import type { EntityDef, EntityRole, RangedAi, SniperAi } from '../data/schema';
import { circlesOverlap, clamp } from './collision';
import { emitFx } from './fx';
import { spawnGem } from './gems';
import { grantXp } from './level';
import { spawnAcidPool } from './obstacles';
import { TEAM_ENEMY, spawnProjectile } from './projectiles';
import { applySlow, tickEnemySlow } from './status';
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
  slowMul: Float32Array;
  noxious: Uint8Array;
  corpseRemain: Float32Array;
  rootRemain: Float32Array;
  tetherDps: Float32Array;
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
    slowMul: new Float32Array(cap),
    noxious: new Uint8Array(cap),
    corpseRemain: new Float32Array(cap),
    rootRemain: new Float32Array(cap),
    tetherDps: new Float32Array(cap),
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
    enemies.attackCd[i] = def.ai.type === 'chase' ? 0 : def.ai.cooldown * Math.random();
    enemies.windup[i] = 0;
    enemies.aimX[i] = x;
    enemies.aimY[i] = y;
    enemies.slowRemain[i] = 0;
    enemies.slowMul[i] = 1;
    enemies.noxious[i] = role === ROLE_ELITE ? 1 : 0;
    enemies.corpseRemain[i] = 0;
    enemies.rootRemain[i] = 0;
    enemies.tetherDps[i] = 0;
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

export function startEnemyDeath(world: World, index: number): void {
  const { enemies } = world;
  if (enemies.alive[index] === 0) return;
  if (enemies.corpseRemain[index] > 0) return;
  if (enemies.noxious[index] !== 0) {
    enemies.corpseRemain[index] = world.catalog.loop.noxious.corpseDelay;
    enemies.hp[index] = 0;
    enemies.speed[index] = 0;
    enemies.windup[index] = 0;
    return;
  }
  killEnemy(world, index);
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
    world.bossesDefeated += 1;
    world.portal.x = x;
    world.portal.y = y;
  }
  if (!spawnGem(world.gems, x, y, xp)) {
    grantXp(world, xp);
  }
}

export function countSnipers(world: World): number {
  const { enemies } = world;
  let n = 0;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    const defId = enemies.defId[i];
    if (defId && world.catalog.entity(defId).ai.type === 'sniper') n += 1;
  }
  return n;
}

export function stepEnemies(world: World, dt: number): void {
  const { enemies } = world;
  const bounds = world.catalog.world;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    tickEnemySlow(enemies, i, dt);
    if (enemies.rootRemain[i] > 0) {
      enemies.rootRemain[i] = Math.max(0, enemies.rootRemain[i] - dt);
      if (enemies.rootRemain[i] <= 0) enemies.tetherDps[i] = 0;
    }
    if (enemies.corpseRemain[i] > 0) {
      enemies.corpseRemain[i] -= dt;
      if (enemies.corpseRemain[i] <= 0) explodeNoxious(world, i);
      continue;
    }
    const defId = enemies.defId[i];
    const ai = defId ? world.catalog.entity(defId).ai : { type: 'chase' as const };
    const target = chaseTarget(world, i);
    const dx = target.x - enemies.x[i];
    const dy = target.y - enemies.y[i];
    const len = Math.hypot(dx, dy);
    const rooted = enemies.rootRemain[i] > 0;
    const speed = rooted ? 0 : enemies.speed[i] * localEnemySpeedMul(world, i);
    if (ai.type === 'ranged') {
      stepRanged(world, i, ai, dx, dy, len, dt, speed);
    } else if (ai.type === 'sniper') {
      stepSniper(world, i, ai, dx, dy, len, dt, speed);
    } else if (len > 0.001) {
      enemies.x[i] += (dx / len) * speed * dt;
      enemies.y[i] += (dy / len) * speed * dt;
    }
    const pad = enemies.radius[i] + 8;
    enemies.x[i] = clamp(enemies.x[i], pad, bounds.width - pad);
    enemies.y[i] = clamp(enemies.y[i], pad, bounds.height - pad);
  }
  tickTetherBurn(world, dt);
}

function chaseTarget(world: World, index: number): { x: number; y: number } {
  if (world.enemies.role[index] === ROLE_FODDER && world.decoy.active) {
    return { x: world.decoy.x, y: world.decoy.y };
  }
  return { x: world.player.x, y: world.player.y };
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

function stepSniper(
  world: World,
  i: number,
  ai: SniperAi,
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
    if (len < ai.keep) {
      enemies.x[i] -= nx * speed * dt;
      enemies.y[i] -= ny * speed * dt;
    } else {
      enemies.x[i] += -ny * speed * 0.25 * dt;
      enemies.y[i] += nx * speed * 0.25 * dt;
    }
  }

  if (enemies.windup[i] > 0) {
    enemies.windup[i] -= dt;
    if (enemies.windup[i] <= 0) {
      fireSniper(world, i, ai);
      enemies.attackCd[i] = ai.cooldown;
      enemies.windup[i] = 0;
    }
    return;
  }

  enemies.attackCd[i] = Math.max(0, enemies.attackCd[i] - dt);
  if (enemies.attackCd[i] <= 0) {
    enemies.windup[i] = ai.windup;
    enemies.aimX[i] = world.player.x;
    enemies.aimY[i] = world.player.y;
  }
}

function fireSniper(world: World, i: number, ai: SniperAi): void {
  const { enemies, player } = world;
  const x0 = enemies.x[i];
  const y0 = enemies.y[i];
  const x1 = enemies.aimX[i];
  const y1 = enemies.aimY[i];
  if (player.iframeRemain > 0) return;
  if (pillarBlocksShot(world, x0, y0, player.x, player.y)) return;
  const dist = pointToSegment(player.x, player.y, x0, y0, x1, y1);
  if (dist > ai.lineWidth + player.radius) return;
  emitFx(world.fx, FX_HIT, player.x, player.y, 0xff3355);
  player.hp -= ai.damage * world.coefficient;
}

function pillarBlocksShot(world: World, x0: number, y0: number, x1: number, y1: number): boolean {
  const { obstacles } = world;
  for (let i = 0; i < obstacles.cap; i += 1) {
    if (obstacles.alive[i] === 0) continue;
    const obs = obstacles.items[i];
    if (obs.type !== 'pillar') continue;
    if (segmentHitsCircle(x0, y0, x1, y1, obs.x, obs.y, obs.radius)) return true;
  }
  return false;
}

function explodeNoxious(world: World, index: number): void {
  const { enemies, player } = world;
  const cfg = world.catalog.loop.noxious;
  const x = enemies.x[index];
  const y = enemies.y[index];
  emitFx(world.fx, FX_DEATH, x, y, 0x66ff88);
  if (
    player.iframeRemain <= 0 &&
    circlesOverlap(x, y, cfg.popRadius, player.x, player.y, player.radius)
  ) {
    player.hp -= cfg.popDamage * world.coefficient;
  }
  spawnAcidPool(world, x, y);
  killEnemy(world, index);
}

function tickTetherBurn(world: World, dt: number): void {
  const { enemies } = world;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0 || enemies.rootRemain[i] <= 0 || enemies.tetherDps[i] <= 0) continue;
    if (enemies.role[i] !== ROLE_ELITE && enemies.role[i] !== ROLE_BOSS) continue;
    for (let f = 0; f < enemies.cap; f += 1) {
      if (f === i || enemies.alive[f] === 0 || enemies.role[f] !== ROLE_FODDER) continue;
      if (
        !circlesOverlap(
          enemies.x[i],
          enemies.y[i],
          enemies.radius[i],
          enemies.x[f],
          enemies.y[f],
          enemies.radius[f],
        )
      ) {
        continue;
      }
      enemies.hp[f] -= enemies.tetherDps[i] * dt;
      if (enemies.hp[f] <= 0) startEnemyDeath(world, f);
    }
  }
}

function localEnemySpeedMul(world: World, index: number): number {
  const cfg = world.catalog.obstacles;
  let mul = world.enemies.slowMul[index];
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

function pointToSegment(
  px: number,
  py: number,
  x0: number,
  y0: number,
  x1: number,
  y1: number,
): number {
  const dx = x1 - x0;
  const dy = y1 - y0;
  const len2 = dx * dx + dy * dy;
  if (len2 < 0.0001) return Math.hypot(px - x0, py - y0);
  let t = ((px - x0) * dx + (py - y0) * dy) / len2;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(px - (x0 + t * dx), py - (y0 + t * dy));
}

function segmentHitsCircle(
  x0: number,
  y0: number,
  x1: number,
  y1: number,
  cx: number,
  cy: number,
  radius: number,
): boolean {
  return pointToSegment(cx, cy, x0, y0, x1, y1) <= radius;
}

export function applyNoxiousContact(world: World, index: number): void {
  if (world.enemies.noxious[index] === 0) return;
  const cfg = world.catalog.loop.noxious;
  applySlow(world.player, cfg.contactSlowMul, cfg.contactSlowDuration);
}
