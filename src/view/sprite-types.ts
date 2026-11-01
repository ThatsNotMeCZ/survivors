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

export type UiRect = {
  x: number;
  y: number;
  w: number;
  h: number;
};

export type UiNineSliceMargins = {
  top: number;
  right: number;
  bottom: number;
  left: number;
};

export type UiNineSliceDef = {
  margins: UiNineSliceMargins;
  expandable: UiRect;
  repeat?: 'stretch' | 'repeat' | 'round';
  scale?: number;
};

export type UiSpriteEntry = {
  idle: UiRect;
  hover: UiRect;
  active: UiRect;
  nineSlice?: UiNineSliceDef;
};

export type UiAtlasDef = {
  src: string;
  width: number;
  height: number;
  frames: Record<string, UiSpriteEntry>;
};

export type SpriteManifest = {
  entities: Record<string, EntitySpriteDef>;
  items: string[];
  skills: string[];
  env: string[];
  fx: string[];
  ui?: string[];
  uiAtlas?: UiAtlasDef;
};
