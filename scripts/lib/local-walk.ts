/**
 * Local export-tree walker — a pure module (no Cloudinary, no network) that
 * turns a Lightroom export directory into the list of assets the sync script
 * mirrors to Cloudinary.
 *
 * Export tree shape (from `tools/structured-export.lrplugin`, see
 * `docs/lightroom-export-spec.md`):
 *
 *   <root>/<set...>/<collection>/<preset>/<name>.jpg
 *
 * Per plan decision D4, a local file at that path maps to:
 *   - Cloudinary folder:   photo-portfolio/<set...>/<collection>
 *   - public_id:           <folder>/<filename-stem>
 *
 * The mapping is deterministic so re-running a sync overwrites the same asset
 * rather than creating duplicates (idempotent uploads).
 *
 * Normalization: every path segment (sets, collection, filename stem) is run
 * through the site's `toSlug` helper — the same function the gallery tree uses
 * to derive route segments from `asset_folder`. This keeps the uploaded folder
 * names, the resulting `asset_folder` on Cloudinary, and the derived site routes
 * consistent: a set named "US Open" on disk (`us open`) becomes `us-open`
 * everywhere. Without this, a space or capital letter in a Lightroom set name
 * would produce a Cloudinary folder that slugs to a different route than its own
 * name, breaking idempotency.
 *
 * The md5 computation is injectable (`options.computeMd5`) so the walker can be
 * unit-tested against a fixture tree without real file hashing, and so the CLI
 * can swap in a streaming hash if needed later.
 */

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { toSlug } from '../../src/lib/utils';

export interface LocalAsset {
  /** Cloudinary folder, e.g. `photo-portfolio/tennis/atx-open-2025`. */
  cloudFolder: string;
  /** Deterministic public_id = `<cloudFolder>/<slugified-stem>`. */
  publicId: string;
  /** Absolute path to the source `.jpg` on disk. */
  absPath: string;
  /** MD5 hex of the file bytes; compared against the remote etag. */
  md5: string;
}

export interface WalkOptions {
  /** Preset subfolder to mirror (default `portfolio` per D4). */
  preset?: string;
  /** Cloudinary root prefix (default `photo-portfolio`). */
  rootFolder?: string;
  /** Injectable hasher (default: MD5 of file bytes). Eases unit testing. */
  computeMd5?: (absPath: string) => string;
}

export const DEFAULT_PRESET = 'portfolio';
export const DEFAULT_ROOT_FOLDER = 'photo-portfolio';

/** Default hasher: MD5 hex of the file's bytes (matches Cloudinary's etag). */
export function md5File(absPath: string): string {
  return crypto.createHash('md5').update(fs.readFileSync(absPath)).digest('hex');
}

const JPG_EXTENSIONS = new Set(['.jpg', '.jpeg']);

/**
 * Walk an export root and return one `LocalAsset` per `.jpg` whose immediate
 * parent directory is the requested preset. Files under other presets, non-jpg
 * files, and jpgs not sitting directly under a `<preset>/` directory are
 * ignored. Results are sorted by `publicId` for stable, diff-friendly output.
 */
export function walkExportTree(root: string, options: WalkOptions = {}): LocalAsset[] {
  const preset = (options.preset ?? DEFAULT_PRESET).toLowerCase();
  const rootFolder = options.rootFolder ?? DEFAULT_ROOT_FOLDER;
  const computeMd5 = options.computeMd5 ?? md5File;
  const out: LocalAsset[] = [];

  /** `relSegments` are the directory names from `root` down to `dir` (raw, un-slugified). */
  function recurse(dir: string, relSegments: string[]): void {
    let entries: fs.Dirent[];
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return; // unreadable directory — skip rather than abort the whole walk
    }
    for (const entry of entries) {
      const abs = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        recurse(abs, [...relSegments, entry.name]);
        continue;
      }
      if (!entry.isFile()) continue;
      if (!JPG_EXTENSIONS.has(path.extname(entry.name).toLowerCase())) continue;

      // The file's immediate directory must be the preset (case-insensitive).
      const dirName = relSegments[relSegments.length - 1];
      if (!dirName || dirName.toLowerCase() !== preset) continue;

      // Folder segments = everything from root to the collection, excluding the
      // preset directory itself: `<set...>/<collection>`.
      const folderSegs = relSegments.slice(0, -1).map(toSlug).filter(Boolean);
      if (folderSegs.length === 0) continue; // jpg directly under root/<preset>, no collection

      const cloudFolder = [rootFolder, ...folderSegs].join('/');
      const stem = toSlug(path.parse(entry.name).name);
      if (!stem) continue;
      const publicId = `${cloudFolder}/${stem}`;

      out.push({ cloudFolder, publicId, absPath: abs, md5: computeMd5(abs) });
    }
  }

  recurse(root, []);
  out.sort((a, b) => a.publicId.localeCompare(b.publicId));
  return out;
}
