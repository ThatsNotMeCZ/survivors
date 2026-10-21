import { existsSync } from 'node:fs';
import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { PNG } from 'pngjs';

type WorkflowNode = {
  class_type: string;
  inputs: Record<string, unknown>;
};

type Workflow = Record<string, WorkflowNode>;

type SpriteKind = 'front' | 'icon' | 'env';

type SpriteEntry = {
  key: string;
  kind: SpriteKind;
  size: number;
  prompt: string;
  negative?: string;
  biome?: string;
  vessel?: string;
  item?: string;
  identity?: string;
};

type SpriteCatalog = {
  styleSuffix: string;
  refStyleSuffix?: string;
  identities?: Record<string, string>;
  entries: SpriteEntry[];
};

type ModelsConfig = {
  url: string;
  checkpoint: string;
  lora: string;
  loraStrength: number;
};

type Args = {
  keys: string[];
  seed: number | null;
  vessel: string | null;
  item: string | null;
  kind: SpriteKind | null;
  list: boolean;
  force: boolean;
};

const ROOT = join(import.meta.dir, '..');
const SPRITES_DIR = join(ROOT, 'public/sprites');
const REF_DIR = join(SPRITES_DIR, '_ref');
const POLL_MS = 500;
const TIMEOUT_MS = 240_000;
const SAVE_NODE = '9';
const SCALE_NODE = '8';
const CHROMA_PX = 128;
const REF_PX = 512;
const REF_STEPS = 32;
const QUALITY_NEG =
  'photorealistic, 3d render, blur, antialias, smooth shading, cinematic, multiple characters, text, watermark, portrait photo';

const catalog = (await Bun.file(join(ROOT, 'tools/comfy/sprites.json')).json()) as SpriteCatalog;
const models = (await Bun.file(join(ROOT, 'tools/comfy/models.json')).json()) as ModelsConfig;
const txtWorkflow = (await Bun.file(
  join(ROOT, 'tools/comfy/workflows/sprite-txt2img-api.json'),
).json()) as Workflow;
const byKey = new Map(catalog.entries.map((entry) => [entry.key, entry]));
const comfyUrl = (process.env.COMFYUI_URL ?? models.url).replace(/\/$/, '');

function flagValue(argv: string[], i: number): string | null {
  const value = argv[i + 1];
  if (!value || value.startsWith('--')) return null;
  return value;
}

function parseArgs(argv: string[]): Args {
  const keys: string[] = [];
  let seed: number | null = null;
  let vessel: string | null = null;
  let item: string | null = null;
  let kind: SpriteKind | null = null;
  let list = false;
  let force = false;
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--force') {
      force = true;
      continue;
    }
    if (arg === '--list') {
      list = true;
      continue;
    }
    if (arg === '--ref-front' || arg === '--front') {
      kind = 'front';
      continue;
    }
    if (arg === '--icon') {
      kind = 'icon';
      continue;
    }
    if (arg === '--env') {
      kind = 'env';
      continue;
    }
    if (arg === '--key') {
      const value = flagValue(argv, i);
      if (!value) throw new Error('--key needs a texture key');
      keys.push(value);
      i += 1;
      continue;
    }
    if (arg === '--seed') {
      const value = flagValue(argv, i);
      if (!value) throw new Error('--seed needs an integer');
      seed = Number(value);
      if (!Number.isInteger(seed) || seed < 0) throw new Error(`bad --seed ${value}`);
      i += 1;
      continue;
    }
    if (arg === '--vessel') {
      const value = flagValue(argv, i);
      if (!value) {
        vessel = 'runner';
        continue;
      }
      vessel = value;
      i += 1;
      continue;
    }
    if (arg === '--item') {
      const value = flagValue(argv, i);
      if (!value) {
        list = true;
        kind = 'icon';
        continue;
      }
      item = value;
      kind = 'icon';
      i += 1;
      continue;
    }
    if (arg === '--all' || arg === '--entity' || arg === '--walk' || arg === '--lock' || arg === '--import' || arg === '--views') {
      throw new Error(
        `${arg} is gone. Comfy writes character refs to public/sprites/_ref/ and icons to public/sprites/. bun run art:ref -- runner   or   bun run art:item -- glass-cannon`,
      );
    }
    throw new Error(
      `unknown arg ${arg} (use --ref-front, --vessel, --item, --icon, --env, --key, --seed, --force, --list)`,
    );
  }
  if (kind === 'front' && !vessel) vessel = 'runner';
  return { keys, seed, vessel, item, kind, list, force };
}

function isCharacterRef(entry: SpriteEntry): boolean {
  return entry.kind === 'front';
}

function destPath(entry: SpriteEntry): string {
  return join(isCharacterRef(entry) ? REF_DIR : SPRITES_DIR, `${entry.key}.png`);
}

function outputSize(entry: SpriteEntry): number {
  return isCharacterRef(entry) ? REF_PX : entry.size;
}

function printList(): void {
  console.log(`front refs (--vessel <id>) → public/sprites/_ref/ at ${REF_PX}px:`);
  for (const entry of catalog.entries.filter((row) => row.kind === 'front')) {
    console.log(`  ${entry.vessel}  ${entry.key}`);
  }
  console.log('\nicons (--item <id>) → public/sprites/:');
  for (const entry of catalog.entries.filter((row) => row.kind === 'icon')) {
    console.log(`  ${entry.item ?? entry.key}  ${entry.key}  ${entry.size}px`);
  }
  const envs = catalog.entries.filter((row) => row.kind === 'env');
  if (envs.length > 0) {
    console.log('\nenv:');
    for (const entry of envs) console.log(`  ${entry.key}  ${entry.size}px`);
  }
}

function pickEntries(args: Args): SpriteEntry[] {
  let selected: SpriteEntry[];
  if (args.keys.length > 0) {
    selected = args.keys.map((key) => {
      const hit = byKey.get(key);
      if (!hit) throw new Error(`unknown sprite key ${key}`);
      return hit;
    });
  } else if (args.item) {
    selected = catalog.entries.filter((entry) => entry.item === args.item);
    if (selected.length === 0) {
      throw new Error(
        `unknown --item ${args.item}. Known: ${catalog.entries
          .map((entry) => entry.item)
          .filter(Boolean)
          .join(', ')}`,
      );
    }
  } else if (args.kind === 'front') {
    selected = catalog.entries.filter(
      (entry) => entry.kind === 'front' && (!args.vessel || entry.vessel === args.vessel),
    );
  } else if (args.kind) {
    selected = catalog.entries.filter((entry) => entry.kind === args.kind);
  } else if (args.vessel) {
    selected = catalog.entries.filter((entry) => entry.vessel === args.vessel && entry.kind === 'front');
  } else {
    selected = [...catalog.entries];
  }
  const out = selected.filter((entry) => {
    const dest = destPath(entry);
    if (existsSync(dest) && !args.force) {
      console.log(`skip ${entry.key} (exists, pass --force)`);
      return false;
    }
    return true;
  });
  return out;
}

function promptText(entry: SpriteEntry): string {
  const parts: string[] = [entry.prompt];
  if (entry.identity) {
    const identity = catalog.identities?.[entry.identity];
    if (!identity) throw new Error(`unknown identity ${entry.identity}`);
    parts.push(identity);
  }
  const style = isCharacterRef(entry)
    ? (catalog.refStyleSuffix ?? catalog.styleSuffix)
    : catalog.styleSuffix;
  parts.push(style);
  return parts.join(', ');
}

async function comfyJson(path: string): Promise<unknown> {
  const res = await fetch(`${comfyUrl}${path}`);
  if (!res.ok) throw new Error(`GET ${path} -> ${res.status}`);
  return res.json();
}

function namesOf(payload: unknown): string[] {
  if (Array.isArray(payload)) return payload.filter((item): item is string => typeof item === 'string');
  return [];
}

function hasModel(list: string[], filename: string): boolean {
  return list.some((name) => name === filename || name.endsWith(`/${filename}`));
}

async function assertComfy(): Promise<void> {
  try {
    await comfyJson('/system_stats');
  } catch {
    throw new Error(`ComfyUI is not reachable at ${comfyUrl}. Start it: bun run art:comfy`);
  }
  const checkpoints = namesOf(await comfyJson('/models/checkpoints'));
  const loras = namesOf(await comfyJson('/models/loras'));
  if (!hasModel(checkpoints, models.checkpoint)) {
    throw new Error(`missing checkpoint ${models.checkpoint}. Run bun run art:download and restart ComfyUI.`);
  }
  if (!hasModel(loras, models.lora)) {
    throw new Error(`missing LoRA ${models.lora}. Run bun run art:download and restart ComfyUI.`);
  }
}

function buildPrompt(entry: SpriteEntry, seed: number): Workflow {
  const graph = structuredClone(txtWorkflow);
  const ckpt = graph['1']?.inputs;
  const lora = graph['2']?.inputs;
  const positive = graph['3']?.inputs;
  const sampler = graph['6']?.inputs;
  const scale = graph[SCALE_NODE]?.inputs;
  const save = graph[SAVE_NODE]?.inputs;
  if (!ckpt || !lora || !positive || !sampler || !scale || !save) {
    throw new Error('workflow JSON is missing required nodes');
  }
  ckpt.ckpt_name = models.checkpoint;
  lora.lora_name = models.lora;
  lora.strength_model = models.loraStrength;
  lora.strength_clip = models.loraStrength;
  positive.text = promptText(entry);
  const negative = graph['4']?.inputs;
  if (negative) {
    negative.text = entry.negative ? `${QUALITY_NEG}, ${entry.negative}` : QUALITY_NEG;
  }
  sampler.seed = seed;
  if (isCharacterRef(entry)) sampler.steps = REF_STEPS;
  const px = isCharacterRef(entry) ? REF_PX : CHROMA_PX;
  scale.width = px;
  scale.height = px;
  save.filename_prefix = isCharacterRef(entry) ? `hermetic/ref/${entry.key}` : `hermetic/${entry.key}`;
  return graph;
}

async function queuePrompt(prompt: Workflow): Promise<string> {
  const res = await fetch(`${comfyUrl}/prompt`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ prompt }),
  });
  const body = (await res.json()) as {
    prompt_id?: string;
    error?: { message?: string; details?: string };
    node_errors?: Record<string, unknown>;
  };
  if (!res.ok || !body.prompt_id) {
    throw new Error(`POST /prompt failed: ${body.error?.details ?? body.error?.message ?? res.status}`);
  }
  if (body.node_errors && Object.keys(body.node_errors).length > 0) {
    throw new Error(`workflow node_errors: ${JSON.stringify(body.node_errors)}`);
  }
  return body.prompt_id;
}

type HistoryImage = { filename: string; subfolder: string; type: string };

async function waitForImage(promptId: string): Promise<HistoryImage> {
  const deadline = Date.now() + TIMEOUT_MS;
  while (Date.now() < deadline) {
    const history = (await comfyJson(`/history/${promptId}`)) as Record<
      string,
      { outputs?: Record<string, { images?: HistoryImage[] }> }
    >;
    const images = history[promptId]?.outputs?.[SAVE_NODE]?.images;
    if (images && images[0]) return images[0];
    await Bun.sleep(POLL_MS);
  }
  throw new Error(`timed out waiting for ${promptId}`);
}

async function downloadView(image: HistoryImage): Promise<Buffer> {
  const params = new URLSearchParams({
    filename: image.filename,
    subfolder: image.subfolder,
    type: image.type,
  });
  const res = await fetch(`${comfyUrl}/view?${params.toString()}`);
  if (!res.ok) throw new Error(`GET /view -> ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}

function isBackground(data: Buffer, offset: number): boolean {
  return data[offset] >= 245 && data[offset + 1] >= 245 && data[offset + 2] >= 245 && data[offset + 3] > 0;
}

function chromaKeyWhite(png: PNG): void {
  const { width, height, data } = png;
  const seen = new Uint8Array(width * height);
  const stack: number[] = [];
  const push = (x: number, y: number): void => {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const p = y * width + x;
    if (seen[p]) return;
    seen[p] = 1;
    if (!isBackground(data, p << 2)) return;
    stack.push(p);
  };
  for (let x = 0; x < width; x += 1) {
    push(x, 0);
    push(x, height - 1);
  }
  for (let y = 0; y < height; y += 1) {
    push(0, y);
    push(width - 1, y);
  }
  while (stack.length > 0) {
    const p = stack.pop();
    if (p === undefined) break;
    data[(p << 2) + 3] = 0;
    const x = p % width;
    const y = (p / width) | 0;
    push(x - 1, y);
    push(x + 1, y);
    push(x, y - 1);
    push(x, y + 1);
  }
}

function opaqueBounds(png: PNG): { x: number; y: number; w: number; h: number } | null {
  const { width, height, data } = png;
  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      if (data[((y * width + x) << 2) + 3] < 16) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) return null;
  return { x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1 };
}

function cropToFit(src: PNG, size: number): PNG {
  const box = opaqueBounds(src);
  const dst = new PNG({ width: size, height: size });
  if (!box) return dst;
  const pad = 2;
  const sx0 = Math.max(0, box.x - pad);
  const sy0 = Math.max(0, box.y - pad);
  const sx1 = Math.min(src.width, box.x + box.w + pad);
  const sy1 = Math.min(src.height, box.y + box.h + pad);
  const sw = Math.max(1, sx1 - sx0);
  const sh = Math.max(1, sy1 - sy0);
  const scale = Math.min(size / sw, size / sh);
  const dw = Math.max(1, Math.round(sw * scale));
  const dh = Math.max(1, Math.round(sh * scale));
  const ox = Math.floor((size - dw) / 2);
  const oy = Math.floor((size - dh) / 2);
  for (let y = 0; y < dh; y += 1) {
    const sy = Math.min(sh - 1, Math.floor(((y + 0.5) * sh) / dh));
    for (let x = 0; x < dw; x += 1) {
      const sx = Math.min(sw - 1, Math.floor(((x + 0.5) * sw) / dw));
      const si = ((sy0 + sy) * src.width + (sx0 + sx)) << 2;
      const di = ((oy + y) * size + (ox + x)) << 2;
      dst.data[di] = src.data[si];
      dst.data[di + 1] = src.data[si + 1];
      dst.data[di + 2] = src.data[si + 2];
      dst.data[di + 3] = src.data[si + 3];
    }
  }
  return dst;
}

function toGamePng(raw: Buffer, size: number): Buffer {
  const png = PNG.sync.read(raw);
  chromaKeyWhite(png);
  return PNG.sync.write(cropToFit(png, size));
}

async function writeManifest(): Promise<void> {
  const glob = new Bun.Glob('*.png');
  const keys: string[] = [];
  for await (const file of glob.scan({ cwd: SPRITES_DIR })) {
    if (file.startsWith('_') || file.includes('/')) continue;
    keys.push(file.replace(/\.png$/, ''));
  }
  keys.sort();
  await Bun.write(join(SPRITES_DIR, 'manifest.json'), `${JSON.stringify({ keys }, null, 2)}\n`);
}

const args = parseArgs(process.argv.slice(2));
if (args.list) {
  printList();
} else {
  const entries = pickEntries(args);
  if (entries.length === 0) {
    console.log('nothing to generate (all exist; pass --force)');
  } else {
    await assertComfy();
    if (entries.some(isCharacterRef)) await mkdir(REF_DIR, { recursive: true });
    let wroteGame = false;
    for (const entry of entries) {
      const seed = args.seed ?? Math.floor(Math.random() * 1_000_000_000);
      const size = outputSize(entry);
      const dest = destPath(entry);
      console.log(`${entry.key} seed=${seed} ${size}px ${entry.kind}${isCharacterRef(entry) ? ' → _ref' : ''}`);
      const promptId = await queuePrompt(buildPrompt(entry, seed));
      const image = await waitForImage(promptId);
      await Bun.write(dest, toGamePng(await downloadView(image), size));
      console.log(`  wrote ${dest}`);
      if (!isCharacterRef(entry)) wroteGame = true;
    }
    if (wroteGame) await writeManifest();
    const refs = entries.filter(isCharacterRef).length;
    const rest = entries.length - refs;
    if (refs > 0) console.log(`${refs} character ref(s) at ${REF_PX}px in public/sprites/_ref/`);
    if (rest > 0) console.log(`${rest} sprite(s) at game size in public/sprites/`);
  }
}
