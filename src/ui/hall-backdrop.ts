import { createFullscreenProgram, type GlProgramHelper } from './gl-canvas';

export interface HallBackdropController {
  start(): void;
  stop(): void;
  destroy(): void;
  updateStage(stageElement: HTMLElement | null, locked: boolean): void;
}

const HALL_FS = `
precision mediump float;

varying vec2 v_uv;
uniform vec2 u_res;
uniform vec2 u_center; // Stage/pedestal center in pixel coordinates
uniform float u_time;
uniform float u_locked;

// Pseudo-random & noise utilities
float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
    u.y
  );
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  vec2 shift = vec2(100.0);
  mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
  for (int i = 0; i < 4; i++) {
    v += a * noise(p);
    p = rot * p * 2.02 + shift;
    a *= 0.5;
  }
  return v;
}

// Procedural occult sigil circle on the floor
float sigilRings(vec2 p, float t) {
  float r = length(p);
  if (r > 1.25 || r < 0.02) return 0.0;

  float ring1 = smoothstep(0.025, 0.002, abs(r - 0.98));
  float ring2 = smoothstep(0.020, 0.002, abs(r - 0.90));
  float ring3 = smoothstep(0.016, 0.002, abs(r - 0.68));
  float ring4 = smoothstep(0.014, 0.002, abs(r - 0.44));
  float ring5 = smoothstep(0.016, 0.002, abs(r - 0.16));

  float angle = atan(p.y, p.x);

  // Rotating rune ticks on outer band
  float ticks1 = smoothstep(0.65, 0.95, cos((angle + t * 0.06) * 36.0)) * smoothstep(0.08, 0.0, abs(r - 0.94));
  // Rotating inner radial divisions
  float ticks2 = smoothstep(0.80, 0.98, cos((angle - t * 0.09) * 12.0)) * smoothstep(0.14, 0.0, abs(r - 0.56));
  // Hermetic triangle / geometric lines
  float triAngle = angle + t * 0.04;
  float geom = smoothstep(0.85, 0.99, cos(triAngle * 3.0)) * smoothstep(0.20, 0.0, abs(r - 0.44));

  float glowBase = ring1 * 1.0 + ring2 * 0.75 + ring3 * 0.85 + ring4 * 0.70 + ring5 * 0.55;
  return glowBase + ticks1 * 0.85 + ticks2 * 0.70 + geom * 0.60;
}

// Procedural rising embers/sparks
float embers(vec2 uv, float t) {
  float acc = 0.0;
  for (int i = 0; i < 24; i++) {
    float fi = float(i);
    float speed = 0.10 + fract(fi * 0.317) * 0.16;
    float seedX = fract(fi * 0.618);
    float x = (seedX - 0.5) * 0.85 + sin(t * 1.4 + fi * 2.3) * 0.05;
    float y = fract(0.95 - (t * speed + fract(fi * 0.733))) * 1.15 - 0.1;

    vec2 pos = vec2(x, y);
    float dist = length(uv - pos);
    float spark = smoothstep(0.035, 0.002, dist);
    float flicker = 0.55 + 0.45 * sin(t * 8.5 + fi * 4.7);
    float life = smoothstep(0.95, 0.45, y) * smoothstep(-0.05, 0.2, y);
    acc += spark * flicker * life;
  }
  return acc;
}

void main() {
  vec2 res = max(u_res, vec2(1.0, 1.0));
  vec2 p = (gl_FragCoord.xy - res * 0.5) / min(res.x, res.y);

  // Pedestal center in screen aspect-corrected coordinates
  vec2 centerNorm = (u_center - res * 0.5) / min(res.x, res.y);
  vec2 stageCoord = p - centerNorm;

  // 1. Deep Atmospheric Dark Base
  vec3 bgDeep = vec3(0.065, 0.048, 0.080);
  vec3 bgVoid = vec3(0.020, 0.015, 0.025);
  vec3 col = mix(bgDeep, bgVoid, length(p) * 0.9);

  // 2. Slow Domain-Warped Aetheric Smoke / Fog
  vec2 fogUv = p * 1.5;
  fogUv.y += u_time * 0.03;
  vec2 warp = vec2(
    fbm(fogUv + vec2(0.0, u_time * 0.035)),
    fbm(fogUv + vec2(5.2, u_time * 0.025))
  );
  float smoke = fbm(fogUv + warp * 1.3);
  float centerFalloff = smoothstep(1.3, 0.1, length(stageCoord));
  smoke *= (0.4 + 0.6 * centerFalloff);

  vec3 smokeCold = vec3(0.18, 0.13, 0.25);
  vec3 smokeWarm = mix(vec3(0.36, 0.18, 0.08), vec3(0.10, 0.14, 0.20), u_locked);
  col += mix(smokeCold, smokeWarm, smoke * 0.7) * smoke * 0.55;

  // 3. Volumetric Occult Light Cone / God-Ray falling onto pedestal
  vec2 rayUv = stageCoord;
  float coneWidth = 0.32 + (1.0 - rayUv.y) * 0.26;
  float inCone = smoothstep(coneWidth, 0.0, abs(rayUv.x));
  float rayVertical = smoothstep(-0.65, 0.85, rayUv.y);
  float rayNoise = noise(vec2(rayUv.x * 5.0, rayUv.y * 2.0 - u_time * 0.18));
  float beam = inCone * rayVertical * (0.60 + 0.40 * rayNoise);
  vec3 beamColor = mix(vec3(0.32, 0.25, 0.16), vec3(0.14, 0.16, 0.24), u_locked);
  col += beamColor * beam * 0.38;

  // 4. Perspective-Squashed Transmutation Seal (Floor Pedestal)
  vec2 floorCoord = stageCoord;
  floorCoord.y += 0.24; // under vessel feet
  floorCoord.y *= 2.8;  // perspective compression

  float sigilTime = u_time * (1.0 - u_locked * 0.7);
  float sigilMask = sigilRings(floorCoord * 2.3, sigilTime);

  float sealDist = length(floorCoord * 2.3);
  float sealGlow = smoothstep(1.4, 0.1, sealDist) * 0.35;

  vec3 brassCol = vec3(0.86, 0.72, 0.38);
  vec3 emberCol = vec3(0.92, 0.42, 0.12);
  vec3 lockedSigilCol = vec3(0.28, 0.34, 0.44);

  float sigilBlink = 0.80 + 0.20 * sin(u_time * 1.2);
  vec3 activeSigilColor = mix(emberCol, brassCol, 0.65) * sigilBlink;
  vec3 sigilColor = mix(activeSigilColor, lockedSigilCol, u_locked);

  col += sigilColor * sigilMask * (0.95 - u_locked * 0.45);
  col += mix(emberCol * 0.4, lockedSigilCol * 0.20, u_locked) * sealGlow;

  // 5. Rising Embers / Occult Cinders
  if (u_locked < 0.95) {
    vec2 emberCoord = stageCoord;
    emberCoord.y += 0.18;
    float emb = embers(emberCoord, u_time);
    vec3 emberTint = vec3(0.98, 0.52, 0.14);
    col += emberTint * emb * 0.95;
  }

  // 6. Deep Vignette & Dark Hermetic Grade
  float edgeDist = length(p);
  float vignette = smoothstep(1.5, 0.4, edgeDist);
  col *= vignette;

  // Micro film-grain to prevent 8-bit banding on dark gradients
  float grain = (hash(gl_FragCoord.xy + fract(u_time)) - 0.5) * 0.025;
  col += grain;

  col = clamp(col, 0.0, 1.0);
  gl_FragColor = vec4(col, 1.0);
}
`;

export function mountHallBackdrop(container: HTMLElement): HallBackdropController {
  const canvas = document.createElement('canvas');
  canvas.className = 'hall-backdrop-canvas';
  canvas.setAttribute('aria-hidden', 'true');
  container.replaceChildren(canvas);

  let currentStageEl: HTMLElement | null = null;
  let isLocked = false;

  const motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
  let reducedMotion = motionQuery.matches;
  motionQuery.addEventListener('change', (e) => {
    reducedMotion = e.matches;
  });

  let uResLoc: WebGLUniformLocation | null = null;
  let uCenterLoc: WebGLUniformLocation | null = null;
  let uTimeLoc: WebGLUniformLocation | null = null;
  let uLockedLoc: WebGLUniformLocation | null = null;

  const helper: GlProgramHelper | null = createFullscreenProgram(canvas, HALL_FS, {
    dprCap: 1.25,
    alpha: false,
    onRender(time, gl, w, h) {
      if (!uResLoc && helper) {
        uResLoc = helper.getUniformLocation('u_res');
        uCenterLoc = helper.getUniformLocation('u_center');
        uTimeLoc = helper.getUniformLocation('u_time');
        uLockedLoc = helper.getUniformLocation('u_locked');
      }

      if (uResLoc) gl.uniform2f(uResLoc, w, h);

      // Compute stage center coordinates in canvas pixels
      let cx = w * 0.48;
      let cy = h * 0.45;
      if (currentStageEl) {
        const rect = currentStageEl.getBoundingClientRect();
        const canvasRect = canvas.getBoundingClientRect();
        if (canvasRect.width > 0 && canvasRect.height > 0 && rect.width > 0) {
          const scaleX = w / canvasRect.width;
          const scaleY = h / canvasRect.height;
          cx = (rect.left + rect.width * 0.5 - canvasRect.left) * scaleX;
          const stageBottom = (rect.bottom - rect.height * 0.32 - canvasRect.top) * scaleY;
          cy = h - stageBottom;
        }
      }

      if (uCenterLoc) gl.uniform2f(uCenterLoc, cx, cy);
      if (uTimeLoc) gl.uniform1f(uTimeLoc, reducedMotion ? 1.0 : time);
      if (uLockedLoc) gl.uniform1f(uLockedLoc, isLocked ? 1.0 : 0.0);
    },
  });

  return {
    start() {
      helper?.start();
    },
    stop() {
      helper?.stop();
    },
    destroy() {
      helper?.destroy();
      canvas.remove();
    },
    updateStage(stageElement: HTMLElement | null, locked: boolean) {
      currentStageEl = stageElement;
      isLocked = locked;
    },
  };
}
