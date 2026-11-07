import { catalog } from '../data/catalog';
import type { ItemDef, SurvivorDef, UnlockCondition } from '../data/schema';
import { currentStage } from '../sim/loop';
import type { World } from '../sim/world';
import { hasQueryFlag } from './settings';

export const RECORDS_VERSION = 1;
const STORAGE_KEY = 'survivors.records.v1';
const MAX_RECENT_RUNS = 10;

export type RunOutcome = 'victory' | 'defeat' | 'abandon';

export type SurvivorRecord = {
  runs: number;
  victories: number;
  defeats: number;
  abandons: number;
  kills: number;
  bossesDefeated: number;
  bestTime: number;
  fastestVictory: number | null;
  highestLevel: number;
  totalPlayTime: number;
  totalDamageDealt: number;
};

export type RunHistoryEntry = {
  timestamp: number;
  outcome: RunOutcome;
  survivorId: string;
  stageId: string;
  stageName: string;
  runTime: number;
  level: number;
  coefficient: number;
  kills: number;
  bossesDefeated: number;
  damageDealt: number;
  items: { id: string; stacks: number }[];
};

export type ArchiveRecords = {
  version: number;
  totalRuns: number;
  victories: number;
  defeats: number;
  abandons: number;
  totalPlayTime: number;
  totalKills: number;
  fodderKills: number;
  eliteKills: number;
  bossKills: number;
  totalDamageDealt: number;
  totalDamageTaken: number;
  totalHealingDone: number;
  totalGemsCollected: number;
  totalItemsCollected: number;
  totalLevelsGained: number;
  stagesCleared: number;
  longestRunTime: number;
  fastestVictoryTime: number | null;
  highestLevel: number;
  highestCoefficient: number;
  mostKillsInRun: number;
  mostDamageInRun: number;
  furthestStageIndex: number;
  bySurvivor: Record<string, SurvivorRecord>;
  entityKills: Record<string, number>;
  entityEncounters: Record<string, number>;
  entityLores: Record<string, number>;
  itemPicks: Record<string, number>;
  stageVisits: Record<string, number>;
  stageClears: Record<string, number>;
  recentRuns: RunHistoryEntry[];
};

type WorldProgressSnapshot = {
  totalKills: number;
  fodderKills: number;
  eliteKills: number;
  bossKills: number;
  stagesCleared: number;
  maxVisitedStage: number;
  killsByEntity: Record<string, number>;
  encountersByEntity: Record<string, number>;
};

const recordedWorlds = new WeakSet<World>();
const committedSnapshots = new WeakMap<World, WorldProgressSnapshot>();
let cached: ArchiveRecords | null = null;

function emptyRecords(): ArchiveRecords {
  return {
    version: RECORDS_VERSION,
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

function emptySurvivorRecord(): SurvivorRecord {
  return {
    runs: 0,
    victories: 0,
    defeats: 0,
    abandons: 0,
    kills: 0,
    bossesDefeated: 0,
    bestTime: 0,
    fastestVictory: null,
    highestLevel: 1,
    totalPlayTime: 0,
    totalDamageDealt: 0,
  };
}

export function getRecords(): ArchiveRecords {
  if (cached) return cached;
  cached = normalizeRecords(readStored());
  return cached;
}

export function resetRecords(): ArchiveRecords {
  const fresh = emptyRecords();
  cached = fresh;
  writeStored(fresh);
  return fresh;
}

export function recordItemPick(itemId: string): void {
  if (hasQueryFlag('smoke')) return;
  const rec = getRecords();
  rec.totalItemsCollected += 1;
  rec.itemPicks[itemId] = (rec.itemPicks[itemId] ?? 0) + 1;
  writeStored(rec);
}

export function recordLorePickup(entityId: string): boolean {
  if (hasQueryFlag('smoke')) return false;
  const rec = getRecords();
  const already = (rec.entityLores[entityId] ?? 0) > 0;
  rec.entityLores[entityId] = (rec.entityLores[entityId] ?? 0) + 1;
  writeStored(rec);
  return !already;
}

export function commitWorldProgress(world: World): ArchiveRecords {
  const rec = getRecords();
  if (hasQueryFlag('smoke')) return rec;

  let snap = committedSnapshots.get(world);
  if (!snap) {
    snap = {
      totalKills: 0,
      fodderKills: 0,
      eliteKills: 0,
      bossKills: 0,
      stagesCleared: 0,
      maxVisitedStage: -1,
      killsByEntity: {},
      encountersByEntity: {},
    };
    committedSnapshots.set(world, snap);
  }

  let dirty = false;

  const dkTotal = Math.max(0, world.kills.total - snap.totalKills);
  const dkFodder = Math.max(0, world.kills.fodder - snap.fodderKills);
  const dkElite = Math.max(0, world.kills.elite - snap.eliteKills);
  const dkBoss = Math.max(0, world.kills.boss - snap.bossKills);
  if (dkTotal > 0 || dkFodder > 0 || dkElite > 0 || dkBoss > 0) {
    rec.totalKills += dkTotal;
    rec.fodderKills += dkFodder;
    rec.eliteKills += dkElite;
    rec.bossKills += dkBoss;
    snap.totalKills = world.kills.total;
    snap.fodderKills = world.kills.fodder;
    snap.eliteKills = world.kills.elite;
    snap.bossKills = world.kills.boss;
    dirty = true;
  }

  for (const [entityId, count] of Object.entries(world.killsByEntity)) {
    const prev = snap.killsByEntity[entityId] ?? 0;
    const delta = Math.max(0, count - prev);
    if (delta > 0) {
      rec.entityKills[entityId] = (rec.entityKills[entityId] ?? 0) + delta;
      snap.killsByEntity[entityId] = count;
      dirty = true;
    }
  }

  for (const [entityId, count] of Object.entries(world.encountersByEntity)) {
    const prev = snap.encountersByEntity[entityId] ?? 0;
    const delta = Math.max(0, count - prev);
    if (delta > 0) {
      rec.entityEncounters[entityId] = (rec.entityEncounters[entityId] ?? 0) + delta;
      snap.encountersByEntity[entityId] = count;
      dirty = true;
    }
  }

  const stages = world.catalog.loop.stages;
  const maxVisited = Math.min(world.stageIndex, stages.length - 1);
  if (maxVisited > snap.maxVisitedStage) {
    for (let i = snap.maxVisitedStage + 1; i <= maxVisited; i += 1) {
      const stId = stages[i].id;
      rec.stageVisits[stId] = (rec.stageVisits[stId] ?? 0) + 1;
    }
    snap.maxVisitedStage = maxVisited;
    if (world.stageIndex > rec.furthestStageIndex) {
      rec.furthestStageIndex = world.stageIndex;
    }
    dirty = true;
  }

  const clearedCount = Math.min(world.stagesCleared, stages.length);
  if (clearedCount > snap.stagesCleared) {
    for (let i = snap.stagesCleared; i < clearedCount; i += 1) {
      const stId = stages[i].id;
      rec.stageClears[stId] = (rec.stageClears[stId] ?? 0) + 1;
    }
    rec.stagesCleared += clearedCount - snap.stagesCleared;
    snap.stagesCleared = clearedCount;
    dirty = true;
  }

  if (dirty) writeStored(rec);
  return rec;
}

export function isStageVisited(stageId: string, rec: ArchiveRecords = getRecords()): boolean {
  return (rec.stageVisits[stageId] ?? 0) > 0 || (rec.stageClears[stageId] ?? 0) > 0;
}

export function isEntitySeen(entityId: string, rec: ArchiveRecords = getRecords()): boolean {
  return (rec.entityEncounters[entityId] ?? 0) > 0 || (rec.entityKills[entityId] ?? 0) > 0;
}

export function getUnlockLabel(
  cond: UnlockCondition | undefined,
  rec: ArchiveRecords = getRecords(),
): string {
  if (!cond) return 'Unlocked';
  let text = cond.label;

  if (cond.type === 'stage-clear') {
    const stage = catalog.loop.stages.find((s) => s.id === cond.stageId);
    if (stage && !isStageVisited(stage.id, rec)) {
      text = text.split(stage.name).join('???');
    }
    return text;
  }

  if (cond.type === 'boss-kill') {
    const entity = catalog.entities.find((e) => e.id === cond.entityId);
    if (entity && !isEntitySeen(cond.entityId, rec)) {
      text = text.split(entity.name).join('???');
    }
    const stageId = cond.stageId ?? catalog.loop.stages.find((s) => s.boss === cond.entityId)?.id;
    if (stageId) {
      const stage = catalog.loop.stages.find((s) => s.id === stageId);
      if (stage && !isStageVisited(stage.id, rec)) {
        text = text.split(stage.name).join('???');
      }
    }
    return text;
  }

  return text;
}

export function checkUnlockCondition(
  cond: UnlockCondition | undefined,
  rec: ArchiveRecords = getRecords(),
): { unlocked: boolean; progress: string; label: string } {
  const label = getUnlockLabel(cond, rec);
  if (!cond) return { unlocked: true, progress: 'Unlocked', label };
  if (cond.type === 'stage-clear') {
    const need = cond.count ?? 1;
    const have = rec.stageClears[cond.stageId] ?? 0;
    const stage = catalog.loop.stages.find((s) => s.id === cond.stageId);
    const stageName = isStageVisited(cond.stageId, rec) ? (stage?.name ?? cond.stageId) : '???';
    return {
      unlocked: have >= need,
      progress: need > 1 ? `${Math.min(have, need)} / ${need} ${stageName} Clears` : have >= 1 ? 'Cleared' : '0 / 1 Cleared',
      label,
    };
  }
  if (cond.type === 'boss-kill') {
    const need = cond.count ?? 1;
    const have = rec.entityKills[cond.entityId] ?? 0;
    return {
      unlocked: have >= need,
      progress: need > 1 ? `${Math.min(have, need)} / ${need} Slain` : have >= 1 ? 'Slain' : '0 / 1 Slain',
      label,
    };
  }
  if (cond.type === 'total-kills') {
    const have = rec.totalKills;
    return {
      unlocked: have >= cond.count,
      progress: `${Math.min(have, cond.count).toLocaleString()} / ${cond.count.toLocaleString()} Slain`,
      label,
    };
  }
  if (cond.type === 'elite-kills') {
    const have = rec.eliteKills;
    return {
      unlocked: have >= cond.count,
      progress: `${Math.min(have, cond.count).toLocaleString()} / ${cond.count.toLocaleString()} Elites Slain`,
      label,
    };
  }
  const have = rec.victories;
  return {
    unlocked: have >= cond.count,
    progress: `${Math.min(have, cond.count)} / ${cond.count} Transmutations`,
    label,
  };
}

export function isItemUnlocked(item: ItemDef, rec: ArchiveRecords = getRecords()): boolean {
  return checkUnlockCondition(item.unlock, rec).unlocked;
}

export function isSurvivorUnlocked(survivor: SurvivorDef, rec: ArchiveRecords = getRecords()): boolean {
  return checkUnlockCondition(survivor.unlock, rec).unlocked;
}

export function getUnlockedItemIds(rec: ArchiveRecords = getRecords()): Set<string> {
  const out = new Set<string>();
  for (const item of catalog.items) {
    if (isItemUnlocked(item, rec)) out.add(item.id);
  }
  return out;
}

export function getCollectedLoreIds(rec: ArchiveRecords = getRecords()): Set<string> {
  const out = new Set<string>();
  for (const [id, count] of Object.entries(rec.entityLores)) {
    if (count > 0) out.add(id);
  }
  return out;
}

export function hasRecordedWorld(world: World): boolean {
  return recordedWorlds.has(world);
}

export function recordRunEnd(world: World, outcome: RunOutcome): ArchiveRecords {
  const rec = getRecords();
  if (hasQueryFlag('smoke') || recordedWorlds.has(world)) {
    return rec;
  }
  if (outcome === 'abandon' && world.runTime < 1 && world.kills.total === 0) {
    recordedWorlds.add(world);
    return rec;
  }
  recordedWorlds.add(world);

  const stage = currentStage(world);
  const survivorId = world.survivor.id;
  const surv = rec.bySurvivor[survivorId] ?? emptySurvivorRecord();

  rec.totalRuns += 1;
  surv.runs += 1;
  if (outcome === 'victory') {
    rec.victories += 1;
    surv.victories += 1;
    if (rec.fastestVictoryTime === null || world.runTime < rec.fastestVictoryTime) {
      rec.fastestVictoryTime = world.runTime;
    }
    if (surv.fastestVictory === null || world.runTime < surv.fastestVictory) {
      surv.fastestVictory = world.runTime;
    }
  } else if (outcome === 'defeat') {
    rec.defeats += 1;
    surv.defeats += 1;
  } else {
    rec.abandons += 1;
    surv.abandons += 1;
  }

  rec.totalPlayTime += world.runTime;
  surv.totalPlayTime += world.runTime;

  commitWorldProgress(world);
  surv.kills += world.kills.total;
  surv.bossesDefeated += world.bossesDefeated;

  rec.totalDamageDealt += world.damageDealt;
  rec.totalDamageTaken += world.damageTaken;
  rec.totalHealingDone += world.healingDone;
  rec.totalGemsCollected += world.gemsCollected;
  rec.totalLevelsGained += Math.max(0, world.level - 1);
  surv.totalDamageDealt += world.damageDealt;

  if (world.runTime > rec.longestRunTime) rec.longestRunTime = world.runTime;
  if (world.runTime > surv.bestTime) surv.bestTime = world.runTime;
  if (world.level > rec.highestLevel) rec.highestLevel = world.level;
  if (world.level > surv.highestLevel) surv.highestLevel = world.level;
  if (world.coefficient > rec.highestCoefficient) rec.highestCoefficient = world.coefficient;
  if (world.kills.total > rec.mostKillsInRun) rec.mostKillsInRun = world.kills.total;
  if (world.damageDealt > rec.mostDamageInRun) rec.mostDamageInRun = world.damageDealt;
  if (world.stageIndex > rec.furthestStageIndex) rec.furthestStageIndex = world.stageIndex;

  rec.bySurvivor[survivorId] = surv;

  const historyEntry: RunHistoryEntry = {
    timestamp: Date.now(),
    outcome,
    survivorId,
    stageId: stage.id,
    stageName: stage.name,
    runTime: world.runTime,
    level: world.level,
    coefficient: world.coefficient,
    kills: world.kills.total,
    bossesDefeated: world.bossesDefeated,
    damageDealt: Math.round(world.damageDealt),
    items: world.inventory.map((inst) => ({ id: inst.id, stacks: inst.stacks })),
  };
  rec.recentRuns = [historyEntry, ...rec.recentRuns].slice(0, MAX_RECENT_RUNS);

  writeStored(rec);
  return rec;
}

function readStored(): Partial<ArchiveRecords> {
  if (typeof localStorage === 'undefined') return {};
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return {};
    const parsed: unknown = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? (parsed as Partial<ArchiveRecords>) : {};
  } catch {
    return {};
  }
}

function writeStored(records: ArchiveRecords): void {
  if (typeof localStorage === 'undefined') return;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(records));
  } catch {
    /* private browsing or quota exceeded */
  }
}

function normalizeRecords(raw: Partial<ArchiveRecords>): ArchiveRecords {
  const base = emptyRecords();
  return {
    version: RECORDS_VERSION,
    totalRuns: nonNegInt(raw.totalRuns),
    victories: nonNegInt(raw.victories),
    defeats: nonNegInt(raw.defeats),
    abandons: nonNegInt(raw.abandons),
    totalPlayTime: nonNegNum(raw.totalPlayTime),
    totalKills: nonNegInt(raw.totalKills),
    fodderKills: nonNegInt(raw.fodderKills),
    eliteKills: nonNegInt(raw.eliteKills),
    bossKills: nonNegInt(raw.bossKills),
    totalDamageDealt: nonNegNum(raw.totalDamageDealt),
    totalDamageTaken: nonNegNum(raw.totalDamageTaken),
    totalHealingDone: nonNegNum(raw.totalHealingDone),
    totalGemsCollected: nonNegInt(raw.totalGemsCollected),
    totalItemsCollected: nonNegInt(raw.totalItemsCollected),
    totalLevelsGained: nonNegInt(raw.totalLevelsGained),
    stagesCleared: nonNegInt(raw.stagesCleared),
    longestRunTime: nonNegNum(raw.longestRunTime),
    fastestVictoryTime:
      typeof raw.fastestVictoryTime === 'number' && Number.isFinite(raw.fastestVictoryTime) && raw.fastestVictoryTime > 0
        ? raw.fastestVictoryTime
        : null,
    highestLevel: Math.max(1, nonNegInt(raw.highestLevel, 1)),
    highestCoefficient: Math.max(1, nonNegNum(raw.highestCoefficient, 1)),
    mostKillsInRun: nonNegInt(raw.mostKillsInRun),
    mostDamageInRun: nonNegNum(raw.mostDamageInRun),
    furthestStageIndex: nonNegInt(raw.furthestStageIndex),
    bySurvivor: normalizeSurvivorMap(raw.bySurvivor),
    entityKills: normalizeNumMap(raw.entityKills),
    entityEncounters: normalizeNumMap(raw.entityEncounters),
    entityLores: normalizeNumMap(raw.entityLores),
    itemPicks: normalizeNumMap(raw.itemPicks),
    stageVisits: normalizeNumMap(raw.stageVisits),
    stageClears: normalizeNumMap(raw.stageClears),
    recentRuns: Array.isArray(raw.recentRuns) ? raw.recentRuns.slice(0, MAX_RECENT_RUNS) : base.recentRuns,
  };
}

function normalizeNumMap(map: unknown): Record<string, number> {
  if (!map || typeof map !== 'object') return {};
  const out: Record<string, number> = {};
  for (const [k, v] of Object.entries(map as Record<string, unknown>)) {
    if (typeof v === 'number' && Number.isFinite(v) && v > 0) {
      out[k] = Math.floor(v);
    }
  }
  return out;
}

function normalizeSurvivorMap(map: unknown): Record<string, SurvivorRecord> {
  if (!map || typeof map !== 'object') return {};
  const out: Record<string, SurvivorRecord> = {};
  for (const [k, v] of Object.entries(map as Record<string, unknown>)) {
    if (!v || typeof v !== 'object') continue;
    const s = v as Partial<SurvivorRecord>;
    out[k] = {
      runs: nonNegInt(s.runs),
      victories: nonNegInt(s.victories),
      defeats: nonNegInt(s.defeats),
      abandons: nonNegInt(s.abandons),
      kills: nonNegInt(s.kills),
      bossesDefeated: nonNegInt(s.bossesDefeated),
      bestTime: nonNegNum(s.bestTime),
      fastestVictory:
        typeof s.fastestVictory === 'number' && Number.isFinite(s.fastestVictory) && s.fastestVictory > 0
          ? s.fastestVictory
          : null,
      highestLevel: Math.max(1, nonNegInt(s.highestLevel, 1)),
      totalPlayTime: nonNegNum(s.totalPlayTime),
      totalDamageDealt: nonNegNum(s.totalDamageDealt),
    };
  }
  return out;
}

function nonNegNum(val: unknown, fallback = 0): number {
  return typeof val === 'number' && Number.isFinite(val) && val >= 0 ? val : fallback;
}

function nonNegInt(val: unknown, fallback = 0): number {
  return typeof val === 'number' && Number.isFinite(val) && val >= 0 ? Math.floor(val) : fallback;
}
