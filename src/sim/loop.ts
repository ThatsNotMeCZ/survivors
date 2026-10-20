import { clamp } from './collision';
import { ROLE_BOSS, ROLE_ELITE, clearEnemies, ringPoint, spawnEnemy } from './enemies';
import { clearGems } from './gems';
import { clearObstacles, placeStageObstacles } from './obstacles';
import { clearProjectiles } from './projectiles';
import { hashString, mulberry32 } from './rng';
import type { World } from './world';

export type ObjectiveKind = 'wait' | 'hold' | 'boss' | 'portal';

export type Objective = {
  kind: ObjectiveKind;
  remaining: number;
  pct: number;
  targetX: number;
  targetY: number;
  hasTarget: boolean;
  name: string;
};

export function currentStage(world: World) {
  return world.catalog.loop.stages[world.stageIndex];
}

export function currentObjective(world: World): Objective {
  if (world.portal.open) {
    const need = world.catalog.loop.portalHold;
    return {
      kind: 'portal',
      remaining: 0,
      pct: need > 0 ? Math.min(1, world.portal.hold / need) : 0,
      targetX: world.portal.x,
      targetY: world.portal.y,
      hasTarget: true,
      name: '',
    };
  }
  if (world.bossSpawned && world.counts.boss > 0) {
    const { enemies } = world;
    for (let i = 0; i < enemies.cap; i += 1) {
      if (enemies.alive[i] === 0 || enemies.role[i] !== ROLE_BOSS) continue;
      const max = enemies.maxHp[i] > 0 ? enemies.maxHp[i] : 1;
      const defId = enemies.defId[i];
      return {
        kind: 'boss',
        remaining: 0,
        pct: Math.max(0, enemies.hp[i] / max),
        targetX: enemies.x[i],
        targetY: enemies.y[i],
        hasTarget: true,
        name: defId ? world.catalog.entity(defId).name : 'Boss',
      };
    }
  }
  if (world.teleporter.state === 'charging') {
    const hold = world.teleporter.hold;
    return {
      kind: 'hold',
      remaining: 0,
      pct: hold > 0 ? Math.min(1, world.teleporter.charge / hold) : 0,
      targetX: world.teleporter.x,
      targetY: world.teleporter.y,
      hasTarget: true,
      name: '',
    };
  }
  const stage = currentStage(world);
  return {
    kind: 'wait',
    remaining: Math.max(0, stage.teleporterAt - world.stageTime),
    pct: stage.teleporterAt > 0 ? Math.min(1, world.stageTime / stage.teleporterAt) : 0,
    targetX: 0,
    targetY: 0,
    hasTarget: false,
    name: '',
  };
}

export function beginStage(world: World, index: number): void {
  const stage = world.catalog.loop.stages[index];
  world.stageIndex = index;
  world.stageTime = 0;
  world.stageGen += 1;
  world.bossSpawned = false;
  world.lastFodderAt = -99;
  world.lastEliteAt = -99;
  world.credits = 0;
  world.teleporter.state = 'hidden';
  world.teleporter.charge = 0;
  world.teleporter.hold = stage.teleporterHold;
  world.teleporter.radius = stage.teleporterRadius;
  world.portal.open = false;
  world.portal.hold = 0;
  world.portal.x = 0;
  world.portal.y = 0;
  clearEnemies(world);
  clearGems(world.gems);
  clearProjectiles(world.projectiles);
  clearObstacles(world.obstacles);
  world.player.x = world.catalog.world.width * 0.5;
  world.player.y = world.catalog.world.height * 0.5;
  world.player.hp = world.stats.maxHp;
  world.player.dashRemain = 0;
  world.player.iframeRemain = 0;
  world.player.slowRemain = 0;
  reserveTeleporter(world);
  placeStageObstacles(world);
}

export function stepLoop(world: World, dt: number): void {
  updateCoefficient(world);
  stepTeleporter(world, dt);
  stepPortal(world, dt);
  updateFocus(world);
  if (world.player.hp <= 0 && !world.won) {
    world.phase = 'defeat';
  }
}

function updateCoefficient(world: World): void {
  const { perSecond, stageBonus } = world.catalog.loop.difficulty;
  world.coefficient = 1 + world.runTime * perSecond + world.stageIndex * stageBonus;
}

function stepTeleporter(world: World, dt: number): void {
  const stage = currentStage(world);
  if (world.teleporter.state === 'hidden' && world.stageTime >= stage.teleporterAt) {
    world.teleporter.state = 'charging';
    world.teleporter.charge = 0;
  }
  if (world.teleporter.state !== 'charging') return;
  const dist = Math.hypot(world.player.x - world.teleporter.x, world.player.y - world.teleporter.y);
  if (dist <= world.teleporter.radius) {
    world.teleporter.charge += dt;
  }
  if (world.teleporter.charge >= world.teleporter.hold) {
    world.teleporter.state = 'done';
    spawnStageBoss(world);
  }
}

function spawnStageBoss(world: World): void {
  if (world.bossSpawned) return;
  const stage = currentStage(world);
  const def = world.catalog.entity(stage.boss);
  const point = ringPoint(world, world.teleporter.x, world.teleporter.y, def.stats.radius);
  if (spawnEnemy(world, def, point.x, point.y) < 0) return;
  world.bossSpawned = true;
}

function stepPortal(world: World, dt: number): void {
  if (world.bossSpawned && world.counts.boss === 0 && !world.portal.open && !world.won) {
    const last = world.stageIndex >= world.catalog.loop.stages.length - 1;
    if (last) {
      world.won = true;
      if (world.phase === 'play') world.phase = 'victory';
      return;
    }
    world.portal.open = true;
    world.portal.hold = 0;
    if (world.portal.x === 0 && world.portal.y === 0) {
      world.portal.x = world.teleporter.x;
      world.portal.y = world.teleporter.y;
    }
  }
  if (!world.portal.open) return;
  const { portalRadius, portalHold } = world.catalog.loop;
  const dist = Math.hypot(world.player.x - world.portal.x, world.player.y - world.portal.y);
  if (dist <= portalRadius) {
    world.portal.hold += dt;
    if (world.portal.hold >= portalHold) {
      beginStage(world, world.stageIndex + 1);
    }
  } else {
    world.portal.hold = 0;
  }
}

function reserveTeleporter(world: World): void {
  const stage = currentStage(world);
  const rng = mulberry32(
    hashString(stage.id) ^ ((world.stageIndex + 3) * 0x9e3779b9) ^ (world.stageGen * 0x27d4eb2d),
  );
  const bounds = world.catalog.world;
  const pad = stage.teleporterRadius + 48;
  const ox = world.player.x;
  const oy = world.player.y;
  for (let attempt = 0; attempt < 24; attempt += 1) {
    const dist = 480 + rng() * 320;
    const ang = rng() * Math.PI * 2;
    const x = clamp(ox + Math.cos(ang) * dist, pad, bounds.width - pad);
    const y = clamp(oy + Math.sin(ang) * dist, pad, bounds.height - pad);
    if (Math.hypot(x - ox, y - oy) >= 360) {
      world.teleporter.x = x;
      world.teleporter.y = y;
      return;
    }
  }
  world.teleporter.x = clamp(ox + 520, pad, bounds.width - pad);
  world.teleporter.y = clamp(oy, pad, bounds.height - pad);
}

function updateFocus(world: World): void {
  const { enemies } = world;
  world.focus.kind = 'none';
  world.focus.hp = 0;
  world.focus.maxHp = 0;
  world.focus.name = '';
  let elite = -1;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    if (enemies.role[i] === ROLE_BOSS) {
      world.focus.kind = 'boss';
      world.focus.hp = enemies.hp[i];
      world.focus.maxHp = enemies.maxHp[i];
      const bossId = enemies.defId[i];
      world.focus.name = bossId ? world.catalog.entity(bossId).name : 'Boss';
      return;
    }
    if (elite < 0 && enemies.role[i] === ROLE_ELITE) elite = i;
  }
  if (elite >= 0) {
    const eliteId = enemies.defId[elite];
    world.focus.kind = 'elite';
    world.focus.hp = enemies.hp[elite];
    world.focus.maxHp = enemies.maxHp[elite];
    world.focus.name = eliteId ? world.catalog.entity(eliteId).name : 'Elite';
  }
}
