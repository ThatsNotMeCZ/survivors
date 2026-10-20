import { emptyInput } from '../src/sim/input-frame';
import { applyLevelChoice } from '../src/sim/level';
import { countObstacles, overlappingHazard } from '../src/sim/obstacles';
import { TEAM_ENEMY } from '../src/sim/projectiles';
import { resolveStats } from '../src/sim/stats';
import { stepWorld, createWorld, type World } from '../src/sim/world';

const DT = 1 / 60;
const LIMIT = 400;
const log: string[] = [];

const world = createWorld();
const input = emptyInput();
assertObstacles(world, 'stage-init');
const initIds = obstacleIds(world);
let lastPhase = world.phase;
let lastStage = world.stageIndex;
let lastTel = world.teleporter.state;
let lastLevel = world.level;
let lastBoss = world.bossSpawned;

for (let t = 0; t < LIMIT; t += DT) {
  if (world.phase === 'levelup') {
    applyLevelChoice(world, safestOffer(world));
    continue;
  }
  if (world.phase === 'victory' || world.phase === 'defeat') break;

  steer(world, input, t);
  stepWorld(world, input, DT);

  if (world.phase !== lastPhase) {
    log.push(`${world.runTime.toFixed(1)}s phase ${lastPhase} -> ${world.phase}`);
    lastPhase = world.phase;
  }
  if (world.stageIndex !== lastStage) {
    log.push(`${world.runTime.toFixed(1)}s stage ${world.stageIndex} ${world.catalog.loop.stages[world.stageIndex].name}`);
    assertObstacles(world, 'stage-wipe');
    const nextIds = obstacleIds(world);
    if (nextIds.length === 0) throw new Error('obstacles missing after stage wipe');
    if (nextIds.every((id, i) => id === initIds[i])) {
      throw new Error('obstacle ids did not reset on stage transition');
    }
    lastStage = world.stageIndex;
  }
  if (world.teleporter.state !== lastTel) {
    log.push(`${world.runTime.toFixed(1)}s tel ${lastTel} -> ${world.teleporter.state}`);
    lastTel = world.teleporter.state;
  }
  if (world.level !== lastLevel) {
    log.push(`${world.runTime.toFixed(1)}s level ${world.level} items=${world.inventory.map((i) => i.id).join(',')}`);
    lastLevel = world.level;
  }
  if (world.bossSpawned !== lastBoss) {
    log.push(`${world.runTime.toFixed(1)}s bossSpawned=${world.bossSpawned} living=${world.counts.boss}`);
    lastBoss = world.bossSpawned;
  }
}

console.log(log.join('\n'));
console.log(
  JSON.stringify({
    phase: world.phase,
    runTime: Number(world.runTime.toFixed(1)),
    stage: world.stageIndex,
    level: world.level,
    items: world.inventory,
    hp: Number(world.player.hp.toFixed(1)),
    won: world.won,
    fodder: world.counts.fodder,
    elite: world.counts.elite,
    boss: world.counts.boss,
    obstacles: {
      pillar: countObstacles(world.obstacles, 'pillar'),
      hazard: countObstacles(world.obstacles, 'hazard'),
      volatile: countObstacles(world.obstacles, 'volatile'),
    },
  }),
);
if (world.phase !== 'victory') {
  throw new Error(`loop-smoke failed: ${world.phase} at ${world.runTime.toFixed(1)}s`);
}

function safestOffer(world: ReturnType<typeof createWorld>): number {
  const offer = world.offer;
  if (!offer || offer.length === 0) return 0;
  let best = 0;
  let bestScore = -Infinity;
  for (let i = 0; i < offer.length; i += 1) {
    const trial = world.inventory.map((inst) => ({ ...inst }));
    const existing = trial.find((inst) => inst.id === offer[i].id);
    if (existing) existing.stacks += 1;
    else trial.push({ id: offer[i].id, stacks: 1 });
    const stats = resolveStats(world.survivor.stats, trial, world.catalog.item);
    let score = stats.damageMul * 8 + stats.speed / 80 + stats.maxHp / 40;
    if (stats.maxHp < 75) score -= 25;
    if (stats.speed < 240) score -= 25;
    if (offer[i].rarity === 'lunar') score -= 40;
    if (score > bestScore) {
      bestScore = score;
      best = i;
    }
  }
  return best;
}

function assertObstacles(world: World, tag: string): void {
  const pillar = countObstacles(world.obstacles, 'pillar');
  const hazard = countObstacles(world.obstacles, 'hazard');
  const volatile = countObstacles(world.obstacles, 'volatile');
  if (pillar !== 14 || hazard !== 8 || volatile !== 9) {
    throw new Error(`${tag} obstacle counts pillar=${pillar} hazard=${hazard} volatile=${volatile}`);
  }
  if (world.counts.fodder !== 0 || world.counts.elite !== 0 || world.counts.boss !== 0) {
    throw new Error(`${tag} expected empty enemy pools`);
  }
  const cfg = world.catalog.obstacles;
  const px = world.player.x;
  const py = world.player.y;
  const tx = world.teleporter.x;
  const ty = world.teleporter.y;
  const placed: { x: number; y: number; type: string }[] = [];
  for (let i = 0; i < world.obstacles.cap; i += 1) {
    if (world.obstacles.alive[i] === 0) continue;
    const obs = world.obstacles.items[i];
    if (obs.x < cfg.borderPad || obs.y < cfg.borderPad) {
      throw new Error(`${tag} obstacle ${obs.id} inside border pad`);
    }
    if (Math.hypot(obs.x - px, obs.y - py) < cfg.playerKeepOut) {
      throw new Error(`${tag} obstacle ${obs.id} too close to player spawn`);
    }
    const telKeep = obs.type === 'volatile' ? cfg.volatileTeleporterKeepOut : cfg.teleporterKeepOut;
    if (Math.hypot(obs.x - tx, obs.y - ty) < telKeep) {
      throw new Error(`${tag} obstacle ${obs.id} too close to teleporter`);
    }
    for (const other of placed) {
      if (Math.hypot(obs.x - other.x, obs.y - other.y) < cfg.minSpacing) {
        throw new Error(`${tag} obstacles overlapping spacing`);
      }
    }
    placed.push({ x: obs.x, y: obs.y, type: obs.type });
  }
}

function obstacleIds(world: World): number[] {
  const ids: number[] = [];
  for (let i = 0; i < world.obstacles.cap; i += 1) {
    if (world.obstacles.alive[i] === 0) continue;
    ids.push(world.obstacles.items[i].id);
  }
  return ids;
}

function steer(world: ReturnType<typeof createWorld>, input: ReturnType<typeof emptyInput>, t: number): void {
  const { player, enemies, teleporter, portal, projectiles, obstacles } = world;
  let tx = player.x + Math.cos(t * 0.8) * 400;
  let ty = player.y + Math.sin(t * 0.8) * 400;

  if (teleporter.state === 'charging') {
    const orbit = teleporter.radius * 0.45;
    tx = teleporter.x + Math.cos(t * 2.2) * orbit;
    ty = teleporter.y + Math.sin(t * 2.2) * orbit;
  } else if (world.bossSpawned && world.counts.boss > 0) {
    for (let i = 0; i < enemies.cap; i += 1) {
      if (enemies.alive[i] === 0 || enemies.role[i] !== 2) continue;
      tx = enemies.x[i] + Math.cos(t * 2.6) * 220;
      ty = enemies.y[i] + Math.sin(t * 2.6) * 220;
      break;
    }
  }
  if (portal.open) {
    tx = portal.x;
    ty = portal.y;
  }

  let dodgeX = 0;
  let dodgeY = 0;
  let threat = false;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0 || enemies.windup[i] <= 0) continue;
    const defId = enemies.defId[i];
    if (!defId || world.catalog.entity(defId).ai.type !== 'sniper') continue;
    const dx = enemies.aimX[i] - enemies.x[i];
    const dy = enemies.aimY[i] - enemies.y[i];
    const len = Math.hypot(dx, dy) || 1;
    const nx = dx / len;
    const ny = dy / len;
    const along = (player.x - enemies.x[i]) * nx + (player.y - enemies.y[i]) * ny;
    const px = player.x - enemies.x[i] - along * nx;
    const py = player.y - enemies.y[i] - along * ny;
    const dist = Math.hypot(px, py);
    if (dist < 28) {
      threat = true;
      dodgeX += px;
      dodgeY += py;
    }
  }
  for (let i = 0; i < projectiles.alive.length; i += 1) {
    if (projectiles.alive[i] === 0 || projectiles.team[i] !== TEAM_ENEMY) continue;
    const dx = projectiles.x[i] - player.x;
    const dy = projectiles.y[i] - player.y;
    const d = Math.hypot(dx, dy);
    if (d < 120) {
      threat = true;
      dodgeX -= dx;
      dodgeY -= dy;
    }
  }

  let aimX = player.x + 80;
  let aimY = player.y;
  let bestRole = -1;
  let nearest = Infinity;
  for (let i = 0; i < enemies.cap; i += 1) {
    if (enemies.alive[i] === 0) continue;
    const dx = enemies.x[i] - player.x;
    const dy = enemies.y[i] - player.y;
    const d = Math.hypot(dx, dy);
    const role = enemies.role[i];
    if (role > bestRole || (role === bestRole && d < nearest)) {
      bestRole = role;
      nearest = d;
      aimX = enemies.x[i];
      aimY = enemies.y[i];
    }
    if (role !== 0 && d < 110) threat = true;
    if (role === 0 && d < 64) threat = true;
  }

  if (Math.hypot(dodgeX, dodgeY) > 1) {
    tx = player.x + dodgeX;
    ty = player.y + dodgeY;
  }

  let avoidX = 0;
  let avoidY = 0;
  let hazardThreat = overlappingHazard(world, player.x, player.y, player.radius + 12);
  for (let i = 0; i < obstacles.cap; i += 1) {
    if (obstacles.alive[i] === 0) continue;
    const obs = obstacles.items[i];
    const dx = player.x - obs.x;
    const dy = player.y - obs.y;
    const d = Math.hypot(dx, dy);
    const pad = obs.type === 'hazard' ? obs.radius + 28 : obs.radius + player.radius + 18;
    if (d < pad && d > 0.001) {
      avoidX += dx / d;
      avoidY += dy / d;
      if (obs.type === 'hazard') hazardThreat = true;
    }
  }
  if (Math.hypot(avoidX, avoidY) > 0.2) {
    tx = player.x + avoidX * 180;
    ty = player.y + avoidY * 180;
  }

  input.moveX = tx - player.x;
  input.moveY = ty - player.y;
  const mag = Math.hypot(input.moveX, input.moveY);
  if (mag > 1) {
    input.moveX /= mag;
    input.moveY /= mag;
  }

  input.aimX = aimX;
  input.aimY = aimY;
  input.held.primary = true;
  input.held.utility = false;
  input.pressed.utility = (threat || hazardThreat) && player.skillCd.utility <= 0 && player.dashRemain <= 0;
}
