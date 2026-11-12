import Phaser from 'phaser';
import { getSettings } from '../../ui/settings';
import { ZONE_LINE, type ZonePool } from '../../sim/zones';

const BRIMSTONE_LINE_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform float uTime;
uniform float uProgress;
uniform float uLength;
uniform float uWidth;
uniform float uSeed;

float hash21(vec2 p) {
  p = fract(p * vec2(127.1, 311.7) + uSeed * 13.37);
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
  return 0.54 * vnoise(p) + 0.30 * vnoise(p * 2.15 + vec2(7.3, 11.1)) + 0.16 * vnoise(p * 4.35 + vec2(13.7, 29.3));
}

void main() {
  vec2 uv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  
  // Total dimensions including padding
  float totalLen = uLength + 24.0;
  float totalWidth = uWidth + 24.0;

  // Real pixel-space relative to line center
  vec2 rawPos = vec2((uv.x - 0.5) * totalLen, (uv.y - 0.5) * totalWidth);

  // Discrete 1px pixel art stepping
  vec2 p = floor(rawPos) + 0.5;

  float halfLen = uLength * 0.5;
  float halfWidth = uWidth * 0.5;

  // Ignition expansion from center to ends during initial 12% of duration
  float igniteReach = clamp(uProgress / 0.12, 0.0, 1.0) * (halfLen + 4.0);
  if (abs(p.x) > igniteReach) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // End taper along the line ends
  float endTaper = 1.0 - smoothstep(halfLen - 6.0, halfLen + 4.0, abs(p.x));
  if (endTaper <= 0.01) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Burnout fade during final 22% of duration
  float fade = 1.0 - smoothstep(0.78, 1.0, uProgress);

  // Wavy seam center line (fissure path meandering slightly in Y)
  float seamOffset = (fbm(vec2(p.x * 0.045, uSeed * 3.1)) - 0.5) * 5.0;
  float distToSeam = abs(p.y - seamOffset);

  // Flame turbulence & licking tongues
  float t = uTime * 4.5;
  vec2 flameUv = vec2(p.x * 0.09 + sin(t * 0.5) * 0.4, p.y * 0.16 - t);
  float flameNoise = fbm(flameUv);
  float flameTurb = fbm(vec2(p.x * 0.18 - t * 0.8, p.y * 0.32 + t * 0.6));

  // Dynamic fiery width based on flame noise
  float activeWidth = (halfWidth + 2.0) * (0.65 + 0.55 * flameTurb) * endTaper;
  if (distToSeam > activeWidth + 4.0) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Seam core, inner flame, outer crust
  float coreRatio = clamp(1.0 - distToSeam / max(1.0, activeWidth * 0.35), 0.0, 1.0);
  float flameRatio = clamp(1.0 - distToSeam / max(1.0, activeWidth), 0.0, 1.0);

  // Discretize flame density into quantized stepped bands
  float heat = flameRatio * 0.5 + coreRatio * 0.5 + (flameNoise - 0.5) * 0.35;
  heat = clamp(heat * fade, 0.0, 1.0);

  if (heat <= 0.08) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Resurrect 64 Brimstone / Magma Palette:
  // Charred scorched crust:  #2e1815
  // Deep sulfur crimson:     #9e2835
  // Searing magma red:       #ea4f36
  // Intense sulfur orange:   #f79617
  // White-hot gold/yellow:   #f9c22b
  // Incandescent flare tip:  #fff4c8
  vec3 crustDark  = vec3(0.180, 0.094, 0.082);
  vec3 magmaDeep  = vec3(0.620, 0.157, 0.208);
  vec3 flameRed   = vec3(0.918, 0.310, 0.212);
  vec3 sulfurGold = vec3(0.969, 0.588, 0.090);
  vec3 coreHot    = vec3(0.976, 0.761, 0.169);
  vec3 tipFlare   = vec3(1.000, 0.957, 0.784);

  vec3 col = crustDark;
  float alpha = 0.0;

  if (heat > 0.78) {
    col = mix(coreHot, tipFlare, (heat - 0.78) / 0.22);
    alpha = 0.96;
  } else if (heat > 0.52) {
    col = mix(sulfurGold, coreHot, (heat - 0.52) / 0.26);
    alpha = 0.90;
  } else if (heat > 0.32) {
    col = mix(flameRed, sulfurGold, (heat - 0.32) / 0.20);
    alpha = 0.82;
  } else if (heat > 0.18) {
    col = mix(magmaDeep, flameRed, (heat - 0.18) / 0.14);
    alpha = 0.65;
  } else {
    col = mix(crustDark, magmaDeep, heat / 0.18);
    alpha = 0.45;
  }

  // Ignition flash along the leading edge
  float edgeDist = abs(abs(p.x) - igniteReach);
  if (uProgress < 0.15 && edgeDist < 6.0) {
    col = mix(col, tipFlare, 1.0 - edgeDist / 6.0);
    alpha = min(1.0, alpha + 0.35);
  }

  alpha *= endTaper * clamp(fade * 1.2, 0.0, 1.0);
  gl_FragColor = vec4(col * alpha, alpha);
}
`;

type BrimstoneSlot = {
  quad: Phaser.GameObjects.Shader;
  progress: number;
  length: number;
  width: number;
  seed: number;
};

const BRIMSTONE_CAP = 8;

export class BrimstoneLineShaderPool {
  private time = 0;
  private slots: BrimstoneSlot[] = [];

  constructor(scene: Phaser.Scene) {
    for (let i = 0; i < BRIMSTONE_CAP; i += 1) {
      const slot: BrimstoneSlot = {
        quad: null as unknown as Phaser.GameObjects.Shader,
        progress: 0,
        length: 150,
        width: 18,
        seed: i * 7.73,
      };

      slot.quad = scene.add
        .shader(
          {
            name: 'BrimstoneLineShader',
            shaderName: 'BrimstoneLineShader',
            fragmentSource: BRIMSTONE_LINE_FRAG,
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
          180,
          48,
        )
        .setDepth(2.05)
        .setVisible(false);

      this.slots.push(slot);
    }
  }

  sync(zones: ZonePool, runTime: number): void {
    this.time = runTime;

    if (getSettings().reduceVfx) {
      for (const slot of this.slots) {
        slot.quad.setVisible(false);
      }
      return;
    }

    let slotIdx = 0;
    for (let i = 0; i < zones.cap && slotIdx < BRIMSTONE_CAP; i += 1) {
      if (zones.alive[i] === 0 || zones.kind[i] !== ZONE_LINE) continue;

      const slot = this.slots[slotIdx];
      slotIdx += 1;

      const duration = zones.duration[i] > 0 ? zones.duration[i] : 2.4;
      const progress = Math.max(0, Math.min(1, 1 - zones.remain[i] / duration));
      const lineLen = zones.length[i];
      const lineWidth = zones.width[i];

      slot.progress = progress;
      slot.length = lineLen;
      slot.width = lineWidth;
      slot.seed = (i + 1) * 11.37;

      const rot = Math.atan2(zones.dirY[i], zones.dirX[i]);
      const quadW = lineLen + 24;
      const quadH = lineWidth + 24;

      slot.quad
        .setSize(quadW, quadH)
        .setOrigin(0.5, 0.5)
        .setPosition(Math.round(zones.x[i]), Math.round(zones.y[i]))
        .setRotation(rot)
        .setVisible(true);
    }

    for (let i = slotIdx; i < BRIMSTONE_CAP; i += 1) {
      this.slots[i].quad.setVisible(false);
    }
  }

  destroy(): void {
    for (const slot of this.slots) {
      slot.quad.destroy();
    }
  }
}
