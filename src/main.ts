import { bootAudio } from './audio';
import { startGame } from './game';
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
} from './ui/overlay';
import { applySettingsToDom, hasQueryFlag, skipShell } from './ui/settings';

let game: Phaser.Game | null = null;

document.addEventListener('DOMContentLoaded', () => {
  applySettingsToDom();
  applyPromoAttr();
  bindOverlay({
    onStart: startRun,
    onResume: hideOverlay,
    onQuit: quitToMenu,
  });

  if (hasQueryFlag('smoke')) {
    hideOverlay();
    startGame('game-container', true);
    return;
  }

  bootAudio();

  hideHud();
  const promo = getPromoShot();
  if (skipShell()) {
    startRun();
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
  hideOverlay();
  hideSting();
  setHoldPrompt({ visible: false, title: '', detail: '', pct: 0, outside: false });
  game = startGame('game-container', false);
}

function quitToMenu(): void {
  if (game) {
    game.destroy(true);
    game = null;
  }
  hideHud();
  hideOverlay();
  hideSting();
  setHoldPrompt({ visible: false, title: '', detail: '', pct: 0, outside: false });
  showMainMenu();
}
