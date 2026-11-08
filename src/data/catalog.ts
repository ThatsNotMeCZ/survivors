import entitiesRaw from './entities.json';
import itemsRaw from './items.json';
import loopRaw from './loop.json';
import obstaclesRaw from './obstacles.json';
import {
  CATALOG_VERSION,
  type EntityDef,
  type EntityRole,
  type ItemDef,
  type ItemHook,
  type LoopDef,
  type ObstacleCatalog,
  type ObstacleKind,
  type SkillDef,
  type SkillEffect,
  type StageDef,
  type SurvivorDef,
  type UnlockCondition,
  type VersionedList,
  type WorldDef,
} from './schema';
import skillsRaw from './skills.json';
import survivorsRaw from './survivors.json';
import worldRaw from './world.json';

const IMPLEMENTED_EFFECTS = new Set<SkillEffect['type']>([
  'projectile',
  'dash',
  'self-slow',
  'delayed-strike',
  'slow-line',
  'tether',
]);

const IMPLEMENTED_HOOK_OPS = new Set<ItemHook['op']>(['add', 'pct', 'on-kill', 'on-crit']);

export type Catalog = {
  world: WorldDef;
  loop: LoopDef;
  obstacles: ObstacleCatalog;
  skill: (id: string) => SkillDef;
  survivor: (id: string) => SurvivorDef;
  entity: (id: string) => EntityDef;
  item: (id: string) => ItemDef;
  items: ItemDef[];
  entities: EntityDef[];
  survivors: SurvivorDef[];
};

export const catalog: Catalog = loadCatalog();

function loadCatalog(): Catalog {
  const world = asWorld(worldRaw);
  const loop = asLoop(loopRaw);
  const obstacles = asObstacles(obstaclesRaw);
  const skills = indexById('skills.json', asList<SkillDef>(skillsRaw as VersionedList<SkillDef>, 'skills.json'));
  const survivors = indexById(
    'survivors.json',
    asList<SurvivorDef>(survivorsRaw as VersionedList<SurvivorDef>, 'survivors.json'),
  );
  const entities = indexById(
    'entities.json',
    asList<EntityDef>(entitiesRaw as VersionedList<EntityDef>, 'entities.json'),
  );
  const items = indexById('items.json', asList<ItemDef>(itemsRaw as VersionedList<ItemDef>, 'items.json'));

  for (const entity of entities.values()) {
    if (!entity.lore || typeof entity.lore !== 'string') {
      throw new Error(`Entity "${entity.id}" missing lore`);
    }
    if (entity.role === 'boss') {
      if (entity.ai.type !== 'boss') {
        throw new Error(`Boss "${entity.id}" must use ai.type "boss"`);
      }
      if (!Array.isArray(entity.ai.attacks) || entity.ai.attacks.length === 0) {
        throw new Error(`Boss "${entity.id}" needs at least one attack`);
      }
      for (const atk of entity.ai.attacks) {
        if (!(atk.cooldown > 0)) {
          throw new Error(`Boss "${entity.id}" attack "${atk.type}" must have cooldown > 0`);
        }
        if (atk.type === 'summon') {
          const summoned = entities.get(atk.entity);
          if (!summoned) {
            throw new Error(`Boss "${entity.id}" summon points to missing entity "${atk.entity}"`);
          }
          if (summoned.role !== 'fodder') {
            throw new Error(`Boss "${entity.id}" summon "${atk.entity}" must have role "fodder"`);
          }
          if (!(atk.count > 0) || !(atk.maxAlive >= atk.count)) {
            throw new Error(`Boss "${entity.id}" summon "${atk.entity}" has invalid count/maxAlive`);
          }
        }
      }
    }
  }

  for (const item of items.values()) {
    for (const hook of item.hooks) {
      if (!IMPLEMENTED_HOOK_OPS.has(hook.op)) {
        throw new Error(`Item "${item.id}" uses unimplemented hook "${hook.op}"`);
      }
      if (hook.op === 'on-kill' && hook.stat !== 'hp') {
        throw new Error(`Item "${item.id}" on-kill stat must be hp`);
      }
      if (hook.op === 'on-crit' && hook.stat !== 'cooldown') {
        throw new Error(`Item "${item.id}" on-crit stat must be cooldown`);
      }
    }
    if (item.unlock) {
      assertUnlock(`Item "${item.id}"`, item.unlock, loop.stages, entities);
    }
  }

  for (const skill of skills.values()) {
    for (const effect of skill.effects) {
      if (!IMPLEMENTED_EFFECTS.has(effect.type)) {
        throw new Error(`Skill "${skill.id}" uses unimplemented effect "${effect.type}"`);
      }
    }
  }
  for (const survivor of survivors.values()) {
    for (const slot of ['primary', 'secondary', 'utility', 'special'] as const) {
      const skillId = survivor.skills[slot];
      if (skillId && !skills.has(skillId)) {
        throw new Error(`Survivor "${survivor.id}" slot ${slot} points to missing skill "${skillId}"`);
      }
    }
    for (const itemId of survivor.startingItems) {
      if (!items.has(itemId)) {
        throw new Error(`Survivor "${survivor.id}" starting item missing: "${itemId}"`);
      }
    }
    if (survivor.unlock) {
      assertUnlock(`Survivor "${survivor.id}"`, survivor.unlock, loop.stages, entities);
    }
  }
  const roles: EntityRole[] = ['fodder', 'elite', 'boss'];
  for (const role of roles) {
    const chance = loop.loreDropChance?.[role];
    if (typeof chance !== 'number' || chance < 0 || chance > 1) {
      throw new Error(`loop.json loreDropChance.${role} must be a number between 0 and 1`);
    }
  }
  if (!survivors.has(world.defaultSurvivor)) {
    throw new Error(`world.defaultSurvivor missing: "${world.defaultSurvivor}"`);
  }
  if (!entities.has(world.defaultEnemy)) {
    throw new Error(`world.defaultEnemy missing: "${world.defaultEnemy}"`);
  }
  if (loop.stages.length < 1) {
    throw new Error('loop.json needs at least one stage');
  }
  for (const stage of loop.stages) {
    assertStageEntity(entities, stage, 'fodder');
    assertStageEntity(entities, stage, 'elite');
    assertStageEntity(entities, stage, 'boss');
    if (!obstacles.biomes[stage.id]) {
      throw new Error(`obstacles.json missing biome names for stage "${stage.id}"`);
    }
    if (stage.ranged) {
      const ranged = entities.get(stage.ranged);
      if (!ranged) {
        throw new Error(`Stage "${stage.id}" ranged missing: "${stage.ranged}"`);
      }
      if (ranged.role !== 'fodder') {
        throw new Error(`Stage "${stage.id}" ranged "${stage.ranged}" has role "${ranged.role}"`);
      }
      if (ranged.ai.type !== 'ranged') {
        throw new Error(`Stage "${stage.id}" ranged "${stage.ranged}" ai must be ranged`);
      }
    }
    if (stage.sniper) {
      const sniper = entities.get(stage.sniper);
      if (!sniper) {
        throw new Error(`Stage "${stage.id}" sniper missing: "${stage.sniper}"`);
      }
      if (sniper.role !== 'fodder') {
        throw new Error(`Stage "${stage.id}" sniper "${stage.sniper}" has role "${sniper.role}"`);
      }
      if (sniper.ai.type !== 'sniper') {
        throw new Error(`Stage "${stage.id}" sniper "${stage.sniper}" ai must be sniper`);
      }
    }
  }

  return {
    world,
    loop,
    obstacles,
    skill: get(skills, 'skill'),
    survivor: get(survivors, 'survivor'),
    entity: get(entities, 'entity'),
    item: get(items, 'item'),
    items: [...items.values()],
    entities: [...entities.values()],
    survivors: [...survivors.values()],
  };
}

function assertStageEntity(
  entities: Map<string, EntityDef>,
  stage: StageDef,
  key: 'fodder' | 'elite' | 'boss',
): void {
  const id = stage[key];
  const def = entities.get(id);
  if (!def) {
    throw new Error(`Stage "${stage.id}" ${key} missing: "${id}"`);
  }
  const expectedRole = key === 'elite' ? 'fodder' : key;
  if (def.role !== expectedRole) {
    throw new Error(`Stage "${stage.id}" ${key} "${id}" has role "${def.role}", expected "${expectedRole}"`);
  }
}

function assertUnlock(
  owner: string,
  unlock: UnlockCondition,
  stages: StageDef[],
  entities: Map<string, EntityDef>,
): void {
  if (!unlock.label || typeof unlock.label !== 'string') {
    throw new Error(`${owner} unlock missing label`);
  }
  if (unlock.type === 'stage-clear') {
    if (!stages.some((s) => s.id === unlock.stageId)) {
      throw new Error(`${owner} unlock references unknown stage "${unlock.stageId}"`);
    }
    return;
  }
  if (unlock.type === 'boss-kill') {
    if (!entities.has(unlock.entityId)) {
      throw new Error(`${owner} unlock references unknown entity "${unlock.entityId}"`);
    }
    if (unlock.stageId && !stages.some((s) => s.id === unlock.stageId)) {
      throw new Error(`${owner} unlock references unknown stage "${unlock.stageId}"`);
    }
    return;
  }
  if (
    unlock.type === 'total-kills' ||
    unlock.type === 'elite-kills' ||
    unlock.type === 'victories'
  ) {
    if (typeof unlock.count !== 'number' || unlock.count <= 0) {
      throw new Error(`${owner} unlock.count must be > 0`);
    }
    return;
  }
  throw new Error(`${owner} uses unknown unlock type "${(unlock as { type: string }).type}"`);
}

function asWorld(raw: unknown): WorldDef {
  const data = raw as WorldDef;
  if (data.version !== CATALOG_VERSION) {
    throw new Error(`world.json version ${data.version}, expected ${CATALOG_VERSION}`);
  }
  return data;
}

function asLoop(raw: unknown): LoopDef {
  const data = raw as LoopDef;
  if (data.version !== CATALOG_VERSION) {
    throw new Error(`loop.json version ${data.version}, expected ${CATALOG_VERSION}`);
  }
  if (!Array.isArray(data.stages)) {
    throw new Error('loop.json missing stages[]');
  }
  const dir = data.director;
  if (
    !(dir.groupSizeMin > 0) ||
    !(dir.groupSizeMax >= dir.groupSizeMin) ||
    !(dir.eliteGroupSizeMin > 0) ||
    !(dir.eliteGroupSizeMax >= dir.eliteGroupSizeMin) ||
    !(dir.groupSpreadRadius > 0) ||
    !(dir.eliteCostMul >= 1)
  ) {
    throw new Error('loop.json director group/elite sizing config invalid');
  }
  const el = data.elite;
  if (!el || !(el.hpMul > 0) || !(el.damageMul > 0) || !(el.xpMul > 0) || !(el.creditsMul > 0) || !(el.radiusMul > 0)) {
    throw new Error('loop.json missing valid elite multiplier config');
  }
  return data;
}

function asObstacles(raw: unknown): ObstacleCatalog {
  const data = raw as ObstacleCatalog;
  if (data.version !== CATALOG_VERSION) {
    throw new Error(`obstacles.json version ${data.version}, expected ${CATALOG_VERSION}`);
  }
  const kinds: ObstacleKind[] = ['pillar', 'hazard', 'volatile'];
  for (const kind of kinds) {
    if (!(data.counts[kind] > 0)) {
      throw new Error(`obstacles.json counts.${kind} must be > 0`);
    }
  }
  if (!(data.dynamicHazards >= 0)) {
    throw new Error('obstacles.json dynamicHazards must be >= 0');
  }
  return data;
}

function asList<T extends { id: string }>(raw: VersionedList<T>, file: string): T[] {
  if (raw.version !== CATALOG_VERSION) {
    throw new Error(`${file} version ${raw.version}, expected ${CATALOG_VERSION}`);
  }
  if (!Array.isArray(raw.entries)) {
    throw new Error(`${file} missing entries[]`);
  }
  return raw.entries;
}

function indexById<T extends { id: string }>(file: string, entries: T[]): Map<string, T> {
  const map = new Map<string, T>();
  for (const entry of entries) {
    if (!entry.id) throw new Error(`${file} entry missing id`);
    if (map.has(entry.id)) throw new Error(`${file} duplicate id "${entry.id}"`);
    map.set(entry.id, entry);
  }
  return map;
}

function get<T>(map: Map<string, T>, kind: string): (id: string) => T {
  return (id: string) => {
    const hit = map.get(id);
    if (!hit) throw new Error(`Unknown ${kind} "${id}"`);
    return hit;
  };
}
