import { describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  CHASE_ATTACK_COOLDOWN,
  CHASE_ATTACK_DURATION,
  isEnemyAttacking,
  spawnEnemy,
  stepEnemies,
} from '../src/sim/enemies';
import { emptyInput } from '../src/sim/input-frame';
import { createWorld, stepWorld } from '../src/sim/world';
import { generateProceduralSheets } from '../src/view/procedural-pixel-art';

describe('Attack Animation & Attack State Lifecycle', () => {
  it('triggers a single attack on melee chaser reaching range and does not reset attackRemain every tick', () => {
    const world = createWorld();
    world.player.x = 200;
    world.player.y = 200;

    const emberMite = world.catalog.entity('ember-mite');
    const idx = spawnEnemy(world, emberMite, 215, 200);
    expect(idx).toBeGreaterThanOrEqual(0);

    // Initial state: not attacking yet
    expect(world.enemies.attackRemain[idx]).toBe(0);
    expect(world.enemies.attackCd[idx]).toBe(0);
    expect(isEnemyAttacking(world, idx)).toBe(false);

    // Step world with enemy in attack range: attack begins
    stepEnemies(world, 0.05);
    expect(isEnemyAttacking(world, idx)).toBe(true);
    expect(world.enemies.attackRemain[idx]).toBeCloseTo(CHASE_ATTACK_DURATION, 2);
    expect(world.enemies.attackCd[idx]).toBeCloseTo(CHASE_ATTACK_COOLDOWN, 2);

    // Advance 0.1s more: attackRemain should count down, NOT reset to CHASE_ATTACK_DURATION
    stepEnemies(world, 0.1);
    expect(isEnemyAttacking(world, idx)).toBe(true);
    expect(world.enemies.attackRemain[idx]).toBeCloseTo(CHASE_ATTACK_DURATION - 0.1, 2);

    // Advance until attack completes (remaining 0.25s of the 0.35s attack duration)
    stepEnemies(world, 0.26);
    expect(world.enemies.attackRemain[idx]).toBe(0);
    expect(isEnemyAttacking(world, idx)).toBe(false);

    // Enemy is still in melee range, but on cooldown: should NOT trigger another attack immediately
    expect(world.enemies.attackCd[idx]).toBeGreaterThan(0);
    stepEnemies(world, 0.1);
    expect(world.enemies.attackRemain[idx]).toBe(0);
    expect(isEnemyAttacking(world, idx)).toBe(false);

    // Advance past remaining cooldown
    stepEnemies(world, world.enemies.attackCd[idx] + 0.01);
    // Cooldown elapsed and still in range -> new attack initiates!
    expect(isEnemyAttacking(world, idx)).toBe(true);
    expect(world.enemies.attackRemain[idx]).toBeGreaterThan(0);
  });

  it('preserves continuous contact DPS during and between attacks', () => {
    const world = createWorld();
    world.player.x = 200;
    world.player.y = 200;
    world.player.hp = 100;
    world.player.iframeRemain = 0;

    const emberMite = world.catalog.entity('ember-mite');
    const idx = spawnEnemy(world, emberMite, 200, 200); // directly on player

    // Run world steps (covers attack duration + cooldown)
    const initialHp = world.player.hp;
    const input = emptyInput();
    for (let s = 0; s < 10; s += 1) {
      stepWorld(world, input, 0.1);
    }

    // Player should have taken continuous damage
    expect(world.player.hp).toBeLessThan(initialHp);
  });

  it('ranged enemy windup triggers attack state that ends when projectile fires', () => {
    const world = createWorld();
    world.player.x = 200;
    world.player.y = 200;

    const spitter = world.catalog.entity('ember-spitter');
    const idx = spawnEnemy(world, spitter, 300, 200); // within range (280)
    world.enemies.attackCd[idx] = 0; // ready to attack

    // Next step initiates windup
    stepEnemies(world, 0.05);
    expect(world.enemies.windup[idx]).toBeGreaterThan(0);
    expect(isEnemyAttacking(world, idx)).toBe(true);

    // Step until windup completes
    const windupLeft = world.enemies.windup[idx];
    stepEnemies(world, windupLeft + 0.01);

    // Windup is complete: attack ended, attackCd set, no longer in attack state
    expect(world.enemies.windup[idx]).toBe(0);
    expect(world.enemies.attackCd[idx]).toBeGreaterThan(0);
    expect(isEnemyAttacking(world, idx)).toBe(false);
  });

  it('manifest.json defines entity attack animation with repeat: 0', () => {
    const manifestRaw = readFileSync(join(process.cwd(), 'public/sprites/manifest.json'), 'utf-8');
    const manifest = JSON.parse(manifestRaw);

    for (const [entityId, def] of Object.entries<any>(manifest.entities)) {
      if (def.anims?.attack) {
        expect(def.anims.attack.repeat).toBe(0);
      }
    }
  });

  it('generateProceduralSheets defines attack animation with repeat: 0', () => {
    const sheets = generateProceduralSheets();
    for (const [id, sheet] of sheets) {
      if (sheet.anims.attack) {
        expect(sheet.anims.attack.repeat).toBe(0);
      }
    }
  });
});
