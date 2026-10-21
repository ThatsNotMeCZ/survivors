import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

type ModelsConfig = {
  url: string;
  home: string;
};

const ROOT = join(import.meta.dir, '..');
const models = (await Bun.file(join(ROOT, 'tools/comfy/models.json')).json()) as ModelsConfig;

function expandHome(path: string): string {
  return path.startsWith('~/') ? join(homedir(), path.slice(2)) : path;
}

const comfyHome = expandHome(process.env.COMFYUI_HOME ?? models.home);
const comfyUrl = (process.env.COMFYUI_URL ?? models.url).replace(/\/$/, '');
const parsed = new URL(comfyUrl);
const host = parsed.hostname || '127.0.0.1';
const port = parsed.port || '8188';
const python = join(comfyHome, '.venv/bin/python');
const mainPy = join(comfyHome, 'main.py');

async function alreadyUp(): Promise<boolean> {
  try {
    const res = await fetch(`${comfyUrl}/system_stats`);
    return res.ok;
  } catch {
    return false;
  }
}

if (await alreadyUp()) {
  console.log(`ComfyUI already running at ${comfyUrl}`);
  process.exit(0);
}

if (!existsSync(mainPy)) {
  throw new Error(`ComfyUI main.py missing at ${mainPy}. Set COMFYUI_HOME.`);
}
if (!existsSync(python)) {
  throw new Error(`ComfyUI venv missing at ${python}. Create ~/ComfyUI/.venv first.`);
}

console.log(`starting ComfyUI ${comfyHome} → ${comfyUrl}`);
const child = Bun.spawn([python, 'main.py', '--listen', host, '--port', port], {
  cwd: comfyHome,
  stdin: 'inherit',
  stdout: 'inherit',
  stderr: 'inherit',
});
const code = await child.exited;
process.exit(code);
