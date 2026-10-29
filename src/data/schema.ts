export const CATALOG_VERSION = 1;

export type SkillSlot = 'primary' | 'secondary' | 'utility' | 'special';
export type SkillInput = 'hold' | 'press';
export type ItemRarity = 'common' | 'uncommon' | 'rare' | 'lunar';
export type EntityRole = 'fodder' | 'elite' | 'boss';
export type RunPhase = 'play' | 'levelup' | 'portal' | 'victory' | 'defeat';
export type TeleporterState = 'hidden' | 'charging' | 'done';

export type StatId = 'speed' | 'maxHp' | 'radius' | 'damage' | 'cooldown';

export type ItemHook =
  | { op: 'add'; stat: StatId; value: number }
  | { op: 'pct'; stat: StatId; value: number }
  | { op: 'on-kill'; stat: 'hp'; value: number };

export type ProjectileEffect = {
  type: 'projectile';
  speed: number;
  lifetime: number;
  radius: number;
  damage: number;
  pierce?: boolean;
  flyOver?: boolean;
  impactRadius?: number;
};

export type DashEffect = {
  type: 'dash';
  distance: number;
  duration: number;
  iframe: number;
  decoyDuration?: number;
};

export type SelfSlowEffect = {
  type: 'self-slow';
  mul: number;
  duration: number;
};

export type DelayedStrikeEffect = {
  type: 'delayed-strike';
  delay: number;
  radius: number;
  damage: number;
};

export type SlowLineEffect = {
  type: 'slow-line';
  length: number;
  width: number;
  duration: number;
  slowMul: number;
  damage: number;
  fodderOnly: boolean;
  offset?: number;
};

export type TetherEffect = {
  type: 'tether';
  speed: number;
  lifetime: number;
  radius: number;
  rootDuration: number;
  fodderContactDps: number;
};

/** Add a variant here and a case in `sim/skills.ts`. */
export type SkillEffect =
  | ProjectileEffect
  | DashEffect
  | SelfSlowEffect
  | DelayedStrikeEffect
  | SlowLineEffect
  | TetherEffect;

export type SkillDef = {
  id: string;
  name: string;
  slot: SkillSlot;
  input: SkillInput;
  cooldown: number;
  lore?: string;
  hook?: string;
  effects: SkillEffect[];
};

export type SurvivorStats = {
  speed: number;
  maxHp: number;
  radius: number;
};

export type ViewDot = {
  kind: 'dot' | 'chevron';
  size: number;
  inner: string;
  mid: string;
};

export type SurvivorDef = {
  id: string;
  name: string;
  title?: string;
  lore?: string;
  stats: SurvivorStats;
  skills: Record<SkillSlot, string | null>;
  startingItems: string[];
  view: ViewDot;
};

export type ChaseAi = { type: 'chase' };

export type RangedAi = {
  type: 'ranged';
  range: number;
  keep: number;
  cooldown: number;
  windup: number;
  projectile: { speed: number; lifetime: number; radius: number; damage: number };
};

export type SniperAi = {
  type: 'sniper';
  keep: number;
  cooldown: number;
  windup: number;
  damage: number;
  lineWidth: number;
};

export type EntityAi = ChaseAi | RangedAi | SniperAi;

export type EntityDef = {
  id: string;
  name: string;
  role: EntityRole;
  tags: string[];
  stats: { speed: number; maxHp: number; radius: number };
  contact: { dps: number };
  rewards: { xp: number; credits: number };
  ai: EntityAi;
  view: ViewDot;
};

export type ItemDef = {
  id: string;
  name: string;
  rarity: ItemRarity;
  stack: 'linear' | 'none';
  hooks: ItemHook[];
  lore: string;
};

export type ObstacleKind = 'pillar' | 'hazard' | 'volatile';
export type ObstacleLife = 'intact' | 'primed' | 'detonated';

export type Obstacle = {
  id: number;
  type: ObstacleKind;
  x: number;
  y: number;
  radius: number;
  hp: number;
  maxHp: number;
  state: ObstacleLife;
  timer: number;
  biomeVariant: string;
};

export type BiomeObstacleNames = Record<ObstacleKind, string>;

export type ObstacleCatalog = {
  version: number;
  counts: Record<ObstacleKind, number>;
  dynamicHazards: number;
  borderPad: number;
  playerKeepOut: number;
  teleporterKeepOut: number;
  volatileTeleporterKeepOut: number;
  minSpacing: number;
  placeRetries: number;
  pillar: { radius: number };
  hazard: {
    radius: number;
    playerSpeedMul: number;
    enemySpeedMul: number;
    dps: number;
  };
  volatile: {
    radius: number;
    hp: number;
    prime: number;
    explosionRadius: number;
    enemyDamage: number;
    playerDamage: number;
    rimeSlowDuration: number;
    rimeSlowMul: number;
  };
  biomes: Record<string, BiomeObstacleNames>;
};

export type WorldDef = {
  version: number;
  width: number;
  height: number;
  viewZoom: number;
  maxProjectiles: number;
  defaultSurvivor: string;
  defaultEnemy: string;
};

export type StageView = {
  grid: string;
  border: string;
  zone: string;
  portal: string;
};

export type StageDef = {
  id: string;
  name: string;
  fodder: string;
  ranged?: string;
  rangedChance?: number;
  sniper?: string;
  elite: string;
  boss: string;
  firstEliteAt: number;
  teleporterAt: number;
  teleporterHold: number;
  teleporterRadius: number;
  view: StageView;
};

export type LoopDef = {
  version: number;
  xpBase: number;
  xpGrowth: number;
  gemPickup: number;
  gemMagnet: number;
  gemMagnetSpeed: number;
  maxFodder: number;
  maxElites: number;
  maxGems: number;
  hashCell: number;
  fodderContactCap: number;
  levelChoices: number;
  portalRadius: number;
  portalHold: number;
  director: {
    creditRate: number;
    fodderCost: number;
    eliteCost: number;
    sniperCost: number;
    fodderInterval: number;
    eliteInterval: number;
    sniperInterval: number;
    maxSnipers: number;
    spawnMin: number;
    spawnMax: number;
  };
  noxious: {
    contactSlowMul: number;
    contactSlowDuration: number;
    corpseDelay: number;
    popRadius: number;
    popDamage: number;
  };
  shielder: {
    delay: number;
    percentHp: number;
  };
  difficulty: {
    perSecond: number;
    stageBonus: number;
    speedPerCoeff: number;
  };
  rarityWeight: Record<ItemRarity, number>;
  stages: StageDef[];
};

export type VersionedList<T> = {
  version: number;
  entries: T[];
};

export type ItemInstance = {
  id: string;
  stacks: number;
};

export type ResolvedStats = {
  speed: number;
  maxHp: number;
  radius: number;
  damageMul: number;
  cooldownMul: number;
};
