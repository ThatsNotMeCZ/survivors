export interface CinderCircleController {
  start(): void;
  stop(): void;
  destroy(): void;
}

const ATLAS_SRC = 'sprites/env/atlas.png';
const CINDER_FRAME = { x: 5, y: 720, w: 320, h: 315 };

const VS_SOURCE = `
attribute vec2 a_pos;
varying vec2 v_uv;
void main() {
  v_uv = (a_pos + 1.0) * 0.5;
  v_uv.y = 1.0 - v_uv.y;
  gl_Position = vec4(a_pos, 0.0, 1.0);
}
`;

const FS_SOURCE = `
precision mediump float;
varying vec2 v_uv;
uniform sampler2D u_tex;
uniform float u_time;

vec4 sampleTex(vec2 uv) {
  if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
    return vec4(0.0);
  }
  return texture2D(u_tex, uv);
}

float getEmissive(vec4 col) {
  if (col.a < 0.05) return 0.0;
  // Isolate only hot rune/ember pixels; keep dark stone (r ~= b) at 0.0
  float warmth = max(col.r - col.b * 0.85, 0.0);
  return smoothstep(0.28, 0.68, warmth) * col.a;
}

void main() {
  vec2 center = vec2(0.5);
  vec2 d = v_uv - center;

  // Hypnotic occult slow rotation (~72s period)
  float angle = u_time * 0.087;
  float ca = cos(angle);
  float sa = sin(angle);
  vec2 rotUv = vec2(d.x * ca - d.y * sa, d.x * sa + d.y * ca) + center;

  vec4 base = sampleTex(rotUv);
  float selfEmissive = getEmissive(base);

  // Subtle 16-tap radial bloom around carved runes + outer silhouette halo
  float glowAccum = 0.0;
  float innerBloom = 0.0;
  float rimAlpha = 0.0;

  for (int i = 0; i < 8; i++) {
    float a = float(i) * 0.785398;
    vec2 off1 = vec2(cos(a), sin(a)) * 0.010;
    vec2 off2 = vec2(cos(a + 0.392), sin(a + 0.392)) * 0.026;
    vec2 off3 = vec2(cos(a), sin(a)) * 0.044;

    vec4 s1 = sampleTex(rotUv + off1);
    vec4 s2 = sampleTex(rotUv + off2);
    vec4 s3 = sampleTex(rotUv + off3);

    float e1 = getEmissive(s1);
    float e2 = getEmissive(s2);

    innerBloom += e1;
    glowAccum += e1 * 0.6 + e2 * 0.4;
    rimAlpha += s2.a * 0.5 + s3.a * 0.5;
  }
  innerBloom /= 8.0;
  glowAccum /= 8.0;
  rimAlpha /= 8.0;

  // Slow, subdued ember breathing
  float pulse = 0.84 + 0.16 * sin(u_time * 1.8) + 0.06 * cos(u_time * 3.9);
  glowAccum *= pulse;
  innerBloom *= pulse;

  // Moody outer rim halo outside the stone perimeter
  float outerHalo = max(rimAlpha - base.a, 0.0) * (0.55 + 0.25 * pulse);

  // Dark Hermetic ember palette (deep smoldering crimson -> muted molten amber)
  vec3 deepEmber = vec3(0.52, 0.09, 0.02);
  vec3 smolderOrange = vec3(0.85, 0.32, 0.06);
  vec3 warmGold = vec3(0.95, 0.62, 0.18);

  vec3 glowCol = mix(deepEmber, smolderOrange, clamp(glowAccum * 1.5, 0.0, 1.0));
  glowCol = mix(glowCol, warmGold, clamp(innerBloom * 1.15 - 0.15, 0.0, 1.0));

  // Keep stone and ring dark/moody; let runes smolder and outer rim cast a subtle dark crimson halo
  vec3 tonedBase = vec3(base.r * 0.85, base.g * 0.72, base.b * 0.78);
  vec3 darkStoneRgb = tonedBase * mix(0.65, 0.92, selfEmissive) * base.a;
  float stoneMask = mix(1.0, 0.25, base.a * (1.0 - selfEmissive));
  vec3 runeGlowRgb = glowCol * (glowAccum * 0.42 + selfEmissive * 0.16 * pulse) * stoneMask;
  vec3 haloRgb = mix(deepEmber, smolderOrange, outerHalo * 0.5) * outerHalo * 0.55;

  vec3 finalRgb = darkStoneRgb + runeGlowRgb + haloRgb;
  float finalAlpha = clamp(base.a + glowAccum * 0.38 + outerHalo * 0.65, 0.0, 1.0);

  gl_FragColor = vec4(finalRgb, finalAlpha);
}
`;

function createShader(gl: WebGLRenderingContext, type: number, source: string): WebGLShader | null {
  const shader = gl.createShader(type);
  if (!shader) return null;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    console.warn('[CinderCircle] Shader compile error:', gl.getShaderInfoLog(shader));
    gl.deleteShader(shader);
    return null;
  }
  return shader;
}

export function mountMenuCinderCircle(container: HTMLElement): CinderCircleController {
  const canvas = document.createElement('canvas');
  canvas.className = 'cinder-circle-canvas';
  canvas.width = 512;
  canvas.height = 512;
  canvas.setAttribute('aria-hidden', 'true');
  container.replaceChildren(canvas);

  let gl: WebGLRenderingContext | null = null;
  try {
    gl = canvas.getContext('webgl', {
      alpha: true,
      premultipliedAlpha: true,
      antialias: true,
      preserveDrawingBuffer: true,
    });
  } catch {
    gl = null;
  }

  let running = false;
  let rafId = 0;
  let startTime = 0;
  let destroyed = false;
  let textureReady = false;

  // If WebGL fails, fallback to 2D canvas drawing
  if (!gl) {
    const ctx = canvas.getContext('2d');
    const fallbackImg = new Image();
    fallbackImg.onload = () => {
      if (!ctx || destroyed) return;
      ctx.clearRect(0, 0, 512, 512);
      ctx.drawImage(fallbackImg, CINDER_FRAME.x, CINDER_FRAME.y, CINDER_FRAME.w, CINDER_FRAME.h, 46, 50, 420, 413);
    };
    fallbackImg.src = ATLAS_SRC;
    return {
      start() {},
      stop() {},
      destroy() {
        destroyed = true;
        canvas.remove();
      },
    };
  }

  const vs = createShader(gl, gl.VERTEX_SHADER, VS_SOURCE);
  const fs = createShader(gl, gl.FRAGMENT_SHADER, FS_SOURCE);
  if (!vs || !fs) {
    return {
      start() {},
      stop() {},
      destroy() {
        destroyed = true;
        canvas.remove();
      },
    };
  }

  const program = gl.createProgram();
  if (!program) {
    return {
      start() {},
      stop() {},
      destroy() {
        destroyed = true;
        canvas.remove();
      },
    };
  }

  gl.attachShader(program, vs);
  gl.attachShader(program, fs);
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.warn('[CinderCircle] Program link error:', gl.getProgramInfoLog(program));
    return {
      start() {},
      stop() {},
      destroy() {
        destroyed = true;
        canvas.remove();
      },
    };
  }

  gl.useProgram(program);

  // Quad geometry
  const quadBuf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, quadBuf);
  gl.bufferData(
    gl.ARRAY_BUFFER,
    new Float32Array([
      -1, -1,
       1, -1,
      -1,  1,
      -1,  1,
       1, -1,
       1,  1,
    ]),
    gl.STATIC_DRAW,
  );

  const aPos = gl.getAttribLocation(program, 'a_pos');
  gl.enableVertexAttribArray(aPos);
  gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0);

  const uTex = gl.getUniformLocation(program, 'u_tex');
  const uTime = gl.getUniformLocation(program, 'u_time');
  gl.uniform1i(uTex, 0);

  gl.enable(gl.BLEND);
  gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
  gl.viewport(0, 0, 512, 512);

  // Texture creation
  const texture = gl.createTexture();
  const atlasImg = new Image();
  atlasImg.onload = () => {
    if (destroyed || !gl) return;
    const offscreen = document.createElement('canvas');
    offscreen.width = 512;
    offscreen.height = 512;
    const octx = offscreen.getContext('2d');
    if (octx) {
      // Scale sprite cleanly into 512x512 leaving border for bloom
      const targetW = 420;
      const targetH = (CINDER_FRAME.h / CINDER_FRAME.w) * targetW;
      const ox = (512 - targetW) / 2;
      const oy = (512 - targetH) / 2;
      octx.imageSmoothingEnabled = true;
      octx.drawImage(
        atlasImg,
        CINDER_FRAME.x,
        CINDER_FRAME.y,
        CINDER_FRAME.w,
        CINDER_FRAME.h,
        ox,
        oy,
        targetW,
        targetH,
      );
    }

    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, offscreen);
    textureReady = true;

    // Render initial static frame immediately
    renderFrame(0);
  };
  atlasImg.src = ATLAS_SRC;

  function renderFrame(nowMs: number): void {
    if (!gl || !textureReady || destroyed) return;
    if (startTime === 0) startTime = nowMs;
    const elapsedSec = (nowMs - startTime) / 1000;

    gl.viewport(0, 0, 512, 512);
    gl.useProgram(program);

    gl.bindBuffer(gl.ARRAY_BUFFER, quadBuf);
    gl.enableVertexAttribArray(aPos);
    gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0);

    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.uniform1i(uTex, 0);

    gl.enable(gl.BLEND);
    gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);

    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    gl.uniform1f(uTime, elapsedSec);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }

  function loop(nowMs: number): void {
    if (!running) return;
    renderFrame(nowMs);
    rafId = requestAnimationFrame(loop);
  }

  return {
    start() {
      if (running || destroyed) return;
      running = true;
      rafId = requestAnimationFrame(loop);
    },
    stop() {
      if (!running) return;
      running = false;
      if (rafId) {
        cancelAnimationFrame(rafId);
        rafId = 0;
      }
    },
    destroy() {
      destroyed = true;
      running = false;
      if (rafId) cancelAnimationFrame(rafId);
      if (gl) {
        if (texture) gl.deleteTexture(texture);
        if (quadBuf) gl.deleteBuffer(quadBuf);
        if (program) gl.deleteProgram(program);
      }
      canvas.remove();
    },
  };
}
