/**
 * Sync-plan diff — a pure module that compares the local export inventory
 * against the remote Cloudinary inventory and classifies every asset into one
 * of four buckets. No I/O, no Cloudinary SDK: it operates on plain data so the
 * diff logic is fully unit-testable.
 *
 * Change detection (per plan D4): local MD5 vs remote etag. Cloudinary's etag
 * is the MD5 hex of the stored asset's bytes, so for an asset uploaded from a
 * given file the etag equals the file's MD5 — making it a reliable, content-
 * based change signal that needs no timestamps or version tracking.
 */

import type { LocalAsset } from './local-walk';

/** A remote Cloudinary asset, reduced to the fields the diff needs. */
export interface RemoteAsset {
  publicId: string;
  /** MD5 hex of the stored bytes; may be empty if Cloudinary omitted it. */
  etag: string;
}

export interface SyncPlan {
  /** Local assets with no remote counterpart — to be uploaded. */
  uploads: LocalAsset[];
  /** Local assets whose remote etag differs from the local MD5 — to re-upload. */
  updates: LocalAsset[];
  /** Local assets whose remote etag matches the local MD5 — no action. */
  unchanged: LocalAsset[];
  /** Remote assets with no local counterpart — candidates for deletion. */
  deletes: RemoteAsset[];
}

/**
 * Compute the sync plan. Matching is by `publicId` (deterministic per D4):
 *  - local only            → upload
 *  - both, etag === md5     → unchanged
 *  - both, etag !== md5     → update (also when the remote etag is missing,
 *                             which is the safe default — re-upload to converge)
 *  - remote only            → delete (inert unless the CLI is run with --delete)
 */
export function computeSyncPlan(local: LocalAsset[], remote: RemoteAsset[]): SyncPlan {
  const remoteById = new Map(remote.map((r) => [r.publicId, r]));
  const localIds = new Set(local.map((l) => l.publicId));

  const uploads: LocalAsset[] = [];
  const updates: LocalAsset[] = [];
  const unchanged: LocalAsset[] = [];

  for (const l of local) {
    const r = remoteById.get(l.publicId);
    if (!r) {
      uploads.push(l);
    } else if (r.etag && l.md5 && r.etag === l.md5) {
      unchanged.push(l);
    } else {
      updates.push(l);
    }
  }

  const deletes = remote.filter((r) => !localIds.has(r.publicId));

  return { uploads, updates, unchanged, deletes };
}
