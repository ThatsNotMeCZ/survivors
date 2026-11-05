import Phaser from 'phaser';
import { isEnemyAttacking } from '../../sim/enemies';
import type { World } from '../../sim/world';

const CINDER_SMOKE_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform float uTime;
uniform float uAttack;
uniform float uFacing;
uniform float uEnraged;

float hash21(vec2 p) {
  p = fract(p * vec2(127.1, 311.7));
  p += dot(p, p + 34.5);
  return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
  float n = hash21(p);
  return vec2(n, hash21(p + n + 19.19));
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
  float v = 0.0;
  v += 0.55 * vnoise(p);
  v += 0.30 * vnoise(p * 2.07 + vec2(13.1, 7.7));
  v += 0.15 * vnoise(p * 4.13 + vec2(3.7, 29.3));
  return v;
}

float sparkLayer(vec2 uv, vec2 gridScale, float speed, float threshold, float seed, out vec3 sparkColor) {
  vec2 p = vec2(uv.x * gridScale.x, uv.y * gridScale.y - uTime * speed);
  vec2 cell = floor(p);
  vec2 local = fract(p) - 0.5;
  vec2 rnd = hash22(cell + seed);

  if (rnd.x > threshold) {
    sparkColor = vec3(0.0);
    return 0.0;
  }

  vec2 offset = (rnd - 0.5) * 0.65;
  offset.x += sin(uTime * 14.0 + rnd.y * 6.28) * 0.16;

  vec2 diff = local - offset;
  // Elongate vertically to simulate rising spark streak
  diff.y *= 0.52;
  float d = length(diff);

  float core = smoothstep(0.09, 0.01, d);
  float halo = smoothstep(0.26, 0.02, d) * 0.45;
  float intensity = core + halo;

  // Cool from incandescent white-gold near vent to burning orange and deep amber-red
  float coolProgress = clamp(uv.y * 1.15 + (1.0 - rnd.y) * 0.25, 0.0, 1.0);
  vec3 hotCol = mix(vec3(1.0, 0.95, 0.65), vec3(1.0, 0.45, 0.08), coolProgress);
  vec3 coldCol = vec3(0.95, 0.16, 0.02);
  sparkColor = mix(hotCol, coldCol, smoothstep(0.45, 1.0, coolProgress));
  sparkColor = mix(sparkColor, vec3(1.0, 1.0, 0.92), core * 0.7);

  return intensity;
}

void main() {
  vec2 uv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);

  // Plume geometry: widening cone rising from furnace vent
  float width = mix(0.12, 0.44, pow(clamp(uv.y, 0.0, 1.0), 0.72));
  float sway = sin(uv.y * 6.0 - uTime * (3.0 + uAttack * 2.0)) * 0.035 * (1.0 + 0.6 * uAttack);
  sway += uFacing * 0.025 * uv.y;

  float dx = abs(uv.x - 0.5 - sway);
  float cone = smoothstep(width, width * 0.15, dx);

  // Vertical boundary fading: vent entrance at bottom, dispersion at top
  float bottomFade = smoothstep(0.04, 0.16, uv.y);
  float topFade = smoothstep(0.98, 0.62, uv.y);
  float plumeMask = cone * bottomFade * topFade;

  if (plumeMask <= 0.001) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Multi-octave rising turbulent FBM smoke
  float riseSpeed = mix(2.2, 4.6, uAttack);
  vec2 flow = vec2(-sway * 1.5, -uTime * riseSpeed);
  vec2 p = vec2((uv.x - 0.5) * 4.2, uv.y * 3.4) + flow;

  vec2 warp = vec2(
    fbm(p + vec2(1.7, 7.3)),
    fbm(p + vec2(8.1, 2.9))
  );
  float smokeNoise = fbm(p * 1.4 + warp * 1.3);

  // Smoke density threshold & contrast
  float densityCut = mix(0.34, 0.22, uAttack);
  float smokeDensity = smoothstep(densityCut, 0.78, smokeNoise) * plumeMask;
  smokeDensity = clamp(smokeDensity * mix(1.15, 1.55, uAttack + uEnraged * 0.2), 0.0, 1.0);

  // Furnace fire bleeding into base of plume
  float glowHeight = mix(0.24, 0.50, uAttack);
  float heat = smoothstep(glowHeight, 0.05, uv.y) * (0.65 + 0.35 * smokeNoise);
  vec3 fireRim = vec3(1.0, 0.28, 0.05);
  vec3 fireCore = vec3(1.0, 0.82, 0.28);
  vec3 furnaceCol = mix(fireRim, fireCore, heat * (0.75 + 0.25 * uAttack));

  // Volcanic / kiln soot shading
  vec3 sootDark = vec3(0.10, 0.06, 0.07);
  vec3 sootMid = vec3(0.25, 0.16, 0.14);
  vec3 sootRim = vec3(0.42, 0.30, 0.26);
  vec3 smokeCol = mix(sootDark, sootMid, smokeNoise);
  smokeCol = mix(smokeCol, sootRim, smoothstep(width * 0.35, width, dx) * 0.5);

  vec3 compositeSmoke = mix(smokeCol, furnaceCol, clamp(heat * (1.3 + uAttack * 0.5), 0.0, 1.0));

  // Attack Sparks / Flying Embers
  // Low baseline occasional ember during idle, eruption during attack
  float sparkThreshold1 = mix(0.06, 0.55, uAttack);
  float sparkThreshold2 = mix(0.03, 0.42, uAttack);

  vec3 col1 = vec3(0.0);
  vec3 col2 = vec3(0.0);
  float s1 = sparkLayer(uv, vec2(30.0, 20.0), mix(12.0, 25.0, uAttack), sparkThreshold1, 19.3, col1);
  float s2 = sparkLayer(uv, vec2(22.0, 15.0), mix(9.0, 20.0, uAttack), sparkThreshold2, 83.7, col2);

  // Mask sparks within the plume cone and vertical limits
  float sparkMask = cone * smoothstep(0.06, 0.18, uv.y) * smoothstep(0.96, 0.55, uv.y);
  s1 *= sparkMask;
  s2 *= sparkMask;

  vec3 sparkOutput = (col1 * s1 + col2 * s2) * (1.1 + uAttack * 0.8);
  float totalSparkAlpha = clamp((s1 + s2) * (0.85 + uAttack * 0.4), 0.0, 1.0);

  vec3 finalColor = compositeSmoke + sparkOutput;
  float totalAlpha = clamp(smokeDensity * 0.85 + totalSparkAlpha, 0.0, 0.96);

  gl_FragColor = vec4(finalColor * totalAlpha, totalAlpha);
}
`;

export class CinderSmokeShader {
  private quad: Phaser.GameObjects.Shader;
  private time = 0;
  private attackIntensity = 0;
  private facing = 1;
  private enraged = 0;

  constructor(scene: Phaser.Scene) {
    this.quad = scene.add
      .shader(
        {
          name: 'CinderSmokeShader',
          shaderName: 'CinderSmokeShader',
          fragmentSource: CINDER_SMOKE_FRAG,
          setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
            setUniform('uTime', this.time);
            setUniform('uAttack', this.attackIntensity);
            setUniform('uFacing', this.facing);
            setUniform('uEnraged', this.enraged);
          },
        },
        0,
        0,
        112,
        144,
      )
      .setOrigin(0.5, 0.90)
      .setDepth(3.05)
      .setVisible(false);
  }

  sync(world: World, dt: number): void {
    const { boss, enemies } = world;
    const idx = boss.enemyIndex;

    if (idx < 0 || enemies.alive[idx] === 0) {
      this.quad.setVisible(false);
      this.attackIntensity = 0;
      return;
    }

    const defId = enemies.defId[idx];
    if (defId !== 'cinder-heart') {
      this.quad.setVisible(false);
      this.attackIntensity = 0;
      return;
    }

    this.time = world.runTime;
    this.facing = enemies.facing[idx] < 0 ? -1.0 : 1.0;
    this.enraged = boss.enraged ? 1.0 : 0.0;

    // Detect attack states: windup, active channel, or attack animation remain
    const attacking =
      isEnemyAttacking(world, idx) ||
      boss.phase === 'windup' ||
      boss.phase === 'channel';

    const targetAttack = attacking ? 1.0 : 0.0;
    const lerpSpeed = attacking ? 10.0 : 4.5;
    this.attackIntensity += (targetAttack - this.attackIntensity) * Math.min(1.0, dt * lerpSpeed);

    // Cinder Heart top chimneys are ~26px above boss center
    const bx = Math.round(enemies.x[idx]);
    const by = Math.round(enemies.y[idx] - 26);

    this.quad
      .setPosition(bx, by)
      .setVisible(true);
  }
}
