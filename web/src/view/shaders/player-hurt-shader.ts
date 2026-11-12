import Phaser from 'phaser';

const PLAYER_HURT_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform float uTime;
uniform float uIntensity;
uniform float uHpPct;

void main() {
  vec2 uv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  vec2 p = (uv - 0.5) * 2.0;
  float r = length(p);

  // Organic irregular edge noise for visceral rim
  float noise = sin(p.x * 10.0 + uTime * 7.0) * cos(p.y * 10.0 - uTime * 6.0) * 0.07;
  float edge = smoothstep(0.72 + noise, 1.38, r);

  // Heartbeat warning when at critical health
  float heartbeat = 0.0;
  if (uHpPct < 0.28) {
    float pulse = pow(sin(uTime * 6.0) * 0.5 + 0.5, 4.0);
    heartbeat = pulse * (1.0 - uHpPct / 0.28) * 0.42;
  }

  float totalVignette = clamp(edge * (uIntensity * 0.88 + heartbeat), 0.0, 0.88);
  if (totalVignette <= 0.001) {
    gl_FragColor = vec4(0.0);
    return;
  }

  vec3 deepBlood = vec3(0.72, 0.04, 0.10);
  vec3 hotScarlet = vec3(1.0, 0.22, 0.28);
  vec3 col = mix(deepBlood, hotScarlet, uIntensity * 0.5);

  gl_FragColor = vec4(col * totalVignette, totalVignette);
}
`;

export class PlayerHurtShader {
  private quad: Phaser.GameObjects.Shader;
  private time = 0;
  private intensity = 0;
  private hpPct = 1;
  private triggerCd = 0;

  constructor(scene: Phaser.Scene) {
    this.quad = scene.add
      .shader(
        {
          name: 'PlayerHurtShader',
          shaderName: 'PlayerHurtShader',
          fragmentSource: PLAYER_HURT_FRAG,
          setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
            setUniform('uTime', this.time);
            setUniform('uIntensity', this.intensity);
            setUniform('uHpPct', this.hpPct);
          },
        },
        0,
        0,
        128,
        128,
      )
      .setDepth(8.5)
      .setVisible(false);
  }

  trigger(amount = 0.85): void {
    if (this.triggerCd > 0) return;
    this.triggerCd = 0.22;
    this.intensity = Math.min(1.0, this.intensity + amount);
    this.quad.setVisible(true);
  }

  sync(
    camera: Phaser.Cameras.Scene2D.Camera,
    runTime: number,
    hp: number,
    maxHp: number,
    dt: number,
  ): void {
    this.time = runTime;
    this.triggerCd = Math.max(0, this.triggerCd - dt);
    this.hpPct = maxHp > 0 ? Math.max(0, Math.min(1, hp / maxHp)) : 1;

    // Exponential decay of hurt flash
    if (this.intensity > 0) {
      this.intensity = Math.max(0, this.intensity - dt * 3.4);
    }

    const needsRender = this.intensity > 0.01 || this.hpPct < 0.28;
    if (!needsRender) {
      this.quad.setVisible(false);
      return;
    }

    const view = camera.worldView;
    const pad = 16;
    const w = Math.max(64, view.width + pad * 2);
    const h = Math.max(64, view.height + pad * 2);

    this.quad
      .setSize(w, h)
      .setOrigin(0.5, 0.5)
      .setPosition(view.centerX, view.centerY)
      .setVisible(true);
  }
}
