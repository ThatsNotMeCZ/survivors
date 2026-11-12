import Phaser from 'phaser';
import { bootAudio } from './audio';
import { startGame } from './game';
import { mountCoverCompose } from './promo/cover-compose';
import { mountPromoTitle } from './promo/pose';
import { applyPromoAttr, getPromoShot, markPromoReady } from './promo/shot';
import { hideHud } from './ui/hud';
import {
  bindOverlay,
  hideOverlay,
  hideSting,
  setHoldPrompt,
  showArchives,
  showLobby,
  showMainMenu,
  showWebglBlocker,
} from './ui/overlay';
import { applySettingsToDom, hasQueryFlag, skipShell } from './ui/settings';
import { probeWebGl } from './ui/webgl-gate';

let game: Phaser.Game | null = null;
let webglReady = false;

document.addEventListener('DOMContentLoaded', () => {
  applySettingsToDom();
  applyPromoAttr();
  bindOverlay({
    onStart: startRun,
    onResume: hideOverlay,
    onQuit: quitToMenu,
  });

  if (hasQueryFlag('nowebgl')) {
    showWebglBlocker('missing');
    return;
  }

  const gate = probeWebGl();
  if (gate !== 'ok') {
    showWebglBlocker(gate);
    return;
  }
  webglReady = true;

  if (hasQueryFlag('smoke')) {
    bootRun(true);
    return;
  }

  bootAudio();

  hideHud();
  const promo = getPromoShot();
  if (skipShell()) {
    startRun();
    return;
  }
  if (promo === 'cover') {
    mountCoverCompose();
    return;
  }
  if (promo === 'hall' || promo === 'banner') {
    showLobby();
    if (promo === 'banner') mountPromoTitle();
    markPromoReady();
    return;
  }
  if (promo === 'archives') {
    showArchives('menu', 'entities');
    markPromoReady();
    return;
  }
  showMainMenu();
});

function startRun(): void {
  if (game) return;
  bootRun(false);
}

function bootRun(smoke: boolean): void {
  if (!webglReady) {
    showWebglBlocker('missing');
    return;
  }
  hideOverlay();
  hideSting();
  setHoldPrompt({ visible: false, title: '', detail: '', pct: 0, outside: false });
  try {
    game = startGame('game-container', smoke);
  } catch {
    showWebglBlocker('missing');
    return;
  }
  bindWebGlLost(game);
}

function bindWebGlLost(instance: Phaser.Game): void {
  const renderer = instance.renderer;
  if (!(renderer instanceof Phaser.Renderer.WebGL.WebGLRenderer)) {
    tearDownGame();
    showWebglBlocker('missing');
    return;
  }
  renderer.once(Phaser.Renderer.Events.LOSE_WEBGL, () => {
    if (game !== instance) return;
    tearDownGame();
    showWebglBlocker('lost');
  });
}

function tearDownGame(): void {
  if (!game) return;
  const instance = game;
  game = null;
  try {
    instance.destroy(true);
  } catch {
    // renderer already dead
  }
}

function quitToMenu(): void {
  tearDownGame();
  hideHud();
  hideOverlay();
  hideSting();
  setHoldPrompt({ visible: false, title: '', detail: '', pct: 0, outside: false });
  showMainMenu();
}
