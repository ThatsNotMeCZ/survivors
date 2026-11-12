import { describe, expect, it } from 'bun:test';
import { rollChoices } from '../src/sim/level';
import { dailySeed, formatSeedTag, utcYmd } from '../src/sim/rng';
import { createWorld } from '../src/sim/world';

function obstacleSnapshot(world: ReturnType<typeof createWorld>) {
  const points: { x: number; y: number; type: string }[] = [];
  for (let i = 0; i < world.obstacles.cap; i += 1) {
    if (world.obstacles.alive[i] === 0) continue;
    const obs = world.obstacles.items[i];
    points.push({ x: obs.x, y: obs.y, type: obs.type });
  }
  return points;
}

describe('Daily Rite seed', () => {
  it('formats a four-hex seed tag', () => {
    expect(formatSeedTag(0xa4f9)).toBe('#A4F9');
    expect(formatSeedTag(15)).toBe('#000F');
  });

  it('hashes UTC date into a stable daily seed', () => {
    expect(utcYmd(Date.UTC(2026, 10, 11))).toBe('2026-11-11');
    expect(dailySeed('2026-11-11')).toBe(dailySeed('2026-11-11'));
    expect(dailySeed('2026-11-11')).not.toBe(dailySeed('2026-11-12'));
  });

  it('repeats teleporter, obstacles, and first offers for the same run seed', () => {
    const a = createWorld('runner', { runSeed: 0xa4f9 });
    const b = createWorld('runner', { runSeed: 0xa4f9 });
    expect(a.teleporter.x).toBe(b.teleporter.x);
    expect(a.teleporter.y).toBe(b.teleporter.y);
    expect(obstacleSnapshot(a)).toEqual(obstacleSnapshot(b));
    expect(rollChoices(a).map((item) => item.id)).toEqual(rollChoices(b).map((item) => item.id));
  });

  it('changes layout and offers when the seed changes', () => {
    const a = createWorld('runner', { runSeed: 0xa4f9 });
    const b = createWorld('runner', { runSeed: 0xbeef });
    const sameTel = a.teleporter.x === b.teleporter.x && a.teleporter.y === b.teleporter.y;
    const sameObs = JSON.stringify(obstacleSnapshot(a)) === JSON.stringify(obstacleSnapshot(b));
    expect(sameTel && sameObs).toBe(false);
  });
});
