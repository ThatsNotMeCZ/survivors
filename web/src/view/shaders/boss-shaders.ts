import Phaser from 'phaser';
import {
  HAZ_CONE,
  HAZ_METEOR,
  HAZ_POOL,
  HAZ_PRISON,
  HAZ_PULSE,
} from '../../sim/boss-hazards';
import { PILLAR_COVER_EXTRA_RADIUS } from '../../sim/enemies';
import type { World } from '../../sim/world';
import { CinderSmokeShader } from './cinder-smoke-shader';

const HAZARD_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform float uTime;
uniform float uKind;
uniform float uStyle;
uniform float uState;
uniform float uProgress;
uniform float uAngle;
uniform vec2 uDir;

float hash21(vec2 p) {
  p = fract(p * vec2(127.1, 311.7));
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
  return 0.55 * vnoise(p) + 0.30 * vnoise(p * 2.1 + 11.3) + 0.15 * vnoise(p * 4.3 + 27.1);
}

vec2 hash22(vec2 p) {
  float n = hash21(p);
  return vec2(n, hash21(p + n + 19.19));
}

// Boiling pixelated bubble burst cell matching environmental hazard
float bubbleLayer(vec2 p, float speed, float scale, out float bubbleBody, out float bubbleRing, out float bubbleSpec) {
  vec2 sp = p * scale;
  vec2 cell = floor(sp);
  vec2 local = fract(sp) - 0.5;
  vec2 rnd = hash22(cell);

  float lifeTime = fract(uTime * speed + rnd.x * 6.28);
  float grow = sin(clamp(lifeTime / 0.88, 0.0, 1.0) * 3.14159);
  grow = pow(grow, 0.75);
  float radius = grow * (0.34 + rnd.y * 0.14);

  vec2 offset = (rnd - 0.5) * 0.28;
  vec2 diff = local - offset;
  float d = length(diff);

  float active = step(0.05, radius) * step(lifeTime, 0.94);
  bubbleBody = step(d, radius) * active;
  bubbleRing = step(radius - 0.09, d) * bubbleBody;
  
  float specDist = length(diff - vec2(-radius * 0.32, -radius * 0.32));
  bubbleSpec = step(specDist, max(0.04, radius * 0.25)) * bubbleBody * (1.0 - bubbleRing);
  return bubbleBody;
}

void main() {
  vec2 uv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  vec2 p = (uv - 0.5) * 2.0;
  float r = length(p);
  float ang = atan(p.y, p.x);

  vec3 col = vec3(0.0);
  float alpha = 0.0;

  // 0: HAZ_METEOR (falling clinker / hailstone telegraph circle)
  if (uKind < 0.5) {
    if (r > 1.02) {
      gl_FragColor = vec4(0.0);
      return;
    }
    float outerRing = smoothstep(0.06, 0.0, abs(r - 0.96));
    float fillR = clamp(uProgress, 0.08, 1.0) * 0.96;
    float fillEdge = smoothstep(0.04, 0.0, abs(r - fillR));
    float cracks = fbm(p * 4.5 + vec2(uTime * 0.8, -uTime * 0.6));
    float innerFill = step(r, fillR) * (0.20 + 0.32 * uProgress + 0.25 * cracks);
    float urgent = uProgress > 0.72 ? (0.5 + 0.5 * sin(uTime * 28.0)) : 0.0;

    vec3 baseCol = uStyle < 0.5 ? vec3(1.0, 0.42, 0.12) : vec3(0.42, 0.82, 1.0);
    vec3 hotCol = uStyle < 0.5 ? vec3(1.0, 0.92, 0.65) : vec3(0.92, 0.98, 1.0);

    alpha = clamp(outerRing * 0.92 + fillEdge * 0.85 + innerFill, 0.0, 0.95);
    col = mix(baseCol, hotCol, clamp(outerRing + fillEdge * 0.7 + urgent * 0.5, 0.0, 1.0));
  }
  // 1: HAZ_POOL (bubbling lava or crystalline frost puddle)
  else if (uKind < 1.5) {
    float fade = 1.0 - smoothstep(0.75, 1.0, uProgress);
    if (uStyle < 0.5) {
      // Lava Pool from Cinder Heart meteor:
      // Resurrect 64 palette + slow movement + clean discrete magma crater
      const float GRID = 64.0;
      vec2 uvGrid = (floor(uv * GRID) + 0.5) / GRID;
      vec2 pGrid = (uvGrid - 0.5) * 2.0;
      float rGrid = length(pGrid);

      if (rGrid > 1.0) {
        gl_FragColor = vec4(0.0);
        return;
      }

      float boilSpeed = 0.14;
      float animTime = uTime * boilSpeed;

      float edgeNoise = fbm(pGrid * 2.5 + vec2(sin(animTime * 0.8), cos(animTime * 0.6)) * 0.35);
      float poolR = 0.86 + (edgeNoise - 0.5) * 0.14;
      float poolMask = smoothstep(poolR, poolR - 0.14, rGrid);

      if (poolMask <= 0.01) {
        gl_FragColor = vec4(0.0);
        return;
      }

      vec2 flow = vec2(
        fbm(pGrid * 1.6 + vec2(animTime * 0.2, -animTime * 0.16)),
        fbm(pGrid * 1.6 + vec2(-animTime * 0.16, animTime * 0.2))
      );
      float surface = fbm(pGrid * 2.4 + flow * 0.8);

      // Resurrect 64 lava palette:
      vec3 crust = vec3(0.180, 0.094, 0.082);      // #2e1815
      vec3 deepMagma = vec3(0.620, 0.157, 0.208);  // #9e2835
      vec3 magmaDeep = vec3(0.918, 0.310, 0.212);  // #ea4f36
      vec3 lavaEmber = vec3(0.969, 0.588, 0.090);  // #f79617
      vec3 lavaGlint = vec3(0.976, 0.761, 0.169);  // #f9c22b

      float heatVeins = step(0.48, surface);
      vec3 fluid = mix(crust, magmaDeep, surface);
      fluid = mix(fluid, deepMagma, (1.0 - surface) * 0.45);
      fluid = mix(fluid, lavaEmber, heatVeins * 0.65);

      // Fine micro-fissure sparks
      float sparkNoise = fbm(pGrid * 7.0 - vec2(animTime * 0.8, -animTime * 0.6));
      float sparkGlow = step(0.76, sparkNoise);
      fluid = mix(fluid, lavaGlint, sparkGlow * 0.8);

      col = fluid;
      alpha = clamp((0.40 + surface * 0.38 + sparkGlow * 0.2) * poolMask * fade * 0.92, 0.0, 0.92);
    } else {
      // Crystalline rime pool
      float n = fbm(p * 3.8 + vec2(uTime * 0.65, -uTime * 0.45));
      float edgeR = 0.88 + (n - 0.5) * 0.18;
      if (r > edgeR) {
        gl_FragColor = vec4(0.0);
        return;
      }
      float rim = smoothstep(edgeR, edgeR - 0.14, r);
      float veins = fbm(p * 7.2 - vec2(uTime * 1.1, uTime * 0.8));
      float shard = smoothstep(0.45, 0.75, veins);
      vec3 deepIce = vec3(0.16, 0.42, 0.68);
      vec3 rime = mix(vec3(0.45, 0.84, 1.0), vec3(0.92, 0.98, 1.0), shard);
      col = mix(deepIce, rime, shard);
      alpha = rim * fade * 0.68;
    }
  }
  // 2: HAZ_PRISON (Rime Prison closing ice ring + spikes)
  else if (uKind < 2.5) {
    if (r > 1.04) {
      gl_FragColor = vec4(0.0);
      return;
    }
    float teeth = 0.045 * cos(ang * 12.0 + uTime * 3.0);
    if (uState < 0.5) {
      float outerRing = smoothstep(0.05, 0.0, abs(r - 0.95));
      float closeR = max(0.14, (1.0 - uProgress * 0.82) * 0.95 + teeth);
      float closingRing = smoothstep(0.065, 0.0, abs(r - closeR));
      float frostWeb = step(closeR, r) * step(r, 0.95) * 0.22;
      float flash = uProgress > 0.75 ? (0.5 + 0.5 * sin(uTime * 30.0)) : 0.0;
      vec3 iceCol = mix(vec3(0.35, 0.82, 1.0), vec3(0.95, 0.99, 1.0), clamp(closingRing + flash * 0.5, 0.0, 1.0));
      alpha = clamp(outerRing * 0.85 + closingRing * 0.95 + frostWeb, 0.0, 0.95);
      col = iceCol;
    } else {
      // Snapped shut: jagged ice cage fade-out
      float fade = 1.0 - uProgress;
      float cage = smoothstep(0.08, 0.0, abs(r - (0.38 + teeth * 1.6))) + step(r, 0.38) * 0.45;
      col = vec3(0.82, 0.96, 1.0);
      alpha = clamp(cage * fade, 0.0, 0.9);
    }
  }
  // 3: HAZ_CONE (Glacial Sweep directional frost mist cone)
  else if (uKind < 3.5) {
    if (r > 1.0 || r < 0.04) {
      gl_FragColor = vec4(0.0);
      return;
    }
    vec2 dir = normalize(uDir);
    float cosHalf = cos(uAngle * 0.5);
    float dotDir = dot(p / r, dir);
    if (dotDir < cosHalf) {
      gl_FragColor = vec4(0.0);
      return;
    }
    float angFactor = clamp((dotDir - cosHalf) / max(0.001, 1.0 - cosHalf), 0.0, 1.0);
    float edgeBorder = smoothstep(0.08, 0.0, angFactor) + smoothstep(0.05, 0.0, abs(r - 0.97));
    float radialFlow = fbm(vec2(r * 5.0 - uTime * 3.6, ang * 3.5));

    if (uState < 0.5) {
      // Windup telegraph: sweeping frost lines + filling wedge
      float sweep = step(r, clamp(uProgress, 0.1, 1.0)) * (0.18 + 0.22 * radialFlow);
      col = mix(vec3(0.38, 0.82, 1.0), vec3(0.92, 0.98, 1.0), edgeBorder);
      alpha = clamp(edgeBorder * 0.78 + sweep, 0.0, 0.85);
    } else {
      // Active blizzard burst
      float fade = 1.0 - smoothstep(0.4, 1.0, uProgress);
      float radialFade = smoothstep(1.0, 0.72, r) * smoothstep(0.0, 0.18, angFactor);
      float cloud = (0.45 + 0.55 * radialFlow) * radialFade;
      col = mix(vec3(0.48, 0.86, 1.0), vec3(0.96, 0.99, 1.0), radialFlow);
      alpha = clamp(cloud * fade * 0.85, 0.0, 0.9);
    }
  }

  gl_FragColor = vec4(col * alpha, alpha);
}
`;

const PULSE_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform float uTime;
uniform float uState;
uniform float uProgress;
uniform float uRadius;
uniform mat4 uPillars0;
uniform mat4 uPillars1;
uniform mat4 uPillars2;
uniform mat4 uPillars3;

bool rayBlockedByPillar(vec2 target, vec4 pil) {
  if (pil.w < 0.5) return false;
  float len = length(target);
  if (len < 1.0) return false;
  vec2 dir = target / len;
  float proj = dot(pil.xy, dir);
  if (proj <= 0.0 || proj >= len) return false;
  vec2 closest = dir * proj;
  float distSq = dot(pil.xy - closest, pil.xy - closest);
  return distSq <= pil.z * pil.z;
}

bool isShadowed(vec2 pos) {
  if (rayBlockedByPillar(pos, uPillars0[0])) return true;
  if (rayBlockedByPillar(pos, uPillars0[1])) return true;
  if (rayBlockedByPillar(pos, uPillars0[2])) return true;
  if (rayBlockedByPillar(pos, uPillars0[3])) return true;
  if (rayBlockedByPillar(pos, uPillars1[0])) return true;
  if (rayBlockedByPillar(pos, uPillars1[1])) return true;
  if (rayBlockedByPillar(pos, uPillars1[2])) return true;
  if (rayBlockedByPillar(pos, uPillars1[3])) return true;
  if (rayBlockedByPillar(pos, uPillars2[0])) return true;
  if (rayBlockedByPillar(pos, uPillars2[1])) return true;
  if (rayBlockedByPillar(pos, uPillars2[2])) return true;
  if (rayBlockedByPillar(pos, uPillars2[3])) return true;
  if (rayBlockedByPillar(pos, uPillars3[0])) return true;
  if (rayBlockedByPillar(pos, uPillars3[1])) return true;
  return false;
}

void main() {
  vec2 uv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  vec2 p = (uv - 0.5) * 2.0;
  float r = length(p);
  if (r > 1.0) {
    gl_FragColor = vec4(0.0);
    return;
  }

  vec2 worldOffset = p * uRadius;
  bool shadowed = isShadowed(worldOffset);

  vec3 col = vec3(0.0);
  float alpha = 0.0;

  if (uState < 0.5) {
    float outerRing = smoothstep(0.015, 0.0, abs(r - 0.985));
    float waveR = clamp(uProgress, 0.05, 1.0) * 0.985;
    float waveEdge = smoothstep(0.025, 0.0, abs(r - waveR));
    float ripples = 0.5 + 0.5 * sin(r * 28.0 - uTime * 10.0);

    if (shadowed) {
      // Safe shelter shadow behind pillar: calm warm-emerald tint so player sees cover
      col = vec3(0.25, 0.85, 0.62);
      alpha = (0.10 + 0.06 * uProgress) * smoothstep(1.0, 0.85, r);
    } else {
      float dangerFill = (0.10 + 0.16 * uProgress + 0.06 * ripples) * smoothstep(1.0, 0.92, r);
      float flash = uProgress > 0.78 ? (0.5 + 0.5 * sin(uTime * 32.0)) : 0.0;
      col = mix(vec3(0.32, 0.76, 1.0), vec3(0.92, 0.98, 1.0), clamp(outerRing + waveEdge + flash * 0.45, 0.0, 1.0));
      alpha = clamp(outerRing * 0.85 + waveEdge * 0.75 + dangerFill, 0.0, 0.82);
    }
  } else {
    // Detonation shockwave
    if (shadowed) {
      gl_FragColor = vec4(0.0);
      return;
    }
    float fade = 1.0 - uProgress;
    float shockR = 0.25 + uProgress * 0.75;
    float ring = smoothstep(0.08, 0.0, abs(r - shockR));
    col = vec3(0.85, 0.97, 1.0);
    alpha = clamp((ring * 0.85 + 0.22) * fade, 0.0, 0.88);
  }

  gl_FragColor = vec4(col * alpha, alpha);
}
`;

const LASER_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform float uTime;
uniform float uChanneling;
uniform float uProgress;

void main() {
  vec2 uv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  float along = uv.x;
  float across = (uv.y - 0.5) * 2.0;

  vec3 col = vec3(0.0);
  float alpha = 0.0;

  if (uChanneling < 0.5) {
    // Lock-on telegraph beam
    float width = mix(0.18, 0.06, uProgress);
    float line = smoothstep(width, 0.0, abs(across));
    float dash = step(0.35, fract(along * 14.0 - uTime * 6.0));
    float flash = uProgress > 0.7 ? (0.5 + 0.5 * sin(uTime * 34.0)) : 0.0;
    col = mix(vec3(0.45, 0.85, 1.0), vec3(1.0, 0.96, 1.0), flash);
    alpha = line * (0.45 + 0.45 * dash);
  } else {
    // Active Aether Laser beam: plasma core + dual helical arcs + end flare
    float wave1 = sin(along * 22.0 - uTime * 24.0) * 0.22;
    float wave2 = cos(along * 17.0 + uTime * 19.0) * 0.18;
    float core = smoothstep(0.28, 0.03, abs(across));
    float outerGlow = smoothstep(0.88, 0.12, abs(across)) * 0.55;
    float arc1 = smoothstep(0.11, 0.0, abs(across - wave1)) * 0.75;
    float arc2 = smoothstep(0.10, 0.0, abs(across - wave2)) * 0.65;

    float endDist = length(vec2((along - 0.96) * 6.5, across));
    float endFlare = smoothstep(0.85, 0.05, endDist);

    float intensity = clamp(core + outerGlow + arc1 + arc2 + endFlare, 0.0, 1.0);
    col = mix(vec3(0.28, 0.72, 1.0), vec3(0.95, 0.99, 1.0), clamp(core + endFlare * 0.7, 0.0, 1.0));
    alpha = clamp(intensity * 0.92, 0.0, 0.95);
  }

  gl_FragColor = vec4(col * alpha, alpha);
}
`;

type HazardQuadSlot = {
  quad: Phaser.GameObjects.Shader;
  kind: number;
  style: number;
  state: number;
  progress: number;
  angle: number;
  dir: [number, number];
};

const HAZARD_QUAD_CAP = 14;

export class BossShaders {
  private time = 0;
  private hazardSlots: HazardQuadSlot[] = [];

  private pulseQuad: Phaser.GameObjects.Shader;
  private pulseState = 0;
  private pulseProgress = 0;
  private pulseRadius = 620;
  private pillars0 = new Array<number>(16).fill(0);
  private pillars1 = new Array<number>(16).fill(0);
  private pillars2 = new Array<number>(16).fill(0);
  private pillars3 = new Array<number>(16).fill(0);

  private laserQuad: Phaser.GameObjects.Shader;
  private laserChanneling = 0;
  private laserProgress = 0;

  private cinderSmoke: CinderSmokeShader;

  constructor(scene: Phaser.Scene) {
    for (let i = 0; i < HAZARD_QUAD_CAP; i += 1) {
      const slot: HazardQuadSlot = {
        quad: null as unknown as Phaser.GameObjects.Shader,
        kind: 0,
        style: 0,
        state: 0,
        progress: 0,
        angle: 1,
        dir: [1, 0],
      };
      slot.quad = scene.add
        .shader(
          {
            name: 'BossHazardShader',
            shaderName: 'BossHazardShader',
            fragmentSource: HAZARD_FRAG,
            setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
              setUniform('uTime', this.time);
              setUniform('uKind', slot.kind);
              setUniform('uStyle', slot.style);
              setUniform('uState', slot.state);
              setUniform('uProgress', slot.progress);
              setUniform('uAngle', slot.angle);
              setUniform('uDir', slot.dir);
            },
          },
          0,
          0,
          64,
          64,
        )
        .setDepth(2)
        .setVisible(false);
      this.hazardSlots.push(slot);
    }

    this.pulseQuad = scene.add
      .shader(
        {
          name: 'BossPulseShader',
          shaderName: 'BossPulseShader',
          fragmentSource: PULSE_FRAG,
          setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
            setUniform('uTime', this.time);
            setUniform('uState', this.pulseState);
            setUniform('uProgress', this.pulseProgress);
            setUniform('uRadius', this.pulseRadius);
            setUniform('uPillars0', this.pillars0);
            setUniform('uPillars1', this.pillars1);
            setUniform('uPillars2', this.pillars2);
            setUniform('uPillars3', this.pillars3);
          },
        },
        0,
        0,
        128,
        128,
      )
      .setDepth(2)
      .setVisible(false);

    this.laserQuad = scene.add
      .shader(
        {
          name: 'BossLaserShader',
          shaderName: 'BossLaserShader',
          fragmentSource: LASER_FRAG,
          setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
            setUniform('uTime', this.time);
            setUniform('uChanneling', this.laserChanneling);
            setUniform('uProgress', this.laserProgress);
          },
        },
        0,
        0,
        128,
        48,
      )
      .setDepth(5.5)
      .setVisible(false);

    this.cinderSmoke = new CinderSmokeShader(scene);
  }

  sync(world: World, dt = 1 / 60): void {
    this.time = world.runTime;
    this.cinderSmoke.sync(world, dt);
    const pool = world.bossHazards;
    let used = 0;
    let pulseSlot = -1;

    for (let i = 0; i < pool.cap; i += 1) {
      if (pool.alive[i] === 0) continue;
      if (pool.kind[i] === HAZ_PULSE) {
        pulseSlot = i;
        continue;
      }
      if (used >= HAZARD_QUAD_CAP) continue;

      const slot = this.hazardSlots[used];
      used += 1;
      const kind = pool.kind[i];
      const r = pool.radius[i];
      const dur = pool.duration[i] > 0 ? pool.duration[i] : 1;

      slot.kind =
        kind === HAZ_METEOR
          ? 0
          : kind === HAZ_POOL
            ? 1
            : kind === HAZ_PRISON
              ? 2
              : kind === HAZ_CONE
                ? 3
                : 0;
      slot.style = pool.style[i];
      slot.state = pool.state[i];
      slot.progress = Math.min(1, Math.max(0, pool.elapsed[i] / dur));
      slot.angle = pool.angle[i];
      slot.dir[0] = pool.dirX[i];
      slot.dir[1] = pool.dirY[i];

      const quadSize = r * 2;
      slot.quad
        .setVisible(true)
        .setSize(quadSize, quadSize)
        .setOrigin(0.5, 0.5)
        .setPosition(Math.round(pool.x[i]), Math.round(pool.y[i]));
    }

    for (let i = used; i < HAZARD_QUAD_CAP; i += 1) {
      this.hazardSlots[i].quad.setVisible(false);
    }

    if (pulseSlot >= 0) {
      const px = pool.x[pulseSlot];
      const py = pool.y[pulseSlot];
      const r = pool.radius[pulseSlot];
      const dur = pool.duration[pulseSlot] > 0 ? pool.duration[pulseSlot] : 1;
      this.pulseState = pool.state[pulseSlot];
      this.pulseProgress = Math.min(1, Math.max(0, pool.elapsed[pulseSlot] / dur));
      this.pulseRadius = r;
      this.fillPillarMatrices(world, px, py);
      this.pulseQuad
        .setVisible(true)
        .setSize(r * 2, r * 2)
        .setOrigin(0.5, 0.5)
        .setPosition(Math.round(px), Math.round(py));
    } else {
      this.pulseQuad.setVisible(false);
    }

    this.syncLaser(world);
  }

  private syncLaser(world: World): void {
    const { boss, enemies } = world;
    const idx = boss.enemyIndex;
    if (
      idx < 0 ||
      enemies.alive[idx] === 0 ||
      boss.activeAttack < 0 ||
      boss.phase === 'none'
    ) {
      this.laserQuad.setVisible(false);
      return;
    }
    const defId = enemies.defId[idx];
    if (!defId) {
      this.laserQuad.setVisible(false);
      return;
    }
    const ai = world.catalog.entity(defId).ai;
    if (ai.type !== 'boss') {
      this.laserQuad.setVisible(false);
      return;
    }
    const atk = ai.attacks[boss.activeAttack];
    if (!atk || atk.type !== 'laser') {
      this.laserQuad.setVisible(false);
      return;
    }

    const bx = enemies.x[idx];
    const by = enemies.y[idx];
    const ex = boss.laserEndX;
    const ey = boss.laserEndY;
    const dx = ex - bx;
    const dy = ey - by;
    const len = Math.max(24, Math.hypot(dx, dy));
    const ang = Math.atan2(dy, dx);
    const midX = (bx + ex) * 0.5;
    const midY = (by + ey) * 0.5;
    const dur = boss.duration > 0 ? boss.duration : 1;

    this.laserChanneling = boss.phase === 'channel' ? 1.0 : 0.0;
    this.laserProgress = Math.min(1, Math.max(0, boss.elapsed / dur));

    this.laserQuad
      .setVisible(true)
      .setSize(len, atk.hitRadius * 3.0)
      .setOrigin(0.5, 0.5)
      .setPosition(midX, midY)
      .setRotation(ang);
  }

  private fillPillarMatrices(world: World, bx: number, by: number): void {
    this.pillars0.fill(0);
    this.pillars1.fill(0);
    this.pillars2.fill(0);
    this.pillars3.fill(0);
    const mats = [this.pillars0, this.pillars1, this.pillars2, this.pillars3];
    const { obstacles } = world;
    let slot = 0;
    for (let i = 0; i < obstacles.cap && slot < 14; i += 1) {
      if (obstacles.alive[i] === 0) continue;
      const obs = obstacles.items[i];
      if (obs.type !== 'pillar') continue;
      const matIdx = slot >> 2;
      const colOffset = (slot & 3) * 4;
      const arr = mats[matIdx];
      arr[colOffset] = obs.x - bx;
      arr[colOffset + 1] = obs.y - by;
      arr[colOffset + 2] = obs.radius + PILLAR_COVER_EXTRA_RADIUS;
      arr[colOffset + 3] = 1.0;
      slot += 1;
    }
  }
}
