import Phaser from 'phaser';
import { startGame } from './game';
import { hideHud } from './ui/hud';
import { bindOverlay, hideOverlay, showMainMenu } from './ui/overlay';

let game: Phaser.Game | null = null;

document.addEventListener('DOMContentLoaded', () => {
  const smoke = new URLSearchParams(window.location.search).has('smoke');
  if (smoke) {
    startGame('game-container', true);
    return;
  }

  bindOverlay({
    onStart: startRun,
    onResume: hideOverlay,
    onQuit: quitToMenu,
  });
  hideHud();
  showMainMenu();
});

function startRun(): void {
  if (game) return;
  hideOverlay();
  game = startGame('game-container', false);
}

function quitToMenu(): void {
  if (game) {
    game.destroy(true);
    game = null;
  }
  hideHud();
  showMainMenu();
}
