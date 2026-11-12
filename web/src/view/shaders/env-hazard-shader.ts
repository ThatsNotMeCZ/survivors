import Phaser from 'phaser';
import { getSettings } from '../../ui/settings';
import type { BiomeId } from '../procedural-pixel-art';

const ENV_HAZARD_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform sampler2D uMainSampler;
uniform float uTime;
uniform float uStyle;
uniform float uPlayerIn;
uniform float uSeed;
uniform float uFade;
uniform vec4 uFrameRect; // u0, v0, u1, v1
uniform float uHasTex;

float hash21(vec2 p) {
  p = fract(p * vec2(127.1, 311.7) + uSeed * 17.31);
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
  v += 0.52 * vnoise(p);
  v += 0.31 * vnoise(p * 2.08 + vec2(13.1, 7.7));
  v += 0.17 * vnoise(p * 4.15 + vec2(3.7, 29.3));
  return v;
}

// Micro-bubble cell confined inside fluid channels
float microBubble(vec2 p, float speed, float scale) {
  vec2 sp = p * scale;
  vec2 cell = floor(sp);
  vec2 local = fract(sp) - 0.5;
  vec2 rnd = hash22(cell);

  float lifeTime = fract(uTime * speed + rnd.x * 6.28);
  float grow = sin(clamp(lifeTime / 0.85, 0.0, 1.0) * 3.14159);
  float radius = grow * (0.16 + rnd.y * 0.12);

  vec2 offset = (rnd - 0.5) * 0.35;
  float d = length(local - offset);
  return step(d, radius) * step(0.04, radius) * step(lifeTime, 0.92);
}

void main() {
  // Discrete 64x64 grid matching native pixel art resolution
  const float GRID = 64.0;
  vec2 rawUv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  vec2 uv = (floor(rawUv * GRID) + 0.5) / GRID;
  vec2 p = (uv - 0.5) * 2.0;
  float r = length(p);

  vec2 atlasUv = mix(uFrameRect.xy, uFrameRect.zw, clamp(uv, 0.0, 1.0));
  vec4 baseTex = uHasTex > 0.5 ? texture2D(uMainSampler, atlasUv) : vec4(0.0);

  // If we have an authored sprite, isolate ONLY the molten/liquid interior
  // Dark rocky rim, cracks in stone, and exterior transparent pixels must stay 100% unaffected.
  float liquidMask = 0.0;
  if (uHasTex > 0.5) {
    if (baseTex.a < 0.2) {
      gl_FragColor = vec4(0.0);
      return;
    }
    if (uStyle < 0.5) {
      // Cinder molten core: strong red/orange, low blue, not dark rock
      float warmth = baseTex.r - baseTex.b;
      float brightness = max(baseTex.r, baseTex.g);
      liquidMask = smoothstep(0.20, 0.42, warmth) * step(0.26, brightness);
    } else {
      // Rime / Acid green-cyan pool: green dominance over red
      float greenHue = baseTex.g - baseTex.r * 0.75;
      liquidMask = smoothstep(0.08, 0.28, greenHue) * step(0.24, baseTex.g);
    }
  } else {
    // Procedural fallback mask if no texture attached
    float edgeNoise = fbm(p * 2.2);
    liquidMask = smoothstep(0.78, 0.62, r + (edgeNoise - 0.5) * 0.15);
  }

  if (liquidMask <= 0.02) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Slow, subtle surface flow
  float flowSpeed = mix(0.12, 0.22, uPlayerIn);
  vec2 flow = vec2(
    fbm(p * 2.0 + vec2(uTime * flowSpeed, -uTime * flowSpeed * 0.8)),
    fbm(p * 2.0 + vec2(-uTime * flowSpeed * 0.8, uTime * flowSpeed))
  );
  float surface = fbm(p * 3.0 + flow * 0.8);

  // Tiny discrete 1-2px boiling specks / micro-bubbles
  float micro1 = microBubble(p + flow * 0.1, mix(0.18, 0.32, uPlayerIn), 7.0);
  float micro2 = microBubble(p - flow * 0.12 + vec2(13.7, 29.1), mix(0.22, 0.38, uPlayerIn), 9.0);
  float microTotal = clamp(micro1 + micro2, 0.0, 1.0);

  vec3 col = vec3(0.0);
  float alpha = 0.0;

  if (uStyle > 1.5) {
    // Style 2: Glacial Crevasse (Freezing cyan brine + crystalline ice glints)
    vec3 deepCyan = vec3(0.12, 0.55, 0.85);
    vec3 brightCyan = vec3(0.45, 0.92, 1.0);
    vec3 hotGlint = vec3(0.92, 0.98, 1.0);

    vec3 fluid = mix(deepCyan, brightCyan, surface);
    fluid = mix(fluid, hotGlint, microTotal * 0.85);

    col = fluid;
    alpha = clamp((0.35 + surface * 0.30 + microTotal * 0.35) * liquidMask, 0.0, 0.65);
  } else if (uStyle > 0.5) {
    // Style 1: Rime Caustic Acid Pool (Bubbling toxic emerald & lime)
    vec3 causticGreen = vec3(0.118, 0.737, 0.451); // #1ebc73
    vec3 neonAcid = vec3(0.569, 0.859, 0.412);     // #91db69
    vec3 acidSpec = vec3(0.804, 0.875, 0.424);     // #cdff82

    vec3 fluid = mix(causticGreen, neonAcid, surface);
    fluid = mix(fluid, acidSpec, microTotal * 0.9);

    float sizzle = uPlayerIn * (0.5 + 0.5 * sin(uTime * 3.5)) * 0.20;
    col = fluid + acidSpec * sizzle;
    alpha = clamp((0.38 + surface * 0.30 + microTotal * 0.32 + sizzle) * liquidMask, 0.0, 0.68);
  } else {
    // Style 0: Cinder Molten Core (Warm glowing lava veins + golden micro-sparks)
    vec3 magmaDeep = vec3(0.918, 0.310, 0.212);  // #ea4f36
    vec3 lavaEmber = vec3(0.969, 0.588, 0.090);  // #f79617
    vec3 lavaGlint = vec3(0.976, 0.761, 0.169);  // #f9c22b

    vec3 fluid = mix(magmaDeep, lavaEmber, surface);
    fluid = mix(fluid, lavaGlint, microTotal * 0.85);

    float simmer = uPlayerIn * (0.5 + 0.5 * sin(uTime * 3.2)) * 0.18;
    col = fluid + lavaGlint * simmer;
    alpha = clamp((0.36 + surface * 0.32 + microTotal * 0.32 + simmer) * liquidMask, 0.0, 0.68);
  }

  alpha *= clamp(uFade, 0.0, 1.0);
  gl_FragColor = vec4(col * alpha, alpha);
}
`;

type EnvHazardSlot = {
  quad: Phaser.GameObjects.Shader;
  style: number;
  playerIn: number;
  seed: number;
  fade: number;
  frameRect: [number, number, number, number];
  hasTex: number;
};

const HAZARD_SHADER_CAP = 16;

export class EnvHazardShaderPool {
  private time = 0;
  private slots: EnvHazardSlot[] = [];

  constructor(scene: Phaser.Scene) {
    for (let i = 0; i < HAZARD_SHADER_CAP; i += 1) {
      const slot: EnvHazardSlot = {
        quad: null as unknown as Phaser.GameObjects.Shader,
        style: 0,
        playerIn: 0,
        seed: i * 7.13,
        fade: 1.0,
        frameRect: [0, 0, 1, 1],
        hasTex: 0,
      };

      slot.quad = scene.add
        .shader(
          {
            name: 'EnvHazardShader',
            shaderName: 'EnvHazardShader',
            fragmentSource: ENV_HAZARD_FRAG,
            setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
              setUniform('uMainSampler', 0);
              setUniform('uTime', this.time);
              setUniform('uStyle', slot.style);
              setUniform('uPlayerIn', slot.playerIn);
              setUniform('uSeed', slot.seed);
              setUniform('uFade', slot.fade);
              setUniform('uFrameRect', slot.frameRect);
              setUniform('uHasTex', slot.hasTex);
            },
          },
          0,
          0,
          128,
          128,
        )
        .setDepth(1.10)
        .setVisible(false);

      this.slots.push(slot);
    }
  }

  sync(
    obstacles: {
      cap: number;
      alive: Uint8Array;
      items: Array<{
        type: string;
        x: number;
        y: number;
        radius: number;
        timer?: number;
      }>;
    },
    obstacleSprites: Phaser.GameObjects.Image[],
    playerX: number,
    playerY: number,
    playerRadius: number,
    biome: BiomeId,
    theme: string,
    runTime: number,
    dt: number,
  ): void {
    this.time = runTime;

    if (getSettings().reduceVfx) {
      for (const slot of this.slots) {
        slot.quad.setVisible(false);
      }
      return;
    }

    const defaultStyle = theme === 'glacial' ? 2 : biome === 'rime' ? 1 : 0;
    let used = 0;

    for (let i = 0; i < obstacles.cap && used < HAZARD_SHADER_CAP; i += 1) {
      if (obstacles.alive[i] === 0) continue;
      const obs = obstacles.items[i];
      if (obs.type !== 'hazard') continue;

      const slot = this.slots[used];
      const sprite = obstacleSprites[i];
      used += 1;

      // Check if player is currently standing inside this hazard
      const dist = Math.hypot(playerX - obs.x, playerY - obs.y);
      const isPlayerInside = dist <= obs.radius + playerRadius;

      // If this is a timed dynamic hazard (noxious acid pool), use caustic acid style 1
      const isTimed = (obs.timer ?? 0) > 0;
      slot.style = isTimed ? 1 : defaultStyle;
      slot.fade = isTimed ? Math.min(1.0, (obs.timer ?? 1.0) / 1.0) : 1.0;
      slot.seed = (i + 1) * 13.37;

      const targetPlayerIn = isPlayerInside ? 1.0 : 0.0;
      slot.playerIn += (targetPlayerIn - slot.playerIn) * Math.min(1.0, dt * 8.0);

      if (sprite && sprite.texture && sprite.frame) {
        if (slot.quad.textures.length === 0 || slot.quad.textures[0] !== sprite.texture) {
          slot.quad.setTextures([sprite.texture]);
        }
        slot.hasTex = 1.0;
        slot.frameRect[0] = sprite.frame.u0;
        slot.frameRect[1] = sprite.frame.v0;
        slot.frameRect[2] = sprite.frame.u1;
        slot.frameRect[3] = sprite.frame.v1;
      } else {
        slot.hasTex = 0.0;
      }

      // Exact match with underlying sprite diameter so no oversized overlap occurs
      const diameter = Math.round(obs.radius * 2);
      slot.quad
        .setSize(diameter, diameter)
        .setOrigin(0.5, 0.5)
        .setPosition(Math.round(obs.x), Math.round(obs.y))
        .setVisible(true);
    }

    for (let i = used; i < HAZARD_SHADER_CAP; i += 1) {
      this.slots[i].quad.setVisible(false);
      this.slots[i].playerIn = 0;
      this.slots[i].fade = 1.0;
    }
  }
}
