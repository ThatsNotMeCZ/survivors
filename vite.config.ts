import { defineConfig, type Plugin } from 'vite';
import { writeAudioManifest } from './scripts/audio-manifest';

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

export default defineConfig({
  plugins: [audioManifestPlugin()],
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
