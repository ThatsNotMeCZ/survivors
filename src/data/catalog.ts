import entitiesRaw from './entities.json';
import itemsRaw from './items.json';
import loopRaw from './loop.json';
import {
  CATALOG_VERSION,
  type EntityDef,
  type ItemDef,
  type LoopDef,
  type SkillDef,
  type SkillEffect,
  type StageDef,
  type SurvivorDef,
  type VersionedList,
  type WorldDef,
} from './schema';
import skillsRaw from './skills.json';
import survivorsRaw from './survivors.json';
import worldRaw from './world.json';

const IMPLEMENTED_EFFECTS = new Set<SkillEffect['type']>(['projectile', 'dash']);

export type Catalog = {
  world: WorldDef;
  loop: LoopDef;
  skill: (id: string) => SkillDef;
  survivor: (id: string) => SurvivorDef;
  entity: (id: string) => EntityDef;
  item: (id: string) => ItemDef;
  items: ItemDef[];
  entities: EntityDef[];
};

export const catalog: Catalog = loadCatalog();

function loadCatalog(): Catalog {
  const world = asWorld(worldRaw);
  const loop = asLoop(loopRaw);
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
  }

  return {
    world,
    loop,
    skill: get(skills, 'skill'),
    survivor: get(survivors, 'survivor'),
    entity: get(entities, 'entity'),
    item: get(items, 'item'),
    items: [...items.values()],
    entities: [...entities.values()],
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
  if (def.role !== key) {
    throw new Error(`Stage "${stage.id}" ${key} "${id}" has role "${def.role}"`);
  }
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
