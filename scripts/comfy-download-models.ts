import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { mkdir, rename } from 'node:fs/promises';

type ModelFile = {
  role: string;
  filename: string;
  dir: string;
  url: string;
  fallbackUrl?: string;
  civitaiFallback?: boolean;
  minBytes: number;
};

type ModelsConfig = {
  home: string;
  files: ModelFile[];
};

const ROOT = join(import.meta.dir, '..');
const config = (await Bun.file(join(ROOT, 'tools/comfy/models.json')).json()) as ModelsConfig;
const comfyHome = expandHome(process.env.COMFYUI_HOME ?? config.home);

function expandHome(path: string): string {
  return path.startsWith('~/') ? join(homedir(), path.slice(2)) : path;
}

async function alreadyHave(file: ModelFile): Promise<boolean> {
  const dest = join(comfyHome, file.dir, file.filename);
  const blob = Bun.file(dest);
  if (!(await blob.exists())) return false;
  if (blob.size < file.minBytes) {
    console.log(`incomplete ${file.filename} (${blob.size} bytes), re-downloading`);
    return false;
  }
  console.log(`skip ${file.filename} (${blob.size} bytes)`);
  return true;
}

function requestHeaders(civitai: boolean): Record<string, string> {
  const headers: Record<string, string> = {
    'User-Agent': 'survivors-art-download',
  };
  if (civitai && process.env.CIVITAI_TOKEN) {
    headers.Authorization = `Bearer ${process.env.CIVITAI_TOKEN}`;
  }
  return headers;
}

async function openDownload(file: ModelFile): Promise<Response> {
  const attempts: { url: string; civitai: boolean }[] = [{ url: file.url, civitai: false }];
  if (file.fallbackUrl) attempts.push({ url: file.fallbackUrl, civitai: Boolean(file.civitaiFallback) });
  let lastError = '';
  for (const attempt of attempts) {
    console.log(`GET ${attempt.url}`);
    const res = await fetch(attempt.url, { headers: requestHeaders(attempt.civitai), redirect: 'follow' });
    if (res.ok && res.body) return res;
    lastError = `${attempt.url} -> ${res.status} ${res.statusText}`;
    console.log(`  failed ${lastError}`);
  }
  throw new Error(lastError || `could not download ${file.filename}`);
}

async function download(file: ModelFile): Promise<void> {
  const dest = join(comfyHome, file.dir, file.filename);
  await mkdir(dirname(dest), { recursive: true });
  const res = await openDownload(file);
  if (!res.body) throw new Error(`${file.filename}: empty body`);
  const total = Number(res.headers.get('content-length') ?? 0);
  const part = `${dest}.part`;
  const writer = Bun.file(part).writer();
  const reader = res.body.getReader();
  let got = 0;
  let lastPct = -1;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    writer.write(value);
    got += value.byteLength;
    if (total > 0) {
      const pct = Math.floor((got / total) * 100);
      if (pct >= lastPct + 5) {
        lastPct = pct;
        console.log(`  ${file.filename} ${pct}%`);
      }
    }
  }
  await writer.end();
  if (got < file.minBytes) {
    throw new Error(`${file.filename} too small (${got} bytes)`);
  }
  await rename(part, dest);
  console.log(`wrote ${dest} (${got} bytes)`);
}

let missing = 0;
for (const file of config.files) {
  if (await alreadyHave(file)) continue;
  missing += 1;
  await download(file);
}
if (missing === 0) {
  console.log(`all models present in ${comfyHome}`);
} else {
  console.log(`downloaded ${missing} file(s) into ${comfyHome}`);
  console.log('restart ComfyUI if it was already running so it sees new files');
}
