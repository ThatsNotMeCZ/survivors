import { describe, expect, it } from 'bun:test';
import { classifyWebGl } from '../src/ui/webgl-gate';

function fakeGl(exts: string[]) {
  return {
    getExtension: (name: string) => (exts.includes(name) ? {} : null),
  };
}

describe('classifyWebGl', () => {
  it('ok when context and Phaser 4 extensions exist', () => {
    expect(classifyWebGl(fakeGl(['ANGLE_instanced_arrays', 'OES_vertex_array_object']), false)).toBe('ok');
  });

  it('missing when no context and no software fallback', () => {
    expect(classifyWebGl(null, false)).toBe('missing');
  });

  it('software when caveat failed but a context exists', () => {
    expect(classifyWebGl(null, true)).toBe('software');
  });

  it('incomplete when instanced arrays are missing', () => {
    expect(classifyWebGl(fakeGl(['OES_vertex_array_object']), false)).toBe('incomplete');
  });

  it('incomplete when VAO extension is missing', () => {
    expect(classifyWebGl(fakeGl(['ANGLE_instanced_arrays']), false)).toBe('incomplete');
  });
});
