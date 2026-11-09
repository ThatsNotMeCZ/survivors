import Phaser from 'phaser';
import { playSfx, setMusicScene } from '../audio';
import {
  FX_CENSER_IMPACT,
  FX_CRUCIBLE_IMPACT,
  FX_DASH,
  FX_DEATH,
  FX_GEM,
  FX_HIT,
  FX_HURT,
  FX_MUZZLE,
  FX_STRIKE,
  SPARK_CAP,
} from '../config';
import { catalog } from '../data/catalog';
import type { ItemDef, SkillSlot } from '../data/schema';
import {
  ROLE_BOSS,
  ROLE_ELITE,
  ROLE_FODDER,
  currentEnemyAttackAnim,
  currentEnemySpeed,
  isEnemyAttacking,
} from '../sim/enemies';
import { MAX_LORE_DROPS } from '../sim/gems';
import { emptyInput, type InputFrame } from '../sim/input-frame';
import { applyLevelChoice } from '../sim/level';
import { currentObjective, currentStage, type Objective } from '../sim/loop';
import { playerSpeedMul } from '../sim/obstacles';
import { ZONE_LINE, ZONE_STRIKE } from '../sim/zones';
import { MAX_RADIUS_RATIO, MIN_RADIUS_RATIO } from '../sim/stats';
import { aimAngle, createWorld, stepWorld, type World } from '../sim/world';
import { formatTime, initArenaHud, setHudCombat, setHudFps } from '../ui/hud';
import {
  bindOverlay,
  getOverlayMode,
  hideOverlay,
  hideSting,
  isModalOpen,
  isSimPaused,
  setHoldPrompt,
  showLevelUp,
  showPause,
  showRunEnd,
  showSting,
  stingActive,
  type RunRecapUnlock,
} from '../ui/overlay';
import {
  commitWorldProgress,
  getCollectedLoreIds,
  getRecords,
  getUnlockLabel,
  getUnlockedItemIds,
  isItemUnlocked,
  isSurvivorUnlocked,
  recordItemPick,
  recordLorePickup,
  recordRunEnd,
} from '../ui/records';
import { getSettings } from '../ui/settings';
import {
  applyShotVisual,
  createFxStillPool,
  eventFxId,
  spawnFxStill,
  stepFxStills as advanceFxStills,
  syncZoneFx,
  type FxStillPool,
} from './fx-sprites';
import { uploadPixelTextures } from './pixel-textures';
import {
  floorKey,
  hazardKey,
  pillarKey,
  moveFacing,
  spriteFacing,
  type HorizontalFacing,
  crosshairKey,
  playerEyesKey,
  stageBiome,
  stageEnvTheme,
  volatileKey,
  type BiomeId,
  type EnvThemeId,
} from './procedural-pixel-art';
import {
  applyEnvTexture,
  applyUiTexture,
  authoredEntity,
  createEntityAnims,
  entityTextureKey,
  fodderAnimSpec,
  fodderGpuAnimations,
  fxTextureKey,
  getEnvFrame,
  playEntity,
  preloadSprites,
  resolveEnvThemeProp,
} from './sprites';
import { AmbientShader } from './shaders/ambient-shader';
import { BossShaders } from './shaders/boss-shaders';
import { BrimstoneLineShaderPool } from './shaders/brimstone-line-shader';
import { CircleChargeShader } from './shaders/circle-charge-shader';
import { DamageFxShaderPool } from './shaders/damage-fx-shader';
import { EliteAffixShaderPool } from './shaders/elite-affix-shader';
import { EnvHazardShaderPool } from './shaders/env-hazard-shader';
import { PlayerHurtShader } from './shaders/player-hurt-shader';
import { SkillImpactShaderPool } from './shaders/skill-impact-shader';

type GpuMember = Omit<Partial<Phaser.Types.GameObjects.SpriteGPULayer.Member>, 'animation'> & {
  animation?: string | number | { base?: string | number; duration?: number; delay?: number; yoyo?: boolean };
};

type Spark = {
  life: number;
  max: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  size: number;
  tint: number;
};

const GHOST_CAP = 3;
const WAYPOINT_DIST = 80;
const WAYPOINT_PAD = 52;
/** Display size > mite 24 / spitter 28 so the vessel reads as the hero. */
const PLAYER_DISPLAY = 40;

/**
 * Aimed-primary run. Combat rules live in `src/sim/`. Content in `src/data/`.
 */
export class ArenaScene extends Phaser.Scene {
  private world!: World;
  private inputFrame: InputFrame = emptyInput();
  private playerSprite!: Phaser.GameObjects.Sprite;
  private playerEyes!: Phaser.GameObjects.Image;
  private playerGlow!: Phaser.GameObjects.Image;
  private eliteSprites: Phaser.GameObjects.Sprite[] = [];
  private eliteAffixShaders!: EliteAffixShaderPool;
  private bossSprite!: Phaser.GameObjects.Sprite;
  private obstacleSprites: Phaser.GameObjects.Image[] = [];
  private volatileGlows: Phaser.GameObjects.Image[] = [];
  private floor!: Phaser.GameObjects.Image;
  private circleSprite!: Phaser.GameObjects.Image;
  private circleChargeShader!: CircleChargeShader;
  private circleGlowFilter?: any;
  private portalSprite!: Phaser.GameObjects.Image;
  private telGlow!: Phaser.GameObjects.Image;
  private crosshair!: Phaser.GameObjects.Image;
  private waypoint!: Phaser.GameObjects.Image;
  private shots: Phaser.GameObjects.Image[] = [];
  private zoneFx: Phaser.GameObjects.Image[] = [];
  private fxStills!: FxStillPool;
  private ghosts: Phaser.GameObjects.Image[] = [];
  private ghostLife: Float32Array = new Float32Array(GHOST_CAP);
  private ghostCd = 0;
  private ambientShader!: AmbientShader;
  private bossShaders!: BossShaders;
  private brimstoneLineShaders!: BrimstoneLineShaderPool;
  private damageFx!: DamageFxShaderPool;
  private envHazardShaders!: EnvHazardShaderPool;
  private playerHurtShader!: PlayerHurtShader;
  private skillImpactShaders!: SkillImpactShaderPool;
  private playerTrail1!: Phaser.GameObjects.Sprite;
  private playerTrail2!: Phaser.GameObjects.Sprite;
  private eliteTrails1: Phaser.GameObjects.Sprite[] = [];
  private eliteTrails2: Phaser.GameObjects.Sprite[] = [];
  private bossTrail1!: Phaser.GameObjects.Sprite;
  private bossTrail2!: Phaser.GameObjects.Sprite;
  private fodderLayers = new Map<string, Phaser.GameObjects.SpriteGPULayer>();
  private fodderTrailLayers = new Map<string, Phaser.GameObjects.SpriteGPULayer>();
  private enemyGlowLayer!: Phaser.GameObjects.SpriteGPULayer;
  private enemyPrevX = new Float32Array(0);
  private enemyPrevY = new Float32Array(0);
  private enemyAliveLast = new Uint8Array(0);
  private playerPrevX = 0;
  private playerPrevY = 0;
  private gemLayer!: Phaser.GameObjects.SpriteGPULayer;
  private loreSprites: Phaser.GameObjects.Image[] = [];
  private loreGlows: Phaser.GameObjects.Image[] = [];
  private sparkLayer!: Phaser.GameObjects.SpriteGPULayer;
  private sparks: Spark[] = [];
  private zoneGfx!: Phaser.GameObjects.Graphics;
  private telegraphGfx!: Phaser.GameObjects.Graphics;
  private gpuMember: GpuMember = {
    x: 0,
    y: 0,
    scaleX: 0,
    scaleY: 0,
    alpha: 0,
    tintBlend: 0.7,
    tintBottomLeft: 0xffffff,
    tintTopLeft: 0xffffff,
    tintBottomRight: 0xffffff,
    tintTopRight: 0xffffff,
  };
  private fodderShown!: Record<string, Uint8Array>;
  private fodderAnimName = new Map<string, string[]>();
  private fodderAnimStart = new Map<string, Float64Array>();
  private fodderAttackPlayed = new Map<string, Uint8Array>();
  private gemShown!: Uint8Array;
  private sparkShown!: Uint8Array;
  private cursors!: Phaser.Types.Input.Keyboard.CursorKeys;
  private wasd!: Record<'W' | 'A' | 'S' | 'D', Phaser.Input.Keyboard.Key>;
  private shift!: Phaser.Input.Keyboard.Key;
  private space!: Phaser.Input.Keyboard.Key;
  private qKey!: Phaser.Input.Keyboard.Key;
  private decoySprite!: Phaser.GameObjects.Sprite;
  private utilityWasDown = false;
  private secondaryWasDown = false;
  private specialWasDown = false;
  private lastStageGen = -1;
  private lastPhase: World['phase'] = 'play';
  private lastStageIndex = 0;
  private lastBossSpawned = false;
  private bossMusicActive = false;
  private shownOffer: ItemDef[] | null = null;
  private walkPhase = 0;
  private lastCircleKey = '';
  private lastFacing: HorizontalFacing = 'right';
  private initialUnlockedItems = new Set<string>();
  private initialUnlockedSurvivors = new Set<string>();

  constructor() {
    super({ key: 'arena' });
  }

  preload(): void {
    preloadSprites(this);
  }

  create(): void {
    const initialRec = getRecords();
    this.initialUnlockedItems = getUnlockedItemIds(initialRec);
    this.initialUnlockedSurvivors = new Set(
      catalog.survivors.filter((s) => isSurvivorUnlocked(s, initialRec)).map((s) => s.id),
    );
    this.world = createWorld(resolveSurvivorId(), {
      unlockedItems: this.initialUnlockedItems,
      collectedLores: getCollectedLoreIds(initialRec),
    });
    commitWorldProgress(this.world);
    const { width, height, maxProjectiles } = catalog.world;
    const loop = catalog.loop;
    uploadPixelTextures(this);
    createEntityAnims(this);
    const biome = this.biome();
    const theme = this.envTheme();
    const vessel = this.vesselId();

    this.floor = this.add.image(width / 2, height / 2, floorKey(theme)).setDepth(0);
    this.circleSprite = this.add.image(0, 0, '').setVisible(false).setDepth(1);
    if (typeof (this.circleSprite as any).enableFilters === 'function') {
      try {
        (this.circleSprite as any).enableFilters();
        const filters = (this.circleSprite as any).filters;
        if (filters?.internal?.addGlow) {
          this.circleGlowFilter = filters.internal.addGlow(0xffaa33, 8, 0, 0);
          this.circleGlowFilter.setActive(false);
        }
      } catch {
        // Fallback for non-WebGL / unsupported filter environments
      }
    }
    this.portalSprite = this.add.image(0, 0, '').setVisible(false).setDepth(1);
    this.zoneGfx = this.add.graphics().setDepth(1);
    this.telegraphGfx = this.add.graphics().setDepth(3);

    this.fodderLayers = new Map();
    this.fodderTrailLayers = new Map();
    this.fodderShown = {};
    for (const def of catalog.entities) {
      if (def.role === 'boss') continue;
      const tex = entityTextureKey(def.id);
      if (!this.textures.exists(tex)) continue;
      const trailLayer = this.add.spriteGPULayer(tex, this.world.enemies.cap * 2).setDepth(1.9);
      this.fodderTrailLayers.set(def.id, trailLayer);
      const layer = this.add.spriteGPULayer(tex, this.world.enemies.cap).setDepth(2);
      layer.setAnimationEnabled('Linear', true);
      const gpuAnims = fodderGpuAnimations(def.id);
      if (gpuAnims.length > 0) layer.setAnimations(gpuAnims);
      this.fodderLayers.set(def.id, layer);
      this.fodderShown[def.id] = new Uint8Array(this.world.enemies.cap);
      this.fodderAnimName.set(def.id, new Array(this.world.enemies.cap).fill(''));
      this.fodderAnimStart.set(def.id, new Float64Array(this.world.enemies.cap));
      this.fodderAttackPlayed.set(def.id, new Uint8Array(this.world.enemies.cap));
    }
    const gemTex = this.textures.exists(fxTextureKey('gem')) ? fxTextureKey('gem') : 'px-gem';
    this.gemLayer = this.add.spriteGPULayer(gemTex, loop.maxGems).setDepth(2);
    this.sparkLayer = this.add.spriteGPULayer('px-spark', SPARK_CAP).setDepth(6);
    this.gemShown = new Uint8Array(loop.maxGems);
    this.sparkShown = new Uint8Array(SPARK_CAP);
    for (const layer of this.fodderLayers.values()) {
      seedGpuLayer(layer, this.world.enemies.cap, this.gpuMember);
    }
    for (const trailLayer of this.fodderTrailLayers.values()) {
      seedGpuLayer(trailLayer, this.world.enemies.cap * 2, this.gpuMember);
    }
    this.enemyGlowLayer = this.add.spriteGPULayer('px-glow', this.world.enemies.cap).setDepth(1.85);
    this.enemyGlowLayer.setBlendMode(Phaser.BlendModes.ADD);
    seedGpuLayer(this.enemyGlowLayer, this.world.enemies.cap, this.gpuMember);
    seedGpuLayer(this.gemLayer, loop.maxGems, this.gpuMember);
    seedGpuLayer(this.sparkLayer, SPARK_CAP, this.gpuMember);

    this.enemyPrevX = new Float32Array(this.world.enemies.cap);
    this.enemyPrevY = new Float32Array(this.world.enemies.cap);
    this.enemyAliveLast = new Uint8Array(this.world.enemies.cap);
    this.playerPrevX = this.world.player.x;
    this.playerPrevY = this.world.player.y;
    this.loreSprites = [];
    this.loreGlows = [];
    for (let i = 0; i < MAX_LORE_DROPS; i += 1) {
      const glow = this.add.image(0, 0, 'px-glow').setVisible(false).setDepth(2.4).setAlpha(0.32).setScale(1.6).setTint(0xffd35a);
      glow.setBlendMode(Phaser.BlendModes.ADD);
      this.loreGlows.push(glow);
      this.loreSprites.push(this.add.image(0, 0, 'px-lore').setVisible(false).setDepth(2.5).setScale(1.5));
    }
    this.sparks = [];
    for (let i = 0; i < SPARK_CAP; i += 1) {
      this.sparks.push({ life: 0, max: 0.2, x: 0, y: 0, vx: 0, vy: 0, size: 1, tint: 0xffffff });
    }

    this.playerGlow = this.add.image(0, 0, 'px-player-halo').setDepth(4).setAlpha(0.48).setScale(1.8);
    this.playerGlow.setBlendMode(Phaser.BlendModes.ADD);
    this.playerTrail1 = this.add.sprite(this.world.player.x, this.world.player.y, entityTextureKey(vessel)).setVisible(false).setDepth(4.8);
    this.fitBody(this.playerTrail1);
    this.playerTrail2 = this.add.sprite(this.world.player.x, this.world.player.y, entityTextureKey(vessel)).setVisible(false).setDepth(4.7);
    this.fitBody(this.playerTrail2);
    this.playerSprite = this.add.sprite(this.world.player.x, this.world.player.y, entityTextureKey(vessel)).setDepth(5);
    playEntity(this.playerSprite, vessel, 'idle');
    this.fitBody(this.playerSprite);
    this.playerEyes = this.add.image(0, 0, this.eyesKey(biome)).setDepth(6);
    this.decoySprite = this.add.sprite(0, 0, entityTextureKey(vessel)).setVisible(false).setDepth(4).setAlpha(0.45).setTint(0xc4a05a);
    this.fitBody(this.decoySprite);
    this.eliteSprites = [];
    this.eliteTrails1 = [];
    this.eliteTrails2 = [];
    for (let i = 0; i < loop.maxElites; i += 1) {
      const elite = this.add.sprite(0, 0, entityTextureKey('ember-chaser')).setVisible(false).setDepth(3);
      this.eliteSprites.push(elite);
      const t1 = this.add.sprite(0, 0, entityTextureKey('ember-chaser')).setVisible(false).setDepth(2.9);
      const t2 = this.add.sprite(0, 0, entityTextureKey('ember-chaser')).setVisible(false).setDepth(2.8);
      this.eliteTrails1.push(t1);
      this.eliteTrails2.push(t2);
    }
    this.bossSprite = this.add.sprite(0, 0, entityTextureKey('cinder-heart')).setVisible(false).setDepth(3);
    this.bossTrail1 = this.add.sprite(0, 0, entityTextureKey('cinder-heart')).setVisible(false).setDepth(2.9);
    this.bossTrail2 = this.add.sprite(0, 0, entityTextureKey('cinder-heart')).setVisible(false).setDepth(2.8);
    this.obstacleSprites = [];
    this.volatileGlows = [];
    for (let i = 0; i < this.world.obstacles.cap; i += 1) {
      this.obstacleSprites.push(this.add.image(0, 0, pillarKey(biome)).setVisible(false).setDepth(2));
      this.volatileGlows.push(
        this.add.image(0, 0, 'px-glow').setVisible(false).setDepth(1).setAlpha(0.2).setScale(3.2),
      );
      this.volatileGlows[i].setBlendMode(Phaser.BlendModes.ADD);
    }
    this.telGlow = this.add.image(0, 0, 'px-glow').setDepth(1).setAlpha(0).setScale(6);
    this.telGlow.setBlendMode(Phaser.BlendModes.ADD);
    this.crosshair = this.add.image(this.world.aimX, this.world.aimY, this.crosshairKey()).setDepth(10);
    this.waypoint = this.add.image(0, 0, 'px-waypoint').setVisible(false).setDepth(11);
    if (applyUiTexture(this.waypoint, 'nav-arrow', 'px-waypoint')) {
      this.waypoint.setScale(1.0);
    } else {
      this.waypoint.setScale(1.2);
    }

    this.shots = [];
    for (let i = 0; i < maxProjectiles; i += 1) {
      this.shots.push(this.add.image(0, 0, 'px-bolt-player').setVisible(false).setDepth(5.2));
    }
    this.zoneFx = [];
    for (let i = 0; i < this.world.zones.cap; i += 1) {
      this.zoneFx.push(this.add.image(0, 0, 'px-bolt-player').setVisible(false).setDepth(3));
    }
    this.fxStills = createFxStillPool(this);
    this.ghosts = [];
    this.ghostLife = new Float32Array(GHOST_CAP);
    for (let i = 0; i < GHOST_CAP; i += 1) {
      const ghost = this.add.image(0, 0, entityTextureKey(vessel)).setVisible(false).setDepth(4).setAlpha(0).setTint(0xb8fff8);
      this.fitBody(ghost);
      this.ghosts.push(ghost);
    }

    this.ambientShader = new AmbientShader(this);
    this.bossShaders = new BossShaders(this);
    this.brimstoneLineShaders = new BrimstoneLineShaderPool(this);
    this.circleChargeShader = new CircleChargeShader(this);
    this.damageFx = new DamageFxShaderPool(this);
    this.eliteAffixShaders = new EliteAffixShaderPool(this);
    this.envHazardShaders = new EnvHazardShaderPool(this);
    this.playerHurtShader = new PlayerHurtShader(this);
    this.skillImpactShaders = new SkillImpactShaderPool(this);

    this.cameras.main.setBounds(0, 0, width, height);
    this.cameras.main.setZoom(catalog.world.viewZoom);
    this.cameras.main.centerOn(this.world.player.x, this.world.player.y);

    if (!this.input.keyboard) {
      throw new Error('Keyboard plugin missing');
    }
    this.cursors = this.input.keyboard.createCursorKeys();
    this.wasd = this.input.keyboard.addKeys('W,A,S,D') as typeof this.wasd;
    this.shift = this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SHIFT);
    this.space = this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE);
    this.qKey = this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.Q);
    this.input.mouse?.disableContextMenu();

    hideOverlay();
    hideSting();
    setHoldPrompt({ visible: false, title: '', detail: '', pct: 0, outside: false });
    this.lastPhase = 'play';
    this.lastStageIndex = this.world.stageIndex;
    this.lastBossSpawned = this.world.bossSpawned;
    this.bossMusicActive = this.world.bossSpawned && this.world.counts.boss > 0;
    this.shownOffer = null;
    bindOverlay({
      onPick: (index) => {
        const picked = this.world.offer?.[index];
        if (picked) recordItemPick(picked.id);
        applyLevelChoice(this.world, index);
      },
      onRestart: () => {
        if (this.world.phase !== 'victory' && this.world.phase !== 'defeat') {
          recordRunEnd(this.world, 'abandon');
        }
        hideOverlay();
        this.scene.restart();
      },
      onAbandon: () => {
        recordRunEnd(this.world, 'abandon');
        showRunEnd('abandon', `${currentStage(this.world).name} · ${formatTime(this.world.runTime)}`, this.runRecap());
      },
      onPause: () => {
        if (this.world.phase !== 'play') return;
        commitWorldProgress(this.world);
        if (getOverlayMode() === 'hidden') showPause();
      },
    });

    const webgl = this.game.renderer instanceof Phaser.Renderer.WebGL.WebGLRenderer;
    initArenaHud(webgl ? 'webgl' : 'canvas');
    setMusicScene({ kind: 'stage', stageId: currentStage(this.world).id });
  }

  update(_time: number, delta: number): void {
    const dt = delta / 1000;
    this.readInput();
    const paused = isSimPaused();
    if (!paused) {
      stepWorld(this.world, this.inputFrame, dt);
    }
    this.syncView(dt);
    this.syncHud();
    this.syncOverlay();
    this.syncStings();
    this.syncHoldPrompt();
    setHudFps(this.game.loop.actualFps);
  }

  private syncHud(): void {
    const stage = currentStage(this.world);
    const objective = currentObjective(this.world);
    const tel = this.world.teleporter;
    const portal = this.world.portal;
    const player = this.world.player;
    const holding =
      tel.state === 'charging' &&
      Math.hypot(player.x - tel.x, player.y - tel.y) <= tel.radius;
    const outsideCircle = tel.state === 'charging' && !holding;
    const outsidePortal =
      portal.open &&
      Math.hypot(player.x - portal.x, player.y - portal.y) >
        this.world.catalog.loop.portalRadius;

    let outsideWarning = '';
    if (outsideCircle) {
      outsideWarning = 'The seal cools · Return to the Transmutation Circle';
    } else if (outsidePortal) {
      outsideWarning = 'Stand in the gate to descend';
    }

    const copy = objectiveCopy(objective, outsideWarning);
    setHudCombat({
      stage: stage.name,
      biome: this.biome(),
      playerHp: this.world.player.hp,
      playerMax: this.world.player.maxHp,
      level: this.world.level,
      xp: this.world.xp,
      xpNeed: this.world.xpNeed,
      runTime: this.world.runTime,
      coefficient: this.world.coefficient,
      bosses: this.world.bossesDefeated,
      kills: this.world.kills.total,
      damageDealt: Math.round(this.world.damageDealt),
      iframe: this.world.player.iframeRemain > 0,
      objectiveKicker: copy.kicker,
      objective: copy.label,
      objectiveDetail: copy.detail,
      objectivePct: objective.pct,
      objectiveSub: copy.sub,
      outside: outsideCircle || outsidePortal,
      holding,
      boss: this.world.focus.kind === 'boss',
      skills: hudSkills(this.world),
      items: this.world.inventory.map((inst) => {
        const def = this.world.catalog.item(inst.id);
        return { id: inst.id, name: def.name, stacks: inst.stacks, rarity: def.rarity };
      }),
    });
  }

  private biome(): BiomeId {
    return stageBiome(currentStage(this.world).id);
  }

  private envTheme(): EnvThemeId {
    return stageEnvTheme(currentStage(this.world).id);
  }

  private vesselId(): string {
    return this.world.survivor.id;
  }

  private playerScale(): number {
    const base = this.world?.survivor?.stats?.radius || 14;
    const current = this.world?.player?.radius ?? base;
    const ratio = base > 0 ? current / base : 1;
    return Math.max(MIN_RADIUS_RATIO, Math.min(MAX_RADIUS_RATIO, ratio));
  }

  private fitBody(image: Phaser.GameObjects.Image | Phaser.GameObjects.Sprite, scale = this.playerScale()): void {
    const fw = image.frame?.width ?? PLAYER_DISPLAY;
    const fh = image.frame?.height ?? PLAYER_DISPLAY;
    if (fw === fh) {
      image.setDisplaySize(PLAYER_DISPLAY * scale, PLAYER_DISPLAY * scale);
      return;
    }
    image.setDisplaySize(fw * scale, fh * scale);
  }

  private ySortDepth(y: number, bias = 0): number {
    const h = catalog.world.height || 2560;
    return 3.2 + Math.max(0, Math.min(1, y / h)) * 1.6 + bias;
  }

  private eyesKey(biome: BiomeId): string {
    return playerEyesKey(biome, this.vesselId());
  }

  private crosshairKey(): string {
    const vessel = this.vesselId();
    const survivor = catalog.survivors.find((s) => s.id === vessel);
    return crosshairKey(survivor?.crosshair || vessel);
  }

  private readInput(): void {
    if (isModalOpen()) {
      this.inputFrame.moveX = 0;
      this.inputFrame.moveY = 0;
      this.inputFrame.held.primary = false;
      this.inputFrame.held.secondary = false;
      this.inputFrame.held.utility = false;
      this.inputFrame.held.special = false;
      this.inputFrame.pressed.primary = false;
      this.inputFrame.pressed.secondary = false;
      this.inputFrame.pressed.utility = false;
      this.inputFrame.pressed.special = false;
      this.utilityWasDown = this.shift.isDown || this.space.isDown;
      this.secondaryWasDown = this.input.activePointer.rightButtonDown();
      this.specialWasDown = this.qKey.isDown;
      return;
    }
    const left = this.cursors.left.isDown || this.wasd.A.isDown;
    const right = this.cursors.right.isDown || this.wasd.D.isDown;
    const up = this.cursors.up.isDown || this.wasd.W.isDown;
    const down = this.cursors.down.isDown || this.wasd.S.isDown;
    this.inputFrame.moveX = (right ? 1 : 0) - (left ? 1 : 0);
    this.inputFrame.moveY = (down ? 1 : 0) - (up ? 1 : 0);

    const pointer = this.input.activePointer;
    const worldPoint = this.cameras.main.getWorldPoint(pointer.x, pointer.y);
    this.inputFrame.aimX = worldPoint.x;
    this.inputFrame.aimY = worldPoint.y;

    const utilityDown = this.shift.isDown || this.space.isDown;
    const secondaryDown = pointer.rightButtonDown();
    const specialDown = this.qKey.isDown;
    this.inputFrame.held.primary = pointer.leftButtonDown();
    this.inputFrame.held.secondary = secondaryDown;
    this.inputFrame.held.utility = utilityDown;
    this.inputFrame.held.special = specialDown;
    this.inputFrame.pressed.primary = false;
    this.inputFrame.pressed.secondary = secondaryDown && !this.secondaryWasDown;
    this.inputFrame.pressed.utility = utilityDown && !this.utilityWasDown;
    this.inputFrame.pressed.special = specialDown && !this.specialWasDown;
    this.utilityWasDown = utilityDown;
    this.secondaryWasDown = secondaryDown;
    this.specialWasDown = specialDown;
  }

  private syncView(dt: number): void {
    const { player, projectiles } = this.world;
    const biome = this.biome();
    const theme = this.envTheme();
    if (this.lastStageGen !== this.world.stageGen) {
      this.lastStageGen = this.world.stageGen;
      this.floor.setTexture(floorKey(theme));
      this.playerEyes.setTexture(this.eyesKey(biome));
      this.crosshair.setTexture(this.crosshairKey());
      this.lastCircleKey = '';
    }
    this.syncPlayer(dt, biome);
    this.crosshair.setPosition(this.world.aimX, this.world.aimY);
    this.cameras.main.centerOn(player.x, player.y);
    this.syncObstacles(biome, theme);
    this.syncEnemies(dt, biome);
    this.syncGems();
    this.syncLores();
    this.drawZones(dt);
    this.bossShaders.sync(this.world, dt);
    this.brimstoneLineShaders.sync(this.world.zones, this.world.runTime);
    this.syncBrimstoneSparks(dt);
    this.drawTelegraphs(biome);
    this.syncWaypoint();
    syncZoneFx(this, this.zoneFx, this.world.zones);
    this.consumeFx();
    advanceFxStills(this.fxStills, dt);
    this.stepSparks(dt);
    this.stepGhosts(dt);
    this.ambientShader.sync(this.cameras.main, this.world.runTime, biome);
    this.envHazardShaders.sync(
      this.world.obstacles,
      this.obstacleSprites,
      player.x,
      player.y,
      player.radius,
      biome,
      theme,
      this.world.runTime,
      dt,
    );
    this.damageFx.sync(dt, this.world.runTime);
    this.skillImpactShaders.sync(dt, this.world.runTime);
    this.playerHurtShader.sync(this.cameras.main, this.world.runTime, player.hp, player.maxHp, dt);

    for (let i = 0; i < this.shots.length; i += 1) {
      const sprite = this.shots[i];
      if (projectiles.alive[i] === 0) {
        sprite.setVisible(false);
        continue;
      }
      applyShotVisual(this, sprite, projectiles, i, biome);
    }
  }

  private syncPlayer(dt: number, biome: BiomeId): void {
    const { player } = this.world;
    const vessel = this.vesselId();
    const scale = this.playerScale();
    const moving = this.inputFrame.moveX !== 0 || this.inputFrame.moveY !== 0;
    const baseSpeed = this.world.survivor.stats.speed;
    const inputMag = Math.min(1, Math.hypot(this.inputFrame.moveX, this.inputFrame.moveY));
    const currentSpeed = (moving && player.dashRemain <= 0)
      ? this.world.stats.speed * playerSpeedMul(this.world) * inputMag
      : 0;
    const speedRatio = baseSpeed > 0 ? currentSpeed / baseSpeed : 1;
    if (moving && player.dashRemain <= 0) this.walkPhase += dt * 8 * speedRatio;
    const bob = Math.round(Math.sin(this.walkPhase) * 1.5 * scale);
    this.lastFacing = spriteFacing(moveFacing(this.inputFrame.moveX, this.inputFrame.moveY), this.lastFacing);
    const flipX = this.lastFacing === 'left';
    playEntity(this.playerSprite, vessel, moving && player.dashRemain <= 0 ? 'walk' : 'idle', speedRatio);
    this.fitBody(this.playerSprite, scale);
    this.playerSprite.setFlipX(flipX);
    this.playerEyes.setVisible(!authoredEntity(vessel));
    const ang = aimAngle(this.world);
    const x = Math.round(player.x);
    const y = Math.round(player.y + bob);
    const pDepth = this.ySortDepth(player.y, 0.0002);
    this.playerSprite.setPosition(x, y);
    this.playerSprite.setDepth(pDepth);
    this.playerSprite.setAlpha(player.iframeRemain > 0 ? 0.45 : 1);
    if (player.hurtRemain > 0) {
      this.playerSprite.setTint(0xff5566).setTintMode(Phaser.TintModes.MULTIPLY);
    } else {
      this.playerSprite.clearTint();
    }

    const pvx = player.x - this.playerPrevX;
    const pvy = player.y - this.playerPrevY;
    const pdist = Math.hypot(pvx, pvy);
    const pspeed = dt > 0 ? pdist / dt : 0;
    const reduceVfx = getSettings().reduceVfx;

    if (pspeed > 10 && pdist > 0.05 && !reduceVfx) {
      const norm = 1 / pdist;
      const dirX = pvx * norm;
      const dirY = pvy * norm;
      const trailLen = Math.min(8.0, Math.max(2.5, (pspeed / 100) * 3.8));
      const trailTint = biome === 'cinder' ? 0xd89b52 : 0x78ccff;

      this.playerTrail1.setTexture(this.playerSprite.texture.key, this.playerSprite.frame.name);
      this.fitBody(this.playerTrail1, scale);
      this.playerTrail1.setFlipX(flipX);
      this.playerTrail1.setPosition(
        Math.round(x - dirX * (trailLen * 0.45)),
        Math.round(y - dirY * (trailLen * 0.45)),
      );
      this.playerTrail1.setAlpha(0.38);
      this.playerTrail1.setTint(trailTint);
      this.playerTrail1.setDepth(pDepth - 0.0002);
      this.playerTrail1.setVisible(true);

      this.playerTrail2.setTexture(this.playerSprite.texture.key, this.playerSprite.frame.name);
      this.fitBody(this.playerTrail2, scale);
      this.playerTrail2.setFlipX(flipX);
      this.playerTrail2.setPosition(
        Math.round(x - dirX * trailLen),
        Math.round(y - dirY * trailLen),
      );
      this.playerTrail2.setAlpha(0.16);
      this.playerTrail2.setTint(trailTint);
      this.playerTrail2.setDepth(pDepth - 0.0004);
      this.playerTrail2.setVisible(true);
    } else {
      this.playerTrail1.setVisible(false);
      this.playerTrail2.setVisible(false);
    }
    this.playerPrevX = player.x;
    this.playerPrevY = player.y;
    if (this.world.decoy.active) {
      playEntity(this.decoySprite, vessel, 'idle');
      this.fitBody(this.decoySprite, scale);
      this.decoySprite.setFlipX(flipX);
      this.decoySprite.setVisible(true);
      this.decoySprite.setPosition(Math.round(this.world.decoy.x), Math.round(this.world.decoy.y));
      this.decoySprite.setDepth(this.ySortDepth(this.world.decoy.y));
      this.decoySprite.setAlpha(0.3 + 0.2 * Math.sin(this.world.runTime * 8));
    } else {
      this.decoySprite.setVisible(false);
    }
    this.playerGlow.setPosition(x, y);
    this.playerGlow.setScale(1.8 * scale);
    this.playerGlow.setAlpha(biome === 'cinder' ? 0.48 : 0.32);
    this.playerGlow.setTint(biome === 'cinder' ? 0xffdf90 : 0xb8f0ff);
    this.playerGlow.setDepth(pDepth - 0.001);
    this.playerEyes.setScale(scale);
    this.playerEyes.setDepth(pDepth + 0.0002);
    this.playerEyes.setPosition(
      x + Math.round(Math.cos(ang) * 2 * scale),
      y - Math.round(6 * scale) + Math.round(Math.sin(ang) * 1 * scale),
    );
  }

  private syncObstacles(biome: BiomeId, theme: EnvThemeId): void {
    const { obstacles, player } = this.world;
    const hazardFrame: 0 | 1 = Math.floor(this.world.runTime / 0.45) % 2 === 0 ? 0 : 1;
    const flash = Math.floor(this.world.runTime * 16) % 2 === 0;
    for (let i = 0; i < obstacles.cap; i += 1) {
      const sprite = this.obstacleSprites[i];
      const glow = this.volatileGlows[i];
      if (obstacles.alive[i] === 0) {
        sprite.setVisible(false);
        glow.setVisible(false);
        continue;
      }
      const obs = obstacles.items[i];
      let fallback = pillarKey(biome);
      let propSuffix = 'pillar';
      if (obs.type === 'hazard') {
        fallback = hazardKey(biome, hazardFrame);
        propSuffix = `hazard-${hazardFrame}`;
      } else if (obs.type === 'volatile') {
        fallback = volatileKey(biome);
        propSuffix = 'volatile';
      }

      const isTimedHazard = obs.type === 'hazard' && obs.timer > 0;
      const effectiveTheme = isTimedHazard ? 'rime' : theme;
      const effectiveBiome = isTimedHazard ? 'rime' : biome;
      const envId = resolveEnvThemeProp(effectiveTheme, propSuffix, this);
      if (obs.type === 'hazard') {
        const resolvedHazardId = envId ?? (hazardFrame === 1 ? resolveEnvThemeProp(effectiveTheme, 'hazard-0', this) : null);
        const blendedKey = resolvedHazardId ? `env-blended-${resolvedHazardId}` : '';
        if (blendedKey && this.textures.exists(blendedKey)) {
          sprite.setTexture(blendedKey);
        } else if (resolvedHazardId && applyEnvTexture(sprite, resolvedHazardId, fallback)) {
          // applied direct env texture
        } else {
          sprite.setTexture(hazardKey(effectiveBiome, hazardFrame));
        }
      } else if (envId) {
        applyEnvTexture(sprite, envId, fallback);
      } else {
        sprite.setTexture(fallback);
      }

      sprite.setVisible(true);
      sprite.setPosition(Math.round(obs.x), Math.round(obs.y));

      if (obs.type === 'pillar') {
        if (envId) {
          const rect = getEnvFrame(envId);
          if (rect) {
            sprite.setDisplaySize(rect.w, rect.h);
            const originY = rect.h > obs.radius * 2 ? (rect.h - obs.radius) / rect.h : 0.5;
            sprite.setOrigin(0.5, originY);
          } else {
            sprite.setScale(1);
            sprite.setOrigin(0.5, 0.5);
          }
        } else {
          const display = (obs.radius * 2) / sprite.width;
          sprite.setScale(display);
          sprite.setOrigin(0.5, 0.5);
        }
        sprite.setDepth(this.ySortDepth(obs.y));
      } else if (obs.type === 'volatile') {
        if (envId) {
          const rect = getEnvFrame(envId);
          if (rect) {
            sprite.setDisplaySize(rect.w, rect.h);
          } else {
            sprite.setScale(1);
          }
        } else {
          const display = (obs.radius * 2) / sprite.width;
          sprite.setScale(display);
        }
        sprite.setOrigin(0.5, 0.5);
        sprite.setDepth(this.ySortDepth(obs.y, -0.0001));
      } else if (obs.type === 'hazard') {
        const diameter = obs.radius * 2;
        sprite.setDisplaySize(diameter, diameter);
        sprite.setOrigin(0.5, 0.5);
        sprite.setDepth(1.05);
      } else {
        const display = (obs.radius * 2) / sprite.width;
        sprite.setScale(display);
        sprite.setOrigin(0.5, 0.5);
        sprite.setDepth(this.ySortDepth(obs.y));
      }

      if (obs.type === 'hazard') {
        const isTimed = obs.timer > 0;
        const fade = isTimed ? Math.min(1.0, obs.timer / 1.0) : 1.0;
        sprite.clearTint();
        sprite.setAlpha(fade);
        glow.setVisible(true);
        glow.setPosition(obs.x, obs.y);
        glow.setTint(isTimed ? 0x28f090 : biome === 'cinder' ? 0xff4411 : 0x28f090);
        glow.setAlpha((0.10 + 0.03 * Math.sin(this.world.runTime * 3 + i)) * fade);
        glow.setScale((obs.radius * 1.65) / 32);
      } else if (obs.type === 'pillar') {
        sprite.setAlpha(1.0);
        const near = Math.hypot(player.x - obs.x, player.y - obs.y) < 170;
        sprite.setTint(near ? 0xffe8d0 : 0xffffff);
        glow.setVisible(false);
      } else if (obs.type === 'volatile' && obs.state === 'primed') {
        sprite.setAlpha(1.0);
        sprite.setTint(flash ? 0xffffff : 0xff3322);
        glow.setVisible(true);
        glow.setPosition(obs.x, obs.y);
        glow.setTint(0xff3322);
        glow.setAlpha(0.2);
        glow.setScale(3.2);
        glow.setDepth(this.ySortDepth(obs.y, -0.0002));
      } else {
        sprite.setAlpha(1.0);
        sprite.clearTint();
        glow.setVisible(false);
      }
    }
  }

  private syncEnemies(dt: number, biome: BiomeId): void {
    const { enemies } = this.world;
    let eliteSlot = 0;
    let bossOn = false;
    const eliteData: Array<{
      active: boolean;
      isShielder: boolean;
      shieldActive: boolean;
      isNoxious: boolean;
      isCorpse: boolean;
    }> = [];
    for (let i = 0; i < enemies.cap; i += 1) {
      const alive = enemies.alive[i] !== 0;
      const fodder = alive && enemies.role[i] === ROLE_FODDER;
      const defId = enemies.defId[i];
      const dx = enemies.x[i] - this.enemyPrevX[i];
      const dy = enemies.y[i] - this.enemyPrevY[i];
      const dist = this.enemyAliveLast[i] !== 0 ? Math.hypot(dx, dy) : 0;
      this.hideFodderSlot(i, fodder ? defId : null);
      if (fodder && defId) {
        const layer = this.fodderLayers.get(defId);
        if (layer) {
          const tint = defId === 'enemy-astral-sniper' ? 0xb47aff : 0xffffff;
          const curSpeed = currentEnemySpeed(this.world, i);
          const baseSpeed = this.world.catalog.entity(defId).stats.speed;
          const speedRatio = baseSpeed > 0 ? curSpeed / baseSpeed : 1;
          const flipX = enemies.facing[i] < 0;
          this.gpuMember.x = enemies.x[i];
          this.gpuMember.y = enemies.y[i];
          this.gpuMember.scaleX = flipX ? -1 : 1;
          this.gpuMember.scaleY = 1;
          this.gpuMember.alpha = 1;
          this.gpuMember.frame = 0;

          const attacking = isEnemyAttacking(this.world, i);
          const wantedAttackKey = currentEnemyAttackAnim(this.world, i);
          const attackAnim = fodderAnimSpec(defId, wantedAttackKey) ?? fodderAnimSpec(defId, 'attack');
          const walkAnim = fodderAnimSpec(defId, 'walk');
          const idleAnim = fodderAnimSpec(defId, 'idle');
          const attackPlayed = this.fodderAttackPlayed.get(defId);
          const animNames = this.fodderAnimName.get(defId);
          const animStarts = this.fodderAnimStart.get(defId);

          let wantedAnim = '';
          let animDuration = 0;
          if (attacking && attackAnim) {
            if (attackPlayed && attackPlayed[i] === 1) {
              const elapsed = animStarts ? layer.timeElapsed - animStarts[i] : attackAnim.duration;
              if (elapsed < attackAnim.duration) {
                wantedAnim = attackAnim.name;
                animDuration = attackAnim.duration;
              } else if (walkAnim && curSpeed > 0) {
                wantedAnim = walkAnim.name;
                animDuration = walkAnim.duration / Math.max(0.1, speedRatio);
              } else if (idleAnim && idleAnim.frames.length > 1) {
                wantedAnim = idleAnim.name;
                animDuration = idleAnim.duration;
              }
            } else {
              if (attackPlayed) attackPlayed[i] = 1;
              if (animNames && animStarts) {
                animNames[i] = attackAnim.name;
                animStarts[i] = layer.timeElapsed;
              }
              wantedAnim = attackAnim.name;
              animDuration = attackAnim.duration;
            }
          } else {
            if (attackPlayed) attackPlayed[i] = 0;
            if (walkAnim && curSpeed > 0) {
              wantedAnim = walkAnim.name;
              animDuration = walkAnim.duration / Math.max(0.1, speedRatio);
            } else if (idleAnim && idleAnim.frames.length > 1) {
              wantedAnim = idleAnim.name;
              animDuration = idleAnim.duration;
            }
          }

          if (wantedAnim) {
            if (animNames && animStarts) {
              if (animNames[i] !== wantedAnim) {
                animNames[i] = wantedAnim;
                animStarts[i] = layer.timeElapsed;
              }
              this.gpuMember.creationTime = animStarts[i];
            } else {
              this.gpuMember.creationTime = layer.timeElapsed;
            }
            this.gpuMember.animation = {
              base: wantedAnim,
              duration: animDuration,
            };
          } else {
            if (animNames) animNames[i] = '';
            this.gpuMember.animation = undefined;
            this.gpuMember.creationTime = layer.timeElapsed;
            this.gpuMember.frame = idleAnim ? Number(idleAnim.frames[0]) || 0 : 0;
          }

          const hurt = enemies.hurtRemain[i] > 0;
          if (hurt) {
            this.gpuMember.tintMode = Phaser.TintModes.MULTIPLY;
            this.gpuMember.tintBlend = 0.70;
            this.gpuMember.tintBottomLeft = 0xff5566;
            this.gpuMember.tintTopLeft = 0xff5566;
            this.gpuMember.tintBottomRight = 0xff5566;
            this.gpuMember.tintTopRight = 0xff5566;
          } else {
            this.gpuMember.tintMode = Phaser.TintModes.MULTIPLY;
            this.gpuMember.tintBlend = defId === 'enemy-astral-sniper' ? 0.55 : 0;
            this.gpuMember.tintBottomLeft = tint;
            this.gpuMember.tintTopLeft = tint;
            this.gpuMember.tintBottomRight = tint;
            this.gpuMember.tintTopRight = tint;
          }
          layer.editMember(i, this.gpuMember);
          this.fodderShown[defId][i] = 1;

          const trailLayer = this.fodderTrailLayers.get(defId);
          if (trailLayer) {
            const reduceVfx = getSettings().reduceVfx;
            if (curSpeed > 10 && dist > 0.05 && !reduceVfx) {
              const norm = dist > 0 ? 1 / dist : 0;
              const dirX = dx * norm;
              const dirY = dy * norm;
              const trailLen = Math.min(8.0, Math.max(2.5, (curSpeed / 100) * 3.8));
              const trailTint = biome === 'cinder' ? 0x6e3826 : 0x284868;

              // Trail Step 1 (closer, medium alpha)
              clearGpuAnim(this.gpuMember);
              this.gpuMember.x = enemies.x[i] - dirX * (trailLen * 0.45);
              this.gpuMember.y = enemies.y[i] - dirY * (trailLen * 0.45);
              this.gpuMember.scaleX = flipX ? -1 : 1;
              this.gpuMember.scaleY = 1;
              this.gpuMember.alpha = 0.38;
              this.gpuMember.tintBlend = 0.8;
              this.gpuMember.tintBottomLeft = trailTint;
              this.gpuMember.tintTopLeft = trailTint;
              this.gpuMember.tintBottomRight = trailTint;
              this.gpuMember.tintTopRight = trailTint;
              this.gpuMember.frame = 0;
              trailLayer.editMember(i * 2, this.gpuMember);

              // Trail Step 2 (further, faded alpha)
              this.gpuMember.x = enemies.x[i] - dirX * trailLen;
              this.gpuMember.y = enemies.y[i] - dirY * trailLen;
              this.gpuMember.alpha = 0.16;
              this.gpuMember.tintBlend = 0.85;
              trailLayer.editMember(i * 2 + 1, this.gpuMember);
            } else {
              hideGpuMember(trailLayer, this.gpuMember, i * 2);
              hideGpuMember(trailLayer, this.gpuMember, i * 2 + 1);
            }
          }
        }
      }

      if (!alive || !defId) {
        hideGpuMember(this.enemyGlowLayer, this.gpuMember, i);
        this.enemyPrevX[i] = enemies.x[i];
        this.enemyPrevY[i] = enemies.y[i];
        this.enemyAliveLast[i] = 0;
        continue;
      }

      // Ground under-glow to separate enemy silhouette from dark floor tiles
      const isBoss = enemies.role[i] === ROLE_BOSS;
      const isElite = enemies.role[i] === ROLE_ELITE;
      const gScale = isBoss ? 2.4 : isElite ? 1.45 : 1.0;
      const glowAlpha = biome === 'cinder'
        ? (isBoss ? 0.44 : isElite ? 0.36 : 0.28)
        : (isBoss ? 0.36 : isElite ? 0.28 : 0.20);
      const glowTint = biome === 'cinder' ? 0xff7a33 : 0x60d0ff;

      clearGpuAnim(this.gpuMember);
      this.gpuMember.x = enemies.x[i];
      this.gpuMember.y = enemies.y[i] + (isBoss ? 10 : 4);
      this.gpuMember.scaleX = gScale;
      this.gpuMember.scaleY = gScale * 0.72;
      this.gpuMember.alpha = glowAlpha;
      this.gpuMember.tintBlend = 0.7;
      this.gpuMember.tintBottomLeft = glowTint;
      this.gpuMember.tintTopLeft = glowTint;
      this.gpuMember.tintBottomRight = glowTint;
      this.gpuMember.tintTopRight = glowTint;
      this.gpuMember.frame = 0;
      this.enemyGlowLayer.editMember(i, this.gpuMember);

      if (enemies.role[i] === ROLE_BOSS) {
        const curSpeed = currentEnemySpeed(this.world, i);
        const baseSpeed = this.world.catalog.entity(defId).stats.speed;
        const speedRatio = baseSpeed > 0 ? curSpeed / baseSpeed : 1;
        const attacking = isEnemyAttacking(this.world, i);
        const attackAnimKey = currentEnemyAttackAnim(this.world, i);
        playEntity(
          this.bossSprite,
          defId,
          attacking ? attackAnimKey : curSpeed > 0 ? 'walk' : 'idle',
          speedRatio,
        );
        const bDepth = this.ySortDepth(enemies.y[i]);
        this.bossSprite.setPosition(Math.round(enemies.x[i]), Math.round(enemies.y[i]));
        this.bossSprite.setDepth(bDepth);
        this.bossSprite.setFlipX(enemies.facing[i] < 0);
        this.bossSprite.setVisible(true);

        const bvx = enemies.x[i] - this.enemyPrevX[i];
        const bvy = enemies.y[i] - this.enemyPrevY[i];
        const bdist = this.enemyAliveLast[i] !== 0 ? Math.hypot(bvx, bvy) : 0;
        const bspeed = dt > 0 ? bdist / dt : 0;
        const reduceVfx = getSettings().reduceVfx;

        if (bspeed > 10 && bdist > 0.05 && !reduceVfx) {
          const norm = 1 / bdist;
          const dirX = bvx * norm;
          const dirY = bvy * norm;
          const trailLen = Math.min(10.0, Math.max(3.0, (bspeed / 80) * 4.2));
          const trailTint = biome === 'cinder' ? 0x6e3826 : 0x284868;
          const flipX = enemies.facing[i] < 0;

          this.bossTrail1.setTexture(this.bossSprite.texture.key, this.bossSprite.frame.name);
          this.bossTrail1.setFlipX(flipX);
          this.bossTrail1.setPosition(
            Math.round(enemies.x[i] - dirX * (trailLen * 0.45)),
            Math.round(enemies.y[i] - dirY * (trailLen * 0.45)),
          );
          this.bossTrail1.setAlpha(0.38);
          this.bossTrail1.setTint(trailTint);
          this.bossTrail1.setDepth(bDepth - 0.0002);
          this.bossTrail1.setVisible(true);

          this.bossTrail2.setTexture(this.bossSprite.texture.key, this.bossSprite.frame.name);
          this.bossTrail2.setFlipX(flipX);
          this.bossTrail2.setPosition(
            Math.round(enemies.x[i] - dirX * trailLen),
            Math.round(enemies.y[i] - dirY * trailLen),
          );
          this.bossTrail2.setAlpha(0.16);
          this.bossTrail2.setTint(trailTint);
          this.bossTrail2.setDepth(bDepth - 0.0004);
          this.bossTrail2.setVisible(true);
        } else {
          this.bossTrail1.setVisible(false);
          this.bossTrail2.setVisible(false);
        }

        if (enemies.hurtRemain[i] > 0) {
          this.bossSprite.setTint(0xff5566).setTintMode(Phaser.TintModes.MULTIPLY);
        } else if (this.world.boss.enraged) {
          this.bossSprite.setTint(defId === 'cinder-heart' ? 0xffbb88 : 0xb8f0ff).setTintMode(Phaser.TintModes.MULTIPLY);
        } else {
          this.bossSprite.clearTint();
        }
        bossOn = true;
      } else if (enemies.role[i] === ROLE_ELITE && eliteSlot < this.eliteSprites.length) {
        const sprite = this.eliteSprites[eliteSlot];
        const curSpeed = currentEnemySpeed(this.world, i);
        const baseSpeed = this.world.catalog.entity(defId).stats.speed;
        const speedRatio = baseSpeed > 0 ? curSpeed / baseSpeed : 1;
        const attacking = isEnemyAttacking(this.world, i);
        const attackAnimKey = currentEnemyAttackAnim(this.world, i);
        const eliteScale = this.world.catalog.loop.elite.radiusMul;
        playEntity(
          sprite,
          defId,
          attacking ? attackAnimKey : curSpeed > 0 ? 'walk' : 'idle',
          speedRatio,
        );
        const eDepth = this.ySortDepth(enemies.y[i]);
        sprite.setScale(eliteScale);
        sprite.setPosition(Math.round(enemies.x[i]), Math.round(enemies.y[i]));
        sprite.setDepth(eDepth);
        sprite.setFlipX(enemies.facing[i] < 0);
        sprite.setVisible(true);

        eliteData.push({
          active: true,
          isShielder: enemies.shielder[i] !== 0,
          shieldActive: enemies.shieldHp[i] > 0,
          isNoxious: enemies.noxious[i] !== 0,
          isCorpse: enemies.corpseRemain[i] > 0,
        });

        const evx = enemies.x[i] - this.enemyPrevX[i];
        const evy = enemies.y[i] - this.enemyPrevY[i];
        const edist = this.enemyAliveLast[i] !== 0 ? Math.hypot(evx, evy) : 0;
        const espeed = dt > 0 ? edist / dt : 0;
        const reduceVfx = getSettings().reduceVfx;
        const t1 = this.eliteTrails1[eliteSlot];
        const t2 = this.eliteTrails2[eliteSlot];

        if (espeed > 10 && edist > 0.05 && !reduceVfx && t1 && t2) {
          const norm = 1 / edist;
          const dirX = evx * norm;
          const dirY = evy * norm;
          const trailLen = Math.min(8.0, Math.max(2.5, (espeed / 100) * 3.8));
          const trailTint = biome === 'cinder' ? 0x6e3826 : 0x284868;
          const flipX = enemies.facing[i] < 0;

          t1.setTexture(sprite.texture.key, sprite.frame.name);
          t1.setScale(eliteScale);
          t1.setFlipX(flipX);
          t1.setPosition(
            Math.round(enemies.x[i] - dirX * (trailLen * 0.45)),
            Math.round(enemies.y[i] - dirY * (trailLen * 0.45)),
          );
          t1.setAlpha(0.38);
          t1.setTint(trailTint);
          t1.setDepth(eDepth - 0.0002);
          t1.setVisible(true);

          t2.setTexture(sprite.texture.key, sprite.frame.name);
          t2.setScale(eliteScale);
          t2.setFlipX(flipX);
          t2.setPosition(
            Math.round(enemies.x[i] - dirX * trailLen),
            Math.round(enemies.y[i] - dirY * trailLen),
          );
          t2.setAlpha(0.16);
          t2.setTint(trailTint);
          t2.setDepth(eDepth - 0.0004);
          t2.setVisible(true);
        } else if (t1 && t2) {
          t1.setVisible(false);
          t2.setVisible(false);
        }

        if (enemies.hurtRemain[i] > 0) {
          sprite.setTint(0xff5566).setTintMode(Phaser.TintModes.MULTIPLY);
        } else if (enemies.corpseRemain[i] > 0) {
          const flashCorpse = Math.floor(this.world.runTime * 16) % 2 === 0;
          sprite.setTint(flashCorpse ? 0x88ffaa : 0x226644).setTintMode(Phaser.TintModes.MULTIPLY);
        } else if (defId === 'enemy-astral-sniper') {
          sprite.setTint(0xb47aff).setTintMode(Phaser.TintModes.MULTIPLY);
        } else {
          sprite.clearTint();
        }
        eliteSlot += 1;
      }

      this.enemyPrevX[i] = enemies.x[i];
      this.enemyPrevY[i] = enemies.y[i];
      this.enemyAliveLast[i] = alive ? 1 : 0;
    }
    for (let i = eliteSlot; i < this.eliteSprites.length; i += 1) {
      this.eliteSprites[i].setVisible(false);
      this.eliteSprites[i].setData('attackDone', false);
      if (this.eliteTrails1[i]) this.eliteTrails1[i].setVisible(false);
      if (this.eliteTrails2[i]) this.eliteTrails2[i].setVisible(false);
    }
    this.eliteAffixShaders.sync(this.world.runTime, this.eliteSprites, eliteData);
    if (!bossOn) {
      this.bossSprite.setVisible(false);
      this.bossSprite.setData('attackDone', false);
      this.bossSprite.setData('activeAttackKey', '');
      this.bossTrail1.setVisible(false);
      this.bossTrail2.setVisible(false);
    }
  }

  private hideFodderSlot(index: number, keepDefId?: string | null): void {
    for (const [id, layer] of this.fodderLayers) {
      if (id === keepDefId) continue;
      if (this.fodderShown[id][index] === 0) continue;
      hideGpuMember(layer, this.gpuMember, index);
      this.fodderShown[id][index] = 0;
      const animNames = this.fodderAnimName.get(id);
      if (animNames) animNames[index] = '';
      const attackPlayed = this.fodderAttackPlayed.get(id);
      if (attackPlayed) attackPlayed[index] = 0;
    }
    for (const [id, trailLayer] of this.fodderTrailLayers) {
      if (id === keepDefId) continue;
      hideGpuMember(trailLayer, this.gpuMember, index * 2);
      hideGpuMember(trailLayer, this.gpuMember, index * 2 + 1);
    }
  }

  private syncGems(): void {
    const { gems } = this.world;
    for (let i = 0; i < gems.cap; i += 1) {
      const alive = gems.alive[i] !== 0;
      if (alive) {
        clearGpuAnim(this.gpuMember);
        this.gpuMember.x = gems.x[i];
        this.gpuMember.y = gems.y[i];
        this.gpuMember.scaleX = 1;
        this.gpuMember.scaleY = 1;
        this.gpuMember.alpha = 1;
        this.gpuMember.tintBlend = 0;
        this.gpuMember.tintBottomLeft = 0xffffff;
        this.gpuMember.tintTopLeft = 0xffffff;
        this.gpuMember.tintBottomRight = 0xffffff;
        this.gpuMember.tintTopRight = 0xffffff;
        this.gemLayer.editMember(i, this.gpuMember);
        this.gemShown[i] = 1;
      } else if (this.gemShown[i] !== 0) {
        hideGpuMember(this.gemLayer, this.gpuMember, i);
        this.gemShown[i] = 0;
      }
    }
  }

  private syncLores(): void {
    const { lores, newlyCollectedLores } = this.world;
    for (let i = 0; i < this.loreSprites.length; i += 1) {
      const sprite = this.loreSprites[i];
      const glow = this.loreGlows[i];
      if (i >= lores.cap || lores.alive[i] === 0) {
        sprite.setVisible(false);
        glow.setVisible(false);
        continue;
      }
      const bob = Math.sin(this.world.runTime * 5 + i) * 2.5;
      const x = Math.round(lores.x[i]);
      const y = Math.round(lores.y[i] + bob);
      sprite.setPosition(x, y).setVisible(true);
      glow
        .setPosition(x, y)
        .setVisible(true)
        .setAlpha(0.28 + 0.12 * Math.sin(this.world.runTime * 6 + i));
    }

    if (newlyCollectedLores.length > 0) {
      while (newlyCollectedLores.length > 0) {
        const entityId = newlyCollectedLores.shift();
        if (!entityId) continue;
        const newlyInscribed = recordLorePickup(entityId);
        if (newlyInscribed) {
          playSfx('confirm');
          if (!stingActive()) {
            const def = this.world.catalog.entity(entityId);
            showSting(
              {
                kicker: 'Apocrypha Recovered',
                title: `${def.name} Treatise`,
                sub: 'Inscribed in The Archives',
              },
              1800,
            );
          }
        }
      }
    }
  }

  private syncOverlay(): void {
    const { phase, offer } = this.world;
    if (getOverlayMode() === 'pause') {
      this.lastPhase = phase;
      return;
    }
    if (phase === 'levelup' && offer && this.shownOffer !== offer) {
      const rec = commitWorldProgress(this.world);
      this.world.unlockedItems = getUnlockedItemIds(rec);
      this.shownOffer = offer;
      showLevelUp(offer);
    } else if (phase === 'victory' && this.lastPhase !== 'victory') {
      recordRunEnd(this.world, 'victory');
      showRunEnd('victory', `The last seal holds · ${formatTime(this.world.runTime)}`, this.runRecap());
    } else if (phase === 'defeat' && this.lastPhase !== 'defeat') {
      recordRunEnd(this.world, 'defeat');
      showRunEnd('defeat', `${currentStage(this.world).name} · ${formatTime(this.world.runTime)}`, this.runRecap());
    } else if (phase === 'play' && this.lastPhase !== 'play') {
      hideOverlay();
      this.shownOffer = null;
    }
    this.lastPhase = phase;
  }

  private syncStings(): void {
    if (this.world.stageIndex !== this.lastStageIndex) {
      this.lastStageIndex = this.world.stageIndex;
      this.enemyAliveLast.fill(0);
      this.playerPrevX = this.world.player.x;
      this.playerPrevY = this.world.player.y;
      this.lastBossSpawned = false;
      this.bossMusicActive = false;
      const rec = commitWorldProgress(this.world);
      this.world.unlockedItems = getUnlockedItemIds(rec);
      const stage = currentStage(this.world);
      setMusicScene({ kind: 'stage', stageId: stage.id });
      showSting(
        {
          kicker: 'The Rift yields',
          title: stage.name,
          sub: 'A colder chamber. The working continues.',
        },
        1400,
      );
    }
    if (this.world.bossSpawned && !this.lastBossSpawned) {
      this.lastBossSpawned = true;
      this.bossMusicActive = true;
      const stage = currentStage(this.world);
      setMusicScene({ kind: 'boss', bossId: stage.boss, stageId: stage.id });
      const name = this.world.focus.name || currentObjective(this.world).name || 'the seal';
      showSting(
        {
          kicker: 'The seal breaks',
          title: name,
          sub: currentStage(this.world).name,
        },
        2000,
      );
    }
    if (this.bossMusicActive && this.world.counts.boss === 0 && this.world.portal.open) {
      this.bossMusicActive = false;
      const rec = commitWorldProgress(this.world);
      this.world.unlockedItems = getUnlockedItemIds(rec);
      const stage = currentStage(this.world);
      setMusicScene({ kind: 'stage', stageId: stage.id });
    }
    if (stingActive()) {
      const moving = Math.abs(this.inputFrame.moveX) + Math.abs(this.inputFrame.moveY) > 0;
      if (moving) hideSting();
    }
  }

  private syncHoldPrompt(): void {
    // The hold / portal warning is now integrated directly into #hud-objective and #hud-objective-sub,
    // eliminating duplicate prompt bars and double progress gauges.
    setHoldPrompt({ visible: false, title: '', detail: '', pct: 0, outside: false });
  }

  private runRecap() {
    const finalRec = getRecords();
    const newUnlockedItems = catalog.items.filter(
      (item) => !this.initialUnlockedItems.has(item.id) && isItemUnlocked(item, finalRec),
    );
    const newUnlockedSurvivors = catalog.survivors.filter(
      (s) => !this.initialUnlockedSurvivors.has(s.id) && isSurvivorUnlocked(s, finalRec),
    );

    const newUnlocks: RunRecapUnlock[] = [
      ...newUnlockedItems.map((item) => ({
        kind: 'item' as const,
        id: item.id,
        name: item.name,
        rarity: item.rarity,
        desc: item.unlock?.label ? `Condition Met: ${getUnlockLabel(item.unlock, finalRec)}` : 'New Relic Unlocked',
      })),
      ...newUnlockedSurvivors.map((s) => ({
        kind: 'survivor' as const,
        id: s.id,
        name: s.name,
        desc: s.unlock?.label ? `Condition Met: ${getUnlockLabel(s.unlock, finalRec)}` : 'New Vessel Unsealed',
      })),
    ];

    const allUnlockedItems = getUnlockedItemIds(finalRec);
    const allUnlockedSurvivors = catalog.survivors.filter((s) => isSurvivorUnlocked(s, finalRec));

    return {
      survivor: this.world.survivor.name,
      survivorId: this.world.survivor.id,
      stage: currentStage(this.world).name,
      time: this.world.runTime,
      level: this.world.level,
      coefficient: this.world.coefficient,
      bosses: this.world.bossesDefeated,
      kills: this.world.kills.total,
      damageDealt: Math.round(this.world.damageDealt),
      damageTaken: Math.round(this.world.damageTaken),
      healingDone: Math.round(this.world.healingDone),
      gemsCollected: this.world.gemsCollected,
      items: this.world.inventory.map((inst) => {
        const def = this.world.catalog.item(inst.id);
        return {
          id: inst.id,
          name: def.name,
          stacks: inst.stacks,
          rarity: def.rarity,
          lore: def.lore,
        };
      }),
      newUnlocks,
      unlockProgress: {
        itemsUnlocked: allUnlockedItems.size,
        totalItems: catalog.items.length,
        survivorsUnlocked: allUnlockedSurvivors.length,
        totalSurvivors: catalog.survivors.length,
      },
    };
  }

  private drawZones(dt: number): void {
    const g = this.zoneGfx;
    const tel = this.world.teleporter;
    const biome = this.biome();
    const theme = this.envTheme();
    const inZone =
      tel.state !== 'hidden' && Math.hypot(this.world.player.x - tel.x, this.world.player.y - tel.y) <= tel.radius;
    const t = tel.hold > 0 ? Math.min(1, tel.charge / tel.hold) : 0;

    // Smooth occult energy transfer shader from player to the transmutation circle
    this.circleChargeShader.sync(
      this.world.runTime,
      tel.x,
      tel.y,
      tel.radius,
      t,
      tel.state === 'charging',
      inZone,
      this.world.player.x,
      this.world.player.y,
      biome,
      dt,
    );

    if (this.circleGlowFilter) {
      if (tel.state === 'charging') {
        this.circleGlowFilter.setActive(true);
        this.circleGlowFilter.color = biome === 'cinder' ? 0xffaa33 : 0x55ffff;
        const pulse = 0.5 + 0.5 * Math.sin(this.world.runTime * 4);
        this.circleGlowFilter.outerStrength = inZone ? (1.2 + 2.0 * t + pulse * 1.2) : (0.6 + pulse * 0.4);
        this.circleGlowFilter.innerStrength = inZone ? (0.2 + 0.6 * t) : 0;
      } else {
        this.circleGlowFilter.setActive(false);
      }
    }

    const circleId = resolveEnvThemeProp(theme, 'circle', this);
    const hasAuthoredCircle = !!circleId && tel.state !== 'hidden';
    if (hasAuthoredCircle && circleId) {
      applyEnvTexture(this.circleSprite, circleId);
      this.circleSprite
        .setVisible(true)
        .setPosition(tel.x, tel.y)
        .setDisplaySize(tel.radius * 2, tel.radius * 2);
    } else {
      this.circleSprite.setVisible(false);
    }

    const portalId = resolveEnvThemeProp(theme, 'portal', this);
    const hasAuthoredPortal = !!portalId && this.world.portal.open;
    if (hasAuthoredPortal && portalId) {
      applyEnvTexture(this.portalSprite, portalId);
      const radius = this.world.catalog.loop.portalRadius;
      const hold = this.world.catalog.loop.portalHold;
      const pct = hold > 0 ? Math.min(1, this.world.portal.hold / hold) : 0;
      const pulse = 0.75 + 0.15 * Math.sin(this.world.runTime * 7) + 0.1 * pct;
      this.portalSprite
        .setVisible(true)
        .setPosition(this.world.portal.x, this.world.portal.y)
        .setDisplaySize(radius * 2, radius * 2)
        .setAlpha(pulse);
    } else {
      this.portalSprite.setVisible(false);
    }

    const pulseTick = this.world.portal.open ? Math.floor(this.world.runTime * 8) : 0;
    const circleKey = `${this.world.stageGen}|${tel.state}|${inZone ? 1 : 0}|${Math.round(t * 50)}|${this.world.portal.open ? 1 : 0}|${Math.round(this.world.portal.hold * 10)}|${pulseTick}`;
    if (circleKey === this.lastCircleKey) {
      this.telGlow.setAlpha(tel.state === 'charging' ? (inZone ? 0.22 : 0.08) : 0);
      return;
    }
    this.lastCircleKey = circleKey;
    g.clear();
    if (tel.state !== 'hidden') {
      drawTransmutationCircle(g, tel.x, tel.y, tel.radius, t, inZone, biome, tel.state === 'charging', hasAuthoredCircle);
      this.telGlow.setPosition(tel.x, tel.y);
      this.telGlow.setAlpha(tel.state === 'charging' ? (inZone ? 0.22 : 0.08) : 0);
    } else {
      this.telGlow.setAlpha(0);
    }
    if (this.world.portal.open && !hasAuthoredPortal) {
      const color = biome === 'cinder' ? 0xffb347 : 0xdff6ff;
      const radius = this.world.catalog.loop.portalRadius;
      const hold = this.world.catalog.loop.portalHold;
      const pct = hold > 0 ? Math.min(1, this.world.portal.hold / hold) : 0;
      const pulse = 0.16 + 0.1 * Math.sin(this.world.runTime * 7) + 0.18 * pct;
      g.lineStyle(3, color, 1);
      g.strokeCircle(this.world.portal.x, this.world.portal.y, radius);
      g.fillStyle(color, pulse);
      g.fillCircle(this.world.portal.x, this.world.portal.y, radius);
    }
  }

  private drawTelegraphs(biome: BiomeId): void {
    const g = this.telegraphGfx;
    g.clear();
    const { enemies } = this.world;
    const flash = Math.floor(this.world.runTime * 12) % 2 === 0;
    const line = flash ? 0xffffff : biome === 'cinder' ? 0xff7a3a : 0x55ffff;
    for (let i = 0; i < enemies.cap; i += 1) {
      if (enemies.alive[i] === 0) continue;
      if (enemies.corpseRemain[i] > 0) {
        const pop = this.world.catalog.loop.noxious.popRadius;
        g.lineStyle(2, flash ? 0xccffdd : 0x33cc66, 0.95);
        g.strokeCircle(Math.round(enemies.x[i]), Math.round(enemies.y[i]), pop);
      }
      if (enemies.rootRemain[i] > 0) {
        g.lineStyle(2, 0xc4a05a, 0.85);
        g.lineBetween(
          Math.round(this.world.player.x),
          Math.round(this.world.player.y),
          Math.round(enemies.x[i]),
          Math.round(enemies.y[i]),
        );
      }
      if (enemies.windup[i] <= 0) continue;
      const defId = enemies.defId[i];
      const ai = defId ? this.world.catalog.entity(defId).ai : null;
      if (ai?.type === 'sniper') {
        const laser = flash ? 0xff2244 : 0x4488ff;
        const dx = enemies.aimX[i] - enemies.x[i];
        const dy = enemies.aimY[i] - enemies.y[i];
        const len = Math.hypot(dx, dy) || 1;
        const far = 980;
        dashedLine(g, enemies.x[i], enemies.y[i], enemies.x[i] + (dx / len) * far, enemies.y[i] + (dy / len) * far, laser);
        g.lineStyle(2, laser, 0.55);
        g.lineBetween(
          Math.round(enemies.x[i]),
          Math.round(enemies.y[i]),
          Math.round(enemies.x[i] + (dx / len) * far),
          Math.round(enemies.y[i] + (dy / len) * far),
        );
        continue;
      }
      if (ai?.type === 'boss') {
        const { boss } = this.world;
        const atk = boss.activeAttack >= 0 ? ai.attacks[boss.activeAttack] : null;
        if (atk && boss.phase === 'windup') {
          const grow = boss.duration > 0 ? Math.min(1, boss.elapsed / boss.duration) : 1;
          if (atk.type === 'fan') {
            const baseAng = Math.atan2(boss.aimY - enemies.y[i], boss.aimX - enemies.x[i]);
            const spreadRad = (atk.spread * Math.PI) / 180;
            const reach = Math.min(340, atk.projectile.speed * atk.projectile.lifetime * 0.65);
            const count = Math.max(1, atk.count);
            for (let k = 0; k < count; k += 1) {
              const frac = count === 1 ? 0 : k / (count - 1) - 0.5;
              const ang = baseAng + frac * spreadRad;
              dashedLine(
                g,
                enemies.x[i],
                enemies.y[i],
                enemies.x[i] + Math.cos(ang) * reach,
                enemies.y[i] + Math.sin(ang) * reach,
                line,
              );
            }
            g.lineStyle(2, line, 0.9);
            g.strokeCircle(Math.round(enemies.x[i]), Math.round(enemies.y[i]), Math.round(16 + grow * 22));
          } else if (atk.type === 'bolt') {
            dashedLine(g, enemies.x[i], enemies.y[i], boss.aimX, boss.aimY, line);
            g.lineStyle(2, line, 0.9);
            g.strokeCircle(Math.round(enemies.x[i]), Math.round(enemies.y[i]), Math.round(14 + grow * 20));
          } else if (atk.type === 'summon') {
            g.lineStyle(2, flash ? 0xffffff : line, 0.9);
            g.strokeCircle(Math.round(enemies.x[i]), Math.round(enemies.y[i]), Math.round(enemies.radius[i] + 10 + grow * 18));
          }
        }
        continue;
      }
      const max = ai && ai.type === 'ranged' ? ai.windup : 0.4;
      const grow = max > 0 ? 1 - enemies.windup[i] / max : 1;
      dashedLine(g, enemies.x[i], enemies.y[i], enemies.aimX[i], enemies.aimY[i], line);
      g.lineStyle(1, line, 0.9);
      g.strokeCircle(enemies.x[i], enemies.y[i], Math.round(10 + grow * 16));
    }
    if (this.world.player.rootRemain > 0) {
      g.lineStyle(2, flash ? 0xffffff : 0x66e8ff, 0.95);
      g.strokeCircle(
        Math.round(this.world.player.x),
        Math.round(this.world.player.y),
        this.world.player.radius + 8,
      );
    }
    const { obstacles } = this.world;
    for (let i = 0; i < obstacles.cap; i += 1) {
      if (obstacles.alive[i] === 0) continue;
      const obs = obstacles.items[i];
      if (obs.type !== 'volatile' || obs.state !== 'primed') continue;
      const radius = this.world.catalog.obstacles.volatile.explosionRadius;
      g.lineStyle(1, flash ? 0xffffff : 0xff3322, 0.95);
      g.strokeCircle(Math.round(obs.x), Math.round(obs.y), radius);
    }
    const { zones } = this.world;
    for (let i = 0; i < zones.cap; i += 1) {
      if (zones.alive[i] === 0) continue;
      if (zones.kind[i] === ZONE_STRIKE) {
        const grow = Math.max(0.25, 1 - zones.remain[i] / 0.7);
        g.lineStyle(2, flash ? 0xfff4c8 : 0xffaa33, 0.95);
        g.strokeCircle(Math.round(zones.x[i]), Math.round(zones.y[i]), Math.round(zones.radius[i] * grow));
      } else if (zones.kind[i] === ZONE_LINE) {
        if (getSettings().reduceVfx) {
          const half = zones.length[i] * 0.5;
          const x0 = zones.x[i] - zones.dirX[i] * half;
          const y0 = zones.y[i] - zones.dirY[i] * half;
          const x1 = zones.x[i] + zones.dirX[i] * half;
          const y1 = zones.y[i] + zones.dirY[i] * half;
          g.lineStyle(Math.max(2, zones.width[i] * 0.35), flash ? 0xffcc66 : 0xff5522, 0.8);
          g.lineBetween(Math.round(x0), Math.round(y0), Math.round(x1), Math.round(y1));
        }
      }
    }
  }

  private syncWaypoint(): void {
    const objective = currentObjective(this.world);
    if (!objective.hasTarget) {
      this.waypoint.setVisible(false);
      return;
    }
    const cam = this.cameras.main;
    const view = cam.worldView;
    const onScreen =
      objective.targetX > view.x + WAYPOINT_PAD &&
      objective.targetX < view.x + view.width - WAYPOINT_PAD &&
      objective.targetY > view.y + WAYPOINT_PAD &&
      objective.targetY < view.y + view.height - WAYPOINT_PAD;
    if (onScreen) {
      this.waypoint.setVisible(false);
      return;
    }
    const dx = objective.targetX - this.world.player.x;
    const dy = objective.targetY - this.world.player.y;
    const len = Math.hypot(dx, dy);
    if (len < 1) {
      this.waypoint.setVisible(false);
      return;
    }
    if (this.waypoint.texture.key !== 'ui-atlas' && this.waypoint.texture.key !== 'ui-nav-arrow') {
      if (applyUiTexture(this.waypoint, 'nav-arrow', 'px-waypoint')) {
        this.waypoint.setScale(1.0);
      }
    }
    this.waypoint.setVisible(true);
    this.waypoint.setPosition(
      this.world.player.x + (dx / len) * WAYPOINT_DIST,
      this.world.player.y + (dy / len) * WAYPOINT_DIST,
    );
    const isUiArrow = this.waypoint.frame?.name === 'nav-arrow' || this.waypoint.texture?.key === 'ui-nav-arrow';
    const angleOffset = isUiArrow ? -Math.PI / 2 : 0;
    this.waypoint.setRotation(Math.atan2(dy, dx) + angleOffset);
  }

  private consumeFx(): void {
    const { fx, player } = this.world;
    const utilityId = this.world.survivor.skills.utility ?? '';
    const dashRot = Math.atan2(player.dashVy, player.dashVx);
    for (let i = 0; i < fx.count; i += 1) {
      const kind = fx.kind[i];
      const x = fx.x[i];
      const y = fx.y[i];
      const radius = fx.radius[i];
      const tint = fx.tint[i] || 0xffffff;
      const isCrit = tint === 0xff4422;
      const stillId = eventFxId(kind, tint, utilityId);
      const rotation = kind === FX_DASH ? dashRot : 0;
      const shown = stillId ? spawnFxStill(this, this.fxStills, stillId, x, y, rotation) : false;
      if (kind === FX_HIT) {
        this.damageFx.spawn(x, y, isCrit ? 1 : 0);
      } else if (kind === FX_HURT) {
        this.damageFx.spawn(x, y, 2, 88);
        this.playerHurtShader.trigger(1.0);
      } else if (kind === FX_CENSER_IMPACT) {
        this.skillImpactShaders.spawnCenser(x, y, radius, isCrit);
      } else if (kind === FX_CRUCIBLE_IMPACT) {
        this.skillImpactShaders.spawnCrucible(x, y, radius, isCrit);
      }
      if (!shown) {
        if (kind === FX_HIT) spawnBurst(this.sparks, x, y, tint, 4, 90, 0.18);
        else if (kind === FX_HURT) spawnBurst(this.sparks, x, y, tint, 4, 90, 0.18);
        else if (kind === FX_DEATH) spawnBurst(this.sparks, x, y, tint, 10, 140, 0.28);
        else if (kind === FX_MUZZLE) spawnBurst(this.sparks, x, y, tint, 3, 70, 0.14);
        else if (kind === FX_DASH) spawnBurst(this.sparks, x, y, tint, 6, 110, 0.2);
        else if (kind === FX_STRIKE) spawnBurst(this.sparks, x, y, tint, 14, 160, 0.32);
        else if (kind === FX_GEM) spawnBurst(this.sparks, x, y, tint, 3, 70, 0.15);
        else if (kind === FX_CENSER_IMPACT) spawnBurst(this.sparks, x, y, tint, 8, 120, 0.25);
        else if (kind === FX_CRUCIBLE_IMPACT) spawnBurst(this.sparks, x, y, tint, 14, 160, 0.32);
      }
      if (kind === FX_HIT || kind === FX_CENSER_IMPACT) playSfx('hit');
      else if (kind === FX_HURT) playSfx('hurt');
      else if (kind === FX_DEATH) playSfx(tint === 0xff8844 ? 'break' : 'death');
      else if (kind === FX_MUZZLE) playSfx('muzzle');
      else if (kind === FX_DASH) playSfx('dash');
      else if (kind === FX_STRIKE || kind === FX_CRUCIBLE_IMPACT) playSfx('strike');
      else if (kind === FX_GEM) playSfx('gem');
    }
    fx.count = 0;
  }

  private stepSparks(dt: number): void {
    for (let i = 0; i < this.sparks.length; i += 1) {
      const spark = this.sparks[i];
      if (spark.life <= 0) {
        if (this.sparkShown[i] !== 0) {
          hideGpuMember(this.sparkLayer, this.gpuMember, i);
          this.sparkShown[i] = 0;
        }
        continue;
      }
      spark.life -= dt;
      spark.x += spark.vx * dt;
      spark.y += spark.vy * dt;
      const t = spark.max > 0 ? Math.max(0, spark.life / spark.max) : 0;
      clearGpuAnim(this.gpuMember);
      this.gpuMember.x = spark.x;
      this.gpuMember.y = spark.y;
      this.gpuMember.scaleX = spark.size * (0.4 + 0.8 * t);
      this.gpuMember.scaleY = spark.size * (0.4 + 0.8 * t);
      this.gpuMember.alpha = t;
      this.gpuMember.tintBlend = 0.85;
      this.gpuMember.tintBottomLeft = spark.tint;
      this.gpuMember.tintTopLeft = spark.tint;
      this.gpuMember.tintBottomRight = spark.tint;
      this.gpuMember.tintTopRight = spark.tint;
      this.sparkLayer.editMember(i, this.gpuMember);
      this.sparkShown[i] = 1;
    }
  }

  private stepGhosts(dt: number): void {
    const { player } = this.world;
    this.ghostCd = Math.max(0, this.ghostCd - dt);
    if (player.dashRemain > 0 && this.ghostCd <= 0) {
      this.ghostCd = 0.05;
      const slot = nextGhost(this.ghostLife);
      if (slot >= 0) {
        this.ghostLife[slot] = 0.18;
        const ghost = this.ghosts[slot];
        ghost.setTexture(this.playerSprite.texture.key, this.playerSprite.frame.name);
        this.fitBody(ghost);
        ghost.setFlipX(this.playerSprite.flipX);
        ghost.setPosition(Math.round(player.x), Math.round(player.y));
        ghost.setDepth(this.ySortDepth(player.y, -0.0002));
        ghost.setVisible(true);
        ghost.setAlpha(0.5);
        ghost.setTint(this.world.survivor.id === 'penitent' ? 0xffc878 : 0xb8fff8);
      }
    }
    for (let i = 0; i < GHOST_CAP; i += 1) {
      if (this.ghostLife[i] <= 0) {
        this.ghosts[i].setVisible(false);
        continue;
      }
      this.ghostLife[i] -= dt;
      this.ghosts[i].setAlpha(Math.max(0, this.ghostLife[i] / 0.18) * 0.5);
      if (this.ghostLife[i] <= 0) this.ghosts[i].setVisible(false);
    }
  }

  private syncBrimstoneSparks(dt: number): void {
    if (getSettings().reduceVfx) return;
    const { zones } = this.world;
    for (let i = 0; i < zones.cap; i += 1) {
      if (zones.alive[i] === 0 || zones.kind[i] !== ZONE_LINE) continue;
      if (Math.random() < dt * 26) {
        const half = zones.length[i] * 0.46;
        const along = (Math.random() * 2 - 1) * half;
        const across = (Math.random() * 2 - 1) * (zones.width[i] * 0.3);
        const perpX = -zones.dirY[i];
        const perpY = zones.dirX[i];
        const sx = zones.x[i] + zones.dirX[i] * along + perpX * across;
        const sy = zones.y[i] + zones.dirY[i] * along + perpY * across;
        const tint = Math.random() < 0.65 ? 0xf9c22b : 0xf79617;
        spawnSingleSpark(
          this.sparks,
          sx,
          sy,
          tint,
          (Math.random() - 0.5) * 22,
          -30 - Math.random() * 45,
          0.22 + Math.random() * 0.18,
        );
      }
    }
  }
}

function seedGpuLayer(
  layer: Phaser.GameObjects.SpriteGPULayer,
  count: number,
  member: GpuMember,
): void {
  clearGpuAnim(member);
  member.x = 0;
  member.y = 0;
  member.scaleX = 0;
  member.scaleY = 0;
  member.alpha = 0;
  for (let i = 0; i < count; i += 1) {
    layer.addMember(member);
  }
}

/** Shared `gpuMember` also carries fodder `animation` / `frame` / `creationTime`; strip them on layers that have none. */
function clearGpuAnim(member: GpuMember): void {
  member.animation = undefined;
  member.frame = undefined;
  member.creationTime = undefined;
}

function hideGpuMember(
  layer: Phaser.GameObjects.SpriteGPULayer,
  member: GpuMember,
  index: number,
): void {
  clearGpuAnim(member);
  member.x = 0;
  member.y = 0;
  member.scaleX = 0;
  member.scaleY = 0;
  member.alpha = 0;
  layer.editMember(index, member);
}

function spawnBurst(
  sparks: Spark[],
  x: number,
  y: number,
  tint: number,
  count: number,
  speed: number,
  life: number,
): void {
  if (getSettings().reduceVfx) return;
  let spawned = 0;
  for (let i = 0; i < sparks.length && spawned < count; i += 1) {
    if (sparks[i].life > 0) continue;
    const ang = Math.random() * Math.PI * 2;
    const mag = speed * (0.35 + Math.random() * 0.65);
    sparks[i].life = life;
    sparks[i].max = life;
    sparks[i].x = x;
    sparks[i].y = y;
    sparks[i].vx = Math.cos(ang) * mag;
    sparks[i].vy = Math.sin(ang) * mag;
    sparks[i].size = 0.7 + Math.random() * 0.6;
    sparks[i].tint = tint;
    spawned += 1;
  }
}

function spawnSingleSpark(
  sparks: Spark[],
  x: number,
  y: number,
  tint: number,
  vx: number,
  vy: number,
  life: number,
): void {
  for (let i = 0; i < sparks.length; i += 1) {
    if (sparks[i].life > 0) continue;
    sparks[i].life = life;
    sparks[i].max = life;
    sparks[i].x = x;
    sparks[i].y = y;
    sparks[i].vx = vx;
    sparks[i].vy = vy;
    sparks[i].size = 0.6 + Math.random() * 0.5;
    sparks[i].tint = tint;
    return;
  }
}

function nextGhost(life: Float32Array): number {
  for (let i = 0; i < life.length; i += 1) {
    if (life[i] <= 0) return i;
  }
  return 0;
}

function drawTransmutationCircle(
  g: Phaser.GameObjects.Graphics,
  x: number,
  y: number,
  radius: number,
  charge: number,
  inZone: boolean,
  biome: BiomeId,
  charging: boolean,
  hasAuthoredSprite = false,
): void {
  const cx = Math.round(x);
  const cy = Math.round(y);
  const r = Math.round(radius);
  const active = biome === 'cinder' ? 0xffaa33 : 0x55ffff;
  const muted = biome === 'cinder' ? 0x5a3030 : 0x2a4058;
  const ring = charging && inZone ? active : muted;
  if (!hasAuthoredSprite) {
    g.lineStyle(2, ring, charging ? 0.95 : 0.35);
    g.strokeCircle(cx, cy, r);
    g.lineStyle(1, ring, 0.7);
    g.strokeCircle(cx, cy, Math.round(r * 0.62));
    const inner = Math.round(r * 0.72);
    for (let i = 0; i < 6; i += 1) {
      const a0 = (i * Math.PI) / 3 - Math.PI / 2;
      const a1 = ((i + 2) * Math.PI) / 3 - Math.PI / 2;
      g.lineBetween(
        Math.round(cx + Math.cos(a0) * inner),
        Math.round(cy + Math.sin(a0) * inner),
        Math.round(cx + Math.cos(a1) * inner),
        Math.round(cy + Math.sin(a1) * inner),
      );
    }
    for (let i = 0; i < 6; i += 1) {
      const a = (i * Math.PI) / 3 - Math.PI / 2;
      const nx = Math.round(cx + Math.cos(a) * r);
      const ny = Math.round(cy + Math.sin(a) * r);
      g.fillStyle(ring, 0.9);
      g.fillRect(nx - 2, ny - 2, 4, 4);
    }
  }
  if (charging && charge > 0) {
    g.lineStyle(3, active, inZone ? 1 : 0.45);
    const steps = Math.max(1, Math.round(48 * charge));
    let px = cx;
    let py = cy - r;
    for (let s = 1; s <= steps; s += 1) {
      const ang = -Math.PI / 2 + (Math.PI * 2 * charge * s) / steps;
      const nx = Math.round(cx + Math.cos(ang) * r);
      const ny = Math.round(cy + Math.sin(ang) * r);
      g.lineBetween(px, py, nx, ny);
      px = nx;
      py = ny;
    }
  }
}

function dashedLine(
  g: Phaser.GameObjects.Graphics,
  x0: number,
  y0: number,
  x1: number,
  y1: number,
  color: number,
): void {
  const dx = x1 - x0;
  const dy = y1 - y0;
  const len = Math.hypot(dx, dy);
  if (len < 1) return;
  const nx = dx / len;
  const ny = dy / len;
  g.lineStyle(1, color, 0.95);
  let d = 0;
  while (d < len) {
    const a = d;
    const b = Math.min(len, d + 5);
    g.lineBetween(
      Math.round(x0 + nx * a),
      Math.round(y0 + ny * a),
      Math.round(x0 + nx * b),
      Math.round(y0 + ny * b),
    );
    d += 9;
  }
}

function hudSkills(world: World) {
  const slots: SkillSlot[] = ['primary', 'secondary', 'utility', 'special'];
  const glyphs = ['I', 'II', 'III', 'IV'];
  return slots.map((slot, index) => {
    const id = world.survivor.skills[slot];
    if (!id) {
      return { slot, id: '', name: '', glyph: glyphs[index], cd: 0, max: 0, empty: true, iframe: false };
    }
    const skill = world.catalog.skill(id);
    return {
      slot,
      id,
      name: skill.name,
      glyph: glyphs[index],
      cd: world.player.skillCd[slot],
      max: skill.cooldown * world.stats.cooldownMul,
      empty: false,
      iframe: slot === 'utility' && world.player.iframeRemain > 0,
    };
  });
}

function resolveSurvivorId(): string {
  const id = getSettings().survivorId;
  const hit = catalog.survivors.find((entry) => entry.id === id);
  if (hit && isSurvivorUnlocked(hit)) return hit.id;
  return catalog.world.defaultSurvivor;
}

function objectiveCopy(
  objective: Objective,
  outsideWarning = '',
): { kicker: string; label: string; detail: string; sub?: string } {
  if (objective.kind === 'wait') {
    return {
      kicker: '',
      label: 'The Seal Manifests',
      detail: `${Math.round(objective.pct * 100)}%`,
    };
  }
  if (objective.kind === 'hold') {
    return {
      kicker: '',
      label: 'Channel the Transmutation Circle',
      detail: `${Math.round(objective.pct * 100)}%`,
      sub: outsideWarning,
    };
  }
  if (objective.kind === 'boss') {
    const who = objective.name || 'Boss';
    return {
      kicker: 'Seal Guardian',
      label: `Slay the ${who}`,
      detail: `${Math.round(objective.pct * 100)}%`,
    };
  }
  return {
    kicker: '',
    label: 'Descend the Rift',
    detail: `${Math.round(objective.pct * 100)}%`,
    sub: outsideWarning,
  };
}

