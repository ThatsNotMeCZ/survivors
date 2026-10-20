import Phaser from 'phaser';
import { GAME_HEIGHT, GAME_WIDTH } from './config';
import { ArenaScene } from './view/arena-scene';
import { SmokeScene } from './view/smoke-scene';

export function startGame(parent: string, smoke: boolean): Phaser.Game {
  return new Phaser.Game({
    type: Phaser.WEBGL,
    parent,
    width: GAME_WIDTH,
    height: GAME_HEIGHT,
    backgroundColor: '#0c0a0d',
    banner: false,
    audio: { noAudio: true },
    pixelArt: true,
    roundPixels: true,
    scale: {
      mode: Phaser.Scale.FIT,
      autoCenter: Phaser.Scale.CENTER_BOTH,
    },
    render: {
      antialias: false,
    },
    scene: smoke ? [SmokeScene] : [ArenaScene],
  });
}
