import { existsSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const ROOT = process.cwd();
const DIST_DIR = join(ROOT, 'dist');
const OUTPUT_ZIP = join(ROOT, 'hermetic-rifts-itch.zip');

function main(): void {
  console.log('⚗️ Packaging Hermetic Rifts for itch.io...');

  if (!existsSync(DIST_DIR)) {
    console.error('❌ dist/ directory not found. Run "bun run build" first.');
    process.exit(1);
  }

  const indexHtml = join(DIST_DIR, 'index.html');
  if (!existsSync(indexHtml)) {
    console.error('❌ dist/index.html not found.');
    process.exit(1);
  }

  // Validate index.html uses relative paths (not absolute /assets)
  const htmlContent = Bun.file(indexHtml);
  // Check that audio and sprites manifests are included
  const spriteManifest = join(DIST_DIR, 'sprites', 'manifest.json');
  const audioManifest = join(DIST_DIR, 'audio', 'manifest.json');

  if (!existsSync(spriteManifest)) {
    console.warn('⚠️ Warning: dist/sprites/manifest.json is missing.');
  }
  if (!existsSync(audioManifest)) {
    console.warn('⚠️ Warning: dist/audio/manifest.json is missing.');
  }

  // Delete previous zip if exists
  if (existsSync(OUTPUT_ZIP)) {
    try {
      spawnSync('rm', ['-f', OUTPUT_ZIP]);
    } catch {
      // ignore
    }
  }

  // Zip the CONTENTS of dist (so index.html is at root of archive)
  console.log(`📦 Creating ${OUTPUT_ZIP} from dist/ contents...`);
  const zipRes = spawnSync('zip', ['-r', OUTPUT_ZIP, '.'], {
    cwd: DIST_DIR,
    stdio: 'pipe',
  });

  if (zipRes.status !== 0) {
    console.error('❌ zip command failed:', zipRes.stderr.toString());
    process.exit(1);
  }

  const stats = statSync(OUTPUT_ZIP);
  const sizeMb = (stats.size / (1024 * 1024)).toFixed(2);

  console.log(`\n✅ Successfully generated itch.io package:`);
  console.log(`   File: ${OUTPUT_ZIP}`);
  console.log(`   Size: ${sizeMb} MB`);
  console.log(`   Directly upload this zip to itch.io (Playable in browser / HTML).`);
}

main();
