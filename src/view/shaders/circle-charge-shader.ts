import Phaser from 'phaser';
import { getSettings } from '../../ui/settings';

const CIRCLE_CHARGE_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform float uTime;
uniform float uCharge;
uniform float uActive;
uniform vec2 uPlayerOffset; // player pos relative to circle center, normalized by radius (-1..1)
uniform float uStyle;       // 0 = Cinder ember/gold, 1 = Rime aether cyan

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
  return 0.55 * vnoise(p) + 0.30 * vnoise(p * 2.08 + 7.3) + 0.15 * vnoise(p * 4.15 + 19.1);
}

void main() {
  if (uActive <= 0.01) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Quantize coordinates to a discrete pixel-art grid matching 128x128 circle resolution
  const float GRID = 128.0;
  vec2 rawUv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  vec2 uv = (floor(rawUv * GRID) + 0.5) / GRID;
  vec2 p = (uv - 0.5) * 2.0; // -1..1 from circle center
  float r = length(p);

  if (r > 1.05) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Segment from player position to circle center
  vec2 p0 = uPlayerOffset;
  vec2 p1 = vec2(0.0);
  vec2 seg = p1 - p0;
  float segLen = length(seg);

  if (segLen <= 0.08) {
    gl_FragColor = vec4(0.0);
    return;
  }

  vec2 dir = seg / segLen;
  vec2 normal = vec2(-dir.y, dir.x);

  // Projection of current pixel p onto segment
  vec2 toP = p - p0;
  float proj = dot(toP, dir);
  float t = proj / segLen; // 0 = at player, 1 = at circle center

  // Strict segment bounds: tether exists ONLY between player (t=0) and center (t=1)
  // If proj < 0 (behind player) or proj > segLen (past center), no effect.
  if (t < -0.02 || t > 1.02) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Organic wavy sway along the tether
  float sway = sin(t * 12.0 - uTime * 3.5) * 0.022 * sin(clamp(t, 0.0, 1.0) * 3.14159);
  float distToLine = abs(dot(toP, normal) - sway);

  // Tether width softly tapers from player to center
  float tetherWidth = mix(0.065, 0.038, clamp(t, 0.0, 1.0));
  float beam = smoothstep(tetherWidth, 0.0, distToLine);

  // Soft falloff at ends (fade near player and fade as it enters the center)
  float endFade = smoothstep(0.0, 0.08, t) * smoothstep(1.0, 0.92, t);

  // Slow transfer: pulses and particles drift gently from player (t=0) to center (t=1)
  float travel1 = fract(t * 2.5 - uTime * 0.45);
  float pulse1 = smoothstep(0.0, 0.4, travel1) * smoothstep(1.0, 0.5, travel1);

  float travel2 = fract(t * 3.8 - uTime * 0.65 + 0.5);
  float pulse2 = smoothstep(0.0, 0.35, travel2) * smoothstep(1.0, 0.55, travel2);

  float noiseWave = fbm(vec2(t * 6.0 - uTime * 0.8, distToLine * 14.0));

  float tetherMask = beam * endFade * (0.35 + 0.45 * pulse1 + 0.25 * pulse2 + 0.15 * noiseWave);
  float streamIntensity = clamp(t, 0.0, 1.0);

  // Tiny soft pooling right at the center terminus (radius < 0.08)
  float centerDist = length(p);
  float centerPool = smoothstep(0.08, 0.0, centerDist) * 0.35;

  float totalPattern = tetherMask + centerPool * tetherMask;
  if (totalPattern <= 0.01) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Color palettes (Dark Hermetic tokens)
  vec3 col = vec3(1.0);
  if (uStyle < 0.5) {
    // Cinder: Deep ruby/burnt ember -> molten amber -> hot gold
    vec3 emberDeep = vec3(0.62, 0.15, 0.08); // #9e2614
    vec3 amberMid  = vec3(0.97, 0.59, 0.09); // #f79617
    vec3 goldHot   = vec3(0.98, 0.88, 0.42); // #fae06b
    col = mix(emberDeep, amberMid, clamp(streamIntensity * 0.7 + tetherMask * 0.4, 0.0, 1.0));
    col = mix(col, goldHot, clamp(centerPool * 0.9 + tetherMask * 0.3, 0.0, 1.0));
  } else {
    // Rime: Deep cosmic azure -> bright aether cyan -> pale silver glint
    vec3 azureDeep = vec3(0.12, 0.32, 0.65);
    vec3 cyanMid   = vec3(0.32, 0.82, 1.0);
    vec3 silverHot = vec3(0.88, 0.96, 1.0);
    col = mix(azureDeep, cyanMid, clamp(streamIntensity * 0.7 + tetherMask * 0.4, 0.0, 1.0));
    col = mix(col, silverHot, clamp(centerPool * 0.9 + tetherMask * 0.3, 0.0, 1.0));
  }

  float alpha = clamp(totalPattern * uActive * 0.82, 0.0, 0.88);
  gl_FragColor = vec4(col * alpha, alpha);
}
`;

export class CircleChargeShader {
  private quad: Phaser.GameObjects.Shader;
  private time = 0;
  private charge = 0;
  private active = 0;
  private playerOffset: [number, number] = [0, 0];
  private style = 0;

  constructor(scene: Phaser.Scene) {
    this.quad = scene.add
      .shader(
        {
          name: 'CircleChargeShader',
          shaderName: 'CircleChargeShader',
          fragmentSource: CIRCLE_CHARGE_FRAG,
          setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
            setUniform('uTime', this.time);
            setUniform('uCharge', this.charge);
            setUniform('uActive', this.active);
            setUniform('uPlayerOffset', this.playerOffset);
            setUniform('uStyle', this.style);
          },
        },
        0,
        0,
        256,
        256,
      )
      .setDepth(1.15)
      .setVisible(false);
  }

  sync(
    runTime: number,
    telX: number,
    telY: number,
    radius: number,
    chargePct: number,
    isCharging: boolean,
    inZone: boolean,
    playerX: number,
    playerY: number,
    biome: string,
    dt: number,
  ): void {
    this.time = runTime;

    if (getSettings().reduceVfx || !isCharging) {
      this.active = Math.max(0, this.active - dt * 4.0);
      if (this.active <= 0.01) {
        this.quad.setVisible(false);
        return;
      }
    } else {
      const targetActive = inZone ? 1.0 : 0.0;
      this.active += (targetActive - this.active) * Math.min(1.0, dt * 5.0);
    }

    if (this.active <= 0.01) {
      this.quad.setVisible(false);
      return;
    }

    this.charge = chargePct;
    this.style = biome === 'cinder' ? 0.0 : 1.0;

    // Normalize player position relative to circle center in range -1..1
    const r = Math.max(1, radius);
    this.playerOffset[0] = Math.max(-1.0, Math.min(1.0, (playerX - telX) / r));
    this.playerOffset[1] = Math.max(-1.0, Math.min(1.0, (playerY - telY) / r));

    const diameter = Math.round(radius * 2.15);
    this.quad
      .setSize(diameter, diameter)
      .setOrigin(0.5, 0.5)
      .setPosition(Math.round(telX), Math.round(telY))
      .setVisible(true);
  }

  destroy(): void {
    this.quad.destroy();
  }
}
