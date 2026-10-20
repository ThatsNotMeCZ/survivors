import { FX_DASH } from '../config';
import type { SkillEffect, SkillSlot } from '../data/schema';
import { emitFx } from './fx';
import type { InputFrame } from './input-frame';
import {
  FLAG_FLYOVER,
  FLAG_IMPACT,
  FLAG_PIERCE,
  FLAG_TETHER,
  TEAM_PLAYER,
  spawnProjectile,
} from './projectiles';
import { applySlow } from './status';
import type { World } from './world';
import { spawnDecoy, spawnDelayedStrike, spawnSlowLine } from './zones';

const SLOTS: SkillSlot[] = ['primary', 'secondary', 'utility', 'special'];

export function tickSkillCooldowns(world: World, dt: number): void {
  for (const slot of SLOTS) {
    world.player.skillCd[slot] = Math.max(0, world.player.skillCd[slot] - dt);
  }
}

export function trySkills(world: World, input: InputFrame): void {
  for (const slot of SLOTS) {
    const skillId = world.survivor.skills[slot];
    if (!skillId) continue;
    const skill = world.catalog.skill(skillId);
    const want = skill.input === 'hold' ? input.held[slot] : input.pressed[slot];
    if (!want || world.player.skillCd[slot] > 0) continue;
    if (slot === 'utility' && world.player.dashRemain > 0) continue;

    for (const effect of skill.effects) {
      applyEffect(world, input, effect);
    }
    world.player.skillCd[slot] = skill.cooldown * world.stats.cooldownMul;
  }
}

function applyEffect(world: World, input: InputFrame, effect: SkillEffect): void {
  switch (effect.type) {
    case 'projectile':
      fireProjectile(world, effect);
      return;
    case 'dash':
      startDash(world, input, effect);
      return;
    case 'self-slow':
      applySlow(world.player, effect.mul, effect.duration);
      return;
    case 'delayed-strike':
      spawnDelayedStrike(world.zones, {
        x: world.aimX,
        y: world.aimY,
        radius: effect.radius,
        delay: effect.delay,
        damage: effect.damage * world.stats.damageMul,
      });
      return;
    case 'slow-line':
      laySlowLine(world, effect);
      return;
    case 'tether':
      fireTether(world, effect);
      return;
  }
}

function fireProjectile(world: World, effect: Extract<SkillEffect, { type: 'projectile' }>): void {
  const aim = aimDir(world);
  if (!aim) return;
  const muzzle = world.player.radius + 8;
  let flags = 0;
  if (effect.pierce) flags |= FLAG_PIERCE;
  if (effect.flyOver) flags |= FLAG_FLYOVER;
  const impactRadius = effect.impactRadius ?? 0;
  if (impactRadius > 0) flags |= FLAG_IMPACT | FLAG_FLYOVER;
  spawnProjectile(world.projectiles, {
    x: world.player.x + aim.x * muzzle,
    y: world.player.y + aim.y * muzzle,
    dirX: aim.x,
    dirY: aim.y,
    speed: effect.speed,
    lifetime: effect.lifetime,
    radius: effect.radius,
    damage: effect.damage * world.stats.damageMul,
    team: TEAM_PLAYER,
    flags,
    destX: world.aimX,
    destY: world.aimY,
    impactRadius,
  });
}

function fireTether(world: World, effect: Extract<SkillEffect, { type: 'tether' }>): void {
  const aim = aimDir(world);
  if (!aim) return;
  const muzzle = world.player.radius + 8;
  spawnProjectile(world.projectiles, {
    x: world.player.x + aim.x * muzzle,
    y: world.player.y + aim.y * muzzle,
    dirX: aim.x,
    dirY: aim.y,
    speed: effect.speed,
    lifetime: effect.lifetime,
    radius: effect.radius,
    damage: 0,
    team: TEAM_PLAYER,
    flags: FLAG_TETHER,
    rootDuration: effect.rootDuration,
    tetherDps: effect.fodderContactDps * world.stats.damageMul,
  });
}

function laySlowLine(world: World, effect: Extract<SkillEffect, { type: 'slow-line' }>): void {
  const aim = aimDir(world);
  if (!aim) return;
  const perpX = -aim.y;
  const perpY = aim.x;
  const offset = effect.offset ?? 56;
  spawnSlowLine(world.zones, {
    x: world.player.x + aim.x * offset,
    y: world.player.y + aim.y * offset,
    dirX: perpX,
    dirY: perpY,
    length: effect.length,
    width: effect.width,
    duration: effect.duration,
    slowMul: effect.slowMul,
    damage: effect.damage * world.stats.damageMul,
    fodderOnly: effect.fodderOnly,
  });
}

function startDash(
  world: World,
  input: InputFrame,
  effect: Extract<SkillEffect, { type: 'dash' }>,
): void {
  if (effect.duration <= 0) return;
  let dx = input.moveX;
  let dy = input.moveY;
  if (Math.hypot(dx, dy) < 0.01) {
    dx = world.aimX - world.player.x;
    dy = world.aimY - world.player.y;
  }
  const len = Math.hypot(dx, dy);
  if (len < 0.001) return;
  const speed = effect.distance / effect.duration;
  if ((effect.decoyDuration ?? 0) > 0) {
    spawnDecoy(world.decoy, world.player.x, world.player.y, effect.decoyDuration ?? 0);
  }
  world.player.dashVx = (dx / len) * speed;
  world.player.dashVy = (dy / len) * speed;
  world.player.dashRemain = effect.duration;
  world.player.iframeRemain = effect.iframe;
  emitFx(world.fx, FX_DASH, world.player.x, world.player.y, 0x9ad4ff);
}

function aimDir(world: World): { x: number; y: number } | null {
  const dirX = world.aimX - world.player.x;
  const dirY = world.aimY - world.player.y;
  const len = Math.hypot(dirX, dirY);
  if (len <= 0.001) return null;
  return { x: dirX / len, y: dirY / len };
}
