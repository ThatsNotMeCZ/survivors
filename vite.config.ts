import { defineConfig, type Plugin } from 'vite';
import { writeAudioManifest } from './scripts/audio-manifest';
import { writeSpriteManifest } from './scripts/sprite-manifest';

function audioManifestPlugin(): Plugin {
  const run = (): void => {
    writeAudioManifest();
  };
  return {
    name: 'survivors-audio-manifest',
    buildStart: run,
    configureServer(server) {
      run();
      server.watcher.add('public/audio');
      server.watcher.on('all', (_event, file) => {
        if (!file.includes('public/audio') || file.endsWith('manifest.json')) return;
        run();
      });
    },
  };
}

function spriteManifestPlugin(): Plugin {
  const run = (): void => {
    writeSpriteManifest();
  };
  return {
    name: 'survivors-sprite-manifest',
    buildStart: run,
    configureServer(server) {
      run();
      server.watcher.add('public/sprites');
      server.watcher.on('all', (_event, file) => {
        if (!file.includes('public/sprites') || file.endsWith('manifest.json')) return;
        run();
      });
    },
  };
}

export default defineConfig({
  plugins: [audioManifestPlugin(), spriteManifestPlugin()],
  base: './',
  server: {
    port: 8080,
    host: true,
  },
  build: {
    target: 'es2020',
    rollupOptions: {
      output: {
        manualChunks: {
          phaser: ['phaser'],
        },
      },
    },
  },
});
