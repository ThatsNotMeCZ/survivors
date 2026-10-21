export type SfxClip = {
  src: string;
  /** Linear gain 0–2, multiplied with the SFX bus. Default 1. */
  volume: number;
};

export type AudioManifest = {
  music: {
    menu: string[];
    maps: Record<string, string[]>;
    overlay: string[];
  };
  sfx: Record<string, SfxClip>;
};

export type AudioMix = {
  masterVolume: number;
  sfxVolume: number;
  musicVolume: number;
  muted: boolean;
};

export type MusicScene =
  | { kind: 'none' }
  | { kind: 'menu' }
  | { kind: 'stage'; stageId: string };

export type SfxId =
  | 'click'
  | 'confirm'
  | 'open'
  | 'close'
  | 'error'
  | 'victory'
  | 'defeat'
  | 'muzzle'
  | 'hit'
  | 'hurt'
  | 'death'
  | 'dash'
  | 'strike'
  | 'gem'
  | 'break';
