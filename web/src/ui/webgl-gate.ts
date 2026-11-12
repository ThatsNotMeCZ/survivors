/** Phaser 4 WebGLRenderer requires these WebGL1 extensions. */
export const WEBGL_REQUIRED_EXTENSIONS = ['ANGLE_instanced_arrays', 'OES_vertex_array_object'] as const;

export type WebGlLike = {
  getExtension: (name: string) => unknown;
};

export type WebGlGate = 'ok' | 'missing' | 'software' | 'incomplete';

export type WebGlFail = Exclude<WebGlGate, 'ok'> | 'lost';

export function classifyWebGl(gl: WebGlLike | null, softwareAvailable: boolean): WebGlGate {
  if (!gl) return softwareAvailable ? 'software' : 'missing';
  for (const name of WEBGL_REQUIRED_EXTENSIONS) {
    if (!gl.getExtension(name)) return 'incomplete';
  }
  return 'ok';
}

function tryContext(failIfMajorPerformanceCaveat: boolean): {
  canvas: HTMLCanvasElement;
  gl: WebGLRenderingContext | null;
} {
  const canvas = document.createElement('canvas');
  let gl: WebGLRenderingContext | null = null;
  try {
    const opts: WebGLContextAttributes = {
      alpha: false,
      antialias: false,
      depth: false,
      stencil: false,
      failIfMajorPerformanceCaveat,
    };
    gl =
      canvas.getContext('webgl', opts) ??
      (canvas.getContext('experimental-webgl', opts) as WebGLRenderingContext | null);
  } catch {
    gl = null;
  }
  return { canvas, gl };
}

function disposeProbe(canvas: HTMLCanvasElement, gl: WebGLRenderingContext | null): void {
  const lose = gl?.getExtension('WEBGL_lose_context');
  lose?.loseContext();
  canvas.width = 0;
  canvas.height = 0;
}

/** Probe before Phaser boots. Disposes the test context so it does not count against the GPU limit. */
export function probeWebGl(): WebGlGate {
  if (typeof document === 'undefined') return 'missing';
  const hw = tryContext(true);
  if (hw.gl) {
    const result = classifyWebGl(hw.gl, false);
    disposeProbe(hw.canvas, hw.gl);
    return result;
  }
  disposeProbe(hw.canvas, null);
  const soft = tryContext(false);
  const result = classifyWebGl(null, !!soft.gl);
  disposeProbe(soft.canvas, soft.gl);
  return result;
}
