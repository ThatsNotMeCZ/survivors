export interface GlProgramHelper {
  gl: WebGLRenderingContext;
  program: WebGLProgram;
  canvas: HTMLCanvasElement;
  start(): void;
  stop(): void;
  destroy(): void;
  getUniformLocation(name: string): WebGLUniformLocation | null;
}

export interface GlCanvasOptions {
  dprCap?: number;
  alpha?: boolean;
  onResize?: (width: number, height: number, gl: WebGLRenderingContext) => void;
  onRender?: (time: number, gl: WebGLRenderingContext, width: number, height: number) => void;
}

const FULLSCREEN_VS = `
attribute vec2 a_pos;
varying vec2 v_uv;
void main() {
  v_uv = (a_pos + 1.0) * 0.5;
  v_uv.y = 1.0 - v_uv.y;
  gl_Position = vec4(a_pos, 0.0, 1.0);
}
`;

export function compileShader(
  gl: WebGLRenderingContext,
  type: number,
  source: string,
): WebGLShader | null {
  const shader = gl.createShader(type);
  if (!shader) return null;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    console.warn('[GlCanvas] Shader compile error:', gl.getShaderInfoLog(shader));
    gl.deleteShader(shader);
    return null;
  }
  return shader;
}

export function createFullscreenProgram(
  canvas: HTMLCanvasElement,
  fsSource: string,
  options: GlCanvasOptions = {},
): GlProgramHelper | null {
  const dprCap = options.dprCap ?? 1.25;
  let gl: WebGLRenderingContext | null = null;
  try {
    gl = canvas.getContext('webgl', {
      alpha: options.alpha ?? true,
      premultipliedAlpha: true,
      antialias: false,
      depth: false,
      stencil: false,
      powerPreference: 'high-performance',
    });
  } catch {
    gl = null;
  }

  if (!gl) return null;

  const vs = compileShader(gl, gl.VERTEX_SHADER, FULLSCREEN_VS);
  const fs = compileShader(gl, gl.FRAGMENT_SHADER, fsSource);
  if (!vs || !fs) return null;

  const program = gl.createProgram();
  if (!program) return null;

  gl.attachShader(program, vs);
  gl.attachShader(program, fs);
  gl.linkProgram(program);

  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.warn('[GlCanvas] Link error:', gl.getProgramInfoLog(program));
    gl.deleteProgram(program);
    return null;
  }

  gl.useProgram(program);

  // Fullscreen quad
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
  if (aPos >= 0) {
    gl.enableVertexAttribArray(aPos);
    gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0);
  }

  let running = false;
  let rafId = 0;
  let startTime = 0;
  let destroyed = false;

  const resize = () => {
    if (!gl || destroyed) return;
    const dpr = Math.min(window.devicePixelRatio || 1, dprCap);
    const rect = canvas.getBoundingClientRect();
    const w = Math.max(1, Math.floor(rect.width * dpr));
    const h = Math.max(1, Math.floor(rect.height * dpr));
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
      gl.viewport(0, 0, w, h);
      options.onResize?.(w, h, gl);
    }
  };

  const ro = new ResizeObserver(() => resize());
  ro.observe(canvas);
  resize();

  const tick = (now: number) => {
    if (!running || !gl || destroyed) return;
    if (!startTime) startTime = now;
    const elapsed = (now - startTime) * 0.001;

    resize();
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.useProgram(program);
    options.onRender?.(elapsed, gl, canvas.width, canvas.height);
    gl.drawArrays(gl.TRIANGLES, 0, 6);

    rafId = requestAnimationFrame(tick);
  };

  return {
    gl,
    program,
    canvas,
    getUniformLocation(name: string) {
      return gl.getUniformLocation(program, name);
    },
    start() {
      if (destroyed || running) return;
      running = true;
      startTime = 0;
      resize();
      rafId = requestAnimationFrame(tick);
    },
    stop() {
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
      ro.disconnect();
      if (quadBuf) gl.deleteBuffer(quadBuf);
      if (vs) gl.deleteShader(vs);
      if (fs) gl.deleteShader(fs);
      if (program) gl.deleteProgram(program);
    },
  };
}
