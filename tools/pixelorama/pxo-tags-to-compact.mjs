#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'node:fs';
import { formatCompactSidecar, toCompactSidecar } from './lib/parse-pxo-tags.mjs';

const inputPath = process.argv[2];
const outputPath = process.argv[3];

if (!inputPath) {
  console.error('usage: node tools/pixelorama/pxo-tags-to-compact.mjs <input.json> [output.json]');
  process.exit(1);
}

const rec = JSON.parse(readFileSync(inputPath, 'utf8'));
const compact = toCompactSidecar(rec);
if (!compact) {
  console.error(`not a Pixelorama project JSON or compact sidecar: ${inputPath}`);
  process.exit(1);
}

const text = formatCompactSidecar(compact);
if (outputPath) {
  writeFileSync(outputPath, text);
} else {
  process.stdout.write(text);
}
