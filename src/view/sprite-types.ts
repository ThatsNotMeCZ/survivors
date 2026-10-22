export type SpriteAnimDef = {
  frames: number[];
  frameRate: number;
  repeat: number;
};

export type EntitySpriteDef = {
  src: string;
  frameWidth: number;
  frameHeight: number;
  anims: Record<string, SpriteAnimDef>;
};

export type SpriteManifest = {
  entities: Record<string, EntitySpriteDef>;
  items: string[];
  skills: string[];
  env: string[];
  fx: string[];
};
