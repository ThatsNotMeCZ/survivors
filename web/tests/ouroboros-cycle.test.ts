import { describe, expect, it } from 'bun:test';
import { canSealWorking, completeWorking, isLastStage, stepLoop } from '../src/sim/loop';
import { createWorld } from '../src/sim/world';

function openLastStagePortal() {
  const world = createWorld('runner', { runSeed: 0xa4f9 });
  const last = world.catalog.loop.stages.length - 1;
  world.stageIndex = last;
  world.bossSpawned = true;
  world.bossDefeated = true;
  world.portal.open = false;
  world.portal.x = 400;
  world.portal.y = 400;
  world.portal.hold = 0;
  world.won = false;
  world.phase = 'play';
  stepLoop(world, 0);
  return world;
}

describe('Ouroboros Cycle', () => {
  it('opens a last-stage portal instead of instant victory', () => {
    const world = openLastStagePortal();
    expect(world.portal.open).toBe(true);
    expect(world.won).toBe(false);
    expect(world.phase).toBe('play');
    expect(isLastStage(world)).toBe(true);
    expect(canSealWorking(world)).toBe(true);
  });

  it('wraps to Cinder Yard with inventory and stageGen kept climbing', () => {
    const world = openLastStagePortal();
    const inv = world.inventory.map((inst) => ({ ...inst }));
    const gen = world.stageGen;
    const time = world.runTime;
    world.player.x = world.portal.x;
    world.player.y = world.portal.y;
    const hold = world.catalog.loop.portalHold;
    stepLoop(world, hold + 0.05);
    expect(world.cycleIndex).toBe(1);
    expect(world.stageIndex).toBe(0);
    expect(world.catalog.loop.stages[world.stageIndex].id).toBe('cinder-yard');
    expect(world.stageGen).toBe(gen + 1);
    expect(world.runTime).toBeGreaterThanOrEqual(time);
    expect(world.inventory).toEqual(inv);
    expect(world.won).toBe(false);
    expect(world.portal.open).toBe(false);
  });

  it('completeWorking seals victory without wrapping', () => {
    const world = openLastStagePortal();
    expect(completeWorking(world)).toBe(true);
    expect(world.won).toBe(true);
    expect(world.phase).toBe('victory');
    expect(world.cycleIndex).toBe(0);
    expect(completeWorking(world)).toBe(false);
  });

  it('keeps coefficient on runTime only after wrap', () => {
    const world = openLastStagePortal();
    world.runTime = 120;
    stepLoop(world, 0);
    const before = world.coefficient;
    expect(before).toBeCloseTo(1 + 120 * world.catalog.loop.difficulty.perSecond, 5);
    world.player.x = world.portal.x;
    world.player.y = world.portal.y;
    stepLoop(world, world.catalog.loop.portalHold + 0.05);
    expect(world.cycleIndex).toBe(1);
    expect(world.coefficient).toBeCloseTo(
      1 + world.runTime * world.catalog.loop.difficulty.perSecond,
      5,
    );
  });
});
