import { FX_DASH } from '../config';
import type { SkillEffect, SkillSlot } from '../data/schema';
import { emitFx } from './fx';
import type { InputFrame } from './input-frame';
import { TEAM_PLAYER, spawnProjectile } from './projectiles';
import type { World } from './world';

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
  }
}

function fireProjectile(world: World, effect: Extract<SkillEffect, { type: 'projectile' }>): void {
  const { player } = world;
  const dirX = world.aimX - player.x;
  const dirY = world.aimY - player.y;
  const len = Math.hypot(dirX, dirY);
  if (len <= 0.001) return;
  const nx = dirX / len;
  const ny = dirY / len;
  const muzzle = player.radius + 8;
  spawnProjectile(world.projectiles, {
    x: player.x + nx * muzzle,
    y: player.y + ny * muzzle,
    dirX: nx,
    dirY: ny,
    speed: effect.speed,
    lifetime: effect.lifetime,
    radius: effect.radius,
    damage: effect.damage * world.stats.damageMul,
    team: TEAM_PLAYER,
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
  world.player.dashVx = (dx / len) * speed;
  world.player.dashVy = (dy / len) * speed;
  world.player.dashRemain = effect.duration;
  world.player.iframeRemain = effect.iframe;
  emitFx(world.fx, FX_DASH, world.player.x, world.player.y, 0x9ad4ff);
}
