import { describe, expect, it } from 'bun:test';
import { FX_HIT, FX_TETHER_LATCH } from '../src/config';
import { spawnEnemy } from '../src/sim/enemies';
import { emptyInput } from '../src/sim/input-frame';
import { FLAG_TETHER, spawnProjectile } from '../src/sim/projectiles';
import { createWorld, stepWorld } from '../src/sim/world';

const DT = 1 / 60;

describe('Condemnation Tether Mechanics', () => {
  it('pierces through lesser enemies dealing damage and stops on the first elite', () => {
    const world = createWorld('penitent');
    world.stats.critChance = 0;
    const input = emptyInput();

    const fodderDef = world.catalog.entity('ember-mite');
    const eliteDef = world.catalog.entity('ember-mite');

    // Spawn 2 fodder enemies directly in the flight path
    const f1 = spawnEnemy(world, fodderDef, world.player.x + 60, world.player.y, false);
    const f2 = spawnEnemy(world, fodderDef, world.player.x + 120, world.player.y, false);

    // Spawn an elite behind them
    const elite = spawnEnemy(world, eliteDef, world.player.x + 180, world.player.y, true);

    // Spawn another elite even further behind to ensure tether stops on the first
    const elite2 = spawnEnemy(world, eliteDef, world.player.x + 260, world.player.y, true);

    expect(f1).toBeGreaterThanOrEqual(0);
    expect(f2).toBeGreaterThanOrEqual(0);
    expect(elite).toBeGreaterThanOrEqual(0);
    expect(elite2).toBeGreaterThanOrEqual(0);

    const initialFodderHp1 = world.enemies.hp[f1];
    const initialFodderHp2 = world.enemies.hp[f2];

    // Fire Tether (special)
    input.aimX = world.player.x + 300;
    input.aimY = world.player.y;
    input.pressed.special = true;
    stepWorld(world, input, DT);
    input.pressed.special = false;

    // Step world to let projectile travel through f1, f2 and hit elite
    let latchEmitted = false;
    for (let step = 0; step < 30; step += 1) {
      stepWorld(world, input, DT);
      for (let i = 0; i < world.fx.count; i += 1) {
        if (world.fx.kind[i] === FX_TETHER_LATCH) {
          latchEmitted = true;
          expect(world.fx.x[i]).toBe(world.enemies.x[elite]);
          expect(world.fx.y[i]).toBe(world.enemies.y[elite]);
        }
      }
      if (world.enemies.rootRemain[elite] > 0) break;
    }

    // Fodder enemies took damage or died (45 damage > 14 HP of mite)
    expect(world.enemies.hp[f1] < initialFodderHp1 || world.enemies.alive[f1] === 0).toBe(true);
    expect(world.enemies.hp[f2] < initialFodderHp2 || world.enemies.alive[f2] === 0).toBe(true);

    // First elite is rooted and tethered
    expect(world.enemies.rootRemain[elite]).toBeGreaterThan(0);
    expect(world.enemies.tetherDps[elite]).toBeGreaterThan(0);
    expect(latchEmitted).toBe(true);

    // Second elite was NOT hit and NOT rooted
    expect(world.enemies.rootRemain[elite2]).toBe(0);

    // Tether projectile is killed upon anchoring
    let activeTethers = 0;
    for (let i = 0; i < world.projectiles.alive.length; i += 1) {
      if (world.projectiles.alive[i] && (world.projectiles.flags[i] & FLAG_TETHER) !== 0) {
        activeTethers += 1;
      }
    }
    expect(activeTethers).toBe(0);
  });

  it('sears lesser enemies that touch the stretched tether chain segment between player and rooted elite', () => {
    const world = createWorld('penitent');
    const input = emptyInput();

    const fodderDef = world.catalog.entity('ember-mite');
    const eliteDef = world.catalog.entity('ember-mite');

    // Elite located at (player.x + 200, player.y)
    const elite = spawnEnemy(world, eliteDef, world.player.x + 200, world.player.y, true);
    world.enemies.rootRemain[elite] = 2.5;
    world.enemies.rootDuration[elite] = 2.5;
    world.enemies.tetherDps[elite] = 28;

    // Fodder located on the line segment between player and elite (player.x + 100, player.y)
    const fodder = spawnEnemy(world, fodderDef, world.player.x + 100, world.player.y, false);
    const initialHp = world.enemies.hp[fodder];

    // Step world a few frames
    for (let i = 0; i < 15; i += 1) {
      stepWorld(world, input, DT);
    }

    // Fodder touching the chain takes continuous damage
    expect(world.enemies.hp[fodder]).toBeLessThan(initialHp);
  });
});
