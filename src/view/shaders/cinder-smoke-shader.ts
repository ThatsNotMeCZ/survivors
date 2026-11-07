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
  return 0.58 * vnoise(p) + 0.28 * vnoise(p * 2.05 + vec2(7.3, 3.1)) + 0.14 * vnoise(p * 4.1 + vec2(11.7, 9.5));
}

void main() {
  // Quantize coordinates to exact 28x32 pixel grid matching boss sprite resolution (1:1)
  const vec2 GRID = vec2(28.0, 32.0);
  vec2 rawUv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  vec2 uv = (floor(rawUv * GRID) + 0.5) / GRID;

  // Narrow, gentle plume geometry rising from top furnace vent
  float width = mix(0.14, 0.38, pow(clamp(uv.y, 0.0, 1.0), 0.75));
  float sway = sin(uv.y * 5.0 - uTime * (1.6 + uAttack * 0.8)) * 0.04;
  sway += uFacing * 0.02 * uv.y;

  float dx = abs(uv.x - 0.5 - sway);
  float cone = smoothstep(width, width * 0.25, dx);

  // Soft vertical fades: gentle release at bottom, evaporation at top
  float bottomFade = smoothstep(0.04, 0.18, uv.y);
  float topFade = smoothstep(0.96, 0.60, uv.y);
  float plumeMask = cone * bottomFade * topFade;

  if (plumeMask <= 0.02) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Gentle, slow upward smoke motion
  float riseSpeed = mix(1.2, 2.2, uAttack);
  vec2 flow = vec2(-sway * 1.2, -uTime * riseSpeed);
  vec2 p = vec2((uv.x - 0.5) * 3.4, uv.y * 2.8) + flow;

  float smokeNoise = fbm(p);

  // Discrete pixel-art opacity steps for light smoke
  float densityCut = mix(0.44, 0.36, uAttack);
  float rawDensity = smoothstep(densityCut, 0.78, smokeNoise) * plumeMask;
  if (rawDensity <= 0.04) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Resurrect 64 soot & cool chimney smoke palette
  // Dark kiln soot:   #181014 vec3(0.094, 0.063, 0.078)
  // Cool charcoal:    #2e222f vec3(0.180, 0.133, 0.184)
  // Ash smoke mid:    #3e3546 vec3(0.243, 0.208, 0.275)
  // Pale wisps:       #625565 vec3(0.384, 0.333, 0.396)
  vec3 sootDark = vec3(0.094, 0.063, 0.078);
  vec3 sootCharcoal = vec3(0.180, 0.133, 0.184);
  vec3 ashMid = vec3(0.243, 0.208, 0.275);
  vec3 wispLight = vec3(0.384, 0.333, 0.396);

  vec3 smokeCol = mix(sootCharcoal, ashMid, smokeNoise);
  smokeCol = mix(smokeCol, wispLight, smoothstep(width * 0.4, width, dx) * 0.45);

  // Subtle warm ember glow at very base of vent
  float emberBase = smoothstep(0.22, 0.04, uv.y) * (0.6 + 0.4 * uAttack);
  vec3 emberCol = vec3(0.969, 0.588, 0.090); // Resurrect 64 ember
  smokeCol = mix(smokeCol, emberCol, emberBase * 0.35);

  // Light, non-intrusive transparency
  float maxAlpha = mix(0.34, 0.52, uAttack + uEnraged * 0.12);
  float alpha = clamp(rawDensity * maxAlpha, 0.0, 0.60);

  gl_FragColor = vec4(smokeCol * alpha, alpha);
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
        28,
        32,
      )
      .setOrigin(0.5, 0.92)
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
    const lerpSpeed = attacking ? 8.0 : 3.5;
    this.attackIntensity += (targetAttack - this.attackIntensity) * Math.min(1.0, dt * lerpSpeed);

    // Vents are situated right at the top perimeter of Cinder Heart
    const bx = Math.round(enemies.x[idx]);
    const by = Math.round(enemies.y[idx] - 20);

    this.quad
      .setPosition(bx, by)
      .setVisible(true);
  }
}
