import Phaser from 'phaser';
import { FX_DASH, FX_DEATH, FX_HIT, FX_MUZZLE, FX_STRIKE, SPARK_CAP } from '../config';
import { catalog } from '../data/catalog';
import type { ItemDef, SkillSlot } from '../data/schema';
import { ROLE_BOSS, ROLE_ELITE, ROLE_FODDER } from '../sim/enemies';
import { emptyInput, type InputFrame } from '../sim/input-frame';
import { applyLevelChoice } from '../sim/level';
import { currentObjective, currentStage, type Objective } from '../sim/loop';
import { FLAG_IMPACT, FLAG_PIERCE, FLAG_TETHER, TEAM_ENEMY } from '../sim/projectiles';
import { ZONE_LINE, ZONE_STRIKE } from '../sim/zones';
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
} from '../ui/overlay';
import { getSettings } from '../ui/settings';
import { uploadPixelTextures } from './pixel-textures';
import {
  eliteGlyphKey,
  eliteKey,
  hazardKey,
  miteKey,
  pillarKey,
  playerBodyKey,
  playerCatalystKey,
  playerEyesKey,
  spitterKey,
  stageBiome,
  volatileKey,
  type BiomeId,
} from './procedural-pixel-art';

type GpuMember = Partial<Phaser.Types.GameObjects.SpriteGPULayer.Member>;

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

type Ambient = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  kind: 'ash' | 'ember' | 'snow' | 'mist';
};

const GHOST_CAP = 3;
const WAYPOINT_DIST = 80;
const WAYPOINT_PAD = 52;
const AMBIENT_CAP = 45;
const ORBIT_CAP = 4;

/**
 * Aimed-primary run. Combat rules live in `src/sim/`. Content in `src/data/`.
 */
export class ArenaScene extends Phaser.Scene {
  private world!: World;
  private inputFrame: InputFrame = emptyInput();
  private playerSprite!: Phaser.GameObjects.Image;
  private playerEyes!: Phaser.GameObjects.Image;
  private playerCatalyst!: Phaser.GameObjects.Image;
  private playerGlow!: Phaser.GameObjects.Image;
  private eliteSprites: Phaser.GameObjects.Image[] = [];
  private eliteGlyphs: Phaser.GameObjects.Image[] = [];
  private bossSprite!: Phaser.GameObjects.Image;
  private bossOrbits: Phaser.GameObjects.Image[] = [];
  private obstacleSprites: Phaser.GameObjects.Image[] = [];
  private volatileGlows: Phaser.GameObjects.Image[] = [];
  private floor!: Phaser.GameObjects.Image;
  private telGlow!: Phaser.GameObjects.Image;
  private crosshair!: Phaser.GameObjects.Image;
  private waypoint!: Phaser.GameObjects.Image;
  private shots: Phaser.GameObjects.Image[] = [];
  private ghosts: Phaser.GameObjects.Image[] = [];
  private ghostLife: Float32Array = new Float32Array(GHOST_CAP);
  private ghostCd = 0;
  private ambientSprites: Phaser.GameObjects.Image[] = [];
  private ambient: Ambient[] = [];
  private miteLayers!: Record<BiomeId, [Phaser.GameObjects.SpriteGPULayer, Phaser.GameObjects.SpriteGPULayer]>;
  private spitterLayers!: Record<BiomeId, Phaser.GameObjects.SpriteGPULayer>;
  private gemLayer!: Phaser.GameObjects.SpriteGPULayer;
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
  private gemShown!: Uint8Array;
  private cursors!: Phaser.Types.Input.Keyboard.CursorKeys;
  private wasd!: Record<'W' | 'A' | 'S' | 'D', Phaser.Input.Keyboard.Key>;
  private shift!: Phaser.Input.Keyboard.Key;
  private space!: Phaser.Input.Keyboard.Key;
  private qKey!: Phaser.Input.Keyboard.Key;
  private decoySprite!: Phaser.GameObjects.Image;
  private utilityWasDown = false;
  private secondaryWasDown = false;
  private specialWasDown = false;
  private lastStageGen = -1;
  private lastPhase: World['phase'] = 'play';
  private lastStageIndex = 0;
  private lastBossSpawned = false;
  private shownOffer: ItemDef[] | null = null;
  private walkPhase = 0;
  private catalystRecoil = 0;
  private lastPrimaryCd = 0;
  private circleSparkCd = 0;
  private lastCircleKey = '';

  constructor() {
    super({ key: 'arena' });
  }

  create(): void {
    this.world = createWorld(resolveSurvivorId());
    const { width, height, maxProjectiles } = catalog.world;
    const loop = catalog.loop;
    uploadPixelTextures(this);
    const biome = this.biome();

    this.floor = this.add.image(width / 2, height / 2, `px-floor-${biome}`).setDepth(0);
    this.zoneGfx = this.add.graphics().setDepth(1);
    this.telegraphGfx = this.add.graphics().setDepth(3);

    this.miteLayers = {
      cinder: [
        this.add.spriteGPULayer(miteKey('cinder', 0), this.world.enemies.cap).setDepth(2),
        this.add.spriteGPULayer(miteKey('cinder', 1), this.world.enemies.cap).setDepth(2),
      ],
      rime: [
        this.add.spriteGPULayer(miteKey('rime', 0), this.world.enemies.cap).setDepth(2),
        this.add.spriteGPULayer(miteKey('rime', 1), this.world.enemies.cap).setDepth(2),
      ],
    };
    this.spitterLayers = {
      cinder: this.add.spriteGPULayer(spitterKey('cinder'), this.world.enemies.cap).setDepth(2),
      rime: this.add.spriteGPULayer(spitterKey('rime'), this.world.enemies.cap).setDepth(2),
    };
    this.gemLayer = this.add.spriteGPULayer('px-gem', loop.maxGems).setDepth(2);
    this.sparkLayer = this.add.spriteGPULayer('px-spark', SPARK_CAP).setDepth(6);
    this.fodderShown = {};
    for (const key of fodderLayerKeys()) {
      this.fodderShown[key] = new Uint8Array(this.world.enemies.cap);
    }
    this.gemShown = new Uint8Array(loop.maxGems);
    for (const layer of this.allFodderLayers()) {
      seedGpuLayer(layer, this.world.enemies.cap, this.gpuMember);
    }
    seedGpuLayer(this.gemLayer, loop.maxGems, this.gpuMember);
    seedGpuLayer(this.sparkLayer, SPARK_CAP, this.gpuMember);
    this.sparks = [];
    for (let i = 0; i < SPARK_CAP; i += 1) {
      this.sparks.push({ life: 0, max: 0.2, x: 0, y: 0, vx: 0, vy: 0, size: 1, tint: 0xffffff });
    }

    this.playerGlow = this.add.image(0, 0, 'px-glow').setDepth(4).setAlpha(0.18).setScale(2.4);
    this.playerGlow.setBlendMode(Phaser.BlendModes.ADD);
    this.playerSprite = this.add.image(this.world.player.x, this.world.player.y, this.bodyKey(biome)).setDepth(5);
    this.playerEyes = this.add.image(0, 0, this.eyesKey(biome)).setDepth(6);
    this.playerCatalyst = this.add.image(0, 0, this.catalystKey(biome)).setDepth(6);
    this.decoySprite = this.add.image(0, 0, this.bodyKey(biome)).setVisible(false).setDepth(4).setAlpha(0.45).setTint(0xc4a05a);
    this.eliteSprites = [];
    this.eliteGlyphs = [];
    for (let i = 0; i < loop.maxElites; i += 1) {
      this.eliteGlyphs.push(this.add.image(0, 0, eliteGlyphKey()).setVisible(false).setDepth(2).setAlpha(0.7));
      this.eliteSprites.push(this.add.image(0, 0, eliteKey(biome)).setVisible(false).setDepth(3));
    }
    this.bossSprite = this.add.image(0, 0, 'px-boss-cinder-heart').setVisible(false).setDepth(3);
    this.bossOrbits = [];
    for (let i = 0; i < ORBIT_CAP; i += 1) {
      this.bossOrbits.push(this.add.image(0, 0, 'px-orbit-cinder').setVisible(false).setDepth(3));
    }
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
    this.crosshair = this.add.image(this.world.aimX, this.world.aimY, 'px-crosshair').setDepth(10);
    this.waypoint = this.add.image(0, 0, 'px-waypoint').setVisible(false).setDepth(11).setScale(1.2);

    this.shots = [];
    for (let i = 0; i < maxProjectiles; i += 1) {
      this.shots.push(this.add.image(0, 0, 'px-bolt-player').setVisible(false).setDepth(4));
    }
    this.ghosts = [];
    this.ghostLife = new Float32Array(GHOST_CAP);
    for (let i = 0; i < GHOST_CAP; i += 1) {
      this.ghosts.push(this.add.image(0, 0, this.bodyKey(biome)).setVisible(false).setDepth(4).setAlpha(0).setTint(0xb8fff8));
    }

    this.ambientSprites = [];
    this.ambient = [];
    for (let i = 0; i < AMBIENT_CAP; i += 1) {
      this.ambientSprites.push(this.add.image(0, 0, 'px-ash').setDepth(1).setAlpha(0.35));
      this.ambient.push({ x: 0, y: 0, vx: 0, vy: 0, kind: 'ash' });
    }

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
    this.shownOffer = null;
    bindOverlay({
      onPick: (index) => {
        applyLevelChoice(this.world, index);
      },
      onRestart: () => {
        hideOverlay();
        this.scene.restart();
      },
      onPause: () => {
        if (this.world.phase !== 'play') return;
        if (getOverlayMode() === 'hidden') showPause();
      },
    });

    const webgl = this.game.renderer instanceof Phaser.Renderer.WebGL.WebGLRenderer;
    initArenaHud(webgl ? 'webgl' : 'canvas');
  }

  update(_time: number, delta: number): void {
    const dt = delta / 1000;
    this.readInput();
    const paused = isSimPaused();
    if (!paused) {
      stepWorld(this.world, this.inputFrame, dt);
    }
    this.syncView(dt);
    this.syncOverlay();
    this.syncStings();
    this.syncHoldPrompt();
    setHudFps(this.game.loop.actualFps);
    const stage = currentStage(this.world);
    const objective = currentObjective(this.world);
    const tel = this.world.teleporter;
    const holding =
      tel.state === 'charging' &&
      Math.hypot(this.world.player.x - tel.x, this.world.player.y - tel.y) <= tel.radius;
    const copy = objectiveCopy(objective);
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
      iframe: this.world.player.iframeRemain > 0,
      objective: copy.label,
      objectiveDetail: copy.detail,
      objectivePct: objective.pct,
      holding,
      boss: this.world.focus.kind === 'boss',
      skills: hudSkills(this.world),
      items: this.world.inventory.map((inst) => {
        const def = this.world.catalog.item(inst.id);
        return { name: def.name, stacks: inst.stacks, rarity: def.rarity };
      }),
    });
  }

  private biome(): BiomeId {
    return stageBiome(currentStage(this.world).id);
  }

  private vesselId(): string {
    return this.world.survivor.id;
  }

  private bodyKey(biome: BiomeId): string {
    return playerBodyKey(biome, this.vesselId());
  }

  private eyesKey(biome: BiomeId): string {
    return playerEyesKey(biome, this.vesselId());
  }

  private catalystKey(biome: BiomeId): string {
    return playerCatalystKey(biome, this.vesselId());
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
    if (this.lastStageGen !== this.world.stageGen) {
      this.lastStageGen = this.world.stageGen;
      this.floor.setTexture(`px-floor-${biome}`);
      this.playerSprite.setTexture(this.bodyKey(biome));
      this.playerEyes.setTexture(this.eyesKey(biome));
      this.playerCatalyst.setTexture(this.catalystKey(biome));
      this.lastCircleKey = '';
    }
    this.syncPlayer(dt, biome);
    this.crosshair.setPosition(this.world.aimX, this.world.aimY);
    this.cameras.main.centerOn(player.x, player.y);
    this.syncObstacles(biome);
    this.syncEnemies(biome);
    this.syncGems();
    this.drawZones(dt);
    this.drawTelegraphs(biome);
    this.syncWaypoint();
    this.consumeFx();
    this.stepSparks(dt);
    this.stepGhosts(dt, biome);
    this.stepAmbient(dt, biome);

    const enemyBolt = biome === 'cinder' ? 'px-bolt-enemy-cinder' : 'px-bolt-enemy-rime';
    for (let i = 0; i < this.shots.length; i += 1) {
      const sprite = this.shots[i];
      if (projectiles.alive[i] === 0) {
        sprite.setVisible(false);
        continue;
      }
      sprite.setTexture(projectiles.team[i] === TEAM_ENEMY ? enemyBolt : 'px-bolt-player');
      sprite.setVisible(true);
      sprite.setPosition(Math.round(projectiles.x[i]), Math.round(projectiles.y[i]));
      if (projectiles.team[i] === TEAM_ENEMY) {
        sprite.clearTint();
        sprite.setScale(1);
      } else if ((projectiles.flags[i] & FLAG_TETHER) !== 0) {
        sprite.setTint(0xc4a05a);
        sprite.setScale(1.6);
      } else if ((projectiles.flags[i] & FLAG_PIERCE) !== 0) {
        sprite.setTint(0x88ffff);
        sprite.setScale(1.5, 0.7);
      } else if ((projectiles.flags[i] & FLAG_IMPACT) !== 0) {
        sprite.setTint(0xffaa55);
        sprite.setScale(1.3);
      } else {
        sprite.clearTint();
        sprite.setScale(1);
      }
    }
  }

  private syncPlayer(dt: number, biome: BiomeId): void {
    const { player } = this.world;
    const moving = this.inputFrame.moveX !== 0 || this.inputFrame.moveY !== 0;
    if (moving && player.dashRemain <= 0) this.walkPhase += dt * 10;
    const bob = Math.round(Math.sin(this.walkPhase) * 1.5);
    if (player.skillCd.primary > this.lastPrimaryCd + 0.02) this.catalystRecoil = 1;
    this.lastPrimaryCd = player.skillCd.primary;
    this.catalystRecoil = Math.max(0, this.catalystRecoil - dt * 8);
    const ang = aimAngle(this.world);
    const x = Math.round(player.x);
    const y = Math.round(player.y + bob);
    this.playerSprite.setPosition(x, y);
    this.playerSprite.setAlpha(player.iframeRemain > 0 ? 0.45 : 1);
    if (this.world.decoy.active) {
      this.decoySprite.setTexture(this.bodyKey(biome));
      this.decoySprite.setVisible(true);
      this.decoySprite.setPosition(Math.round(this.world.decoy.x), Math.round(this.world.decoy.y));
      this.decoySprite.setAlpha(0.3 + 0.2 * Math.sin(this.world.runTime * 8));
    } else {
      this.decoySprite.setVisible(false);
    }
    this.playerGlow.setPosition(x, y);
    this.playerGlow.setAlpha(biome === 'cinder' ? 0.16 : 0.12);
    this.playerEyes.setPosition(x + Math.round(Math.cos(ang) * 2), y - 4 + Math.round(Math.sin(ang) * 1));
    const hand = 10 - this.catalystRecoil * 3;
    this.playerCatalyst.setPosition(x + Math.round(Math.cos(ang) * hand), y + Math.round(Math.sin(ang) * hand));
    this.playerCatalyst.setRotation(ang);
  }

  private syncObstacles(biome: BiomeId): void {
    const { obstacles, player } = this.world;
    const hazardFrame: 0 | 1 = Math.floor(this.world.runTime / 0.25) % 2 === 0 ? 0 : 1;
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
      let key = pillarKey(biome);
      if (obs.type === 'hazard') key = hazardKey(biome, hazardFrame);
      else if (obs.type === 'volatile') key = volatileKey(biome);
      sprite.setTexture(key);
      sprite.setVisible(true);
      sprite.setPosition(Math.round(obs.x), Math.round(obs.y));
      const display = (obs.radius * 2) / sprite.width;
      sprite.setScale(display);
      if (obs.type === 'pillar') {
        const near = Math.hypot(player.x - obs.x, player.y - obs.y) < 170;
        sprite.setTint(near ? 0xffe8d0 : 0xffffff);
        glow.setVisible(false);
      } else if (obs.type === 'volatile' && obs.state === 'primed') {
        sprite.setTint(flash ? 0xffffff : 0xff3322);
        glow.setVisible(true);
        glow.setPosition(obs.x, obs.y);
      } else {
        sprite.clearTint();
        glow.setVisible(false);
      }
    }
  }

  private syncEnemies(biome: BiomeId): void {
    const { enemies } = this.world;
    let eliteSlot = 0;
    let bossOn = false;
    const miteFrame: 0 | 1 = Math.floor(this.world.runTime / 0.15) % 2 === 0 ? 0 : 1;
    for (let i = 0; i < enemies.cap; i += 1) {
      const alive = enemies.alive[i] !== 0;
      const fodder = alive && enemies.role[i] === ROLE_FODDER;
      this.hideFodderSlot(i);
      if (fodder) {
        const defId = enemies.defId[i];
        const aiType = defId ? this.world.catalog.entity(defId).ai.type : 'chase';
        const ranged = aiType === 'ranged' || aiType === 'sniper';
        const layer = ranged ? this.spitterLayers[biome] : this.miteLayers[biome][miteFrame];
        const key = ranged ? `spitter-${biome}` : `mite-${biome}-${miteFrame}`;
        const tint = aiType === 'sniper' ? 0xb47aff : 0xffffff;
        this.gpuMember.x = enemies.x[i];
        this.gpuMember.y = enemies.y[i];
        this.gpuMember.scaleX = 1;
        this.gpuMember.scaleY = 1;
        this.gpuMember.alpha = 1;
        this.gpuMember.tintBlend = aiType === 'sniper' ? 0.55 : 0;
        this.gpuMember.tintBottomLeft = tint;
        this.gpuMember.tintTopLeft = tint;
        this.gpuMember.tintBottomRight = tint;
        this.gpuMember.tintTopRight = tint;
        layer.editMember(i, this.gpuMember);
        this.fodderShown[key][i] = 1;
      }

      if (!alive) continue;
      const defId = enemies.defId[i];
      if (!defId) continue;
      if (enemies.role[i] === ROLE_BOSS) {
        const bossTex = defId === 'frost-sovereign' ? 'px-boss-frost-sovereign' : 'px-boss-cinder-heart';
        this.bossSprite.setTexture(bossTex);
        this.bossSprite.setPosition(Math.round(enemies.x[i]), Math.round(enemies.y[i]));
        this.bossSprite.setVisible(true);
        bossOn = true;
        const cinder = defId === 'cinder-heart';
        for (let o = 0; o < ORBIT_CAP; o += 1) {
          const orbit = this.bossOrbits[o];
          if (!cinder) {
            orbit.setVisible(false);
            continue;
          }
          const ang = this.world.runTime * 1.4 + (o * Math.PI) / 2;
          orbit.setVisible(true);
          orbit.setPosition(
            Math.round(enemies.x[i] + Math.cos(ang) * 48),
            Math.round(enemies.y[i] + Math.sin(ang) * 48),
          );
        }
      } else if (enemies.role[i] === ROLE_ELITE && eliteSlot < this.eliteSprites.length) {
        const sprite = this.eliteSprites[eliteSlot];
        const glyph = this.eliteGlyphs[eliteSlot];
        sprite.setTexture(eliteKey(biome));
        sprite.setPosition(Math.round(enemies.x[i]), Math.round(enemies.y[i]));
        sprite.setVisible(true);
        glyph.setVisible(true);
        glyph.setPosition(Math.round(enemies.x[i]), Math.round(enemies.y[i] + 18));
        glyph.setRotation(this.world.runTime * 1.1);
        glyph.setTint(0x66ff88);
        if (enemies.corpseRemain[i] > 0) {
          const flashCorpse = Math.floor(this.world.runTime * 16) % 2 === 0;
          sprite.setTint(flashCorpse ? 0x88ffaa : 0x226644);
        } else {
          sprite.clearTint();
        }
        eliteSlot += 1;
      }
    }
    for (let i = eliteSlot; i < this.eliteSprites.length; i += 1) {
      this.eliteSprites[i].setVisible(false);
      this.eliteGlyphs[i].setVisible(false);
    }
    if (!bossOn) {
      this.bossSprite.setVisible(false);
      for (const orbit of this.bossOrbits) orbit.setVisible(false);
    }
  }

  private hideFodderSlot(index: number): void {
    for (const key of fodderLayerKeys()) {
      if (this.fodderShown[key][index] === 0) continue;
      const layer = this.layerByKey(key);
      hideGpuMember(layer, this.gpuMember, index);
      this.fodderShown[key][index] = 0;
    }
  }

  private layerByKey(key: string): Phaser.GameObjects.SpriteGPULayer {
    if (key === 'mite-cinder-0') return this.miteLayers.cinder[0];
    if (key === 'mite-cinder-1') return this.miteLayers.cinder[1];
    if (key === 'mite-rime-0') return this.miteLayers.rime[0];
    if (key === 'mite-rime-1') return this.miteLayers.rime[1];
    if (key === 'spitter-cinder') return this.spitterLayers.cinder;
    return this.spitterLayers.rime;
  }

  private allFodderLayers(): Phaser.GameObjects.SpriteGPULayer[] {
    return [
      this.miteLayers.cinder[0],
      this.miteLayers.cinder[1],
      this.miteLayers.rime[0],
      this.miteLayers.rime[1],
      this.spitterLayers.cinder,
      this.spitterLayers.rime,
    ];
  }

  private syncGems(): void {
    const { gems } = this.world;
    for (let i = 0; i < gems.cap; i += 1) {
      const alive = gems.alive[i] !== 0;
      if (alive) {
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

  private syncOverlay(): void {
    const { phase, offer } = this.world;
    if (getOverlayMode() === 'pause') {
      this.lastPhase = phase;
      return;
    }
    if (phase === 'levelup' && offer && this.shownOffer !== offer) {
      this.shownOffer = offer;
      showLevelUp(offer);
    } else if (phase === 'victory' && this.lastPhase !== 'victory') {
      showRunEnd('victory', `The last seal holds · ${formatTime(this.world.runTime)}`, this.runRecap());
    } else if (phase === 'defeat' && this.lastPhase !== 'defeat') {
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
      this.lastBossSpawned = false;
      const stage = currentStage(this.world);
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
    if (stingActive()) {
      const moving = Math.abs(this.inputFrame.moveX) + Math.abs(this.inputFrame.moveY) > 0;
      if (moving) hideSting();
    }
  }

  private syncHoldPrompt(): void {
    if (isModalOpen()) {
      setHoldPrompt({ visible: false, title: '', detail: '', pct: 0, outside: false });
      return;
    }
    const tel = this.world.teleporter;
    const portal = this.world.portal;
    const player = this.world.player;
    if (tel.state === 'charging') {
      const holding = Math.hypot(player.x - tel.x, player.y - tel.y) <= tel.radius;
      const pct = tel.hold > 0 ? Math.min(1, tel.charge / tel.hold) : 0;
      setHoldPrompt({
        visible: true,
        title: holding ? 'Channel the Transmutation Circle' : 'The seal cools',
        detail: holding ? `${Math.round(pct * 100)}% — stay inside the ring` : 'Return to the circle',
        pct,
        outside: !holding,
      });
      return;
    }
    if (portal.open) {
      const radius = this.world.catalog.loop.portalRadius;
      const inside = Math.hypot(player.x - portal.x, player.y - portal.y) <= radius;
      const need = this.world.catalog.loop.portalHold;
      const pct = need > 0 ? Math.min(1, portal.hold / need) : 0;
      setHoldPrompt({
        visible: true,
        title: 'Descend the Rift',
        detail: inside ? 'The gate drinks your step' : 'Stand in the gate',
        pct,
        outside: !inside,
      });
      return;
    }
    setHoldPrompt({ visible: false, title: '', detail: '', pct: 0, outside: false });
  }

  private runRecap() {
    return {
      stage: currentStage(this.world).name,
      time: this.world.runTime,
      level: this.world.level,
      coefficient: this.world.coefficient,
      survivor: this.world.survivor.name,
      bosses: this.world.bossesDefeated,
      items: this.world.inventory.map((inst) => {
        const def = this.world.catalog.item(inst.id);
        return { name: def.name, stacks: inst.stacks };
      }),
    };
  }

  private drawZones(dt: number): void {
    const g = this.zoneGfx;
    const tel = this.world.teleporter;
    const biome = this.biome();
    const inZone =
      tel.state !== 'hidden' && Math.hypot(this.world.player.x - tel.x, this.world.player.y - tel.y) <= tel.radius;
    const t = tel.hold > 0 ? Math.min(1, tel.charge / tel.hold) : 0;
    if (inZone && tel.state === 'charging') {
      this.circleSparkCd -= dt;
      if (this.circleSparkCd <= 0) {
        this.circleSparkCd = 0.14;
        spawnBurst(this.sparks, tel.x, tel.y, biome === 'cinder' ? 0xffaa33 : 0x55ffff, 2, 40, 0.22);
      }
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
      drawTransmutationCircle(g, tel.x, tel.y, tel.radius, t, inZone, biome, tel.state === 'charging');
      this.telGlow.setPosition(tel.x, tel.y);
      this.telGlow.setAlpha(tel.state === 'charging' ? (inZone ? 0.22 : 0.08) : 0);
    } else {
      this.telGlow.setAlpha(0);
    }
    if (this.world.portal.open) {
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
      const max = ai && ai.type === 'ranged' ? ai.windup : 0.4;
      const grow = max > 0 ? 1 - enemies.windup[i] / max : 1;
      dashedLine(g, enemies.x[i], enemies.y[i], enemies.aimX[i], enemies.aimY[i], line);
      g.lineStyle(1, line, 0.9);
      g.strokeCircle(enemies.x[i], enemies.y[i], Math.round(10 + grow * 16));
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
    this.waypoint.setVisible(true);
    this.waypoint.setPosition(
      this.world.player.x + (dx / len) * WAYPOINT_DIST,
      this.world.player.y + (dy / len) * WAYPOINT_DIST,
    );
    this.waypoint.setRotation(Math.atan2(dy, dx));
  }

  private consumeFx(): void {
    const { fx } = this.world;
    for (let i = 0; i < fx.count; i += 1) {
      const kind = fx.kind[i];
      const x = fx.x[i];
      const y = fx.y[i];
      const tint = fx.tint[i] || 0xffffff;
      if (kind === FX_HIT) spawnBurst(this.sparks, x, y, tint, 4, 90, 0.18);
      else if (kind === FX_DEATH) spawnBurst(this.sparks, x, y, tint, 10, 140, 0.28);
      else if (kind === FX_MUZZLE) spawnBurst(this.sparks, x, y, tint, 3, 70, 0.14);
      else if (kind === FX_DASH) spawnBurst(this.sparks, x, y, tint, 6, 110, 0.2);
      else if (kind === FX_STRIKE) spawnBurst(this.sparks, x, y, tint, 14, 160, 0.32);
    }
    fx.count = 0;
  }

  private stepSparks(dt: number): void {
    for (let i = 0; i < this.sparks.length; i += 1) {
      const spark = this.sparks[i];
      if (spark.life <= 0) {
        hideGpuMember(this.sparkLayer, this.gpuMember, i);
        continue;
      }
      spark.life -= dt;
      spark.x += spark.vx * dt;
      spark.y += spark.vy * dt;
      const t = spark.max > 0 ? Math.max(0, spark.life / spark.max) : 0;
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
    }
  }

  private stepGhosts(dt: number, biome: BiomeId): void {
    const { player } = this.world;
    this.ghostCd = Math.max(0, this.ghostCd - dt);
    if (player.dashRemain > 0 && this.ghostCd <= 0) {
      this.ghostCd = 0.05;
      const slot = nextGhost(this.ghostLife);
      if (slot >= 0) {
        this.ghostLife[slot] = 0.18;
        const ghost = this.ghosts[slot];
        ghost.setTexture(this.bodyKey(biome));
        ghost.setPosition(Math.round(player.x), Math.round(player.y));
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

  private stepAmbient(dt: number, biome: BiomeId): void {
    const view = this.cameras.main.worldView;
    for (let i = 0; i < AMBIENT_CAP; i += 1) {
      const speck = this.ambient[i];
      if (speck.vx === 0 && speck.vy === 0) seedAmbient(speck, view, biome);
      speck.x += speck.vx * dt;
      speck.y += speck.vy * dt;
      if (speck.x < view.x - 8 || speck.x > view.x + view.width + 8 || speck.y < view.y - 8 || speck.y > view.y + view.height + 8) {
        seedAmbient(speck, view, biome);
      }
      const sprite = this.ambientSprites[i];
      const tex = speck.kind === 'ash' ? 'px-ash' : speck.kind === 'ember' ? 'px-ember' : speck.kind === 'snow' ? 'px-snow' : 'px-mist';
      sprite.setTexture(tex);
      sprite.setPosition(Math.round(speck.x), Math.round(speck.y));
      sprite.setAlpha(speck.kind === 'mist' ? 0.16 : 0.4);
    }
  }
}

function fodderLayerKeys(): string[] {
  return ['mite-cinder-0', 'mite-cinder-1', 'mite-rime-0', 'mite-rime-1', 'spitter-cinder', 'spitter-rime'];
}

function seedGpuLayer(
  layer: Phaser.GameObjects.SpriteGPULayer,
  count: number,
  member: GpuMember,
): void {
  member.x = 0;
  member.y = 0;
  member.scaleX = 0;
  member.scaleY = 0;
  member.alpha = 0;
  for (let i = 0; i < count; i += 1) {
    layer.addMember(member);
  }
}

function hideGpuMember(
  layer: Phaser.GameObjects.SpriteGPULayer,
  member: GpuMember,
  index: number,
): void {
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

function nextGhost(life: Float32Array): number {
  for (let i = 0; i < life.length; i += 1) {
    if (life[i] <= 0) return i;
  }
  return 0;
}

function seedAmbient(
  speck: Ambient,
  view: Phaser.Geom.Rectangle,
  biome: BiomeId,
): void {
  speck.x = view.x + Math.random() * view.width;
  speck.y = view.y + Math.random() * view.height;
  if (biome === 'cinder') {
    const ember = Math.random() < 0.18;
    speck.kind = ember ? 'ember' : 'ash';
    speck.vx = ember ? (Math.random() - 0.5) * 8 : -12 - Math.random() * 10;
    speck.vy = ember ? -18 - Math.random() * 16 : 10 + Math.random() * 12;
  } else {
    const mist = Math.random() < 0.2;
    speck.kind = mist ? 'mist' : 'snow';
    speck.vx = 18 + Math.random() * 14;
    speck.vy = 16 + Math.random() * 12;
  }
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
): void {
  const cx = Math.round(x);
  const cy = Math.round(y);
  const r = Math.round(radius);
  const active = biome === 'cinder' ? 0xffaa33 : 0x55ffff;
  const muted = biome === 'cinder' ? 0x5a3030 : 0x2a4058;
  const ring = charging && inZone ? active : muted;
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
      return { slot, name: '', glyph: glyphs[index], cd: 0, max: 0, empty: true, iframe: false };
    }
    const skill = world.catalog.skill(id);
    return {
      slot,
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
  return catalog.survivors.some((entry) => entry.id === id) ? id : catalog.world.defaultSurvivor;
}

function objectiveCopy(objective: Objective): { label: string; detail: string } {
  if (objective.kind === 'wait') {
    return { label: `Seal manifests in ${formatTime(objective.remaining)}`, detail: '' };
  }
  if (objective.kind === 'hold') {
    return { label: 'Channel the Transmutation Circle', detail: `${Math.round(objective.pct * 100)}%` };
  }
  if (objective.kind === 'boss') {
    const who = objective.name || 'boss';
    return { label: `Slay the ${who}`, detail: `${Math.round(objective.pct * 100)}% HP` };
  }
  return { label: 'Descend the Rift', detail: `${Math.round(objective.pct * 100)}%` };
}
