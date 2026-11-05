import Phaser from 'phaser';

const DAMAGE_FX_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform float uTime;
uniform float uProgress;
uniform float uStyle;
uniform float uAngle;

float hash21(vec2 p) {
  p = fract(p * vec2(127.1, 311.7));
  p += dot(p, p + 34.5);
  return fract(p.x * p.y);
}

void main() {
  vec2 uv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  vec2 p = (uv - 0.5) * 2.0;
  float r = length(p);
  if (r > 1.02) {
    gl_FragColor = vec4(0.0);
    return;
  }

  float ang = atan(p.y, p.x) + uAngle;

  // Expanding shockwave ring
  float waveR = clamp(uProgress, 0.05, 1.0) * 0.94;
  float ringThickness = 0.11 * (1.0 - uProgress * 0.55);
  float ring = smoothstep(ringThickness, 0.0, abs(r - waveR));

  // Core blast glow fading with expansion
  float coreGlow = smoothstep(waveR, 0.0, r) * (1.0 - uProgress) * 0.48;

  // Angular radial slash lines / sparks
  float spikes = pow(max(0.0, cos(ang * 5.0 + uProgress * 2.0)), 5.0) * smoothstep(0.96, 0.04, r);

  // Overall fade out
  float fade = 1.0 - smoothstep(0.32, 1.0, uProgress);

  vec3 col = vec3(1.0);
  if (uStyle < 0.5) {
    // Style 0: Normal kinetic enemy hit (Solar gold / amber)
    vec3 baseCol = vec3(1.0, 0.52, 0.12);
    vec3 hotCol = vec3(1.0, 0.96, 0.78);
    col = mix(baseCol, hotCol, clamp(ring * 1.1 + coreGlow * 1.6, 0.0, 1.0));
  } else if (uStyle < 1.5) {
    // Style 1: Critical enemy hit (Crimson-violet energy flare)
    vec3 baseCol = vec3(0.95, 0.10, 0.32);
    vec3 hotCol = vec3(1.0, 0.95, 1.0);
    col = mix(baseCol, hotCol, clamp(ring * 1.3 + spikes * 0.85, 0.0, 1.0));
  } else {
    // Style 2: Player hurt (Visceral scarlet rip)
    vec3 baseCol = vec3(0.85, 0.05, 0.12);
    vec3 hotCol = vec3(1.0, 0.82, 0.82);
    col = mix(baseCol, hotCol, clamp(ring + coreGlow * 1.2, 0.0, 1.0));
  }

  float alpha = clamp((ring * 0.95 + coreGlow + spikes * 0.65) * fade, 0.0, 0.95);
  gl_FragColor = vec4(col * alpha, alpha);
}
`;

type DamageFxSlot = {
  quad: Phaser.GameObjects.Shader;
  active: boolean;
  progress: number;
  duration: number;
  style: number;
  angle: number;
};

const DAMAGE_FX_CAP = 16;
const HIT_DURATION = 0.20;

export class DamageFxShaderPool {
  private time = 0;
  private playerHurtCd = 0;
  private slots: DamageFxSlot[] = [];

  constructor(scene: Phaser.Scene) {
    for (let i = 0; i < DAMAGE_FX_CAP; i += 1) {
      const slot: DamageFxSlot = {
        quad: null as unknown as Phaser.GameObjects.Shader,
        active: false,
        progress: 0,
        duration: HIT_DURATION,
        style: 0,
        angle: 0,
      };

      slot.quad = scene.add
        .shader(
          {
            name: 'DamageFxShader',
            shaderName: 'DamageFxShader',
            fragmentSource: DAMAGE_FX_FRAG,
            setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
              setUniform('uTime', this.time);
              setUniform('uProgress', slot.progress);
              setUniform('uStyle', slot.style);
              setUniform('uAngle', slot.angle);
            },
          },
          0,
          0,
          72,
          72,
        )
        .setDepth(4.5)
        .setVisible(false);

      this.slots.push(slot);
    }
  }

  spawn(x: number, y: number, style: number, size = 72): void {
    if (style >= 1.5) {
      if (this.playerHurtCd > 0) return;
      this.playerHurtCd = 0.22;
    }
    // Find inactive slot or the oldest slot with highest progress
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
    slot.duration = HIT_DURATION;
    slot.style = style;
    slot.angle = Math.random() * Math.PI * 2;

    slot.quad
      .setSize(size, size)
      .setOrigin(0.5, 0.5)
      .setPosition(Math.round(x), Math.round(y))
      .setVisible(true);
  }

  sync(dt: number, runTime: number): void {
    this.time = runTime;
    if (this.playerHurtCd > 0) {
      this.playerHurtCd = Math.max(0, this.playerHurtCd - dt);
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
}
