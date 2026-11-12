import { describe, expect, it } from 'bun:test';
import {
  FX_CENSER_IMPACT,
  FX_CRUCIBLE_IMPACT,
  FX_HIT,
} from '../src/config';
import { spawnEnemy } from '../src/sim/enemies';
import { FLAG_IMPACT, spawnProjectile } from '../src/sim/projectiles';
import { createWorld, stepWorld } from '../src/sim/world';
import { spawnDelayedStrike } from '../src/sim/zones';
import { eventFxId } from '../src/view/fx-sprites';

describe('Skill Impact Shader FX Separation', () => {
  it('eventFxId returns null for FX_CENSER_IMPACT and FX_CRUCIBLE_IMPACT so stills do not overlay', () => {
    expect(eventFxId(FX_CENSER_IMPACT, 0xffffff, 'dash')).toBeNull();
    expect(eventFxId(FX_CRUCIBLE_IMPACT, 0xffffff, 'dash')).toBeNull();
    expect(eventFxId(FX_HIT, 0xffffff, 'dash')).toBe('hit');
  });

  it('detonateImpacts emits FX_CENSER_IMPACT with radius when a censer lob lands', () => {
    const world = createWorld('penitent');
    const input = {
      moveX: 0,
      moveY: 0,
      aimX: world.player.x + 100,
      aimY: world.player.y,
      held: { primary: false, secondary: false, utility: false, special: false },
      pressed: { primary: false, secondary: false, utility: false, special: false },
    };

    // Spawn an impact projectile (Censer Lob) that has reached destination
    const targetX = world.player.x + 50;
    const targetY = world.player.y;
    spawnProjectile(world.projectiles, {
      x: targetX,
      y: targetY,
      dirX: 1,
      dirY: 0,
      speed: 0,
      lifetime: 0.05,
      radius: 7,
      damage: 15,
      team: 0,
      flags: FLAG_IMPACT,
      destX: targetX,
      destY: targetY,
      impactRadius: 36,
    });

    // Step world to trigger detonateImpacts
    stepWorld(world, input, 0.06);

    let foundImpact = false;
    let foundHit = false;
    for (let i = 0; i < world.fx.count; i += 1) {
      if (world.fx.kind[i] === FX_CENSER_IMPACT) {
        foundImpact = true;
        expect(world.fx.radius[i]).toBe(36);
        expect(world.fx.x[i]).toBe(targetX);
        expect(world.fx.y[i]).toBe(targetY);
      }
      if (world.fx.kind[i] === FX_HIT) {
        foundHit = true;
      }
    }

    expect(foundImpact).toBe(true);
    expect(foundHit).toBe(false);
  });

  it('direct projectile hit on enemy emits FX_HIT (retaining default collision for homunculus)', () => {
    const world = createWorld('runner');
    const input = {
      moveX: 0,
      moveY: 0,
      aimX: world.player.x + 100,
      aimY: world.player.y,
      held: { primary: false, secondary: false, utility: false, special: false },
      pressed: { primary: false, secondary: false, utility: false, special: false },
    };

    const def = world.catalog.entity('ember-mite');
    const enemyIdx = spawnEnemy(world, def, world.player.x + 40, world.player.y);
    expect(enemyIdx).toBeGreaterThanOrEqual(0);

    // Direct bolt projectile (no FLAG_IMPACT)
    spawnProjectile(world.projectiles, {
      x: world.player.x + 38,
      y: world.player.y,
      dirX: 1,
      dirY: 0,
      speed: 100,
      lifetime: 1.0,
      radius: 6,
      damage: 10,
      team: 0,
    });

    stepWorld(world, input, 0.02);

    let foundHit = false;
    let foundCenserImpact = false;
    for (let i = 0; i < world.fx.count; i += 1) {
      if (world.fx.kind[i] === FX_HIT) {
        foundHit = true;
      }
      if (world.fx.kind[i] === FX_CENSER_IMPACT) {
        foundCenserImpact = true;
      }
    }

    expect(foundHit).toBe(true);
    expect(foundCenserImpact).toBe(false);
  });

  it('Crucible Cull strike detonation emits FX_CRUCIBLE_IMPACT with radius', () => {
    const world = createWorld('runner');
    const input = {
      moveX: 0,
      moveY: 0,
      aimX: world.player.x + 100,
      aimY: world.player.y,
      held: { primary: false, secondary: false, utility: false, special: false },
      pressed: { primary: false, secondary: false, utility: false, special: false },
    };

    spawnDelayedStrike(world.zones, {
      x: world.player.x + 60,
      y: world.player.y + 40,
      radius: 45,
      delay: 0.02,
      damage: 90,
    });

    // Step world past delay so it detonates
    stepWorld(world, input, 0.03);

    let foundCrucibleImpact = false;
    for (let i = 0; i < world.fx.count; i += 1) {
      if (world.fx.kind[i] === FX_CRUCIBLE_IMPACT) {
        foundCrucibleImpact = true;
        expect(world.fx.radius[i]).toBe(45);
        expect(world.fx.x[i]).toBe(world.player.x + 60);
        expect(world.fx.y[i]).toBe(world.player.y + 40);
      }
    }

    expect(foundCrucibleImpact).toBe(true);
  });
});
