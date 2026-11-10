import { describe, expect, it } from 'bun:test';
import {
  createWorld,
  damagePlayer,
  ONE_SHOT_PROTECTION_IFRAME,
  ONE_SHOT_PROTECTION_THRESHOLD,
} from '../src/sim/world';

describe('Player One-Shot Protection (OSP)', () => {
  it('defines threshold at 90% and grants an iframe window', () => {
    expect(ONE_SHOT_PROTECTION_THRESHOLD).toBe(0.9);
    expect(ONE_SHOT_PROTECTION_IFRAME).toBeGreaterThan(0);
  });

  it('leaves 1 HP and grants iframes when taking overkill damage at 100% HP', () => {
    const world = createWorld('runner');
    expect(world.player.hp).toBe(100);
    expect(world.player.maxHp).toBe(100);

    // Overkill damage: 500
    damagePlayer(world, 500);

    expect(world.player.hp).toBe(1);
    expect(world.player.iframeRemain).toBe(ONE_SHOT_PROTECTION_IFRAME);
    expect(world.damageTaken).toBe(99);
  });

  it('leaves 1 HP when taking exact lethal damage at 100% HP', () => {
    const world = createWorld('runner');
    expect(world.player.hp).toBe(100);

    // Exact lethal damage: 100
    damagePlayer(world, 100);

    expect(world.player.hp).toBe(1);
    expect(world.player.iframeRemain).toBe(ONE_SHOT_PROTECTION_IFRAME);
    expect(world.damageTaken).toBe(99);
  });

  it('leaves 1 HP when taking sub-1HP non-fatal damage (e.g. 99.5) at 100% HP', () => {
    const world = createWorld('runner');
    expect(world.player.hp).toBe(100);

    // Damage that would leave 0.5 HP without OSP
    damagePlayer(world, 99.5);

    expect(world.player.hp).toBe(1);
    expect(world.player.iframeRemain).toBe(ONE_SHOT_PROTECTION_IFRAME);
    expect(world.damageTaken).toBe(99);
  });

  it('protects player when at exactly 90% HP (threshold boundary)', () => {
    const world = createWorld('runner');
    world.player.hp = 90;

    // Overkill damage: 200
    damagePlayer(world, 200);

    expect(world.player.hp).toBe(1);
    expect(world.player.iframeRemain).toBe(ONE_SHOT_PROTECTION_IFRAME);
    expect(world.damageTaken).toBe(89);
  });

  it('protects player when above 90% HP (e.g. 95% HP)', () => {
    const world = createWorld('runner');
    world.player.hp = 95;

    damagePlayer(world, 200);

    expect(world.player.hp).toBe(1);
    expect(world.player.iframeRemain).toBe(ONE_SHOT_PROTECTION_IFRAME);
    expect(world.damageTaken).toBe(94);
  });

  it('applies normal non-fatal damage when above 90% HP if HP remains >= 1', () => {
    const world = createWorld('runner');
    expect(world.player.hp).toBe(100);

    damagePlayer(world, 30);

    expect(world.player.hp).toBe(70);
    expect(world.player.iframeRemain).toBe(0);
    expect(world.damageTaken).toBe(30);
  });

  it('does NOT protect player when below 90% HP (e.g. 89% HP)', () => {
    const world = createWorld('runner');
    world.player.hp = 89;

    damagePlayer(world, 100);

    expect(world.player.hp).toBeLessThanOrEqual(0);
  });

  it('does NOT protect player when at 50% HP', () => {
    const world = createWorld('runner');
    world.player.hp = 50;

    damagePlayer(world, 60);

    expect(world.player.hp).toBeLessThanOrEqual(0);
  });

  it('absorbs immediate follow-up attack during the iframe grace window', () => {
    const world = createWorld('runner');
    // First attack triggers OSP and grants iframes
    damagePlayer(world, 300);
    expect(world.player.hp).toBe(1);
    expect(world.player.iframeRemain).toBe(ONE_SHOT_PROTECTION_IFRAME);

    // Immediate next tick hit is absorbed by the iframe
    damagePlayer(world, 100);
    expect(world.player.hp).toBe(1);
  });

  it('allows death once iframes expire after OSP has triggered', () => {
    const world = createWorld('runner');
    // First attack triggers OSP and grants iframes
    damagePlayer(world, 300);
    expect(world.player.hp).toBe(1);

    // Advance time so iframes expire
    world.player.iframeRemain = 0;

    // Follow-up hit kills the player because HP (1) is below 90%
    damagePlayer(world, 10);
    expect(world.player.hp).toBeLessThanOrEqual(0);
  });

  it('respects armor and hazard resist before applying OSP', () => {
    const world = createWorld('runner');
    world.stats.armor = 0.5; // 50% armor
    world.stats.hazardResist = 0.5; // 50% hazard resist

    // Raw hazard damage 200 -> after armor (100) -> after hazard resist (50)
    // 50 damage is non-fatal: 100 - 50 = 50 HP (no OSP needed)
    damagePlayer(world, 200, true);
    expect(world.player.hp).toBe(50);
    expect(world.player.iframeRemain).toBe(0);

    // Now player heals back to full
    world.player.hp = 100;

    // Raw hazard damage 800 -> after armor (400) -> after hazard resist (200)
    // 200 damage is fatal: OSP triggers!
    damagePlayer(world, 800, true);
    expect(world.player.hp).toBe(1);
    expect(world.player.iframeRemain).toBe(ONE_SHOT_PROTECTION_IFRAME);
  });
});
