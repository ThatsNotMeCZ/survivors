import { emptyInput } from '../src/sim/input-frame';
import { applyLevelChoice } from '../src/sim/level';
import { TEAM_ENEMY } from '../src/sim/projectiles';
import { stepWorld, createWorld } from '../src/sim/world';

const DT = 1 / 60;
const LIMIT = 400;
const log: string[] = [];

const world = createWorld();
const input = emptyInput();
let lastPhase = world.phase;
let lastStage = world.stageIndex;
let lastTel = world.teleporter.state;
let lastLevel = world.level;
let lastBoss = world.bossSpawned;

for (let t = 0; t < LIMIT; t += DT) {
  if (world.phase === 'levelup') {
    applyLevelChoice(world, 0);
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
  }),
);
if (world.phase !== 'victory') {
  throw new Error(`loop-smoke failed: ${world.phase} at ${world.runTime.toFixed(1)}s`);
}

function steer(world: ReturnType<typeof createWorld>, input: ReturnType<typeof emptyInput>, t: number): void {
  const { player, enemies, teleporter, portal, projectiles } = world;
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
  input.pressed.utility = threat && player.skillCd.utility <= 0 && player.dashRemain <= 0;
}
