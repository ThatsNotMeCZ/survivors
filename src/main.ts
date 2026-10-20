import Phaser from 'phaser';
import { startGame } from './game';
import { hideHud } from './ui/hud';
import { bindOverlay, hideOverlay, hideSting, setHoldPrompt, showMainMenu } from './ui/overlay';
import { applySettingsToDom, hasQueryFlag, skipShell } from './ui/settings';

let game: Phaser.Game | null = null;

document.addEventListener('DOMContentLoaded', () => {
  applySettingsToDom();
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

  hideHud();
  if (skipShell()) {
    startRun();
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
