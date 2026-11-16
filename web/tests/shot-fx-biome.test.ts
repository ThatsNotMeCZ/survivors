import { describe, expect, it } from 'bun:test';
import { FLAG_IMPACT, FLAG_PIERCE, FLAG_TETHER, TEAM_ENEMY, TEAM_PLAYER } from '../src/sim/projectiles';
import { shotFxId } from '../src/view/fx-sprites';

describe('Enemy projectile art follows biome', () => {
  it('uses frost-spit on rime and glacial stages', () => {
    expect(shotFxId(TEAM_ENEMY, 0, 'rime')).toBe('frost-spit');
    expect(shotFxId(TEAM_ENEMY, 0, 'cinder')).toBe('cinder-spit');
  });

  it('keeps player skill stems independent of biome', () => {
    expect(shotFxId(TEAM_PLAYER, FLAG_IMPACT, 'rime')).toBe('skill-censer-lob');
    expect(shotFxId(TEAM_PLAYER, FLAG_PIERCE, 'rime')).toBe('skill-aether-pierce');
    expect(shotFxId(TEAM_PLAYER, FLAG_TETHER, 'rime')).toBe('skill-condemn-tether');
  });
});
