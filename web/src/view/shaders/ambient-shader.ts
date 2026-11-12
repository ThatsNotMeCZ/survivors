import Phaser from 'phaser';
import type { BiomeId } from '../procedural-pixel-art';

const AMBIENT_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform float uTime;
uniform float uBiome;
uniform vec2 uViewOrigin;
uniform vec2 uViewSize;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
  float n = hash21(p);
  return vec2(n, hash21(p + n + 19.19));
}

float valueNoise(vec2 p) {
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
  v += 0.55 * valueNoise(p);
  v += 0.30 * valueNoise(p * 2.07 + vec2(13.1, 7.7));
  v += 0.15 * valueNoise(p * 4.13 + vec2(3.7, 29.3));
  return v;
}

float particleLayer(vec2 worldPos, float cellSize, vec2 vel, float radius, float seed, float pulseSpeed) {
  vec2 p = (worldPos + vel * uTime) / cellSize;
  vec2 cell = floor(p);
  vec2 local = fract(p) - 0.5;
  vec2 rnd = hash22(cell + seed);
  if (rnd.x < 0.68) return 0.0;
  vec2 offset = (rnd - 0.5) * 0.62;
  offset.x += sin(uTime * pulseSpeed + rnd.y * 6.2831) * 0.12;
  float d = length(local - offset);
  float core = smoothstep(radius, radius * 0.15, d);
  float twinkle = 0.65 + 0.35 * sin(uTime * (pulseSpeed * 1.4) + rnd.x * 12.0);
  return core * twinkle;
}

void main() {
  vec2 uv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  vec2 worldPos = uViewOrigin + uv * uViewSize;

  vec2 qWorld = worldPos;

  // Ground mist / kiln smoke (FBM)
  vec2 mistDrift = uBiome < 0.5 ? vec2(-14.0, -9.0) : vec2(18.0, 11.0);
  float mist1 = fbm((qWorld + mistDrift * uTime) * 0.0045);
  float mist2 = fbm((qWorld - mistDrift * 0.6 * uTime + vec2(91.0, 43.0)) * 0.008);
  float mist = smoothstep(0.46, 0.78, mist1 * 0.65 + mist2 * 0.35);

  vec3 col = vec3(0.0);
  float alpha = 0.0;

  if (uBiome < 0.5) {
    // Cinder Yard: warm ash haze + drifting ash + rising glowing embers
    vec3 smokeCol = vec3(0.24, 0.11, 0.08);
    float smokeA = mist * 0.14;
    col += smokeCol * smokeA;
    alpha += smokeA;

    float ash = particleLayer(qWorld, 115.0, vec2(13.0, -11.0), 0.052, 11.3, 1.6)
              + particleLayer(qWorld, 165.0, vec2(9.0, -7.0), 0.042, 37.9, 1.2) * 0.65;
    vec3 ashCol = vec3(0.58, 0.49, 0.44);
    float ashA = clamp(ash, 0.0, 1.0) * 0.34;
    col += ashCol * ashA;
    alpha += ashA;

    float ember = particleLayer(qWorld, 140.0, vec2(5.0, 24.0), 0.060, 73.1, 3.2)
                + particleLayer(qWorld, 200.0, vec2(-7.0, 31.0), 0.050, 109.7, 2.7);
    float emberClamped = clamp(ember, 0.0, 1.0);
    vec3 emberCol = mix(vec3(1.0, 0.38, 0.12), vec3(1.0, 0.88, 0.45), emberClamped);
    float emberA = emberClamped * 0.62;
    col += emberCol * emberA;
    alpha += emberA;
  } else {
    // Rime Dock / Glacial Tomb: cold brine fog + wind-driven snow + ice glints
    vec3 fogCol = vec3(0.32, 0.62, 0.84);
    float fogA = mist * 0.16;
    col += fogCol * fogA;
    alpha += fogA;

    float snow1 = particleLayer(qWorld, 110.0, vec2(-22.0, -18.0), 0.052, 19.7, 1.8);
    float snow2 = particleLayer(qWorld, 160.0, vec2(-15.0, -13.0), 0.045, 53.4, 1.3);
    float snow = clamp(snow1 + snow2 * 0.8, 0.0, 1.0);
    vec3 snowCol = vec3(0.86, 0.95, 1.0);
    float snowA = snow * 0.42;
    col += snowCol * snowA;
    alpha += snowA;

    float glint = particleLayer(qWorld, 185.0, vec2(-9.0, -6.0), 0.040, 141.2, 4.0);
    vec3 glintCol = vec3(0.55, 0.92, 1.0);
    float glintA = clamp(glint, 0.0, 1.0) * 0.50;
    col += glintCol * glintA;
    alpha += glintA;
  }

  alpha = clamp(alpha, 0.0, 0.78);
  gl_FragColor = vec4(col, alpha);
}
`;

export class AmbientShader {
  private quad: Phaser.GameObjects.Shader;
  private time = 0;
  private biomeVal = 0;
  private viewOrigin: [number, number] = [0, 0];
  private viewSize: [number, number] = [800, 450];

  constructor(scene: Phaser.Scene) {
    this.quad = scene.add
      .shader(
        {
          name: 'AmbientAtmosphereShader',
          shaderName: 'AmbientAtmosphereShader',
          fragmentSource: AMBIENT_FRAG,
          setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
            setUniform('uTime', this.time);
            setUniform('uBiome', this.biomeVal);
            setUniform('uViewOrigin', this.viewOrigin);
            setUniform('uViewSize', this.viewSize);
          },
        },
        0,
        0,
        128,
        128,
      )
      .setDepth(8);
  }

  sync(camera: Phaser.Cameras.Scene2D.Camera, runTime: number, biome: BiomeId): void {
    const view = camera.worldView;
    const pad = 16;
    const w = Math.max(64, view.width + pad * 2);
    const h = Math.max(64, view.height + pad * 2);
    this.time = runTime;
    this.biomeVal = biome === 'cinder' ? 0.0 : 1.0;
    this.viewOrigin[0] = view.x - pad;
    this.viewOrigin[1] = view.y - pad;
    this.viewSize[0] = w;
    this.viewSize[1] = h;
    this.quad.setSize(w, h);
    this.quad.setOrigin(0.5, 0.5);
    this.quad.setPosition(view.centerX, view.centerY);
  }
}
