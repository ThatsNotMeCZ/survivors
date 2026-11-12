import { describe, expect, it } from 'bun:test';
import { catalog } from '../src/data/catalog';
import type { UnlockCondition } from '../src/data/schema';
import {
  checkUnlockCondition,
  getUnlockLabel,
  isEntitySeen,
  isStageVisited,
  type ArchiveRecords,
} from '../src/ui/records';

function createMockRecords(): ArchiveRecords {
  return {
    version: 1,
    totalRuns: 0,
    victories: 0,
    defeats: 0,
    abandons: 0,
    totalPlayTime: 0,
    totalKills: 0,
    fodderKills: 0,
    eliteKills: 0,
    bossKills: 0,
    totalDamageDealt: 0,
    totalDamageTaken: 0,
    totalHealingDone: 0,
    totalGemsCollected: 0,
    totalItemsCollected: 0,
    totalLevelsGained: 0,
    stagesCleared: 0,
    longestRunTime: 0,
    fastestVictoryTime: null,
    highestLevel: 1,
    highestCoefficient: 1,
    mostKillsInRun: 0,
    mostDamageInRun: 0,
    furthestStageIndex: 0,
    bySurvivor: {},
    entityKills: {},
    entityEncounters: {},
    entityLores: {},
    itemPicks: {},
    stageVisits: {},
    stageClears: {},
    recentRuns: [],
  };
}

describe('Redacted Unlock & Discovery Labels', () => {
  it('correctly reports isStageVisited and isEntitySeen', () => {
    const rec = createMockRecords();
    expect(isStageVisited('rime-dock', rec)).toBe(false);
    expect(isEntitySeen('frost-sovereign', rec)).toBe(false);

    rec.stageVisits['rime-dock'] = 1;
    expect(isStageVisited('rime-dock', rec)).toBe(true);

    rec.entityEncounters['frost-sovereign'] = 1;
    expect(isEntitySeen('frost-sovereign', rec)).toBe(true);
  });

  it('redacts The Penitent unlock label across all 4 discovery stages', () => {
    const penitent = catalog.survivor('penitent');
    expect(penitent.unlock).toBeDefined();
    const cond = penitent.unlock!;
    expect(cond.type).toBe('boss-kill');

    // 1. Fresh profile: neither Rime Dock visited nor Frost Sovereign seen
    const recFresh = createMockRecords();
    expect(getUnlockLabel(cond, recFresh)).toBe('Slay the ??? in the ???');
    expect(checkUnlockCondition(cond, recFresh).label).toBe('Slay the ??? in the ???');

    // 2. Rime Dock visited, but Frost Sovereign not encountered yet
    const recVisited = createMockRecords();
    recVisited.stageVisits['rime-dock'] = 1;
    expect(getUnlockLabel(cond, recVisited)).toBe('Slay the ??? in the Rime Dock');
    expect(checkUnlockCondition(cond, recVisited).label).toBe('Slay the ??? in the Rime Dock');

    // 3. Frost Sovereign encountered (e.g. spawned), but Rime Dock not visited in records
    const recBossSeen = createMockRecords();
    recBossSeen.entityEncounters['frost-sovereign'] = 1;
    expect(getUnlockLabel(cond, recBossSeen)).toBe('Slay the Frost Sovereign in the ???');
    expect(checkUnlockCondition(cond, recBossSeen).label).toBe('Slay the Frost Sovereign in the ???');

    // 4. Both Rime Dock visited and Frost Sovereign seen / killed
    const recBoth = createMockRecords();
    recBoth.stageVisits['rime-dock'] = 1;
    recBoth.entityEncounters['frost-sovereign'] = 1;
    expect(getUnlockLabel(cond, recBoth)).toBe('Slay the Frost Sovereign in the Rime Dock');
    expect(checkUnlockCondition(cond, recBoth).label).toBe('Slay the Frost Sovereign in the Rime Dock');
  });

  it('redacts stage-clear unlock conditions for relics', () => {
    const lunarTithe = catalog.item('lunar-tithe');
    expect(lunarTithe.unlock).toBeDefined();
    const cond = lunarTithe.unlock!;
    expect(cond.type).toBe('stage-clear');

    const rec = createMockRecords();
    expect(getUnlockLabel(cond, rec)).toBe('Clear the ???');

    rec.stageVisits['rime-dock'] = 1;
    expect(getUnlockLabel(cond, rec)).toBe('Clear the Rime Dock');
  });

  it('redacts boss-kill relic unlock conditions when boss is unseen', () => {
    const overclock = catalog.item('overclock');
    expect(overclock.unlock).toBeDefined();
    const cond = overclock.unlock!;
    expect(cond.type).toBe('boss-kill');

    const rec = createMockRecords();
    expect(getUnlockLabel(cond, rec)).toBe('Slay the ???');

    rec.entityEncounters['cinder-heart'] = 1;
    expect(getUnlockLabel(cond, rec)).toBe('Slay the Cinder Heart');
  });

  it('obscures stage name in stage-clear multi-clear progress if stage is unvisited', () => {
    const multiClearCond: UnlockCondition = {
      type: 'stage-clear',
      stageId: 'rime-dock',
      count: 3,
      label: 'Clear the Rime Dock 3 times',
    };

    const rec = createMockRecords();
    const stateUnvisited = checkUnlockCondition(multiClearCond, rec);
    expect(stateUnvisited.progress).toBe('0 / 3 ??? Clears');
    expect(stateUnvisited.label).toBe('Clear the ??? 3 times');

    rec.stageVisits['rime-dock'] = 1;
    const stateVisited = checkUnlockCondition(multiClearCond, rec);
    expect(stateVisited.progress).toBe('0 / 3 Rime Dock Clears');
    expect(stateVisited.label).toBe('Clear the Rime Dock 3 times');
  });

  it('preserves non-redacted unlock labels (kills / victories)', () => {
    const calcinedLens = catalog.item('calcined-lens');
    expect(calcinedLens.unlock).toBeDefined();
    const cond = calcinedLens.unlock!;

    const rec = createMockRecords();
    expect(getUnlockLabel(cond, rec)).toBe('Slay 300 Dross across workings');
  });
});
