import { describe, it, expect } from 'vitest';
import { computeSyncPlan, type RemoteAsset } from './sync-plan';
import type { LocalAsset } from './local-walk';

function local(publicId: string, md5: string): LocalAsset {
  return {
    publicId,
    md5,
    cloudFolder: publicId.split('/').slice(0, -1).join('/'),
    absPath: `/tmp/${publicId}.jpg`,
  };
}

function remote(publicId: string, etag: string): RemoteAsset {
  return { publicId, etag };
}

describe('computeSyncPlan', () => {
  it('classifies a local-only asset as an upload', () => {
    const plan = computeSyncPlan([local('photo-portfolio/a/x', 'h1')], []);
    expect(plan.uploads.map((u) => u.publicId)).toEqual(['photo-portfolio/a/x']);
    expect(plan.updates).toHaveLength(0);
    expect(plan.unchanged).toHaveLength(0);
    expect(plan.deletes).toHaveLength(0);
  });

  it('classifies a remote-only asset as a delete', () => {
    const plan = computeSyncPlan([], [remote('photo-portfolio/a/x', 'h1')]);
    expect(plan.deletes.map((d) => d.publicId)).toEqual(['photo-portfolio/a/x']);
    expect(plan.uploads).toHaveLength(0);
  });

  it('classifies a matching md5/etag pair as unchanged', () => {
    const plan = computeSyncPlan(
      [local('photo-portfolio/a/x', 'same')],
      [remote('photo-portfolio/a/x', 'same')],
    );
    expect(plan.unchanged.map((u) => u.publicId)).toEqual(['photo-portfolio/a/x']);
    expect(plan.uploads).toHaveLength(0);
    expect(plan.updates).toHaveLength(0);
    expect(plan.deletes).toHaveLength(0);
  });

  it('classifies a mismatched md5/etag pair as an update', () => {
    const plan = computeSyncPlan(
      [local('photo-portfolio/a/x', 'newhash')],
      [remote('photo-portfolio/a/x', 'oldhash')],
    );
    expect(plan.updates.map((u) => u.publicId)).toEqual(['photo-portfolio/a/x']);
    expect(plan.unchanged).toHaveLength(0);
  });

  it('treats a missing remote etag as an update (safe re-upload)', () => {
    const plan = computeSyncPlan(
      [local('photo-portfolio/a/x', 'h1')],
      [remote('photo-portfolio/a/x', '')],
    );
    expect(plan.updates.map((u) => u.publicId)).toEqual(['photo-portfolio/a/x']);
  });

  it('handles a mixed inventory across all four buckets', () => {
    const localAssets = [
      local('photo-portfolio/a/keep', 'h-keep'), // unchanged
      local('photo-portfolio/a/edit', 'h-new'), // update
      local('photo-portfolio/a/add', 'h-add'), // upload
    ];
    const remoteAssets = [
      remote('photo-portfolio/a/keep', 'h-keep'),
      remote('photo-portfolio/a/edit', 'h-old'),
      remote('photo-portfolio/a/gone', 'h-gone'), // delete
    ];
    const plan = computeSyncPlan(localAssets, remoteAssets);
    expect(plan.unchanged.map((a) => a.publicId)).toEqual(['photo-portfolio/a/keep']);
    expect(plan.updates.map((a) => a.publicId)).toEqual(['photo-portfolio/a/edit']);
    expect(plan.uploads.map((a) => a.publicId)).toEqual(['photo-portfolio/a/add']);
    expect(plan.deletes.map((a) => a.publicId)).toEqual(['photo-portfolio/a/gone']);
  });
});
