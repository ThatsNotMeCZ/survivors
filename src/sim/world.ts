import { FX_HIT, FX_HURT } from '../config';
import { catalog, type Catalog } from '../data/catalog';
import type {
  ItemDef,
  ItemInstance,
  ResolvedStats,
  RunPhase,
  SkillSlot,
  SurvivorDef,
  TeleporterState,
} from '../data/schema';
import { createBossState, type BossState } from './boss';
import {
  createBossHazardPool,
  stepBossHazards,
  type BossHazardPool,
} from './boss-hazards';
import { aabbOverlap, circlesOverlap, clamp } from './collision';
import { stepDirector } from './director';
import {
  CHASE_ATTACK_COOLDOWN,
  CHASE_ATTACK_DURATION,
  ROLE_BOSS,
  ROLE_ELITE,
  ROLE_FODDER,
  applyNoxiousContact,
  applyEnemyDamage,
  createEnemyPool,
  stepEnemies,
  type EnemyPool,
} from './enemies';
import { clearFx, createFxPool, emitFx, type FxPool } from './fx';
import {
  MAX_LORE_DROPS,
  createGemPool,
  createLorePool,
  stepGems,
  stepLores,
  type GemPool,
  type LorePool,
} from './gems';
import type { InputFrame } from './input-frame';
import { emptyCds } from './input-frame';
import { xpForLevel } from './level';
import { beginStage, stepLoop } from './loop';
import {
  createObstaclePool,
  hitObstacleProjectiles,
  hitObstaclesAoE,
  obstacleCap,
  playerSpeedMul,
  stepObstacles,
  type ObstaclePool,
} from './obstacles';
import {
  FLAG_FLYOVER,
  FLAG_IMPACT,
  FLAG_PIERCE,
  FLAG_TETHER,
  TEAM_ENEMY,
  TEAM_PLAYER,
  createProjectilePool,
  killProjectile,
  markProjectileHit,
  projectileHasHit,
  stepProjectiles,
  type ProjectilePool,
} from './projectiles';
import { resolveBodyOverlaps } from './separation';
import { tickSkillCooldowns, trySkills } from './skills';
import { createHash, hashClear, hashInsert, hashQuery, type SpatialHash } from './spatial-hash';
import { resolveStats } from './stats';
import {
  createZonePool,
  emptyDecoy,
  stepZones,
  type DecoyState,
  type ZonePool,
} from './zones';

export type Actor = {
  defId: string;
  x: number;
  y: number;
  radius: number;
  hp: number;
  maxHp: number;
  speed: number;
};

export type PlayerState = Actor & {
  skillCd: Record<SkillSlot, number>;
  dashRemain: number;
  dashVx: number;
  dashVy: number;
  iframeRemain: number;
  slowRemain: number;
  slowMul: number;
  rootRemain: number;
  hurtRemain: number;
  hurtCooldown: number;
};

export type FocusState = {
  kind: 'none' | 'elite' | 'boss';
  hp: number;
  maxHp: number;
  name: string;
};

export type World = {
  catalog: Catalog;
  survivor: SurvivorDef;
  stats: ResolvedStats;
  player: PlayerState;
  inventory: ItemInstance[];
  aimX: number;
  aimY: number;
  projectiles: ProjectilePool;
  enemies: EnemyPool;
  gems: GemPool;
  lores: LorePool;
  collectedLores: Set<string>;
  newlyCollectedLores: string[];
  unlockedItems: Set<string>;
  obstacles: ObstaclePool;
  hash: SpatialHash;
  scratch: number[];
  runTime: number;
  stageTime: number;
  stageIndex: number;
  stageGen: number;
  coefficient: number;
  credits: number;
  lastFodderAt: number;
  lastEliteAt: number;
  counts: { fodder: number; elite: number; boss: number };
  xp: number;
  xpNeed: number;
  level: number;
  pendingLevels: number;
  phase: RunPhase;
  offer: ItemDef[] | null;
  won: boolean;
  bossSpawned: boolean;
  bossDefeated: boolean;
  teleporter: {
    state: TeleporterState;
    x: number;
    y: number;
    radius: number;
    charge: number;
    hold: number;
  };
  portal: { open: boolean; x: number; y: number; hold: number };
  focus: FocusState;
  fx: FxPool;
  zones: ZonePool;
  boss: BossState;
  bossHazards: BossHazardPool;
  decoy: DecoyState;
  bossesDefeated: number;
  lastSniperAt: number;
  kills: { fodder: number; elite: number; boss: number; total: number };
  killsByEntity: Record<string, number>;
  encountersByEntity: Record<string, number>;
  damageDealt: number;
  damageTaken: number;
  healingDone: number;
  gemsCollected: number;
  stagesCleared: number;
};

export type WorldOptions = {
  unlockedItems?: Iterable<string>;
  collectedLores?: Iterable<string>;
};

export function createWorld(
  survivorId = catalog.world.defaultSurvivor,
  options?: WorldOptions,
): World {
  const survivor = catalog.survivor(survivorId);
  const inventory: ItemInstance[] = survivor.startingItems.map((id) => ({ id, stacks: 1 }));
  const stats = resolveStats(survivor.stats, inventory, catalog.item);
  const loop = catalog.loop;
  const enemyCap = loop.maxFodder + loop.maxElites + 1;
  const player = makePlayer(survivor.id, stats, catalog.world.width, catalog.world.height);
  const unlockedItems = options?.unlockedItems
    ? new Set(options.unlockedItems)
    : new Set(catalog.items.map((item) => item.id));
  const collectedLores = new Set(options?.collectedLores ?? []);
  const world: World = {
    catalog,
    survivor,
    stats,
    player,
    inventory,
    aimX: player.x + 1,
    aimY: player.y,
    projectiles: createProjectilePool(catalog.world.maxProjectiles),
    enemies: createEnemyPool(enemyCap),
    gems: createGemPool(loop.maxGems),
    lores: createLorePool(MAX_LORE_DROPS),
    collectedLores,
    newlyCollectedLores: [],
    unlockedItems,
    obstacles: createObstaclePool(
      obstacleCap(catalog.obstacles.counts, catalog.obstacles.dynamicHazards),
      loop.hashCell,
    ),
    hash: createHash(loop.hashCell),
    scratch: new Array<number>(enemyCap).fill(0),
    runTime: 0,
    stageTime: 0,
    stageIndex: 0,
    stageGen: 0,
    coefficient: 1,
    credits: 0,
    lastFodderAt: -99,
    lastEliteAt: -99,
    counts: { fodder: 0, elite: 0, boss: 0 },
    xp: 0,
    xpNeed: xpForLevel(loop.xpBase, loop.xpGrowth, 1),
    level: 1,
    pendingLevels: 0,
    phase: 'play',
    offer: null,
    won: false,
    bossSpawned: false,
    bossDefeated: false,
    teleporter: { state: 'hidden', x: 0, y: 0, radius: loop.stages[0].teleporterRadius, charge: 0, hold: loop.stages[0].teleporterHold },
    portal: { open: false, x: 0, y: 0, hold: 0 },
    focus: { kind: 'none', hp: 0, maxHp: 0, name: '' },
    fx: createFxPool(),
    zones: createZonePool(),
    boss: createBossState(),
    bossHazards: createBossHazardPool(),
    decoy: emptyDecoy(),
    bossesDefeated: 0,
    lastSniperAt: -99,
    kills: { fodder: 0, elite: 0, boss: 0, total: 0 },
    killsByEntity: {},
    encountersByEntity: {},
    damageDealt: 0,
    damageTaken: 0,
    healingDone: 0,
    gemsCollected: 0,
    stagesCleared: 0,
  };
  beginStage(world, 0);
  return world;
}

export function stepWorld(world: World, input: InputFrame, dt: number): void {
  if (world.phase !== 'play') return;
  const prevDamageTaken = world.damageTaken;
  clearFx(world.fx);
  world.aimX = input.aimX;
  world.aimY = input.aimY;
  world.runTime += dt;
  world.stageTime += dt;

  tickSkillCooldowns(world, dt);
  world.player.iframeRemain = Math.max(0, world.player.iframeRemain - dt);
  trySkills(world, input);
  movePlayer(world, input, dt);
  stepProjectiles(world.projectiles, dt);
  detonateImpacts(world);
  stepDirector(world, dt);
  stepEnemies(world, dt);
  rebuildHash(world);
  resolveBodyOverlaps(world);
  rebuildHash(world);
  hitObstacleProjectiles(world);
  hitEnemies(world);
  hitPlayer(world);
  contactDamage(world, dt);
  stepZones(world, dt);
  stepBossHazards(world, dt);
  stepObstacles(world, dt);
  stepGems(world, dt);
  stepLores(world, dt);
  stepLoop(world, dt);

  if (world.damageTaken > prevDamageTaken && world.player.hurtCooldown <= 0) {
    world.player.hurtRemain = 0.14;
    world.player.hurtCooldown = 0.22;
  }
  world.player.hurtCooldown = Math.max(0, world.player.hurtCooldown - dt);
  world.player.hurtRemain = Math.max(0, world.player.hurtRemain - dt);
}

export function aimAngle(world: World): number {
  return Math.atan2(world.aimY - world.player.y, world.aimX - world.player.x);
}

function movePlayer(world: World, input: InputFrame, dt: number): void {
  const { player, stats } = world;
  const bounds = world.catalog.world;
  if (player.dashRemain > 0) {
    player.rootRemain = 0;
    player.dashRemain = Math.max(0, player.dashRemain - dt);
    player.x += player.dashVx * dt;
    player.y += player.dashVy * dt;
  } else if (player.rootRemain <= 0) {
    let mx = input.moveX;
    let my = input.moveY;
    const mag = Math.hypot(mx, my);
    if (mag > 1) {
      mx /= mag;
      my /= mag;
    }
    const speed = stats.speed * playerSpeedMul(world);
    player.x += mx * speed * dt;
    player.y += my * speed * dt;
  }
  const padX = (bounds.borderInsetX ?? 0) + player.radius;
  const padY = (bounds.borderInsetY ?? 0) + player.radius;
  player.x = clamp(player.x, padX, bounds.width - padX);
  player.y = clamp(player.y, padY, bounds.height - padY);
}

function rebuildHash(world: World): void {
  hashClear(world.hash);
  const { enemies } = world;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    hashInsert(world.hash, enemies.x[i], enemies.y[i], i);
  }
}

function detonateImpacts(world: World): void {
  const { projectiles, enemies } = world;
  for (let i = 0; i < projectiles.alive.length; i += 1) {
    if (projectiles.alive[i] === 0) continue;
    if ((projectiles.flags[i] & FLAG_IMPACT) === 0) continue;
    const dx = projectiles.destX[i] - projectiles.x[i];
    const dy = projectiles.destY[i] - projectiles.y[i];
    if (projectiles.life[i] > 0 && dx * dx + dy * dy > 64) continue;
    const x = projectiles.x[i];
    const y = projectiles.y[i];
    const radius = projectiles.impactRadius[i];
    const isCrit = Math.random() < world.stats.critChance;
    const damage = isCrit ? projectiles.damage[i] * world.stats.critMul : projectiles.damage[i];
    emitFx(world.fx, FX_HIT, x, y, isCrit ? 0xff4422 : 0xffaa55);
    for (let e = 0; e < enemies.cap; e += 1) {
      if (enemies.alive[e] === 0 || enemies.corpseRemain[e] > 0) continue;
      if (!circlesOverlap(x, y, radius, enemies.x[e], enemies.y[e], enemies.radius[e])) continue;
      applyEnemyDamage(world, e, damage);
    }
    if (projectiles.team[i] === TEAM_PLAYER) {
      hitObstaclesAoE(world, x, y, radius, damage);
    }
    killProjectile(projectiles, i);
  }
}

function hitEnemies(world: World): void {
  const { projectiles, enemies, hash, scratch } = world;
  for (let i = 0; i < projectiles.alive.length; i += 1) {
    if (projectiles.alive[i] === 0 || projectiles.team[i] !== TEAM_PLAYER) continue;
    if ((projectiles.flags[i] & FLAG_FLYOVER) !== 0) continue;
    const pierce = (projectiles.flags[i] & FLAG_PIERCE) !== 0;
    const tether = (projectiles.flags[i] & FLAG_TETHER) !== 0;
    const reach = projectiles.radius[i] + 48;
    const n = hashQuery(hash, projectiles.x[i], projectiles.y[i], reach, scratch);
    const hits: number[] = [];
    let nearest = -1;
    let best = Infinity;
    for (let k = 0; k < n; k += 1) {
      const idx = scratch[k];
      if (enemies.alive[idx] === 0 || enemies.corpseRemain[idx] > 0) continue;
      if (
        !aabbOverlap(
          projectiles.x[i],
          projectiles.y[i],
          projectiles.radius[i],
          enemies.x[idx],
          enemies.y[idx],
          enemies.radius[idx],
        )
      ) {
        continue;
      }
      if (pierce && projectileHasHit(projectiles, i, idx)) continue;
      const dx = enemies.x[idx] - projectiles.x[i];
      const dy = enemies.y[idx] - projectiles.y[i];
      const dist = dx * dx + dy * dy;
      if (pierce) {
        hits.push(idx);
        continue;
      }
      if (dist < best) {
        best = dist;
        nearest = idx;
      }
    }
    if (pierce) {
      if (hits.length === 0) continue;
      for (const hit of hits) applyPlayerHit(world, i, hit, tether);
      continue;
    }
    if (nearest < 0) continue;
    applyPlayerHit(world, i, nearest, tether);
    killProjectile(projectiles, i);
  }
}

function applyPlayerHit(world: World, proj: number, enemy: number, tether: boolean): void {
  const { projectiles, enemies } = world;
  markProjectileHit(projectiles, proj, enemy);
  if (tether) {
    if (enemies.role[enemy] === ROLE_ELITE || enemies.role[enemy] === ROLE_BOSS) {
      enemies.rootRemain[enemy] = Math.max(enemies.rootRemain[enemy], projectiles.rootDuration[proj]);
      enemies.tetherDps[enemy] = projectiles.tetherDps[proj];
    }
    return;
  }
  const isCrit = Math.random() < world.stats.critChance;
  const damage = isCrit ? projectiles.damage[proj] * world.stats.critMul : projectiles.damage[proj];
  emitFx(world.fx, FX_HIT, projectiles.x[proj], projectiles.y[proj], isCrit ? 0xff4422 : 0xfff4c8);
  applyEnemyDamage(world, enemy, damage);
}

function hitPlayer(world: World): void {
  const { player, projectiles } = world;
  if (player.iframeRemain > 0) return;
  for (let i = 0; i < projectiles.alive.length; i += 1) {
    if (projectiles.alive[i] === 0 || projectiles.team[i] !== TEAM_ENEMY) continue;
    if (
      !aabbOverlap(
        projectiles.x[i],
        projectiles.y[i],
        projectiles.radius[i],
        player.x,
        player.y,
        player.radius,
      )
    ) {
      continue;
    }
    emitFx(world.fx, FX_HURT, projectiles.x[i], projectiles.y[i], 0xff7a3a);
    player.hp -= projectiles.damage[i];
    world.damageTaken += projectiles.damage[i];
    killProjectile(projectiles, i);
  }
}

function contactDamage(world: World, dt: number): void {
  const { player, enemies, hash, scratch } = world;
  if (player.iframeRemain > 0) return;
  const cap = world.catalog.loop.fodderContactCap;
  let fodderHits = 0;
  const n = hashQuery(hash, player.x, player.y, player.radius + 48, scratch);
  for (let k = 0; k < n; k += 1) {
    const idx = scratch[k];
    if (enemies.alive[idx] === 0) continue;
    if (!aabbOverlap(player.x, player.y, player.radius, enemies.x[idx], enemies.y[idx], enemies.radius[idx])) {
      continue;
    }
    if (enemies.corpseRemain[idx] > 0) continue;
    if (enemies.attackRemain[idx] <= 0 && enemies.attackCd[idx] <= 0) {
      enemies.attackRemain[idx] = CHASE_ATTACK_DURATION;
      enemies.attackCd[idx] = CHASE_ATTACK_COOLDOWN;
    }
    if (enemies.role[idx] === ROLE_FODDER) {
      if (fodderHits >= cap) continue;
      fodderHits += 1;
    }
    const dmg = enemies.contactDps[idx] * dt;
    player.hp -= dmg;
    world.damageTaken += dmg;
    applyNoxiousContact(world, idx);
  }
}

function makePlayer(defId: string, stats: ResolvedStats, width: number, height: number): PlayerState {
  return {
    defId,
    x: width * 0.5,
    y: height * 0.5,
    radius: stats.radius,
    hp: stats.maxHp,
    maxHp: stats.maxHp,
    speed: stats.speed,
    skillCd: emptyCds(),
    dashRemain: 0,
    dashVx: 0,
    dashVy: 0,
    iframeRemain: 0,
    slowRemain: 0,
    slowMul: 1,
    rootRemain: 0,
    hurtRemain: 0,
    hurtCooldown: 0,
  };
}
