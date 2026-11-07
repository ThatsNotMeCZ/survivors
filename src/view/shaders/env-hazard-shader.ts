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

uniform float uTime;
uniform float uStyle;
uniform float uPlayerIn;
uniform float uSeed;
uniform float uFade;

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

// Boiling pixelated bubble burst cell
float bubbleLayer(vec2 p, float speed, float scale, out float bubbleBody, out float bubbleRing, out float bubbleSpec) {
  vec2 sp = p * scale;
  vec2 cell = floor(sp);
  vec2 local = fract(sp) - 0.5;
  vec2 rnd = hash22(cell);

  float lifeTime = fract(uTime * speed + rnd.x * 6.28);
  // Slower swelling, holding form, then snapping/popping
  float grow = sin(clamp(lifeTime / 0.88, 0.0, 1.0) * 3.14159);
  grow = pow(grow, 0.75);
  float radius = grow * (0.34 + rnd.y * 0.14);

  vec2 offset = (rnd - 0.5) * 0.28;
  vec2 diff = local - offset;
  float d = length(diff);

  float active = step(0.05, radius) * step(lifeTime, 0.94);
  bubbleBody = step(d, radius) * active;
  bubbleRing = step(radius - 0.09, d) * bubbleBody;
  
  // Pixel specular highlight on top-left of the bubble
  float specDist = length(diff - vec2(-radius * 0.32, -radius * 0.32));
  bubbleSpec = step(specDist, max(0.04, radius * 0.25)) * bubbleBody * (1.0 - bubbleRing);
  return bubbleBody;
}

void main() {
  // Quantize coordinates to discrete pixel grid for chunky pixel art reading
  const float GRID = 64.0;
  vec2 rawUv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  vec2 uv = (floor(rawUv * GRID) + 0.5) / GRID;
  vec2 p = (uv - 0.5) * 2.0;
  float r = length(p);

  if (r > 1.0) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Slower boil speed
  float boilSpeed = mix(0.18, 0.38, uPlayerIn);
  float animTime = uTime * boilSpeed;

  // Organic fluid mask with stepped perimeter
  float edgeNoise = fbm(p * 2.2 + vec2(sin(animTime * 0.8), cos(animTime * 0.6)) * 0.35);
  float poolR = 0.90 + (edgeNoise - 0.5) * 0.16;
  float poolMask = smoothstep(poolR, poolR - 0.16, r);

  if (poolMask <= 0.01) {
    gl_FragColor = vec4(0.0);
    return;
  }

  // Multi-frequency surface turbulence (slow, heavy flow)
  vec2 flow = vec2(
    fbm(p * 1.5 + vec2(animTime * 0.22, -animTime * 0.18)),
    fbm(p * 1.5 + vec2(-animTime * 0.18, animTime * 0.22))
  );
  float surface = fbm(p * 2.2 + flow * 1.2);

  // Large pixelated surface bubbles
  float b1Body, b1Ring, b1Spec;
  float b2Body, b2Ring, b2Spec;
  bubbleLayer(p + flow * 0.10, mix(0.14, 0.28, uPlayerIn), 2.3, b1Body, b1Ring, b1Spec);
  bubbleLayer(p - flow * 0.12 + vec2(17.3, 41.2), mix(0.18, 0.34, uPlayerIn), 3.2, b2Body, b2Ring, b2Spec);

  float totalBubbleBody = clamp(b1Body + b2Body, 0.0, 1.0);
  float totalBubbleRing = clamp(b1Ring + b2Ring, 0.0, 1.0);
  float totalBubbleSpec = clamp(b1Spec + b2Spec, 0.0, 1.0);

  // Rising vapor wisps (slow, lazy drift)
  float vaporSway = sin(uv.y * 4.0 - uTime * (0.35 + uPlayerIn * 0.25)) * 0.08;
  vec2 vaporCoord = vec2(p.x * 1.6 + vaporSway, (uv.y - 0.4) * 2.0 - uTime * (0.24 + uPlayerIn * 0.20));
  float vaporNoise = fbm(vaporCoord);
  float vaporMask = smoothstep(0.46, 0.82, vaporNoise) * smoothstep(0.12, 0.55, uv.y) * smoothstep(1.0, 0.70, r);
  float vaporAlpha = vaporMask * mix(0.32, 0.58, uPlayerIn);

  vec3 col = vec3(0.0);
  float alpha = 0.0;

  if (uStyle > 1.5) {
    // Style 2: Glacial Crevasse (Freezing cyan brine + crystalline ice glints)
    vec3 deepIce = vec3(0.08, 0.28, 0.52);
    vec3 brightCyan = vec3(0.32, 0.88, 1.0);
    vec3 hotGlint = vec3(0.92, 0.98, 1.0);

    vec3 fluid = mix(deepIce, brightCyan, surface);
    fluid = mix(fluid, brightCyan * 1.2, totalBubbleBody);
    fluid = mix(fluid, deepIce * 0.6, totalBubbleRing);
    fluid = mix(fluid, hotGlint, totalBubbleSpec);

    vec3 vaporCol = mix(brightCyan, hotGlint, vaporNoise);
    col = mix(fluid, vaporCol, vaporAlpha * 0.55);
    alpha = clamp((surface * 0.52 + totalBubbleBody * 0.75 + vaporAlpha) * poolMask, 0.0, 0.88);
  } else if (uStyle > 0.5) {
    // Style 1: Rime Brine / Noxious Caustic Acid Pool (Bubbling toxic green-cyan + caustic vapor)
    // Resurrect 64 green tones: #239063, #1ebc73, #91db69, #cdff82
    vec3 deepBrine = vec3(0.086, 0.353, 0.298);    // #165a4c
    vec3 causticGreen = vec3(0.118, 0.737, 0.451); // #1ebc73
    vec3 neonAcid = vec3(0.569, 0.859, 0.412);     // #91db69
    vec3 acidSpec = vec3(0.804, 0.875, 0.424);     // #cdff82

    vec3 fluid = mix(deepBrine, causticGreen, surface);
    fluid = mix(fluid, neonAcid, totalBubbleBody);
    fluid = mix(fluid, deepBrine * 0.7, totalBubbleRing);
    fluid = mix(fluid, acidSpec, totalBubbleSpec);

    vec3 steamCol = mix(causticGreen, neonAcid, vaporNoise);
    col = mix(fluid, steamCol, vaporAlpha * 0.5);

    // Dynamic sizzle flash when player is in the pool (slow pulse)
    float sizzle = uPlayerIn * (0.5 + 0.5 * sin(uTime * 3.5)) * 0.20;
    col += neonAcid * sizzle;

    alpha = clamp((surface * 0.58 + totalBubbleBody * 0.82 + vaporAlpha + sizzle) * poolMask, 0.0, 0.92);
  } else {
    // Style 0: Cinder Slag Fissure (Molten magma crust + lava-colored bubbles from Resurrect 64)
    // Resurrect 64 lava colors:
    // Crust/dark basalt: #2e1815 vec3(0.180, 0.094, 0.082)
    // Deep magma fluid:  #ea4f36 vec3(0.918, 0.310, 0.212)
    // Bubble body lava:  #fb6b1d vec3(0.984, 0.420, 0.114)
    // Bubble magma ring: #f79617 vec3(0.969, 0.588, 0.090)
    // Bubble hot spec:   #f9c22b vec3(0.976, 0.761, 0.169)
    vec3 crust = vec3(0.180, 0.094, 0.082);
    vec3 magmaDeep = vec3(0.918, 0.310, 0.212);
    vec3 lavaBubble = vec3(0.984, 0.420, 0.114);
    vec3 lavaRing = vec3(0.969, 0.588, 0.090);
    vec3 lavaSpec = vec3(0.976, 0.761, 0.169);

    float heatVeins = step(0.48, surface);
    vec3 fluid = mix(crust, magmaDeep, surface);
    fluid = mix(fluid, lavaBubble, heatVeins * 0.65);

    // Lava bubbles with rich orange/red body, molten ring, and gold spec
    fluid = mix(fluid, lavaBubble, totalBubbleBody);
    fluid = mix(fluid, lavaRing, totalBubbleRing);
    fluid = mix(fluid, lavaSpec, totalBubbleSpec);

    vec3 heatHazeCol = mix(magmaDeep, lavaBubble, vaporNoise);
    col = mix(fluid, heatHazeCol, vaporAlpha * 0.42);

    float boilSpark = uPlayerIn * (0.5 + 0.5 * sin(uTime * 3.5)) * 0.18;
    col += lavaRing * boilSpark;

    alpha = clamp((surface * 0.62 + totalBubbleBody * 0.85 + vaporAlpha + boilSpark) * poolMask, 0.0, 0.92);
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
      };

      slot.quad = scene.add
        .shader(
          {
            name: 'EnvHazardShader',
            shaderName: 'EnvHazardShader',
            fragmentSource: ENV_HAZARD_FRAG,
            setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
              setUniform('uTime', this.time);
              setUniform('uStyle', slot.style);
              setUniform('uPlayerIn', slot.playerIn);
              setUniform('uSeed', slot.seed);
              setUniform('uFade', slot.fade);
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

      const size = Math.round(obs.radius * 2.85);
      slot.quad
        .setSize(size, size)
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
