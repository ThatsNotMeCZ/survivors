import { existsSync } from 'node:fs';
import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { PNG } from 'pngjs';

type WorkflowNode = {
  class_type: string;
  inputs: Record<string, unknown>;
};

type Workflow = Record<string, WorkflowNode>;

type SpriteKind = 'ref' | 'walk' | 'icon' | 'env';
type SpriteView = 'front' | 'side';
type WalkFrame = 0 | 1 | 2;

const SPRITE_VIEWS: readonly SpriteView[] = ['front', 'side'];
const ALL_IDS = '*';

function isSpriteView(value: string): value is SpriteView {
  return (SPRITE_VIEWS as readonly string[]).includes(value);
}

type SpriteEntry = {
  key: string;
  kind: SpriteKind;
  view?: SpriteView;
  frame?: WalkFrame;
  from?: string;
  size: number;
  prompt: string;
  negative?: string;
  biome?: string;
  vessel?: string;
  item?: string;
  skill?: string;
  identity?: string;
};

type SpriteCatalog = {
  styleSuffix: string;
  refStyleSuffix?: string;
  itemStyleSuffix?: string;
  skillStyleSuffix?: string;
  identities?: Record<string, string>;
  entries: SpriteEntry[];
};

type ModelsConfig = {
  url: string;
  checkpoint: string;
  lora: string;
  loraStrength: number;
  controlnet?: string;
  controlnetStrength?: number;
  walkDenoise?: number;
};

type Args = {
  keys: string[];
  seed: number | null;
  vessel: string | null;
  item: string | null;
  skill: string | null;
  kind: SpriteKind | null;
  view: SpriteView | null;
  list: boolean;
  force: boolean;
  fromRef: boolean;
  refOnly: boolean;
};

type Job = {
  entry: SpriteEntry;
  runComfy: boolean;
  writeGame: boolean;
};

const ROOT = join(import.meta.dir, '..');
const SPRITES_DIR = join(ROOT, 'public/sprites');
const REF_DIR = join(SPRITES_DIR, '_ref');
const ITEM_REF_DIR = join(REF_DIR, 'items');
const SKILL_REF_DIR = join(REF_DIR, 'skills');
const POLL_MS = 500;
const TIMEOUT_MS = 240_000;
const SAVE_NODE = '9';
const SCALE_NODE = '8';
const DECODE_NODE = '7';
const CHROMA_PX = 128;
const REF_PX = 1024;
const REF_STEPS = 32;
const WALK_DENOISE = 0.55;
const CN_STRENGTH = 0.72;
const QUALITY_NEG =
  'photorealistic, 3d render, blur, antialias, smooth shading, cinematic, multiple characters, text, watermark, portrait photo';

const catalog = (await Bun.file(join(ROOT, 'tools/comfy/sprites.json')).json()) as SpriteCatalog;
const models = (await Bun.file(join(ROOT, 'tools/comfy/models.json')).json()) as ModelsConfig;
const txtWorkflow = (await Bun.file(
  join(ROOT, 'tools/comfy/workflows/sprite-txt2img-api.json'),
).json()) as Workflow;
const walkWorkflow = (await Bun.file(
  join(ROOT, 'tools/comfy/workflows/sprite-walk-controlnet-api.json'),
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
  let skill: string | null = null;
  let kind: SpriteKind | null = null;
  let view: SpriteView | null = null;
  let list = false;
  let force = false;
  let fromRef = false;
  let refOnly = false;
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--force') {
      force = true;
      continue;
    }
    if (arg === '--from-ref') {
      fromRef = true;
      continue;
    }
    if (arg === '--ref-only') {
      refOnly = true;
      continue;
    }
    if (arg === '--list') {
      list = true;
      continue;
    }
    if (arg === '--ref' || arg === '--ref-front' || arg === '--front') {
      kind = 'ref';
      view = 'front';
      continue;
    }
    if (arg === '--left' || arg === '--right' || arg === '--back') {
      throw new Error(`${arg} is gone. Front idle only: bun run art:ref -- runner`);
    }
    if (arg === '--icon') {
      kind = 'icon';
      continue;
    }
    if (arg === '--walk') {
      kind = 'walk';
      continue;
    }
    if (arg === '--env') {
      kind = 'env';
      continue;
    }
    if (arg === '--view') {
      const value = flagValue(argv, i);
      if (!value) throw new Error('--view needs front or side');
      if (!isSpriteView(value)) throw new Error(`bad --view ${value} (use front or side)`);
      view = value;
      if (!kind) kind = 'ref';
      i += 1;
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
    if (arg === '--item' || arg === '--item-ref') {
      const value = flagValue(argv, i);
      kind = 'icon';
      if (arg === '--item-ref') refOnly = true;
      if (!value) {
        item = ALL_IDS;
        continue;
      }
      item = value;
      i += 1;
      continue;
    }
    if (arg === '--skill' || arg === '--skill-ref') {
      const value = flagValue(argv, i);
      kind = 'icon';
      if (arg === '--skill-ref') refOnly = true;
      if (!value) {
        skill = ALL_IDS;
        continue;
      }
      skill = value;
      i += 1;
      continue;
    }
    if (arg === '--all' || arg === '--entity' || arg === '--lock' || arg === '--import' || arg === '--views') {
      throw new Error(
        `${arg} is gone. bun run art:ref -- runner   or   bun run art:walk -- runner`,
      );
    }
    throw new Error(
      `unknown arg ${arg} (use --ref, --walk, --view, --vessel, --item, --item-ref, --skill, --skill-ref, --icon, --env, --key, --seed, --force, --from-ref, --ref-only, --list)`,
    );
  }
  if ((kind === 'ref' || kind === 'walk') && !vessel) vessel = 'runner';
  if ((fromRef || refOnly) && !item && !skill && keys.length === 0) item = ALL_IDS;
  if (item && skill) {
    throw new Error('pick --item or --skill, not both');
  }
  if (fromRef && refOnly) {
    throw new Error(
      '--from-ref writes the 24px icon; --item-ref / --skill-ref / --ref-only writes the 1024 ref. Pick one.',
    );
  }
  return { keys, seed, vessel, item, skill, kind, view, list, force, fromRef, refOnly };
}

function isWalk(entry: SpriteEntry): boolean {
  return entry.kind === 'walk';
}

function isCharacterRef(entry: SpriteEntry): boolean {
  return entry.kind === 'ref' || isWalk(entry);
}

function isItemEntry(entry: SpriteEntry): boolean {
  return Boolean(entry.item);
}

function isSkillEntry(entry: SpriteEntry): boolean {
  return Boolean(entry.skill);
}

function isObjectIcon(entry: SpriteEntry): boolean {
  return isItemEntry(entry) || isSkillEntry(entry);
}

function objectKindOf(entry: SpriteEntry): 'item' | 'skill' {
  if (entry.item) return 'item';
  if (entry.skill) return 'skill';
  throw new Error(`object kind needs item or skill (${entry.key})`);
}

function objectIdOf(entry: SpriteEntry): string {
  const id = entry.item ?? entry.skill;
  if (!id) throw new Error(`object id missing (${entry.key})`);
  return id;
}

function needsControlNet(entry: SpriteEntry): boolean {
  return isWalk(entry);
}

function usesRefPass(entry: SpriteEntry): boolean {
  return isCharacterRef(entry) || isObjectIcon(entry);
}

function destPath(entry: SpriteEntry): string {
  return join(isCharacterRef(entry) ? REF_DIR : SPRITES_DIR, `${entry.key}.png`);
}

function objectRefPath(entry: SpriteEntry): string {
  const dir = isSkillEntry(entry) ? SKILL_REF_DIR : ITEM_REF_DIR;
  return join(dir, `${objectIdOf(entry)}.png`);
}

function gamePath(entry: SpriteEntry): string {
  return join(SPRITES_DIR, `${entry.key}.png`);
}

function outputSize(entry: SpriteEntry): number {
  return usesRefPass(entry) ? REF_PX : entry.size;
}

function knownObjectIds(kind: 'item' | 'skill'): string {
  return catalog.entries
    .map((entry) => (kind === 'item' ? entry.item : entry.skill))
    .filter((id): id is string => Boolean(id))
    .join(', ');
}

function printList(): void {
  console.log(`refs (--vessel <id>) → public/sprites/_ref/ at ${REF_PX}px:`);
  for (const entry of catalog.entries.filter((row) => row.kind === 'ref')) {
    console.log(`  ${entry.vessel}  ${entry.view ?? 'front'}  ${entry.key}`);
  }
  console.log(`\nwalk (--walk --vessel <id>) ControlNet OpenPose from idle → _ref/:`);
  for (const entry of catalog.entries.filter(isWalk)) {
    console.log(`  ${entry.vessel}  frame ${entry.frame ?? 0}  ${entry.key}`);
  }
  console.log(`\nitem icons (--item [id] both steps, --item-ref 1024 only) → _ref/items/{id}.png ${REF_PX}px then public/sprites/ 24px:`);
  for (const entry of catalog.entries.filter(isItemEntry)) {
    console.log(`  ${entry.item}  ${entry.key}  ${entry.size}px`);
  }
  console.log(`\nskill icons (--skill [id] both steps, --skill-ref 1024 only) → _ref/skills/{id}.png ${REF_PX}px then public/sprites/ 24px:`);
  for (const entry of catalog.entries.filter(isSkillEntry)) {
    console.log(`  ${entry.skill}  ${entry.key}  ${entry.size}px`);
  }
  const portraits = catalog.entries.filter((row) => row.kind === 'icon' && !isObjectIcon(row));
  if (portraits.length > 0) {
    console.log('\nportraits (--icon) → public/sprites/:');
    for (const entry of portraits) {
      console.log(`  ${entry.key}  ${entry.size}px`);
    }
  }
  const envs = catalog.entries.filter((row) => row.kind === 'env');
  if (envs.length > 0) {
    console.log('\nenv:');
    for (const entry of envs) console.log(`  ${entry.key}  ${entry.size}px`);
  }
}

function selectEntries(args: Args): SpriteEntry[] {
  if (args.keys.length > 0) {
    return args.keys.map((key) => {
      const hit = byKey.get(key);
      if (!hit) throw new Error(`unknown sprite key ${key}`);
      return hit;
    });
  }
  if (args.item) {
    const selected = catalog.entries.filter((entry) =>
      args.item === ALL_IDS ? isItemEntry(entry) : entry.item === args.item,
    );
    if (args.item !== ALL_IDS && selected.length === 0) {
      throw new Error(`unknown --item ${args.item}. Known: ${knownObjectIds('item')}`);
    }
    return selected;
  }
  if (args.skill) {
    const selected = catalog.entries.filter((entry) =>
      args.skill === ALL_IDS ? isSkillEntry(entry) : entry.skill === args.skill,
    );
    if (args.skill !== ALL_IDS && selected.length === 0) {
      throw new Error(`unknown --skill ${args.skill}. Known: ${knownObjectIds('skill')}`);
    }
    return selected;
  }
  if (args.kind === 'ref' || args.kind === 'walk') {
    const selected = catalog.entries.filter(
      (entry) =>
        entry.kind === args.kind &&
        (!args.vessel || entry.vessel === args.vessel) &&
        (!args.view || entry.view === args.view),
    );
    if (selected.length === 0) {
      throw new Error(
        `no ${args.kind}s for vessel=${args.vessel ?? '*'}. bun run art:list`,
      );
    }
    return selected;
  }
  if (args.kind) {
    return catalog.entries.filter((entry) => entry.kind === args.kind);
  }
  if (args.vessel) {
    const selected = catalog.entries.filter(
      (entry) =>
        entry.kind === 'ref' &&
        entry.vessel === args.vessel &&
        (!args.view || entry.view === args.view),
    );
    if (selected.length === 0) {
      throw new Error(
        `no refs for vessel=${args.vessel} view=${args.view ?? '*'}. bun run art:list`,
      );
    }
    return selected;
  }
  return [...catalog.entries];
}

function objectJob(entry: SpriteEntry, args: Args): Job | null {
  const ref = objectRefPath(entry);
  const game = gamePath(entry);
  const refExists = existsSync(ref);
  const gameExists = existsSync(game);
  const kind = objectKindOf(entry);
  if (args.fromRef) {
    if (!refExists) {
      throw new Error(
        `missing ${kind} ref ${ref}. Generate first: bun run art:${kind}-ref -- ${objectIdOf(entry)}`,
      );
    }
    return { entry, runComfy: false, writeGame: true };
  }
  if (args.refOnly) {
    if (refExists && !args.force) return null;
    return { entry, runComfy: true, writeGame: false };
  }
  if (args.force || !refExists) {
    return { entry, runComfy: true, writeGame: true };
  }
  if (!gameExists) {
    return { entry, runComfy: false, writeGame: true };
  }
  return null;
}

function pickJobs(args: Args): Job[] {
  const jobs: Job[] = [];
  for (const entry of selectEntries(args)) {
    if (isObjectIcon(entry)) {
      const job = objectJob(entry, args);
      if (!job) {
        console.log(`skip ${entry.key} (exists, pass --force)`);
        continue;
      }
      jobs.push(job);
      continue;
    }
    if (args.fromRef) {
      console.log(`skip ${entry.key} (--from-ref is item/skill-only)`);
      continue;
    }
    if (args.refOnly) {
      console.log(`skip ${entry.key} (--item-ref / --skill-ref is item/skill-only)`);
      continue;
    }
    const dest = destPath(entry);
    if (existsSync(dest) && !args.force) {
      console.log(`skip ${entry.key} (exists, pass --force)`);
      continue;
    }
    jobs.push({ entry, runComfy: true, writeGame: !isCharacterRef(entry) });
  }
  return jobs;
}

function promptText(entry: SpriteEntry): string {
  const parts: string[] = [entry.prompt];
  if (entry.identity) {
    const identity = catalog.identities?.[entry.identity];
    if (!identity) throw new Error(`unknown identity ${entry.identity}`);
    parts.push(identity);
  }
  const style = isSkillEntry(entry)
    ? (catalog.skillStyleSuffix ?? catalog.itemStyleSuffix ?? catalog.styleSuffix)
    : isItemEntry(entry)
      ? (catalog.itemStyleSuffix ?? catalog.styleSuffix)
      : isCharacterRef(entry) || isWalk(entry)
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

async function assertControlNet(): Promise<void> {
  const cn = models.controlnet;
  if (!cn) throw new Error('models.json missing controlnet filename');
  const nets = namesOf(await comfyJson('/models/controlnet'));
  if (!hasModel(nets, cn)) {
    throw new Error(
      `missing ControlNet ${cn}. Run bun run art:download and restart ComfyUI (bun run art:comfy).`,
    );
  }
}

function buildPrompt(entry: SpriteEntry, seed: number): Workflow {
  const graph = structuredClone(txtWorkflow);
  const ckpt = graph['1']?.inputs;
  const lora = graph['2']?.inputs;
  const positive = graph['3']?.inputs;
  const sampler = graph['6']?.inputs;
  const save = graph[SAVE_NODE]?.inputs;
  if (!ckpt || !lora || !positive || !sampler || !save) {
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
  if (usesRefPass(entry)) {
    sampler.steps = REF_STEPS;
    save.images = [DECODE_NODE, 0];
    save.filename_prefix = isObjectIcon(entry)
      ? `hermetic/ref/${objectKindOf(entry)}s/${objectIdOf(entry)}`
      : `hermetic/ref/${entry.key}`;
    delete graph[SCALE_NODE];
  } else {
    const scale = graph[SCALE_NODE]?.inputs;
    if (!scale) throw new Error('workflow JSON is missing scale node');
    scale.width = CHROMA_PX;
    scale.height = CHROMA_PX;
    save.filename_prefix = `hermetic/${entry.key}`;
  }
  return graph;
}

async function buildWalkPrompt(entry: SpriteEntry, seed: number): Promise<Workflow> {
  const idleFile = idleSourcePath(entry);
  if (!existsSync(idleFile)) {
    throw new Error(`walk needs idle ref first: ${idleFile}. bun run art:ref -- ${entry.vessel ?? 'runner'}`);
  }
  const idlePng = PNG.sync.read(Buffer.from(await Bun.file(idleFile).arrayBuffer()));
  const frame = (entry.frame ?? 0) as WalkFrame;
  const idleName = await uploadPng(`hermetic-idle-${entry.from}.png`, flattenOnWhite(idlePng));
  const poseName = await uploadPng(`hermetic-pose-${entry.key}.png`, drawWalkPose(idlePng, frame));
  const graph = structuredClone(walkWorkflow);
  const ckpt = graph['1']?.inputs;
  const lora = graph['2']?.inputs;
  const positive = graph['3']?.inputs;
  const sampler = graph['6']?.inputs;
  const save = graph[SAVE_NODE]?.inputs;
  const idleLoad = graph['10']?.inputs;
  const poseLoad = graph['11']?.inputs;
  const cnLoad = graph['12']?.inputs;
  const cnApply = graph['13']?.inputs;
  if (!ckpt || !lora || !positive || !sampler || !save || !idleLoad || !poseLoad || !cnLoad || !cnApply) {
    throw new Error('walk workflow JSON is missing required nodes');
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
  idleLoad.image = idleName;
  poseLoad.image = poseName;
  cnLoad.control_net_name = models.controlnet ?? 'controlnet-openpose-sdxl.safetensors';
  cnApply.strength = models.controlnetStrength ?? CN_STRENGTH;
  sampler.seed = seed;
  sampler.steps = REF_STEPS;
  sampler.denoise = models.walkDenoise ?? WALK_DENOISE;
  save.filename_prefix = `hermetic/ref/${entry.key}`;
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

function borderBackdrop(png: PNG): { r: number; g: number; b: number } | null {
  const { width, height, data } = png;
  const samples = [0, (width - 1) << 2, ((height - 1) * width) << 2, ((height - 1) * width + (width - 1)) << 2];
  let r = 0;
  let g = 0;
  let b = 0;
  for (const off of samples) {
    r += data[off];
    g += data[off + 1];
    b += data[off + 2];
  }
  r = (r / 4) | 0;
  g = (g / 4) | 0;
  b = (b / 4) | 0;
  for (const off of samples) {
    if (Math.abs(data[off] - r) + Math.abs(data[off + 1] - g) + Math.abs(data[off + 2] - b) > 30) return null;
  }
  return { r, g, b };
}

function isBackground(data: Buffer, offset: number, key: { r: number; g: number; b: number } | null): boolean {
  const a = data[offset + 3];
  if (a === 0) return true;
  const r = data[offset];
  const g = data[offset + 1];
  const b = data[offset + 2];
  if (r >= 245 && g >= 245 && b >= 245) return true;
  if (!key) return false;
  return Math.abs(r - key.r) + Math.abs(g - key.g) + Math.abs(b - key.b) <= 36;
}

function isSandPixel(data: Buffer, offset: number): boolean {
  const r = data[offset];
  const g = data[offset + 1];
  const b = data[offset + 2];
  const v = Math.max(r, g, b);
  const c = v - Math.min(r, g, b);
  if (v >= 140 && r > b + 12 && r >= g - 8 && c <= 90) return true;
  return v >= 130 && v <= 210 && c <= 24;
}

function chromaKeySand(png: PNG): void {
  const { width, height, data } = png;
  const seen = new Uint8Array(width * height);
  const stack: number[] = [];
  const push = (x: number, y: number): void => {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const p = y * width + x;
    if (seen[p]) return;
    seen[p] = 1;
    const off = p << 2;
    if (data[off + 3] === 0) return;
    if (!isSandPixel(data, off)) return;
    stack.push(p);
  };
  const y0 = Math.floor(height * 0.78);
  for (let y = y0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) push(x, y);
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

function chromaKeyWhite(png: PNG): void {
  const { width, height, data } = png;
  const key = borderBackdrop(png);
  const seen = new Uint8Array(width * height);
  const stack: number[] = [];
  const push = (x: number, y: number): void => {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const p = y * width + x;
    if (seen[p]) return;
    seen[p] = 1;
    if (!isBackground(data, p << 2, key)) return;
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

type Pt = { x: number; y: number };

function setRgb(png: PNG, x: number, y: number, r: number, g: number, b: number): void {
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const i = (y * png.width + x) << 2;
  png.data[i] = r;
  png.data[i + 1] = g;
  png.data[i + 2] = b;
  png.data[i + 3] = 255;
}

function stampDisk(png: PNG, cx: number, cy: number, radius: number, rgb: [number, number, number]): void {
  const r0 = Math.max(1, Math.round(radius));
  for (let y = -r0; y <= r0; y += 1) {
    for (let x = -r0; x <= r0; x += 1) {
      if (x * x + y * y > r0 * r0) continue;
      setRgb(png, Math.round(cx) + x, Math.round(cy) + y, rgb[0], rgb[1], rgb[2]);
    }
  }
}

function stampBone(png: PNG, a: Pt, b: Pt, rgb: [number, number, number], width: number): void {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const steps = Math.max(1, Math.ceil(Math.hypot(dx, dy)));
  for (let i = 0; i <= steps; i += 1) {
    const t = i / steps;
    stampDisk(png, a.x + dx * t, a.y + dy * t, width / 2, rgb);
  }
}

function walkSkeleton(box: { x: number; y: number; w: number; h: number }, frame: WalkFrame): Record<string, Pt> {
  const cx = box.x + box.w * 0.52;
  const head = { x: cx + box.w * 0.04, y: box.y + box.h * 0.1 };
  const neck = { x: cx, y: box.y + box.h * 0.22 };
  const hip = { x: cx - box.w * 0.02, y: box.y + box.h * 0.55 };
  const shoulder = { x: cx, y: box.y + box.h * 0.28 };
  const stride = box.w * (frame === 1 ? 0.08 : 0.24);
  const fwd = frame === 0 ? stride : frame === 2 ? -stride : 0;
  const lift = frame === 1 ? box.h * 0.07 : 0;
  const rLeg = fwd;
  const lLeg = -fwd;
  return {
    head,
    neck,
    hip,
    rShoulder: { x: shoulder.x + 4, y: shoulder.y },
    lShoulder: { x: shoulder.x - 4, y: shoulder.y },
    rElbow: { x: shoulder.x - rLeg * 0.55, y: shoulder.y + box.h * 0.14 },
    lElbow: { x: shoulder.x - lLeg * 0.55, y: shoulder.y + box.h * 0.14 },
    rWrist: { x: shoulder.x - rLeg * 1.05, y: shoulder.y + box.h * 0.26 },
    lWrist: { x: shoulder.x - lLeg * 1.05, y: shoulder.y + box.h * 0.26 },
    rKnee: { x: hip.x + rLeg * 0.55, y: hip.y + box.h * 0.18 - (rLeg > 0 ? 0 : lift) },
    lKnee: { x: hip.x + lLeg * 0.55, y: hip.y + box.h * 0.18 - (lLeg > 0 ? 0 : lift) },
    rAnkle: { x: hip.x + rLeg, y: box.y + box.h * 0.94 - (rLeg > 0 ? 0 : lift) },
    lAnkle: { x: hip.x + lLeg, y: box.y + box.h * 0.94 - (lLeg > 0 ? 0 : lift) },
  };
}

function stampOpenPose(pose: PNG, k: Record<string, Pt>, bone: number): void {
  const orange: [number, number, number] = [255, 128, 0];
  const cyan: [number, number, number] = [0, 255, 255];
  const green: [number, number, number] = [0, 255, 0];
  const pink: [number, number, number] = [255, 0, 255];
  stampBone(pose, k.head, k.neck, orange, bone);
  stampBone(pose, k.neck, k.hip, orange, bone);
  stampBone(pose, k.rShoulder, k.rElbow, green, bone);
  stampBone(pose, k.rElbow, k.rWrist, green, bone);
  stampBone(pose, k.lShoulder, k.lElbow, pink, bone);
  stampBone(pose, k.lElbow, k.lWrist, pink, bone);
  stampBone(pose, k.hip, k.rKnee, cyan, bone);
  stampBone(pose, k.rKnee, k.rAnkle, cyan, bone);
  stampBone(pose, k.hip, k.lKnee, [0, 85, 255], bone);
  stampBone(pose, k.lKnee, k.lAnkle, [0, 85, 255], bone);
  stampDisk(pose, k.head.x, k.head.y, bone * 1.6, orange);
  stampDisk(pose, k.head.x + bone * 0.7, k.head.y + bone * 0.2, bone * 0.5, [255, 0, 0]);
}

function opaqueBlackPose(width: number, height: number): PNG {
  const pose = new PNG({ width, height });
  for (let i = 0; i < pose.data.length; i += 4) {
    pose.data[i] = 0;
    pose.data[i + 1] = 0;
    pose.data[i + 2] = 0;
    pose.data[i + 3] = 255;
  }
  return pose;
}

function drawWalkPose(idle: PNG, frame: WalkFrame): Buffer {
  const pose = opaqueBlackPose(idle.width, idle.height);
  const box = opaqueBounds(idle) ?? { x: idle.width * 0.3, y: idle.height * 0.1, w: idle.width * 0.4, h: idle.height * 0.8 };
  const k = walkSkeleton(box, frame);
  const bone = Math.max(10, Math.round(Math.min(box.w, box.h) * 0.035));
  stampOpenPose(pose, k, bone);
  return PNG.sync.write(pose);
}

function flattenOnWhite(png: PNG): Buffer {
  const out = new PNG({ width: png.width, height: png.height });
  for (let i = 0; i < png.data.length; i += 4) {
    const a = png.data[i + 3] / 255;
    out.data[i] = Math.round(png.data[i] * a + 255 * (1 - a));
    out.data[i + 1] = Math.round(png.data[i + 1] * a + 255 * (1 - a));
    out.data[i + 2] = Math.round(png.data[i + 2] * a + 255 * (1 - a));
    out.data[i + 3] = 255;
  }
  return PNG.sync.write(out);
}

async function uploadPng(filename: string, bytes: Buffer): Promise<string> {
  const form = new FormData();
  form.append('image', new Blob([new Uint8Array(bytes)], { type: 'image/png' }), filename);
  form.append('overwrite', 'true');
  const res = await fetch(`${comfyUrl}/upload/image`, { method: 'POST', body: form });
  const body = (await res.json()) as { name?: string };
  if (!res.ok || !body.name) throw new Error(`upload ${filename} failed: ${res.status}`);
  return body.name;
}

function idleSourcePath(entry: SpriteEntry): string {
  const key = entry.from;
  if (!key) throw new Error(`walk ${entry.key} missing "from" idle key`);
  return join(REF_DIR, `${key}.png`);
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

function toRefPng(raw: Buffer): Buffer {
  return flattenOnWhite(PNG.sync.read(raw));
}

function toGamePng(raw: Buffer, size: number): Buffer {
  const png = PNG.sync.read(raw);
  chromaKeyWhite(png);
  chromaKeySand(png);
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

async function generateFromComfy(entry: SpriteEntry, seed: number): Promise<Buffer> {
  const size = outputSize(entry);
  const kindLabel = isObjectIcon(entry) ? objectKindOf(entry) : entry.kind;
  const destHint = isObjectIcon(entry)
    ? ` → _ref/${objectKindOf(entry)}s/${objectIdOf(entry)}.png`
    : isCharacterRef(entry)
      ? ' → _ref'
      : '';
  console.log(
    `${entry.key} seed=${seed} ${size}px ${kindLabel}${entry.view ? `/${entry.view}` : ''}${destHint}`,
  );
  const promptId = await queuePrompt(
    isWalk(entry) ? await buildWalkPrompt(entry, seed) : buildPrompt(entry, seed),
  );
  const image = await waitForImage(promptId);
  return downloadView(image);
}

if (import.meta.main) {
const args = parseArgs(process.argv.slice(2));
if (args.list) {
  printList();
} else {
  const jobs = pickJobs(args);
  if (jobs.length === 0) {
    console.log('nothing to generate (all exist; pass --force)');
  } else {
    if (jobs.some((job) => job.runComfy)) {
      await assertComfy();
      if (jobs.some((job) => needsControlNet(job.entry))) await assertControlNet();
    }
    if (jobs.some((job) => isCharacterRef(job.entry))) await mkdir(REF_DIR, { recursive: true });
    if (jobs.some((job) => isItemEntry(job.entry))) await mkdir(ITEM_REF_DIR, { recursive: true });
    if (jobs.some((job) => isSkillEntry(job.entry))) await mkdir(SKILL_REF_DIR, { recursive: true });
    let wroteGame = false;
    let itemRefs = 0;
    let skillRefs = 0;
    let charRefs = 0;
    let gameSprites = 0;
    for (const job of jobs) {
      const { entry } = job;
      if (isObjectIcon(entry)) {
        let raw: Buffer;
        if (job.runComfy) {
          const seed = args.seed ?? Math.floor(Math.random() * 1_000_000_000);
          raw = await generateFromComfy(entry, seed);
          const refDest = objectRefPath(entry);
          await Bun.write(refDest, toRefPng(raw));
          console.log(`  wrote ${refDest}`);
          if (isSkillEntry(entry)) skillRefs += 1;
          else itemRefs += 1;
        } else {
          const refDest = objectRefPath(entry);
          console.log(`${entry.key} from-ref ${refDest} → ${entry.size}px`);
          raw = Buffer.from(await Bun.file(refDest).arrayBuffer());
        }
        if (job.writeGame) {
          const dest = gamePath(entry);
          await Bun.write(dest, toGamePng(raw, entry.size));
          console.log(`  wrote ${dest}`);
          wroteGame = true;
          gameSprites += 1;
        }
        continue;
      }
      const seed = args.seed ?? Math.floor(Math.random() * 1_000_000_000);
      const dest = destPath(entry);
      const raw = await generateFromComfy(entry, seed);
      await Bun.write(
        dest,
        isCharacterRef(entry) ? toRefPng(raw) : toGamePng(raw, outputSize(entry)),
      );
      console.log(`  wrote ${dest}`);
      if (isCharacterRef(entry)) charRefs += 1;
      else {
        wroteGame = true;
        gameSprites += 1;
      }
    }
    if (wroteGame) await writeManifest();
    if (charRefs > 0) console.log(`${charRefs} character ref(s) at ${REF_PX}px in public/sprites/_ref/`);
    if (itemRefs > 0) console.log(`${itemRefs} item ref(s) at ${REF_PX}px in public/sprites/_ref/items/`);
    if (skillRefs > 0) console.log(`${skillRefs} skill ref(s) at ${REF_PX}px in public/sprites/_ref/skills/`);
    if (gameSprites > 0) console.log(`${gameSprites} sprite(s) at game size in public/sprites/`);
  }
}
}
