import Phaser from 'phaser';

const ELITE_AFFIX_FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

varying vec2 outTexCoord;

uniform sampler2D uMainSampler;
uniform float uTime;
uniform float uAffix;        // 1 = Shielder outline, 2 = Noxious overlay
uniform float uShieldActive; // 1 = shield present, 0 = broken / recharging
uniform float uCorpse;       // 1 = dying / exploding corpse
uniform vec4 uFrameRect;     // u0, v0, u1, v1 in texture atlas space
uniform vec2 uFramePixels;   // pixel width and height of sprite frame
uniform float uFlipX;        // 1 = flipped horizontally, 0 = normal

void main() {
  // Map incoming quad UV (0..1) into the sprite sheet frame rect
  vec2 localUv = vec2(outTexCoord.x, 1.0 - outTexCoord.y);
  if (uFlipX > 0.5) {
    localUv.x = 1.0 - localUv.x;
  }

  // Margin accounts for the 2px padding on all sides of the quad
  vec2 pad = vec2(2.0) / (uFramePixels + 4.0);
  vec2 innerUv = (localUv - pad) / (vec2(1.0) - 2.0 * pad);

  // If outside frame area, render transparent unless outline reaches here
  bool insideFrame = innerUv.x >= 0.0 && innerUv.x <= 1.0 && innerUv.y >= 0.0 && innerUv.y <= 1.0;

  vec2 atlasUv = mix(uFrameRect.xy, uFrameRect.zw, clamp(innerUv, 0.0, 1.0));
  vec4 centerTex = insideFrame ? texture2D(uMainSampler, atlasUv) : vec4(0.0);

  vec2 texel = (uFrameRect.zw - uFrameRect.xy) / uFramePixels;

  if (uAffix < 1.5) {
    // -------------------------------------------------------------------------
    // 1. SHIELDER: Blue outline around sprite silhouette (Resurrect 64 blue tones)
    // Resurrect 64 blues:
    // #3060e6 - vec3(0.188, 0.376, 0.902)
    // #4d9be6 - vec3(0.302, 0.608, 0.902) [Resurrect 64 active shield blue]
    // #8fd3ff - vec3(0.561, 0.828, 1.0)   [Resurrect 64 light shield rim]
    // #484a77 - vec3(0.282, 0.290, 0.467) [Resurrect 64 broken shield dusk]
    // -------------------------------------------------------------------------
    if (centerTex.a > 0.35) {
      // Don't draw over the interior of the sprite for outline-only
      gl_FragColor = vec4(0.0);
      return;
    }

    // Sample immediate 4-connected 1px neighbors on sprite boundary
    float aL = texture2D(uMainSampler, atlasUv - vec2(texel.x, 0.0)).a;
    float aR = texture2D(uMainSampler, atlasUv + vec2(texel.x, 0.0)).a;
    float aD = texture2D(uMainSampler, atlasUv - vec2(0.0, texel.y)).a;
    float aU = texture2D(uMainSampler, atlasUv + vec2(0.0, texel.y)).a;

    float neighborAlpha = max(max(aL, aR), max(aD, aU));
    if (neighborAlpha <= 0.35) {
      gl_FragColor = vec4(0.0);
      return;
    }

    // Active shield vs broken shield
    vec3 brightBlue = vec3(0.302, 0.608, 0.902); // #4d9be6
    vec3 lightBlue  = vec3(0.561, 0.828, 1.0);   // #8fd3ff
    vec3 brokenBlue = vec3(0.282, 0.290, 0.467); // #484a77

    float wave = 0.5 + 0.5 * sin(uTime * 5.0 + innerUv.y * 14.0);
    vec3 activeCol = mix(brightBlue, lightBlue, wave * 0.6);

    vec3 outlineCol = uShieldActive > 0.5 ? activeCol : brokenBlue;
    float outlineAlpha = uShieldActive > 0.5 ? 0.95 : 0.45;

    gl_FragColor = vec4(outlineCol * outlineAlpha, outlineAlpha);
    return;
  } else {
    // -------------------------------------------------------------------------
    // 2. NOXIOUS: Greenish overlay shader over the entire sprite
    // Resurrect 64 green tones:
    // #1ebc73 - vec3(0.118, 0.737, 0.451) [Resurrect 64 noxious emerald]
    // #91db69 - vec3(0.569, 0.859, 0.412) [Resurrect 64 toxic lime]
    // #239063 - vec3(0.137, 0.565, 0.388) [Resurrect 64 deep caustic green]
    // -------------------------------------------------------------------------
    if (centerTex.a <= 0.2) {
      gl_FragColor = vec4(0.0);
      return;
    }

    vec3 emerald = vec3(0.118, 0.737, 0.451);
    vec3 toxicLime = vec3(0.569, 0.859, 0.412);
    vec3 deepGreen = vec3(0.137, 0.565, 0.388);

    // Subtle toxic pixel turbulence flowing over the sprite body
    float pulseSpeed = uCorpse > 0.5 ? 14.0 : 4.0;
    float wave = sin(innerUv.y * 16.0 - uTime * pulseSpeed + innerUv.x * 10.0);
    float glow = 0.5 + 0.5 * wave;

    vec3 noxiousCol = mix(deepGreen, emerald, glow);
    noxiousCol = mix(noxiousCol, toxicLime, smoothstep(0.7, 1.0, glow));

    // Semi-transparent overlay preserving underlying pixel silhouette
    float overlayAlpha = (uCorpse > 0.5 ? 0.65 : 0.42 + 0.12 * glow) * centerTex.a;

    gl_FragColor = vec4(noxiousCol * overlayAlpha, overlayAlpha);
    return;
  }
}
`;

type EliteAffixSlot = {
  quad: Phaser.GameObjects.Shader;
  affix: number;
  shieldActive: number;
  corpse: number;
  frameRect: [number, number, number, number];
  framePixels: [number, number];
  flipX: number;
};

const MAX_ELITE_SLOTS = 6;

export class EliteAffixShaderPool {
  private time = 0;
  private slots: EliteAffixSlot[] = [];

  constructor(scene: Phaser.Scene) {
    for (let i = 0; i < MAX_ELITE_SLOTS; i += 1) {
      const slot: EliteAffixSlot = {
        quad: null as unknown as Phaser.GameObjects.Shader,
        affix: 1,
        shieldActive: 1,
        corpse: 0,
        frameRect: [0, 0, 1, 1],
        framePixels: [48, 48],
        flipX: 0,
      };

      slot.quad = scene.add
        .shader(
          {
            name: 'EliteAffixShader',
            shaderName: 'EliteAffixShader',
            fragmentSource: ELITE_AFFIX_FRAG,
            setupUniforms: (setUniform: (name: string, value: unknown) => void) => {
              setUniform('uMainSampler', 0);
              setUniform('uTime', this.time);
              setUniform('uAffix', slot.affix);
              setUniform('uShieldActive', slot.shieldActive);
              setUniform('uCorpse', slot.corpse);
              setUniform('uFrameRect', slot.frameRect);
              setUniform('uFramePixels', slot.framePixels);
              setUniform('uFlipX', slot.flipX);
            },
          },
          0,
          0,
          64,
          64,
        )
        .setDepth(3.05)
        .setVisible(false);

      this.slots.push(slot);
    }
  }

  sync(
    runTime: number,
    eliteSprites: Phaser.GameObjects.Sprite[],
    eliteData: Array<{
      active: boolean;
      isShielder: boolean;
      shieldActive: boolean;
      isNoxious: boolean;
      isCorpse: boolean;
    }>,
  ): void {
    this.time = runTime;

    for (let i = 0; i < this.slots.length; i += 1) {
      const slot = this.slots[i];
      const sprite = eliteSprites[i];
      const data = eliteData[i];

      if (!data || !data.active || !sprite || !sprite.visible) {
        slot.quad.setVisible(false);
        continue;
      }

      const frame = sprite.frame;
      if (!frame || !sprite.texture) {
        slot.quad.setVisible(false);
        continue;
      }

      // Bind texture to the shader quad
      if (slot.quad.textures.length === 0 || slot.quad.textures[0] !== sprite.texture) {
        slot.quad.setTextures([sprite.texture]);
      }

      slot.affix = data.isShielder ? 1.0 : data.isNoxious ? 2.0 : 1.0;
      slot.shieldActive = data.shieldActive ? 1.0 : 0.0;
      slot.corpse = data.isCorpse ? 1.0 : 0.0;
      slot.flipX = sprite.flipX ? 1.0 : 0.0;

      // Extract UV rect of current frame
      slot.frameRect[0] = frame.u0;
      slot.frameRect[1] = frame.v0;
      slot.frameRect[2] = frame.u1;
      slot.frameRect[3] = frame.v1;

      const fw = frame.cutWidth || frame.width || 48;
      const fh = frame.cutHeight || frame.height || 48;
      slot.framePixels[0] = fw;
      slot.framePixels[1] = fh;

      // Quad has 2px padding on all sides (+4px total) so 1px outline has room
      const scaleX = Math.abs(sprite.scaleX) || 1.0;
      const scaleY = Math.abs(sprite.scaleY) || 1.0;
      const quadW = (fw + 4) * scaleX;
      const quadH = (fh + 4) * scaleY;

      slot.quad
        .setSize(quadW, quadH)
        .setOrigin(sprite.originX, sprite.originY)
        .setPosition(sprite.x, sprite.y)
        .setVisible(true);
    }
  }

  destroy(): void {
    for (const slot of this.slots) {
      slot.quad.destroy();
    }
    this.slots.length = 0;
  }
}
