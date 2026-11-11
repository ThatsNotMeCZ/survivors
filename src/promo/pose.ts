import { catalog } from '../data/catalog';
import type { ItemDef } from '../data/schema';
import { initBossState } from '../sim/boss';
import { ROLE_BOSS, ROLE_ELITE, spawnEnemy } from '../sim/enemies';
import type { InputFrame } from '../sim/input-frame';
import { xpForLevel, syncStats } from '../sim/level';
import type { World } from '../sim/world';
import { getPromoShot, type PromoShot } from './shot';

export const TABLET_IDS = ['goat-hoof', 'glass-cannon', 'calcined-lens'] as const;

const RING_MITES = 10;
const ORBIT_PULL = 90;
let lastDashBeat = -1;
let lastPierceBeat = -1;

export function tabletOffer(): ItemDef[] {
  return TABLET_IDS.map((id) => catalog.item(id));
}

export function poseWorld(world: World, shot: PromoShot): void {
  if (shot === 'hall' || shot === 'archives' || shot === 'banner') return;
  dressRun(world);
  if (shot === 'boss') {
    poseBoss(world);
    return;
  }
  poseCircle(world);
  if (shot === 'tablets') {
    world.phase = 'levelup';
    world.offer = tabletOffer();
    world.pendingLevels = 1;
  }
}

export function applyPromoInput(world: World, input: InputFrame, timeSec: number): void {
  const shot = getPromoShot();
  if (shot !== 'circle' && shot !== 'boss') return;
  if (world.phase !== 'play') return;

  if (world.player.hp < world.player.maxHp * 0.4) {
    world.player.hp = world.player.maxHp * 0.75;
  }

  const tel = world.teleporter;
  const ang = timeSec * 0.85;
  let moveX = -Math.sin(ang);
  let moveY = Math.cos(ang);
  const dx = world.player.x - tel.x;
  const dy = world.player.y - tel.y;
  const dist = Math.hypot(dx, dy);
  if (dist > ORBIT_PULL) {
    moveX += (-dx / dist) * 1.6;
    moveY += (-dy / dist) * 1.6;
  }
  const mag = Math.hypot(moveX, moveY) || 1;
  input.moveX = moveX / mag;
  input.moveY = moveY / mag;

  aimAtThreat(world, input);
  input.held.primary = true;
  input.held.secondary = false;
  input.held.utility = false;
  input.held.special = false;
  input.pressed.primary = false;
  input.pressed.secondary = false;
  input.pressed.utility = false;
  input.pressed.special = false;

  const dashBeat = Math.floor(timeSec / 1.55);
  if (dashBeat !== lastDashBeat) {
    lastDashBeat = dashBeat;
    input.pressed.utility = true;
  }
  const pierceBeat = Math.floor((timeSec + 0.8) / 4.1);
  if (pierceBeat !== lastPierceBeat) {
    lastPierceBeat = pierceBeat;
    input.pressed.secondary = true;
  }
}

export function mountPromoTitle(): void {
  const el = document.getElementById('promo-title');
  if (!el) return;
  el.classList.remove('hidden');
  el.setAttribute('aria-hidden', 'false');
}

function dressRun(world: World): void {
  const loop = world.catalog.loop;
  world.runTime = 268;
  world.stageTime = Math.max(world.stageTime, loop.stages[0].teleporterAt + 8);
  world.coefficient = 1 + world.runTime * loop.difficulty.perSecond;
  world.level = 7;
  world.xpNeed = xpForLevel(loop.xpBase, loop.xpGrowth, world.level);
  world.xp = Math.round(world.xpNeed * 0.58);
  world.kills.total = 214;
  world.kills.fodder = 198;
  world.kills.elite = 16;
  world.lastFodderAt = world.stageTime;
  world.lastEliteAt = world.stageTime;
  world.lastSniperAt = world.stageTime;
  world.credits = 0;
  world.inventory = [
    { id: 'goat-hoof', stacks: 2 },
    { id: 'lead-core', stacks: 1 },
    { id: 'salt-ward', stacks: 1 },
  ];
  syncStats(world);
  world.player.hp = world.player.maxHp * 0.78;
}

function poseCircle(world: World): void {
  const tel = world.teleporter;
  world.player.x = tel.x;
  world.player.y = tel.y;
  world.aimX = tel.x + 90;
  world.aimY = tel.y - 40;
  world.teleporter.state = 'charging';
  world.teleporter.charge = tel.hold * 0.72;

  const mite = world.catalog.entity('ember-mite');
  const chaser = world.catalog.entity('ember-chaser');
  const spit = world.catalog.entity('ember-spitter');
  for (let i = 0; i < RING_MITES; i += 1) {
    const ang = (i / RING_MITES) * Math.PI * 2 + 0.35;
    const r = 108 + (i % 3) * 22;
    spawnEnemy(world, mite, tel.x + Math.cos(ang) * r, tel.y + Math.sin(ang) * r);
  }
  spawnEnemy(world, chaser, tel.x + 72, tel.y - 8, true, 'noxious');
  spawnEnemy(world, chaser, tel.x - 64, tel.y + 36, true, 'shielder');
  spawnEnemy(world, spit, tel.x + 130, tel.y - 58);
  spawnEnemy(world, spit, tel.x - 118, tel.y - 52);
}

function poseBoss(world: World): void {
  const tel = world.teleporter;
  const def = world.catalog.entity(world.catalog.loop.stages[0].boss);
  world.player.x = tel.x - 56;
  world.player.y = tel.y + 28;
  world.aimX = tel.x + 64;
  world.aimY = tel.y - 18;
  world.teleporter.state = 'done';
  world.teleporter.charge = tel.hold;
  const idx = spawnEnemy(world, def, tel.x + 72, tel.y - 24);
  if (idx >= 0 && def.ai.type === 'boss') {
    initBossState(world, idx, def.ai);
    world.bossSpawned = true;
    world.boss.cooldowns[0] = 0;
    world.boss.cooldowns[1] = 0.2;
  }
  const mite = world.catalog.entity('ember-mite');
  spawnEnemy(world, mite, tel.x + 118, tel.y + 36);
  spawnEnemy(world, mite, tel.x + 40, tel.y - 96);
}

function aimAtThreat(world: World, input: InputFrame): void {
  const { enemies, player } = world;
  let best = -1;
  let bestD = Infinity;
  let focus = -1;
  let focusD = Infinity;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    const d = Math.hypot(enemies.x[i] - player.x, enemies.y[i] - player.y);
    if (enemies.role[i] === ROLE_ELITE || enemies.role[i] === ROLE_BOSS) {
      if (d < focusD) {
        focus = i;
        focusD = d;
      }
    }
    if (d < bestD) {
      best = i;
      bestD = d;
    }
  }
  const i = focus >= 0 ? focus : best;
  if (i < 0) {
    input.aimX = player.x + 80;
    input.aimY = player.y;
    return;
  }
  input.aimX = enemies.x[i];
  input.aimY = enemies.y[i];
}
