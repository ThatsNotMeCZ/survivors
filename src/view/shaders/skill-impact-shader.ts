import Phaser from 'phaser';
import { getSettings } from '../../ui/settings';

const SKILL_IMPACT_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform float uTime;
uniform float uProgress;
uniform float uKind;    // 0 = Censer Lob impact, 1 = Crucible Cull impact, 2 = Tether Latch burst
uniform float uIsCrit;  // 0 = normal, 1 = crit
uniform float uRadius;  // gameplay AoE radius in world pixels
uniform float uSeed;

float hash21(vec2 p) {
  p = fract(p * vec2(127.1, 311.7) + uSeed * 17.31);
  p += dot(p, p + 34.5);
  return fract(p.x * p.y);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
  return 0.55 * vnoise(p) + 0.30 * vnoise(p * 2.15 + vec2(7.3, 11.1)) + 0.15 * vnoise(p * 4.35 + vec2(13.7, 29.3));
}

void main() {
  vec2 uv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);

  // Normalized coordinate in [-1..1] from center
  vec2 p = (uv - 0.5) * 2.0;
  float r = length(p);
  if (r > 1.04) {
    gl_FragColor = vec4(0.0);
    return;
  }

  float ang = atan(p.y, p.x);
  vec3 col = vec3(0.0);
  float alpha = 0.0;

  // =========================================================================
  // 0: CENSER LOB IMPACT (Shattering vessel, sacred ember burst, incense smoke)
  // =========================================================================
  if (uKind < 0.5) {
    float fade = 1.0 - smoothstep(0.68, 1.0, uProgress);
    if (fade <= 0.01) {
      gl_FragColor = vec4(0.0);
      return;
    }

    // Expanding shockwave of sacred flame
    float waveR = clamp(uProgress / 0.85, 0.05, 1.0) * 0.82;
    float ringThickness = 0.12 * (1.0 - uProgress * 0.45);
    float ring = smoothstep(ringThickness, 0.0, abs(r - waveR));

    // Hot interior core scorch
    float core = smoothstep(waveR * 0.72, 0.0, r) * (1.0 - uProgress * 0.88);

    // Shattering glass/brass vessel shards (8 fragments flying outward)
    float shardCount = 8.0;
    float shardIdx = floor((ang + 3.14159) / (6.28318 / shardCount));
    float shardRand = hash21(vec2(shardIdx, uSeed));
    float shardSpeed = 0.45 + 0.50 * shardRand;
    float shardDist = uProgress * shardSpeed * 0.85;
    vec2 shardCenter = vec2(
      cos((shardIdx + 0.5) * (6.28318 / shardCount)),
      sin((shardIdx + 0.5) * (6.28318 / shardCount))
    ) * shardDist;
    float shardDistToP = length(p - shardCenter);
    float shard = step(shardDistToP, 0.042 * (1.0 - uProgress * 0.55));

    // Billowing incense smoke turbulence
    float smokeN = fbm(p * 4.2 - vec2(cos(ang), sin(ang)) * uProgress * 1.4 + uSeed * 3.3);
    float smoke = smoothstep(0.42, 0.76, smokeN) * step(r, waveR + 0.12) * (1.0 - uProgress * 0.82);

    // Resurrect 64 Dark Hermetic Palettes
    vec3 flareHot  = vec3(1.000, 0.957, 0.784); // #fff4c8 (Incandescent tip)
    vec3 sulfurGold = vec3(0.969, 0.588, 0.090); // #f79617 (Sulfur amber)
    vec3 flameRed   = vec3(0.918, 0.310, 0.212); // #ea4f36 (Searing flame)
    vec3 smokeAsh   = vec3(0.243, 0.208, 0.275); // #3e3546 (Dark incense ash)
    vec3 shardBrass = vec3(0.976, 0.761, 0.169); // #f9c22b (Brass censer shard)

    // Critical overcharge: searing crimson-violet
    vec3 critHot = vec3(1.000, 0.880, 0.920);
    vec3 critMid = vec3(1.000, 0.133, 0.320);

    vec3 hot = mix(flareHot, critHot, uIsCrit);
    vec3 mid = mix(sulfurGold, critMid, uIsCrit);

    col = mix(flameRed, mid, ring);
    col = mix(col, hot, clamp(core * 1.5 + ring * 0.8, 0.0, 1.0));
    col = mix(col, shardBrass, shard * 0.9);
    col = mix(col, smokeAsh, smoke * 0.45);

    alpha = clamp((ring * 0.95 + core * 0.85 + shard * 0.98 + smoke * 0.42) * fade, 0.0, 0.95);
  }
  // =========================================================================
  // 1: CRUCIBLE CULL IMPACT (Alchemical sky-hammer, hexagram fissures, slag shockwave)
  // =========================================================================
  else if (uKind < 1.5) {
    float fade = 1.0 - smoothstep(0.72, 1.0, uProgress);
    if (fade <= 0.01) {
      gl_FragColor = vec4(0.0);
      return;
    }

    // 1. Initial celestial anvil hammerfall flash (descending light column)
    float beamActive = step(uProgress, 0.30);
    float beamFade = 1.0 - uProgress / 0.30;
    float beamW = mix(0.16, 0.02, uProgress / 0.30);
    float beam = smoothstep(beamW, 0.0, abs(p.x)) * beamFade * beamActive;

    // 2. Transmutation double shockwave with 6-fold alchemical facet symmetry
    float waveR = clamp(uProgress / 0.86, 0.05, 1.0) * 0.90;
    float ringW = 0.13 * (1.0 - uProgress * 0.48);
    float ring1 = smoothstep(ringW, 0.0, abs(r - waveR));

    float waveR2 = waveR * 0.60;
    float ring2 = smoothstep(0.08 * (1.0 - uProgress * 0.3), 0.0, abs(r - waveR2)) * (1.0 - uProgress * 0.7);

    // 6-fold alchemical hexagram faceting along the shockwave
    float hex = cos(ang * 6.0);
    float hexFacets = smoothstep(0.09, 0.0, abs(r - waveR * (0.90 + 0.10 * hex))) * 0.8;

    // 3. Molten ground fissures / crucible slag fractures
    float crackN = fbm(p * 5.2 + vec2(uSeed * 4.3, -uSeed * 3.1));
    float crack = smoothstep(0.52, 0.78, crackN) * step(r, waveR + 0.06) * (1.0 - uProgress * 0.65);

    // 4. White-hot center crucible melt pool
    float centerMelt = smoothstep(waveR * 0.50, 0.0, r) * (1.0 - uProgress * 0.92);

    // Palette:
    vec3 tipWhite   = vec3(1.000, 0.965, 0.860); // #fff4c8 (Incandescent white-gold)
    vec3 sulfurGold = vec3(0.976, 0.761, 0.169); // #f9c22b (Molten solar gold)
    vec3 amberFire  = vec3(0.969, 0.588, 0.090); // #f79617 (Sulfur flame)
    vec3 deepMagma  = vec3(0.918, 0.310, 0.212); // #ea4f36 (Searing red)
    vec3 crucibleRed= vec3(0.620, 0.157, 0.208); // #9e2835 (Deep crucible crimson)
    vec3 crustSlag  = vec3(0.180, 0.094, 0.082); // #2e1815 (Scorched crust)

    // Crit variant: blazing crimson-magenta overcharge
    vec3 critCore = vec3(1.000, 0.900, 0.950);
    vec3 critFire = vec3(1.000, 0.180, 0.350);

    vec3 coreHot = mix(tipWhite, critCore, uIsCrit);
    vec3 fireMid = mix(amberFire, critFire, uIsCrit);

    col = mix(crustSlag, crucibleRed, crack);
    col = mix(col, deepMagma, ring1 * 0.7);
    col = mix(col, fireMid, clamp(ring1 + ring2 + hexFacets * 0.7 + crack * 0.9, 0.0, 1.0));
    col = mix(col, sulfurGold, clamp(ring2 * 0.8 + centerMelt * 0.9, 0.0, 1.0));
    col = mix(col, coreHot, clamp(centerMelt * 1.4 + beam * 1.6, 0.0, 1.0));

    float intensity = ring1 * 0.95 + ring2 * 0.82 + hexFacets * 0.65 + crack * 0.88 + centerMelt * 0.95 + beam * 0.98;
    alpha = clamp(intensity * fade, 0.0, 0.96);
  }
  // =========================================================================
  // 2: CONDEMNATION TETHER LATCH BURST (Snapping chain lock, hermetic shackle flash)
  // =========================================================================
  else {
    float fade = 1.0 - smoothstep(0.60, 1.0, uProgress);
    if (fade <= 0.01) {
      gl_FragColor = vec4(0.0);
      return;
    }

    // Inward-clamping shackle ring locking onto target center
    float shackleR = mix(0.95, 0.40, clamp(uProgress / 0.45, 0.0, 1.0));
    float ringThickness = mix(0.12, 0.05, uProgress);
    float shackleRing = smoothstep(ringThickness, 0.0, abs(r - shackleR));

    // 8-spoke radiating chain lock teeth
    float lockTeeth = cos(ang * 8.0);
    float teethPattern = smoothstep(0.10, 0.0, abs(r - shackleR * (1.0 + 0.12 * lockTeeth)));

    // Central flash at moment of latch (first 30% of lifetime)
    float coreFlash = smoothstep(0.35, 0.0, r) * (1.0 - uProgress / 0.35) * step(uProgress, 0.35);

    // Searing hermetic sigil embers
    float sparkNoise = fbm(p * 8.0 + vec2(uSeed * 2.1, uTime * 3.0));
    float sparks = smoothstep(0.55, 0.85, sparkNoise) * step(r, 0.85) * (1.0 - uProgress * 0.7);

    vec3 ironGold  = vec3(0.976, 0.761, 0.169); // #f9c22b
    vec3 sulfurMid = vec3(0.969, 0.588, 0.090); // #f79617
    vec3 bloodDeep = vec3(0.720, 0.140, 0.180); // #b8242e
    vec3 whiteHot  = vec3(1.000, 0.965, 0.880);

    vec3 critMid  = vec3(1.000, 0.150, 0.300);
    vec3 midColor = mix(sulfurMid, critMid, uIsCrit);

    col = mix(bloodDeep, midColor, shackleRing);
    col = mix(col, ironGold, teethPattern * 0.85);
    col = mix(col, whiteHot, coreFlash * 1.5 + sparks * 0.7);

    alpha = clamp((shackleRing * 0.95 + teethPattern * 0.85 + coreFlash * 0.95 + sparks * 0.5) * fade, 0.0, 0.95);
  }

  gl_FragColor = vec4(col * alpha, alpha);
}
`;

type SkillImpactSlot = {
  quad: Phaser.GameObjects.Shader;
  active: boolean;
  progress: number;
  duration: number;
  kind: number;    // 0 = censer, 1 = crucible
  isCrit: number;  // 0 = normal, 1 = crit
  radius: number;
  seed: number;
};

const SKILL_IMPACT_CAP = 12;
const CENSER_DURATION = 0.34;
const CRUCIBLE_DURATION = 0.50;
const TETHER_LATCH_DURATION = 0.38;

export class SkillImpactShaderPool {
  private time = 0;
  private slots: SkillImpactSlot[] = [];

  constructor(scene: Phaser.Scene) {
    for (let i = 0; i < SKILL_IMPACT_CAP; i += 1) {
      const slot: SkillImpactSlot = {
        quad: null as unknown as Phaser.GameObjects.Shader,
        active: false,
        progress: 0,
        duration: CENSER_DURATION,
        kind: 0,
        isCrit: 0,
        radius: 30,
        seed: i * 7.73,
      };

      slot.quad = scene.add
        .shader(
          {
            name: 'SkillImpactShader',
            shaderName: 'SkillImpactShader',
            fragmentSource: SKILL_IMPACT_FRAG,
            setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
              setUniform('uTime', this.time);
              setUniform('uProgress', slot.progress);
              setUniform('uKind', slot.kind);
              setUniform('uIsCrit', slot.isCrit);
              setUniform('uRadius', slot.radius);
              setUniform('uSeed', slot.seed);
            },
          },
          0,
          0,
          84,
          84,
        )
        .setDepth(4.4)
        .setVisible(false);

      this.slots.push(slot);
    }
  }

  spawnCenser(x: number, y: number, radius = 30, isCrit = false): void {
    if (getSettings().reduceVfx) return;
    const effectiveRadius = Math.max(16, radius);
    const quadSize = Math.round(effectiveRadius * 2.8);
    this.spawn(x, y, 0, effectiveRadius, quadSize, CENSER_DURATION, isCrit);
  }

  spawnCrucible(x: number, y: number, radius = 45, isCrit = false): void {
    if (getSettings().reduceVfx) return;
    const effectiveRadius = Math.max(24, radius);
    const quadSize = Math.round(effectiveRadius * 2.6);
    this.spawn(x, y, 1, effectiveRadius, quadSize, CRUCIBLE_DURATION, isCrit);
  }

  spawnTetherLatch(x: number, y: number, radius = 24, isCrit = false): void {
    if (getSettings().reduceVfx) return;
    const effectiveRadius = Math.max(20, radius);
    const quadSize = Math.round(effectiveRadius * 2.8);
    this.spawn(x, y, 2, effectiveRadius, quadSize, TETHER_LATCH_DURATION, isCrit);
  }

  private spawn(
    x: number,
    y: number,
    kind: number,
    radius: number,
    quadSize: number,
    duration: number,
    isCrit: boolean,
  ): void {
    let bestSlot = -1;
    let maxProg = -1;
    for (let i = 0; i < this.slots.length; i += 1) {
      const s = this.slots[i];
      if (!s.active) {
        bestSlot = i;
        break;
      }
      if (s.progress > maxProg) {
        maxProg = s.progress;
        bestSlot = i;
      }
    }

    if (bestSlot < 0) return;

    const slot = this.slots[bestSlot];
    slot.active = true;
    slot.progress = 0;
    slot.duration = duration;
    slot.kind = kind;
    slot.isCrit = isCrit ? 1.0 : 0.0;
    slot.radius = radius;
    slot.seed = (bestSlot + 1) * 11.37 + Math.random() * 99.0;

    slot.quad
      .setSize(quadSize, quadSize)
      .setOrigin(0.5, 0.5)
      .setPosition(Math.round(x), Math.round(y))
      .setVisible(true);
  }

  sync(dt: number, runTime: number): void {
    this.time = runTime;

    if (getSettings().reduceVfx) {
      for (const slot of this.slots) {
        if (slot.active) {
          slot.active = false;
          slot.quad.setVisible(false);
        }
      }
      return;
    }

    for (let i = 0; i < this.slots.length; i += 1) {
      const slot = this.slots[i];
      if (!slot.active) continue;

      slot.progress += dt / slot.duration;
      if (slot.progress >= 1.0) {
        slot.active = false;
        slot.quad.setVisible(false);
      }
    }
  }

  destroy(): void {
    for (const slot of this.slots) {
      slot.quad.destroy();
    }
    this.slots.length = 0;
  }
}
