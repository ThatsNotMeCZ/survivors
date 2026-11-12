import Phaser from 'phaser';
import { getSettings } from '../../ui/settings';
import { FLAG_TETHER, type ProjectilePool } from '../../sim/projectiles';
import { ROLE_BOSS, ROLE_ELITE, type EnemyPool } from '../../sim/enemies';

// =============================================================================
// 1. IN-FLIGHT CHAIN-LANCE FRAGMENT SHADER
// =============================================================================
const TETHER_LANCE_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform float uTime;
uniform float uSeed;

float hash21(vec2 p) {
  p = fract(p * vec2(127.1, 311.7) + uSeed * 19.19);
  p += dot(p, p + 34.5);
  return fract(p.x * p.y);
}

void main() {
  vec2 uv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  // Centered normalized coords: -1..1 in Y, -1..1 in X along lance flight direction (facing +X)
  vec2 p = (uv - 0.5) * 2.0;

  // Discrete 1px pixel art quantization
  p = floor(p * 24.0) / 24.0;

  // Spearhead: sharp triangle tip at x > 0.0, tapering to tip at x = 0.9
  float tipReach = 0.90;
  float lance = 0.0;
  if (p.x > 0.0 && p.x < tipReach) {
    float halfW = (tipReach - p.x) * 0.55;
    lance = step(abs(p.y), halfW);
  }

  // Trailing chain links behind lance head (x < 0.0)
  float chain = 0.0;
  if (p.x <= 0.0 && p.x > -0.95) {
    // Repeated link pattern along X
    float linkX = fract((p.x - uTime * 6.0) * 4.5);
    float linkRing = step(abs(p.y), 0.28) * (1.0 - step(abs(p.y), 0.12) * step(0.2, linkX) * (1.0 - step(0.8, linkX)));
    chain = linkRing;
  }

  // Searing fiery aura
  float aura = clamp(1.0 - length(vec2(p.x * 0.8, p.y * 2.2)), 0.0, 1.0);

  if (lance < 0.5 && chain < 0.5 && aura < 0.45) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Hermetic gold & crimson fire palette
  vec3 tipWhite = vec3(1.0, 0.98, 0.85);
  vec3 goldHot  = vec3(0.976, 0.761, 0.169); // #f9c22b
  vec3 amberMid = vec3(0.969, 0.588, 0.090); // #f79617
  vec3 ironRust = vec3(0.48, 0.16, 0.12);

  vec3 col = mix(ironRust, amberMid, chain);
  col = mix(col, goldHot, lance);
  if (p.x > 0.65 && abs(p.y) < 0.15) {
    col = tipWhite;
  }
  col = mix(col, amberMid, aura * 0.4);

  float alpha = clamp(lance * 0.98 + chain * 0.92 + aura * 0.65, 0.0, 0.96);
  gl_FragColor = vec4(col * alpha, alpha);
}
`;

// =============================================================================
// 2. ACTIVE TAUT BINDING CHAIN FRAGMENT SHADER
// =============================================================================
const TETHER_CHAIN_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform float uTime;
uniform float uProgress; // normalized 0..1 along root duration
uniform float uLength;   // pixel length of chain
uniform float uWidth;    // quad height / 2
uniform float uSeed;

float hash21(vec2 p) {
  p = fract(p * vec2(127.1, 311.7) + uSeed * 13.37);
  p += dot(p, p + 34.5);
  return fract(p.x * p.y);
}

void main() {
  vec2 uv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);

  // Position relative to quad center in pixels
  vec2 p = vec2((uv.x - 0.5) * (uLength + 24.0), (uv.y - 0.5) * (uWidth + 20.0));

  // Discrete 1px pixel stepping
  p = floor(p) + 0.5;

  float halfLen = uLength * 0.5;
  if (abs(p.x) > halfLen + 4.0) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Taut harmonic vibration along the chain
  float vib = sin(p.x * 0.12 - uTime * 14.0) * cos(p.x * 0.04) * 2.2;
  float distToChain = abs(p.y - vib);

  // Interlocking heavy chain links: periodic pattern every 14 pixels
  float linkU = fract((p.x + uTime * 12.0) / 14.0);
  float isOuterLink = step(distToChain, 4.5);
  float isInnerHole = step(distToChain, 1.8) * step(0.24, linkU) * (1.0 - step(0.76, linkU));
  float chainBody = isOuterLink * (1.0 - isInnerHole);

  // Flame / searing sparks along chain
  float flamePulse = sin(p.x * 0.25 - uTime * 8.0) * 0.5 + 0.5;
  float flameGlow = smoothstep(8.5, 0.0, distToChain) * (0.35 + 0.45 * flamePulse);

  if (chainBody < 0.5 && flameGlow < 0.12) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Dark hermetic glowing brass & iron palette
  vec3 coreGlint = vec3(1.000, 0.980, 0.820);
  vec3 moltenGold = vec3(0.976, 0.761, 0.169); // #f9c22b
  vec3 sulfurFire = vec3(0.969, 0.588, 0.090); // #f79617
  vec3 bloodSlag  = vec3(0.580, 0.120, 0.140);
  vec3 darkIron   = vec3(0.220, 0.160, 0.140);

  vec3 col = darkIron;
  if (chainBody > 0.5) {
    col = mix(bloodSlag, moltenGold, step(0.65, flamePulse));
    if (distToChain < 1.0) {
      col = mix(moltenGold, coreGlint, 0.8);
    }
  }
  col = mix(col, sulfurFire, flameGlow * 0.65);

  float alpha = clamp(chainBody * 0.96 + flameGlow * 0.85, 0.0, 0.95);
  gl_FragColor = vec4(col * alpha, alpha);
}
`;

// =============================================================================
// 3. HERMETIC ROOT SEAL FRAGMENT SHADER
// =============================================================================
const TETHER_SEAL_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform float uTime;
uniform float uProgress; // normalized 0..1 along root duration
uniform float uRadius;

void main() {
  vec2 uv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  vec2 p = (uv - 0.5) * 2.0;
  float r = length(p);

  if (r > 1.02) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Discrete 1px pixel stepping for pixel-art aesthetic
  p = floor(p * 32.0) / 32.0;
  float ang = atan(p.y, p.x);

  // Slowly rotating octagonal condemnation seal
  float rotAng = ang + uTime * 1.5;
  float oct = cos(rotAng * 8.0);
  float octRing = smoothstep(0.08, 0.0, abs(r - 0.76 - oct * 0.06));

  // Inner ring
  float innerRing = smoothstep(0.06, 0.0, abs(r - 0.48));

  // 4 Cardinal binding stakes
  float stakes = smoothstep(0.06, 0.0, abs(sin(rotAng * 2.0))) * step(r, 0.88) * (1.0 - step(r, 0.35));

  // Pulsing center rune core
  float centerPulse = (0.5 + 0.5 * sin(uTime * 6.0)) * smoothstep(0.38, 0.0, r);

  float fade = 1.0 - smoothstep(0.85, 1.0, uProgress);
  float mask = clamp(octRing + innerRing * 0.75 + stakes * 0.8 + centerPulse * 0.6, 0.0, 1.0) * fade;

  if (mask <= 0.02) {
    gl_FragColor = vec4(0.0);
    return;
  }

  vec3 sealGold   = vec3(0.976, 0.761, 0.169); // #f9c22b
  vec3 sulfurFire = vec3(0.969, 0.588, 0.090); // #f79617
  vec3 bloodCrim  = vec3(0.720, 0.140, 0.180);
  vec3 flareWhite = vec3(1.000, 0.980, 0.880);

  vec3 col = mix(bloodCrim, sulfurFire, octRing);
  col = mix(col, sealGold, innerRing + stakes * 0.7);
  col = mix(col, flareWhite, centerPulse * 0.8);

  float alpha = clamp(mask * 0.88, 0.0, 0.92);
  gl_FragColor = vec4(col * alpha, alpha);
}
`;

// Capacity constants
const LANCE_CAP = 4;
const CHAIN_CAP = 8;
const SEAL_CAP = 8;

type LanceSlot = {
  quad: Phaser.GameObjects.Shader;
};

type ChainSlot = {
  quad: Phaser.GameObjects.Shader;
  progress: number;
  length: number;
  width: number;
  seed: number;
};

type SealSlot = {
  quad: Phaser.GameObjects.Shader;
  progress: number;
  radius: number;
};

export class CondemnTetherShaderPool {
  private time = 0;
  private lanceSlots: LanceSlot[] = [];
  private chainSlots: ChainSlot[] = [];
  private sealSlots: SealSlot[] = [];

  constructor(scene: Phaser.Scene) {
    // 1. Lance Quads
    for (let i = 0; i < LANCE_CAP; i += 1) {
      const quad = scene.add
        .shader(
          {
            name: 'CondemnTetherLanceShader',
            shaderName: 'CondemnTetherLanceShader',
            fragmentSource: TETHER_LANCE_FRAG,
            setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
              setUniform('uTime', this.time);
              setUniform('uSeed', (i + 1) * 7.73);
            },
          },
          0,
          0,
          48,
          24,
        )
        .setDepth(5.25)
        .setVisible(false);
      this.lanceSlots.push({ quad });
    }

    // 2. Active Chain Quads
    for (let i = 0; i < CHAIN_CAP; i += 1) {
      const slot: ChainSlot = {
        quad: null as unknown as Phaser.GameObjects.Shader,
        progress: 0,
        length: 200,
        width: 32,
        seed: (i + 1) * 11.37,
      };

      slot.quad = scene.add
        .shader(
          {
            name: 'CondemnTetherChainShader',
            shaderName: 'CondemnTetherChainShader',
            fragmentSource: TETHER_CHAIN_FRAG,
            setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
              setUniform('uTime', this.time);
              setUniform('uProgress', slot.progress);
              setUniform('uLength', slot.length);
              setUniform('uWidth', slot.width);
              setUniform('uSeed', slot.seed);
            },
          },
          0,
          0,
          220,
          44,
        )
        .setDepth(2.15)
        .setVisible(false);

      this.chainSlots.push(slot);
    }

    // 3. Hermetic Seal Quads
    for (let i = 0; i < SEAL_CAP; i += 1) {
      const slot: SealSlot = {
        quad: null as unknown as Phaser.GameObjects.Shader,
        progress: 0,
        radius: 36,
      };

      slot.quad = scene.add
        .shader(
          {
            name: 'CondemnTetherSealShader',
            shaderName: 'CondemnTetherSealShader',
            fragmentSource: TETHER_SEAL_FRAG,
            setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
              setUniform('uTime', this.time);
              setUniform('uProgress', slot.progress);
              setUniform('uRadius', slot.radius);
            },
          },
          0,
          0,
          80,
          80,
        )
        .setDepth(2.12)
        .setVisible(false);

      this.sealSlots.push(slot);
    }
  }

  sync(
    runTime: number,
    projectiles: ProjectilePool,
    enemies: EnemyPool,
    playerX: number,
    playerY: number,
  ): void {
    this.time = runTime;

    if (getSettings().reduceVfx) {
      for (const s of this.lanceSlots) s.quad.setVisible(false);
      for (const s of this.chainSlots) s.quad.setVisible(false);
      for (const s of this.sealSlots) s.quad.setVisible(false);
      return;
    }

    // 1. Sync In-flight Lances
    let lanceIdx = 0;
    for (let i = 0; i < projectiles.alive.length && lanceIdx < LANCE_CAP; i += 1) {
      if (projectiles.alive[i] === 0 || (projectiles.flags[i] & FLAG_TETHER) === 0) continue;
      const slot = this.lanceSlots[lanceIdx];
      lanceIdx += 1;

      const rot = Math.atan2(projectiles.vy[i], projectiles.vx[i]);
      slot.quad
        .setSize(52, 28)
        .setOrigin(0.5, 0.5)
        .setPosition(Math.round(projectiles.x[i]), Math.round(projectiles.y[i]))
        .setRotation(rot)
        .setVisible(true);
    }
    for (let i = lanceIdx; i < LANCE_CAP; i += 1) {
      this.lanceSlots[i].quad.setVisible(false);
    }

    // 2. Sync Active Chains & Root Seals
    let chainIdx = 0;
    let sealIdx = 0;
    for (let i = 0; i < enemies.cap; i += 1) {
      if (enemies.alive[i] === 0 || enemies.rootRemain[i] <= 0 || enemies.tetherDps[i] <= 0) continue;
      if (enemies.role[i] !== ROLE_ELITE && enemies.role[i] !== ROLE_BOSS) continue;

      const ex = enemies.x[i];
      const ey = enemies.y[i];
      const er = enemies.radius[i];
      const totalDur = enemies.rootDuration[i] > 0 ? enemies.rootDuration[i] : 2.5;
      const progress = Math.max(0, Math.min(1, 1 - enemies.rootRemain[i] / totalDur));

      // Active Chain Quad
      if (chainIdx < CHAIN_CAP) {
        const slot = this.chainSlots[chainIdx];
        chainIdx += 1;

        const dx = ex - playerX;
        const dy = ey - playerY;
        const dist = Math.hypot(dx, dy);
        const rot = Math.atan2(dy, dx);
        const midX = (playerX + ex) * 0.5;
        const midY = (playerY + ey) * 0.5;

        slot.progress = progress;
        slot.length = dist;
        slot.width = 36;
        slot.seed = (i + 1) * 7.73;

        slot.quad
          .setSize(Math.round(dist + 24), 44)
          .setOrigin(0.5, 0.5)
          .setPosition(Math.round(midX), Math.round(midY))
          .setRotation(rot)
          .setVisible(true);
      }

      // Hermetic Seal Quad
      if (sealIdx < SEAL_CAP) {
        const slot = this.sealSlots[sealIdx];
        sealIdx += 1;

        slot.progress = progress;
        slot.radius = er;
        const sealSize = Math.round(Math.max(48, er * 2.8));

        slot.quad
          .setSize(sealSize, sealSize)
          .setOrigin(0.5, 0.5)
          .setPosition(Math.round(ex), Math.round(ey))
          .setVisible(true);
      }
    }

    for (let i = chainIdx; i < CHAIN_CAP; i += 1) {
      this.chainSlots[i].quad.setVisible(false);
    }
    for (let i = sealIdx; i < SEAL_CAP; i += 1) {
      this.sealSlots[i].quad.setVisible(false);
    }
  }

  destroy(): void {
    for (const s of this.lanceSlots) s.quad.destroy();
    for (const s of this.chainSlots) s.quad.destroy();
    for (const s of this.sealSlots) s.quad.destroy();
    this.lanceSlots.length = 0;
    this.chainSlots.length = 0;
    this.sealSlots.length = 0;
  }
}
