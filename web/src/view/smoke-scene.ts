import Phaser from 'phaser';
import {
  GAME_HEIGHT,
  GAME_WIDTH,
  SMOKE_DOTS,
  SMOKE_WARMUP_MS,
} from '../config';
import { initHud, judgeFps, setHudFps, setHudStatus } from '../ui/hud';

type GpuMember = Partial<Phaser.Types.GameObjects.SpriteGPULayer.Member>;

/**
 * Render-only smoke test. No sim, no physics, no per-dot CPU motion.
 * Dots live in a SpriteGPULayer and tween on the GPU.
 */
export class SmokeScene extends Phaser.Scene {
  private judged = false;

  constructor() {
    super({ key: 'smoke' });
  }

  create(): void {
    this.createDotTexture();
    this.populateGpuDots();

    const webgl = this.game.renderer instanceof Phaser.Renderer.WebGL.WebGLRenderer;
    initHud(webgl ? 'webgl' : 'canvas');

    this.time.delayedCall(SMOKE_WARMUP_MS, () => {
      this.judged = true;
      setHudStatus(judgeFps(this.game.loop.actualFps));
    });
  }

  update(): void {
    setHudFps(this.game.loop.actualFps);
    if (!this.judged) {
      setHudStatus('warmup');
    }
  }

  private createDotTexture(): void {
    const size = 16;
    const texture = this.textures.createCanvas('dot', size, size);
    if (!texture) {
      throw new Error('Failed to create dot canvas texture');
    }

    const ctx = texture.getContext();
    ctx.clearRect(0, 0, size, size);
    const glow = ctx.createRadialGradient(8, 8, 1, 8, 8, 7);
    glow.addColorStop(0, '#e8fbff');
    glow.addColorStop(0.55, '#5ad4ff');
    glow.addColorStop(1, 'rgba(90, 212, 255, 0)');
    ctx.fillStyle = glow;
    ctx.beginPath();
    ctx.arc(8, 8, 7, 0, Math.PI * 2);
    ctx.fill();
    texture.refresh();
  }

  private populateGpuDots(): void {
    const layer = this.add.spriteGPULayer('dot', SMOKE_DOTS);
    layer.setAnimationEnabled('Sine', true);

    const member: GpuMember = {
      x: 0,
      y: 0,
      scaleX: 1,
      scaleY: 1,
      alpha: 1,
      tintBlend: 0,
      tintBottomLeft: 0xffffff,
      tintTopLeft: 0xffffff,
      tintBottomRight: 0xffffff,
      tintTopRight: 0xffffff,
    };

    for (let i = 0; i < SMOKE_DOTS; i += 1) {
      const hueShift = 0x5ad4ff - (i % 40) * 0x040200;
      member.x = anim(Math.random() * GAME_WIDTH, 10 + Math.random() * 28);
      member.y = anim(Math.random() * GAME_HEIGHT, 8 + Math.random() * 22);
      member.scaleX = 0.7 + Math.random() * 0.8;
      member.scaleY = member.scaleX;
      member.alpha = 0.55 + Math.random() * 0.45;
      member.tintBlend = 0.15;
      member.tintBottomLeft = hueShift;
      member.tintTopLeft = hueShift;
      member.tintBottomRight = hueShift;
      member.tintTopRight = hueShift;
      layer.addMember(member);
    }
  }
}

function anim(
  base: number,
  amplitude: number,
): Phaser.Types.GameObjects.SpriteGPULayer.MemberAnimation {
  return {
    base,
    amplitude,
    duration: 1400 + Math.random() * 2200,
    delay: Math.random() * 1200,
    ease: 'Sine',
    yoyo: true,
    loop: true,
  };
}
