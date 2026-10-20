import { FX_HIT } from '../config';
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
import { aabbOverlap, clamp } from './collision';
import { stepDirector } from './director';
import {
  ROLE_FODDER,
  createEnemyPool,
  killEnemy,
  stepEnemies,
  type EnemyPool,
} from './enemies';
import { clearFx, createFxPool, emitFx, type FxPool } from './fx';
import { createGemPool, stepGems, type GemPool } from './gems';
import type { InputFrame } from './input-frame';
import { emptyCds } from './input-frame';
import { xpForLevel } from './level';
import { beginStage, stepLoop } from './loop';
import {
  createObstaclePool,
  hitObstacleProjectiles,
  obstacleCap,
  playerSpeedMul,
  stepObstacles,
  type ObstaclePool,
} from './obstacles';
import {
  TEAM_ENEMY,
  TEAM_PLAYER,
  createProjectilePool,
  killProjectile,
  stepProjectiles,
  type ProjectilePool,
} from './projectiles';
import { resolveBodyOverlaps } from './separation';
import { tickSkillCooldowns, trySkills } from './skills';
import { createHash, hashClear, hashInsert, hashQuery, type SpatialHash } from './spatial-hash';
import { resolveStats } from './stats';

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
};

export function createWorld(survivorId = catalog.world.defaultSurvivor): World {
  const survivor = catalog.survivor(survivorId);
  const inventory: ItemInstance[] = survivor.startingItems.map((id) => ({ id, stacks: 1 }));
  const stats = resolveStats(survivor.stats, inventory, catalog.item);
  const loop = catalog.loop;
  const enemyCap = loop.maxFodder + loop.maxElites + 1;
  const player = makePlayer(survivor.id, stats, catalog.world.width, catalog.world.height);
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
    obstacles: createObstaclePool(obstacleCap(catalog.obstacles.counts), loop.hashCell),
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
    teleporter: { state: 'hidden', x: 0, y: 0, radius: loop.stages[0].teleporterRadius, charge: 0, hold: loop.stages[0].teleporterHold },
    portal: { open: false, x: 0, y: 0, hold: 0 },
    focus: { kind: 'none', hp: 0, maxHp: 0, name: '' },
    fx: createFxPool(),
  };
  beginStage(world, 0);
  return world;
}

export function stepWorld(world: World, input: InputFrame, dt: number): void {
  if (world.phase !== 'play') return;
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
  stepDirector(world, dt);
  stepEnemies(world, dt);
  rebuildHash(world);
  resolveBodyOverlaps(world);
  rebuildHash(world);
  hitObstacleProjectiles(world);
  hitEnemies(world);
  hitPlayer(world);
  contactDamage(world, dt);
  stepObstacles(world, dt);
  stepGems(world, dt);
  stepLoop(world, dt);
}

export function aimAngle(world: World): number {
  return Math.atan2(world.aimY - world.player.y, world.aimX - world.player.x);
}

function movePlayer(world: World, input: InputFrame, dt: number): void {
  const { player, stats } = world;
  const bounds = world.catalog.world;
  if (player.dashRemain > 0) {
    player.dashRemain = Math.max(0, player.dashRemain - dt);
    player.x += player.dashVx * dt;
    player.y += player.dashVy * dt;
  } else {
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
  player.x = clamp(player.x, player.radius, bounds.width - player.radius);
  player.y = clamp(player.y, player.radius, bounds.height - player.radius);
}

function rebuildHash(world: World): void {
  hashClear(world.hash);
  const { enemies } = world;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    hashInsert(world.hash, enemies.x[i], enemies.y[i], i);
  }
}

function hitEnemies(world: World): void {
  const { projectiles, enemies, hash, scratch } = world;
  for (let i = 0; i < projectiles.alive.length; i += 1) {
    if (projectiles.alive[i] === 0 || projectiles.team[i] !== TEAM_PLAYER) continue;
    const reach = projectiles.radius[i] + 48;
    const n = hashQuery(hash, projectiles.x[i], projectiles.y[i], reach, scratch);
    let hit = -1;
    let best = Infinity;
    for (let k = 0; k < n; k += 1) {
      const idx = scratch[k];
      if (enemies.alive[idx] === 0) continue;
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
      const dx = enemies.x[idx] - projectiles.x[i];
      const dy = enemies.y[idx] - projectiles.y[i];
      const dist = dx * dx + dy * dy;
      if (dist < best) {
        best = dist;
        hit = idx;
      }
    }
    if (hit < 0) continue;
    emitFx(world.fx, FX_HIT, projectiles.x[i], projectiles.y[i], 0xfff4c8);
    enemies.hp[hit] -= projectiles.damage[i];
    killProjectile(projectiles, i);
    if (enemies.hp[hit] <= 0) killEnemy(world, hit);
  }
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
    emitFx(world.fx, FX_HIT, projectiles.x[i], projectiles.y[i], 0xff7a3a);
    player.hp -= projectiles.damage[i];
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
    if (enemies.role[idx] === ROLE_FODDER) {
      if (fodderHits >= cap) continue;
      fodderHits += 1;
    }
    player.hp -= enemies.contactDps[idx] * dt;
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
  };
}
