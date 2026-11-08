import { FX_DEATH, FX_MUZZLE } from '../config';
import type { BossAi, BossAttack } from '../data/schema';
import { clamp } from './collision';
import {
  STYLE_FROST,
  STYLE_LAVA,
  spawnBossCone,
  spawnBossMeteor,
  spawnBossPool,
  spawnBossPrison,
  spawnBossPulse,
} from './boss-hazards';
import { spawnEnemy } from './enemies';
import { emitFx } from './fx';
import { TEAM_ENEMY, spawnProjectile } from './projectiles';
import { damagePlayer, type World } from './world';

const MAX_BOSS_ATTACKS = 8;

export type BossCastPhase = 'none' | 'windup' | 'channel';

export type BossAttackCounts = {
  bolt: number;
  fan: number;
  meteor: number;
  cone: number;
  prison: number;
  pulse: number;
  laser: number;
  summon: number;
};

export type BossState = {
  enemyIndex: number;
  cooldowns: Float32Array;
  activeAttack: number;
  phase: BossCastPhase;
  elapsed: number;
  duration: number;
  aimX: number;
  aimY: number;
  laserEndX: number;
  laserEndY: number;
  trailTimer: number;
  enraged: boolean;
  counts: BossAttackCounts;
};

export function createBossState(): BossState {
  return {
    enemyIndex: -1,
    cooldowns: new Float32Array(MAX_BOSS_ATTACKS),
    activeAttack: -1,
    phase: 'none',
    elapsed: 0,
    duration: 0,
    aimX: 0,
    aimY: 0,
    laserEndX: 0,
    laserEndY: 0,
    trailTimer: 0,
    enraged: false,
    counts: {
      bolt: 0,
      fan: 0,
      meteor: 0,
      cone: 0,
      prison: 0,
      pulse: 0,
      laser: 0,
      summon: 0,
    },
  };
}

export function resetBossState(boss: BossState): void {
  boss.enemyIndex = -1;
  boss.cooldowns.fill(0);
  boss.activeAttack = -1;
  boss.phase = 'none';
  boss.elapsed = 0;
  boss.duration = 0;
  boss.aimX = 0;
  boss.aimY = 0;
  boss.laserEndX = 0;
  boss.laserEndY = 0;
  boss.trailTimer = 0;
  boss.enraged = false;
}

export function initBossState(world: World, enemyIndex: number, ai: BossAi): void {
  const { boss } = world;
  resetBossState(boss);
  boss.enemyIndex = enemyIndex;
  for (let k = 0; k < ai.attacks.length && k < MAX_BOSS_ATTACKS; k += 1) {
    const atk = ai.attacks[k];
    if (atk.type === 'bolt' || atk.type === 'fan') {
      boss.cooldowns[k] = 0.8;
    } else if (atk.type === 'summon') {
      boss.cooldowns[k] = 2.4 + k * 0.6;
    } else {
      boss.cooldowns[k] = 1.6 + k * 1.1;
    }
  }
}

export function defaultBossAttackAnim(type: BossAttack['type']): string {
  switch (type) {
    case 'bolt':
      return 'attack-bolt';
    case 'fan':
      return 'attack-fan';
    case 'meteor':
      return 'attack-meteor';
    case 'cone':
      return 'attack-sweep';
    case 'prison':
      return 'attack-prison';
    case 'pulse':
      return 'attack-pulse';
    case 'laser':
      return 'attack-laser';
    case 'summon':
      return 'summon';
  }
}

export function stepBoss(
  world: World,
  i: number,
  ai: BossAi,
  dx: number,
  dy: number,
  len: number,
  dt: number,
  speed: number,
): void {
  const { enemies, boss, player } = world;
  if (boss.enemyIndex !== i) {
    initBossState(world, i, ai);
  }

  if (
    ai.enrage &&
    !boss.enraged &&
    enemies.maxHp[i] > 0 &&
    enemies.hp[i] / enemies.maxHp[i] <= ai.enrage.hpPct
  ) {
    boss.enraged = true;
    for (let k = 0; k < ai.attacks.length; k += 1) {
      boss.cooldowns[k] *= ai.enrage.cooldownMul;
    }
    emitFx(world.fx, FX_DEATH, enemies.x[i], enemies.y[i], 0xff5533);
  }

  for (let k = 0; k < ai.attacks.length && k < MAX_BOSS_ATTACKS; k += 1) {
    if (boss.cooldowns[k] > 0) {
      boss.cooldowns[k] = Math.max(0, boss.cooldowns[k] - dt);
    }
  }

  if (boss.phase === 'windup') {
    boss.elapsed += dt;
    const atk = ai.attacks[boss.activeAttack];
    if (!atk) {
      boss.phase = 'none';
      boss.activeAttack = -1;
      enemies.windup[i] = 0;
      return;
    }
    if (atk.type === 'bolt' || atk.type === 'laser') {
      const follow = Math.min(1, dt * 8);
      boss.aimX += (player.x - boss.aimX) * follow;
      boss.aimY += (player.y - boss.aimY) * follow;
      enemies.aimX[i] = boss.aimX;
      enemies.aimY[i] = boss.aimY;
      const hit = clampBeamToPillar(world, enemies.x[i], enemies.y[i], boss.aimX, boss.aimY);
      boss.laserEndX = hit.x;
      boss.laserEndY = hit.y;
    }
    enemies.windup[i] = Math.max(0.01, boss.duration - boss.elapsed);
    if (boss.elapsed >= boss.duration) {
      finishWindup(world, i, atk);
    }
    return;
  }

  if (boss.phase === 'channel') {
    boss.elapsed += dt;
    const atk = ai.attacks[boss.activeAttack];
    if (!atk || atk.type !== 'laser') {
      boss.phase = 'none';
      boss.activeAttack = -1;
      enemies.windup[i] = 0;
      return;
    }
    enemies.windup[i] = Math.max(0.01, boss.duration - boss.elapsed);
    const toPlayerX = player.x - boss.aimX;
    const toPlayerY = player.y - boss.aimY;
    const toPlayerDist = Math.hypot(toPlayerX, toPlayerY);
    if (toPlayerDist > 0.001) {
      const step = Math.min(toPlayerDist, atk.trackSpeed * dt);
      boss.aimX += (toPlayerX / toPlayerDist) * step;
      boss.aimY += (toPlayerY / toPlayerDist) * step;
    }
    const bounds = world.catalog.world;
    const pad = 40;
    boss.aimX = clamp(boss.aimX, pad, bounds.width - pad);
    boss.aimY = clamp(boss.aimY, pad, bounds.height - pad);
    enemies.aimX[i] = boss.aimX;
    enemies.aimY[i] = boss.aimY;

    const end = clampBeamToPillar(world, enemies.x[i], enemies.y[i], boss.aimX, boss.aimY);
    boss.laserEndX = end.x;
    boss.laserEndY = end.y;

    const distToEnd = Math.hypot(player.x - end.x, player.y - end.y);
    if (player.iframeRemain <= 0 && distToEnd <= atk.hitRadius + player.radius) {
      const dmg = atk.dps * world.coefficient * dt;
      damagePlayer(world, dmg);
    }

    boss.trailTimer += dt;
    if (boss.trailTimer >= atk.trailInterval) {
      boss.trailTimer -= atk.trailInterval;
      spawnBossPool(world.bossHazards, {
        x: end.x,
        y: end.y,
        radius: atk.trailPool.radius,
        duration: atk.trailPool.duration,
        dps: atk.trailPool.dps * world.coefficient,
        slowMul: atk.trailPool.slowMul,
        style: STYLE_FROST,
      });
    }

    if (boss.elapsed >= boss.duration) {
      boss.phase = 'none';
      boss.activeAttack = -1;
      enemies.windup[i] = 0;
      enemies.animName[i] = null;
    }
    return;
  }

  // Movement when not casting: maintain keep distance and slowly strafe
  if (len > 0.001) {
    const nx = dx / len;
    const ny = dy / len;
    let mx = 0;
    let my = 0;
    if (len > ai.keep + 70) {
      mx = nx * speed * dt;
      my = ny * speed * dt;
    } else if (len < ai.keep - 50) {
      mx = -nx * speed * 0.75 * dt;
      my = -ny * speed * 0.75 * dt;
    } else {
      mx = -ny * speed * 0.45 * dt;
      my = nx * speed * 0.45 * dt;
    }
    enemies.x[i] += mx;
    enemies.y[i] += my;
  }

  // Try starting the next ready attack
  for (let k = 0; k < ai.attacks.length && k < MAX_BOSS_ATTACKS; k += 1) {
    if (boss.cooldowns[k] > 0) continue;
    const atk = ai.attacks[k];
    if (atk.type === 'summon') {
      if (
        world.counts.fodder >= world.catalog.loop.maxFodder ||
        countLivingById(world, atk.entity) >= atk.maxAlive
      ) {
        boss.cooldowns[k] = 1.5;
        continue;
      }
    }
    if (atk.type === 'cone' && len > atk.range * 1.15) {
      continue;
    }
    startAttackWindup(world, i, ai, k, atk);
    break;
  }
}

function startAttackWindup(
  world: World,
  i: number,
  ai: BossAi,
  attackIndex: number,
  atk: BossAttack,
): void {
  const { enemies, boss, player } = world;
  const cdMul = boss.enraged && ai.enrage ? ai.enrage.cooldownMul : 1;
  boss.cooldowns[attackIndex] = atk.cooldown * cdMul;
  boss.activeAttack = attackIndex;
  boss.phase = 'windup';
  boss.elapsed = 0;
  boss.duration = Math.max(0.1, atk.windup ?? 0.35);
  boss.aimX = player.x;
  boss.aimY = player.y;
  boss.laserEndX = player.x;
  boss.laserEndY = player.y;
  enemies.aimX[i] = player.x;
  enemies.aimY[i] = player.y;
  enemies.windup[i] = boss.duration;
  enemies.animName[i] = atk.anim ?? defaultBossAttackAnim(atk.type);

  const bx = enemies.x[i];
  const by = enemies.y[i];
  const dx = player.x - bx;
  const dy = player.y - by;
  const len = Math.hypot(dx, dy) || 1;
  const dirX = dx / len;
  const dirY = dy / len;

  if (atk.type === 'meteor') {
    const isCinder = enemies.defId[i] === 'cinder-heart';
    spawnBossMeteor(world.bossHazards, {
      x: player.x,
      y: player.y,
      radius: atk.radius,
      delay: atk.delay,
      damage: atk.damage * world.coefficient,
      style: isCinder ? STYLE_LAVA : STYLE_FROST,
      poolDuration: atk.pool?.duration ?? 0,
      poolRadius: atk.pool?.radius ?? atk.radius,
      poolDps: (atk.pool?.dps ?? 0) * world.coefficient,
      poolSlow: atk.pool?.slowMul ?? 1,
    });
    boss.counts.meteor += 1;
  } else if (atk.type === 'prison') {
    spawnBossPrison(world.bossHazards, {
      x: player.x,
      y: player.y,
      radius: atk.radius,
      delay: atk.delay,
      damage: atk.damage * world.coefficient,
      rootDuration: atk.rootDuration,
    });
    boss.counts.prison += 1;
  } else if (atk.type === 'cone') {
    spawnBossCone(world.bossHazards, {
      x: bx,
      y: by,
      dirX,
      dirY,
      range: atk.range,
      angleRad: (atk.angle * Math.PI) / 180,
      windup: boss.duration,
      lingering: atk.lingering,
      damage: atk.damage * world.coefficient,
      slowMul: atk.slowMul,
      slowDuration: atk.slowDuration,
    });
    boss.counts.cone += 1;
  } else if (atk.type === 'pulse') {
    spawnBossPulse(world.bossHazards, {
      x: bx,
      y: by,
      radius: atk.radius,
      windup: boss.duration,
      damage: atk.damage * world.coefficient,
      slowMul: atk.slowMul,
      slowDuration: atk.slowDuration,
    });
    boss.counts.pulse += 1;
  }
}

function finishWindup(world: World, i: number, atk: BossAttack): void {
  const { enemies, boss } = world;
  const bx = enemies.x[i];
  const by = enemies.y[i];
  const dx = boss.aimX - bx;
  const dy = boss.aimY - by;
  const baseAngle = Math.atan2(dy, dx);
  const muzzle = enemies.radius[i] + 10;
  const tint = enemies.defId[i] === 'cinder-heart' ? 0xff7a3a : 0x7ad4ff;

  if (atk.type === 'bolt') {
    const nx = Math.cos(baseAngle);
    const ny = Math.sin(baseAngle);
    const x = bx + nx * muzzle;
    const y = by + ny * muzzle;
    spawnProjectile(world.projectiles, {
      x,
      y,
      dirX: nx,
      dirY: ny,
      speed: atk.projectile.speed,
      lifetime: atk.projectile.lifetime,
      radius: atk.projectile.radius,
      damage: atk.projectile.damage * world.coefficient,
      team: TEAM_ENEMY,
    });
    emitFx(world.fx, FX_MUZZLE, x, y, tint);
    boss.counts.bolt += 1;
  } else if (atk.type === 'fan') {
    const spreadRad = (atk.spread * Math.PI) / 180;
    const count = Math.max(1, atk.count);
    for (let k = 0; k < count; k += 1) {
      const frac = count === 1 ? 0 : k / (count - 1) - 0.5;
      const ang = baseAngle + frac * spreadRad;
      const nx = Math.cos(ang);
      const ny = Math.sin(ang);
      const x = bx + nx * muzzle;
      const y = by + ny * muzzle;
      spawnProjectile(world.projectiles, {
        x,
        y,
        dirX: nx,
        dirY: ny,
        speed: atk.projectile.speed,
        lifetime: atk.projectile.lifetime,
        radius: atk.projectile.radius,
        damage: atk.projectile.damage * world.coefficient,
        team: TEAM_ENEMY,
      });
    }
    emitFx(world.fx, FX_MUZZLE, bx + Math.cos(baseAngle) * muzzle, by + Math.sin(baseAngle) * muzzle, tint);
    boss.counts.fan += 1;
  } else if (atk.type === 'summon') {
    const alive = countLivingById(world, atk.entity);
    const canSpawn = Math.max(0, Math.min(atk.count, atk.maxAlive - alive));
    const def = world.catalog.entity(atk.entity);
    const bounds = world.catalog.world;
    const pad = def.stats.radius + 24;
    const ring = enemies.radius[i] + def.stats.radius + 28;
    for (let s = 0; s < canSpawn; s += 1) {
      const ang = (s / Math.max(1, canSpawn)) * Math.PI * 2 + world.runTime * 1.7;
      const sx = clamp(bx + Math.cos(ang) * ring, pad, bounds.width - pad);
      const sy = clamp(by + Math.sin(ang) * ring, pad, bounds.height - pad);
      if (spawnEnemy(world, def, sx, sy) >= 0) {
        emitFx(world.fx, FX_MUZZLE, sx, sy, tint);
      }
    }
    boss.counts.summon += 1;
  } else if (atk.type === 'laser') {
    boss.phase = 'channel';
    boss.elapsed = 0;
    boss.duration = atk.duration;
    boss.trailTimer = 0;
    enemies.windup[i] = atk.duration;
    boss.counts.laser += 1;
    return;
  }

  boss.phase = 'none';
  boss.activeAttack = -1;
  enemies.windup[i] = 0;
  enemies.attackRemain[i] = 0.25;
}

function countLivingById(world: World, defId: string): number {
  const { enemies } = world;
  let n = 0;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    if (enemies.defId[i] === defId) n += 1;
  }
  return n;
}

function clampBeamToPillar(
  world: World,
  x0: number,
  y0: number,
  x1: number,
  y1: number,
): { x: number; y: number } {
  const { obstacles } = world;
  const dx = x1 - x0;
  const dy = y1 - y0;
  const len = Math.hypot(dx, dy);
  if (len < 0.001) return { x: x1, y: y1 };
  const ux = dx / len;
  const uy = dy / len;
  let bestT = len;

  for (let i = 0; i < obstacles.cap; i += 1) {
    if (obstacles.alive[i] === 0) continue;
    const obs = obstacles.items[i];
    if (obs.type !== 'pillar') continue;
    const ox = obs.x - x0;
    const oy = obs.y - y0;
    const proj = ox * ux + oy * uy;
    if (proj <= 0 || proj >= bestT) continue;
    const perpSq = ox * ox + oy * oy - proj * proj;
    const rSq = obs.radius * obs.radius;
    if (perpSq <= rSq) {
      const hitT = Math.max(0, proj - Math.sqrt(rSq - perpSq));
      if (hitT < bestT) bestT = hitT;
    }
  }
  return { x: x0 + ux * bestT, y: y0 + uy * bestT };
}
