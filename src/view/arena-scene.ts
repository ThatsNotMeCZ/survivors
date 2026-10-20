import Phaser from 'phaser';
import { FX_DASH, FX_DEATH, FX_HIT, FX_MUZZLE, SPARK_CAP } from '../config';
import { catalog } from '../data/catalog';
import type { ItemDef, ViewDot } from '../data/schema';
import { ROLE_BOSS, ROLE_ELITE, ROLE_FODDER } from '../sim/enemies';
import { emptyInput, type InputFrame } from '../sim/input-frame';
import { applyLevelChoice } from '../sim/level';
import { currentObjective, currentStage, type Objective } from '../sim/loop';
import { TEAM_ENEMY } from '../sim/projectiles';
import { aimAngle, createWorld, stepWorld, type World } from '../sim/world';
import { formatTime, initArenaHud, setHudCombat, setHudFps } from '../ui/hud';
import {
  bindOverlay,
  getOverlayMode,
  hideOverlay,
  showLevelUp,
  showPause,
  showRunEnd,
} from '../ui/overlay';
import { makeChevronTexture, makeDotTexture, parseHex } from './textures';

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

const GHOST_CAP = 8;
const WAYPOINT_DIST = 80;
const WAYPOINT_PAD = 52;

/**
 * Aimed-primary run. Combat rules live in `src/sim/`. Content in `src/data/`.
 */
export class ArenaScene extends Phaser.Scene {
  private world!: World;
  private inputFrame: InputFrame = emptyInput();
  private playerSprite!: Phaser.GameObjects.Image;
  private eliteSprites: Phaser.GameObjects.Image[] = [];
  private bossSprite!: Phaser.GameObjects.Image;
  private crosshair!: Phaser.GameObjects.Image;
  private waypoint!: Phaser.GameObjects.Image;
  private shots: Phaser.GameObjects.Image[] = [];
  private ghosts: Phaser.GameObjects.Image[] = [];
  private ghostLife: Float32Array = new Float32Array(GHOST_CAP);
  private ghostCd = 0;
  private fodderLayer!: Phaser.GameObjects.SpriteGPULayer;
  private gemLayer!: Phaser.GameObjects.SpriteGPULayer;
  private sparkLayer!: Phaser.GameObjects.SpriteGPULayer;
  private sparks: Spark[] = [];
  private gridGfx!: Phaser.GameObjects.Graphics;
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
  private fodderShown!: Uint8Array;
  private gemShown!: Uint8Array;
  private cursors!: Phaser.Types.Input.Keyboard.CursorKeys;
  private wasd!: Record<'W' | 'A' | 'S' | 'D', Phaser.Input.Keyboard.Key>;
  private shift!: Phaser.Input.Keyboard.Key;
  private space!: Phaser.Input.Keyboard.Key;
  private esc!: Phaser.Input.Keyboard.Key;
  private utilityWasDown = false;
  private escWasDown = false;
  private lastStageGen = -1;
  private lastPhase: World['phase'] = 'play';
  private shownOffer: ItemDef[] | null = null;

  constructor() {
    super({ key: 'arena' });
  }

  create(): void {
    this.world = createWorld();
    const { width, height, maxProjectiles } = catalog.world;
    const loop = catalog.loop;

    loadViewTexture(this, 'player', this.world.survivor.view);
    for (const entity of catalog.entities) {
      loadViewTexture(this, entity.id, entity.view);
    }
    makeDotTexture(this, 'shot', 12, '#fff4c8', '#ffd35a');
    makeDotTexture(this, 'spark', 10, '#ffffff', '#ffd35a');
    makeDotTexture(this, 'crosshair', 16, '#ffffff', '#9ad4ff');
    makeDotTexture(this, 'fodder', 16, '#ffffff', '#dddddd');
    makeDotTexture(this, 'gem', 16, '#fff4c8', '#ffd35a');
    makeChevronTexture(this, 'waypoint', '#fff4c8', '#5ad4ff');

    this.gridGfx = this.add.graphics().setDepth(0);
    this.zoneGfx = this.add.graphics().setDepth(1);
    this.telegraphGfx = this.add.graphics().setDepth(3);
    this.drawGrid();

    this.fodderLayer = this.add.spriteGPULayer('fodder', this.world.enemies.cap).setDepth(2);
    this.gemLayer = this.add.spriteGPULayer('gem', loop.maxGems).setDepth(2);
    this.sparkLayer = this.add.spriteGPULayer('spark', SPARK_CAP).setDepth(6);
    this.fodderShown = new Uint8Array(this.world.enemies.cap);
    this.gemShown = new Uint8Array(loop.maxGems);
    seedGpuLayer(this.fodderLayer, this.world.enemies.cap, this.gpuMember);
    seedGpuLayer(this.gemLayer, loop.maxGems, this.gpuMember);
    seedGpuLayer(this.sparkLayer, SPARK_CAP, this.gpuMember);
    this.sparks = [];
    for (let i = 0; i < SPARK_CAP; i += 1) {
      this.sparks.push({ life: 0, max: 0.2, x: 0, y: 0, vx: 0, vy: 0, size: 1, tint: 0xffffff });
    }

    this.playerSprite = this.add.image(this.world.player.x, this.world.player.y, 'player').setDepth(5);
    this.eliteSprites = [];
    for (let i = 0; i < loop.maxElites; i += 1) {
      this.eliteSprites.push(this.add.image(0, 0, catalog.loop.stages[0].elite).setVisible(false).setDepth(3));
    }
    this.bossSprite = this.add.image(0, 0, catalog.loop.stages[0].boss).setVisible(false).setDepth(3);
    this.crosshair = this.add.image(this.world.aimX, this.world.aimY, 'crosshair').setDepth(10);
    this.waypoint = this.add.image(0, 0, 'waypoint').setVisible(false).setDepth(11).setScale(0.9);

    this.shots = [];
    for (let i = 0; i < maxProjectiles; i += 1) {
      this.shots.push(this.add.image(0, 0, 'shot').setVisible(false).setDepth(4));
    }
    this.ghosts = [];
    this.ghostLife = new Float32Array(GHOST_CAP);
    for (let i = 0; i < GHOST_CAP; i += 1) {
      this.ghosts.push(this.add.image(0, 0, 'player').setVisible(false).setDepth(4).setAlpha(0));
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
    this.esc = this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ESC);
    this.input.mouse?.disableContextMenu();

    hideOverlay();
    this.lastPhase = 'play';
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
    this.handlePause();
    const paused = getOverlayMode() === 'pause';
    if (!paused) {
      stepWorld(this.world, this.inputFrame, dt);
    }
    this.syncView(dt);
    this.syncOverlay();
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
      playerHp: this.world.player.hp,
      playerMax: this.world.player.maxHp,
      level: this.world.level,
      xp: this.world.xp,
      xpNeed: this.world.xpNeed,
      runTime: this.world.runTime,
      coefficient: this.world.coefficient,
      dashCd: this.world.player.skillCd.utility,
      iframe: this.world.player.iframeRemain > 0,
      objective: copy.label,
      objectiveDetail: copy.detail,
      holding,
      boss: this.world.focus.kind === 'boss',
    });
  }

  private handlePause(): void {
    const down = this.esc.isDown;
    const pressed = down && !this.escWasDown;
    this.escWasDown = down;
    if (!pressed) return;
    if (this.world.phase !== 'play') return;
    const mode = getOverlayMode();
    if (mode === 'pause') {
      hideOverlay();
      return;
    }
    if (mode === 'hidden') showPause();
  }

  private readInput(): void {
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
    this.inputFrame.held.primary = pointer.leftButtonDown();
    this.inputFrame.held.secondary = pointer.rightButtonDown();
    this.inputFrame.held.utility = utilityDown;
    this.inputFrame.held.special = false;
    this.inputFrame.pressed.primary = false;
    this.inputFrame.pressed.secondary = false;
    this.inputFrame.pressed.utility = utilityDown && !this.utilityWasDown;
    this.inputFrame.pressed.special = false;
    this.utilityWasDown = utilityDown;
  }

  private syncView(dt: number): void {
    const { player, projectiles } = this.world;
    if (this.lastStageGen !== this.world.stageGen) {
      this.lastStageGen = this.world.stageGen;
      this.drawGrid();
    }
    this.playerSprite.setPosition(player.x, player.y);
    this.playerSprite.setRotation(aimAngle(this.world));
    this.playerSprite.setAlpha(player.iframeRemain > 0 ? 0.45 : 1);
    this.crosshair.setPosition(this.world.aimX, this.world.aimY);
    this.cameras.main.centerOn(player.x, player.y);
    this.syncEnemies();
    this.syncGems();
    this.drawZones();
    this.drawTelegraphs();
    this.syncWaypoint();
    this.consumeFx();
    this.stepSparks(dt);
    this.stepGhosts(dt);

    for (let i = 0; i < this.shots.length; i += 1) {
      const sprite = this.shots[i];
      if (projectiles.alive[i] === 0) {
        sprite.setVisible(false);
        continue;
      }
      sprite.setVisible(true);
      sprite.setPosition(projectiles.x[i], projectiles.y[i]);
      sprite.setTint(projectiles.team[i] === TEAM_ENEMY ? 0xff6a4a : 0xffffff);
    }
  }

  private syncEnemies(): void {
    const { enemies } = this.world;
    let eliteSlot = 0;
    let bossOn = false;
    for (let i = 0; i < enemies.cap; i += 1) {
      const alive = enemies.alive[i] !== 0;
      const fodder = alive && enemies.role[i] === ROLE_FODDER;
      if (fodder) {
        const defId = enemies.defId[i];
        const view = defId ? this.world.catalog.entity(defId).view : null;
        const tint = view ? parseHex(view.mid) : 0xffffff;
        const scale = view ? view.size / 16 : 1;
        this.gpuMember.x = enemies.x[i];
        this.gpuMember.y = enemies.y[i];
        this.gpuMember.scaleX = scale;
        this.gpuMember.scaleY = scale;
        this.gpuMember.alpha = 1;
        this.gpuMember.tintBlend = 0.75;
        this.gpuMember.tintBottomLeft = tint;
        this.gpuMember.tintTopLeft = tint;
        this.gpuMember.tintBottomRight = tint;
        this.gpuMember.tintTopRight = tint;
        this.fodderLayer.editMember(i, this.gpuMember);
        this.fodderShown[i] = 1;
      } else if (this.fodderShown[i] !== 0) {
        this.gpuMember.x = 0;
        this.gpuMember.y = 0;
        this.gpuMember.scaleX = 0;
        this.gpuMember.scaleY = 0;
        this.gpuMember.alpha = 0;
        this.fodderLayer.editMember(i, this.gpuMember);
        this.fodderShown[i] = 0;
      }

      if (!alive) continue;
      const defId = enemies.defId[i];
      if (!defId) continue;
      if (enemies.role[i] === ROLE_BOSS) {
        this.bossSprite.setTexture(defId);
        this.bossSprite.setPosition(enemies.x[i], enemies.y[i]);
        this.bossSprite.setVisible(true);
        bossOn = true;
      } else if (enemies.role[i] === ROLE_ELITE && eliteSlot < this.eliteSprites.length) {
        const sprite = this.eliteSprites[eliteSlot];
        sprite.setTexture(defId);
        sprite.setPosition(enemies.x[i], enemies.y[i]);
        sprite.setVisible(true);
        eliteSlot += 1;
      }
    }
    for (let i = eliteSlot; i < this.eliteSprites.length; i += 1) {
      this.eliteSprites[i].setVisible(false);
    }
    if (!bossOn) this.bossSprite.setVisible(false);
  }

  private syncGems(): void {
    const { gems } = this.world;
    for (let i = 0; i < gems.cap; i += 1) {
      const alive = gems.alive[i] !== 0;
      if (alive) {
        this.gpuMember.x = gems.x[i];
        this.gpuMember.y = gems.y[i];
        this.gpuMember.scaleX = 0.7;
        this.gpuMember.scaleY = 0.7;
        this.gpuMember.alpha = 1;
        this.gpuMember.tintBlend = 0.2;
        this.gpuMember.tintBottomLeft = 0xffd35a;
        this.gpuMember.tintTopLeft = 0xffd35a;
        this.gpuMember.tintBottomRight = 0xffd35a;
        this.gpuMember.tintTopRight = 0xffd35a;
        this.gemLayer.editMember(i, this.gpuMember);
        this.gemShown[i] = 1;
      } else if (this.gemShown[i] !== 0) {
        this.gpuMember.x = 0;
        this.gpuMember.y = 0;
        this.gpuMember.scaleX = 0;
        this.gpuMember.scaleY = 0;
        this.gpuMember.alpha = 0;
        this.gemLayer.editMember(i, this.gpuMember);
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
      const stage = currentStage(this.world);
      showRunEnd('victory', `Run complete · ${stage.name} · ${formatTime(this.world.runTime)}`);
    } else if (phase === 'defeat' && this.lastPhase !== 'defeat') {
      const stage = currentStage(this.world);
      showRunEnd('defeat', `${stage.name} · ${formatTime(this.world.runTime)}`);
    } else if (phase === 'play' && this.lastPhase !== 'play') {
      hideOverlay();
      this.shownOffer = null;
    }
    this.lastPhase = phase;
  }

  private drawGrid(): void {
    const { width, height } = catalog.world;
    const stage = currentStage(this.world);
    const g = this.gridGfx;
    g.clear();
    g.lineStyle(1, parseHex(stage.view.grid), 1);
    const step = 128;
    for (let x = 0; x <= width; x += step) {
      g.lineBetween(x, 0, x, height);
    }
    for (let y = 0; y <= height; y += step) {
      g.lineBetween(0, y, width, y);
    }
    g.lineStyle(2, parseHex(stage.view.border), 1);
    g.strokeRect(1, 1, width - 2, height - 2);
  }

  private drawZones(): void {
    const g = this.zoneGfx;
    g.clear();
    const stage = currentStage(this.world);
    const tel = this.world.teleporter;
    if (tel.state !== 'hidden') {
      const color = parseHex(stage.view.zone);
      const t = tel.hold > 0 ? Math.min(1, tel.charge / tel.hold) : 0;
      g.lineStyle(3, color, tel.state === 'charging' ? 0.95 : 0.3);
      g.strokeCircle(tel.x, tel.y, tel.radius);
      g.fillStyle(color, 0.06 + 0.12 * t);
      g.fillCircle(tel.x, tel.y, tel.radius);
    }
    if (this.world.portal.open) {
      const color = parseHex(stage.view.portal);
      const radius = this.world.catalog.loop.portalRadius;
      const hold = this.world.catalog.loop.portalHold;
      const t = hold > 0 ? Math.min(1, this.world.portal.hold / hold) : 0;
      const pulse = 0.16 + 0.1 * Math.sin(this.world.runTime * 7) + 0.18 * t;
      g.lineStyle(5, color, 1);
      g.strokeCircle(this.world.portal.x, this.world.portal.y, radius);
      g.fillStyle(color, pulse);
      g.fillCircle(this.world.portal.x, this.world.portal.y, radius);
    }
  }

  private drawTelegraphs(): void {
    const g = this.telegraphGfx;
    g.clear();
    const { enemies, player } = this.world;
    for (let i = 0; i < enemies.cap; i += 1) {
      if (enemies.alive[i] === 0 || enemies.windup[i] <= 0) continue;
      g.lineStyle(2, 0xff7a3a, 0.85);
      g.lineBetween(enemies.x[i], enemies.y[i], player.x, player.y);
      g.strokeCircle(enemies.x[i], enemies.y[i], enemies.radius[i] + 10);
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

  private stepGhosts(dt: number): void {
    const { player } = this.world;
    this.ghostCd = Math.max(0, this.ghostCd - dt);
    if (player.dashRemain > 0 && this.ghostCd <= 0) {
      this.ghostCd = 0.04;
      const slot = nextGhost(this.ghostLife);
      if (slot >= 0) {
        this.ghostLife[slot] = 0.22;
        const ghost = this.ghosts[slot];
        ghost.setTexture('player');
        ghost.setPosition(player.x, player.y);
        ghost.setRotation(this.playerSprite.rotation);
        ghost.setVisible(true);
        ghost.setAlpha(0.45);
      }
    }
    for (let i = 0; i < GHOST_CAP; i += 1) {
      if (this.ghostLife[i] <= 0) {
        this.ghosts[i].setVisible(false);
        continue;
      }
      this.ghostLife[i] -= dt;
      this.ghosts[i].setAlpha(Math.max(0, this.ghostLife[i] / 0.22) * 0.45);
      if (this.ghostLife[i] <= 0) this.ghosts[i].setVisible(false);
    }
  }
}

function loadViewTexture(scene: Phaser.Scene, key: string, view: ViewDot): void {
  if (view.kind === 'chevron') {
    makeChevronTexture(scene, key, view.inner, view.mid);
    return;
  }
  makeDotTexture(scene, key, view.size, view.inner, view.mid);
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

function objectiveCopy(objective: Objective): { label: string; detail: string } {
  if (objective.kind === 'wait') {
    return { label: `Teleporter in ${formatTime(objective.remaining)}`, detail: '' };
  }
  if (objective.kind === 'hold') {
    return { label: 'Hold the teleporter', detail: `${Math.round(objective.pct * 100)}%` };
  }
  if (objective.kind === 'boss') {
    return { label: 'Kill the boss', detail: `${Math.round(objective.pct * 100)}% HP` };
  }
  return { label: 'Enter the portal', detail: `${Math.round(objective.pct * 100)}%` };
}
