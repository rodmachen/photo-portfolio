/**
 * Cloudinary sync CLI — mirrors a local Lightroom export tree to Cloudinary and
 * (optionally) triggers a Vercel rebuild. Run via `npm run sync` (tsx).
 *
 *   npm run sync -- --dry-run --root "<export-root>"
 *   npm run sync -- --root "<export-root>" --filter atx-open-2023
 *   npm run sync -- --root "<export-root>" --delete --deploy
 *
 * The diff logic lives in the pure, unit-tested modules `lib/local-walk.ts`
 * (build the local inventory) and `lib/sync-plan.ts` (classify uploads /
 * updates / deletes / unchanged). This file is the imperative shell: argument
 * parsing, Cloudinary I/O, and human-readable reporting.
 *
 * Flags:
 *   --dry-run            Print the plan, perform NO writes.
 *   --delete             Allow deletion of remote-only assets (off by default).
 *   --deploy             POST VERCEL_DEPLOY_HOOK_URL, but only if something changed.
 *   --root <path>        Export root (default: the iCloud Photos export path).
 *   --preset <name>      Preset subfolder to mirror (default: portfolio, per D4).
 *   --filter <substring> Only act on assets whose public_id contains <substring>.
 *                        Use this to scope a first real run to one collection.
 *
 * Authorization note: deletions require --delete; without it, remote-only assets
 * are reported but never removed. This keeps legacy UI-uploaded assets (which
 * carry random public_id suffixes) safe during normal runs.
 */

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import process from 'node:process';
import { v2 as cloudinary } from 'cloudinary';
import {
  walkExportTree,
  DEFAULT_PRESET,
  DEFAULT_ROOT_FOLDER,
  type LocalAsset,
} from './lib/local-walk';
import {
  computeSyncPlan,
  type RemoteAsset,
  type SyncPlan,
} from './lib/sync-plan';

/** Default export root: the plugin's iCloud Drive target (see the export spec). */
const DEFAULT_EXPORT_ROOT = path.join(
  os.homedir(),
  'Library/Mobile Documents/com~apple~CloudDocs/Photos',
);

interface CliArgs {
  dryRun: boolean;
  delete: boolean;
  deploy: boolean;
  root: string;
  preset: string;
  filter?: string;
}

function parseArgs(argv: string[]): CliArgs {
  const args: CliArgs = {
    dryRun: false,
    delete: false,
    deploy: false,
    root: DEFAULT_EXPORT_ROOT,
    preset: DEFAULT_PRESET,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case '--dry-run':
        args.dryRun = true;
        break;
      case '--delete':
        args.delete = true;
        break;
      case '--deploy':
        args.deploy = true;
        break;
      case '--root':
        args.root = expandHome(argv[++i] ?? '');
        break;
      case '--preset':
        args.preset = argv[++i] ?? DEFAULT_PRESET;
        break;
      case '--filter':
        args.filter = argv[++i];
        break;
      default:
        console.error(`Unknown argument: ${a}`);
        process.exit(2);
    }
  }
  return args;
}

/** Expand a leading `~` to the user's home directory. */
function expandHome(p: string): string {
  if (p === '~') return os.homedir();
  if (p.startsWith('~/')) return path.join(os.homedir(), p.slice(2));
  return p;
}

/**
 * Minimal .env loader (no dependency). Loads `.env` then `.env.local` from the
 * current working directory; existing process.env values win. The Astro build
 * reads these via `import.meta.env`; this standalone script needs them on
 * `process.env` for the Cloudinary SDK.
 */
function loadDotEnv(): void {
  for (const file of ['.env', '.env.local']) {
    const p = path.resolve(process.cwd(), file);
    if (!fs.existsSync(p)) continue;
    for (const line of fs.readFileSync(p, 'utf8').split('\n')) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (!m) continue;
      const key = m[1];
      let val = m[2].trim();
      if (
        (val.startsWith('"') && val.endsWith('"')) ||
        (val.startsWith("'") && val.endsWith("'"))
      ) {
        val = val.slice(1, -1);
      }
      if (process.env[key] === undefined) process.env[key] = val;
    }
  }
}

function configureCloudinary(): void {
  const cloudName = process.env.PUBLIC_CLOUDINARY_CLOUD_NAME;
  const apiKey =
    process.env.CLOUDINARY_API_KEY ?? process.env.PUBLIC_CLOUDINARY_API_KEY;
  const apiSecret = process.env.CLOUDINARY_API_SECRET;
  if (!cloudName || !apiKey || !apiSecret) {
    console.error(
      'Missing Cloudinary credentials. Set PUBLIC_CLOUDINARY_CLOUD_NAME, ' +
        'CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET in .env.',
    );
    process.exit(1);
  }
  cloudinary.config({
    cloud_name: cloudName,
    api_key: apiKey,
    api_secret: apiSecret,
    secure: true,
  });
}

/**
 * Fetch the managed remote inventory under `photo-portfolio/` via the Admin API
 * `resources` endpoint, paginated with `next_cursor`. The Admin API has
 * friendlier rate limits than the Search API.
 *
 * Note on folder modes: `prefix` filters on `public_id`. Our managed uploads use
 * a deterministic public_id that starts with `photo-portfolio/` (D4), so they
 * are always captured here regardless of folder mode. In DYNAMIC folder mode,
 * legacy UI-uploaded assets carry a random public_id that lacks this prefix
 * (e.g. `atx-open-2025-6959_q3l63c`); those do not appear in this listing (and
 * so are never proposed for deletion — the conservative outcome). To enumerate
 * such assets by folder instead, use
 * `cloudinary.api.resources_by_asset_folder(folder)` per folder.
 */
async function fetchRemoteInventory(): Promise<RemoteAsset[]> {
  const remote: RemoteAsset[] = [];
  let nextCursor: string | undefined;
  do {
    const res = await cloudinary.api.resources({
      type: 'upload',
      resource_type: 'image',
      prefix: `${DEFAULT_ROOT_FOLDER}/`,
      max_results: 500,
      next_cursor: nextCursor,
    });
    for (const r of res.resources as Array<Record<string, unknown>>) {
      remote.push({
        publicId: String(r.public_id),
        etag: typeof r.etag === 'string' ? r.etag : '',
      });
    }
    nextCursor = res.next_cursor;
  } while (nextCursor);
  return remote;
}

/**
 * Detect the account's folder mode (an account-level setting) by sampling a few
 * assets account-wide — NOT from the `photo-portfolio/` prefix listing, which is
 * empty until the first managed upload exists. Assets carrying a non-empty
 * `asset_folder` indicate DYNAMIC folder mode; its absence (folder encoded only
 * in the public_id path) indicates FIXED mode. Read-only.
 */
async function detectFolderMode(): Promise<'dynamic' | 'fixed' | 'unknown'> {
  const res = await cloudinary.api.resources({
    type: 'upload',
    resource_type: 'image',
    max_results: 10,
  });
  const resources = res.resources as Array<Record<string, unknown>>;
  if (resources.length === 0) return 'unknown';
  const anyDynamic = resources.some(
    (r) => typeof r.asset_folder === 'string' && r.asset_folder.length > 0,
  );
  return anyDynamic ? 'dynamic' : 'fixed';
}

function applyFilter(plan: SyncPlan, filter: string): SyncPlan {
  const keepLocal = (a: LocalAsset) => a.publicId.includes(filter);
  const keepRemote = (a: RemoteAsset) => a.publicId.includes(filter);
  return {
    uploads: plan.uploads.filter(keepLocal),
    updates: plan.updates.filter(keepLocal),
    unchanged: plan.unchanged.filter(keepLocal),
    deletes: plan.deletes.filter(keepRemote),
  };
}

function printPlan(plan: SyncPlan, args: CliArgs, folderMode: string): void {
  const line = (label: string, n: number) =>
    console.log(`  ${label.padEnd(10)} ${n}`);
  console.log('');
  console.log(`Sync plan (preset: ${args.preset}, folder mode: ${folderMode})`);
  line('uploads', plan.uploads.length);
  line('updates', plan.updates.length);
  line('deletes', plan.deletes.length);
  line('unchanged', plan.unchanged.length);
  console.log('');

  for (const a of plan.uploads) console.log(`  + upload  ${a.publicId}`);
  for (const a of plan.updates) console.log(`  ~ update  ${a.publicId}`);
  for (const a of plan.deletes) {
    const suffix = args.delete ? '' : ' (skipped — pass --delete to remove)';
    console.log(`  - delete  ${a.publicId}${suffix}`);
  }
}

/** Upload params per folder mode (D4). The CLI is exercised in --dry-run only. */
function uploadOptions(
  asset: LocalAsset,
  folderMode: string,
): Record<string, unknown> {
  const opts: Record<string, unknown> = {
    public_id: asset.publicId,
    overwrite: true,
    invalidate: true,
    resource_type: 'image',
  };
  if (folderMode === 'dynamic') {
    // Dynamic folder mode: set the folder explicitly via asset_folder, and keep
    // the full public_id (which already includes the folder path) by disabling
    // the prefix-from-folder behavior. Verified against the Cloudinary Node SDK:
    // public_id is honored verbatim while asset_folder controls UI placement.
    opts.asset_folder = asset.cloudFolder;
    opts.use_asset_folder_as_public_id_prefix = false;
  }
  // Fixed mode: the folder is implied by the public_id path — no extra params.
  return opts;
}

async function applyPlan(
  plan: SyncPlan,
  args: CliArgs,
  folderMode: string,
): Promise<number> {
  let changes = 0;
  for (const asset of [...plan.uploads, ...plan.updates]) {
    await cloudinary.uploader.upload(
      asset.absPath,
      uploadOptions(asset, folderMode),
    );
    console.log(`  uploaded ${asset.publicId}`);
    changes++;
  }
  if (args.delete) {
    console.log(`\nWARNING: Deleting ${plan.deletes.length} managed remote asset(s).`);
    console.log('  Any managed asset (photo-portfolio/* prefix) absent from the current');
    console.log('  export root will be permanently removed from Cloudinary. If the root');
    console.log('  contains only some collections, unsynced collections will be deleted.');
    console.log('  Use --filter to scope deletions to one collection.\n');
    for (const asset of plan.deletes) {
      await cloudinary.uploader.destroy(asset.publicId, { invalidate: true });
      console.log(`  deleted ${asset.publicId}`);
      changes++;
    }
  }
  return changes;
}

async function fireDeployHook(): Promise<void> {
  const url = process.env.VERCEL_DEPLOY_HOOK_URL;
  if (!url) {
    console.warn('  --deploy requested but VERCEL_DEPLOY_HOOK_URL is not set — skipping.');
    return;
  }
  const res = await fetch(url, { method: 'POST' });
  if (!res.ok) {
    throw new Error(`Deploy hook failed: ${res.status} ${res.statusText}`);
  }
  console.log('  deploy hook fired.');
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  loadDotEnv();
  configureCloudinary();

  console.log(`Walking export root: ${args.root}`);
  const local = walkExportTree(args.root, { preset: args.preset });
  console.log(`  found ${local.length} local ${args.preset} asset(s).`);

  console.log('Detecting Cloudinary folder mode…');
  const folderMode = await detectFolderMode();
  console.log(`  folder mode: ${folderMode}.`);

  console.log('Fetching remote inventory from Cloudinary…');
  const remote = await fetchRemoteInventory();
  console.log(`  found ${remote.length} managed remote asset(s) under ${DEFAULT_ROOT_FOLDER}/.`);

  let plan = computeSyncPlan(local, remote);
  if (args.filter) {
    plan = applyFilter(plan, args.filter);
    console.log(`  filter "${args.filter}" applied.`);
  }

  printPlan(plan, args, folderMode);

  const willChange =
    plan.uploads.length + plan.updates.length + (args.delete ? plan.deletes.length : 0);

  if (args.dryRun) {
    console.log('\nDry run — no changes made.');
    return;
  }

  if (willChange === 0) {
    console.log('\nNothing to do.');
    return;
  }

  if (folderMode === 'unknown') {
    console.error(
      '\nRefusing to upload: could not determine the account folder mode ' +
        '(no assets to sample). Upload one asset via the Cloudinary console first, ' +
        'or re-run once the account has content.',
    );
    process.exit(1);
  }

  const changes = await applyPlan(plan, args, folderMode);
  console.log(`\nApplied ${changes} change(s).`);

  if (args.deploy && changes > 0) {
    await fireDeployHook();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
