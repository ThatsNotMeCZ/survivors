/// <reference types="vite/client" />

declare namespace Phaser {
  namespace Types {
    namespace GameObjects {
      namespace SpriteGPULayer {
        type ExtendedMemberAnimation = {
          base?: string | number;
          duration?: number;
          delay?: number;
          yoyo?: boolean;
        };
      }
    }
  }
  namespace GameObjects {
    interface SpriteGPULayer {
      editMember(
        index: number,
        member: Omit<Partial<Phaser.Types.GameObjects.SpriteGPULayer.Member>, 'animation'> & {
          animation?: string | number | Phaser.Types.GameObjects.SpriteGPULayer.ExtendedMemberAnimation;
        },
      ): this;
      addMember(
        member?: Omit<Partial<Phaser.Types.GameObjects.SpriteGPULayer.Member>, 'animation'> & {
          animation?: string | number | Phaser.Types.GameObjects.SpriteGPULayer.ExtendedMemberAnimation;
        },
      ): this;
    }
  }
}
