import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { walkExportTree, md5File, type LocalAsset } from './local-walk';

/**
 * These tests build a real fixture directory tree under the OS temp dir so the
 * walker exercises actual `fs.readdirSync` traversal. The md5 hasher is stubbed
 * (returns a marker per path) so assertions don't depend on file contents.
 */

let root: string;

/** Create an empty `.jpg` (or arbitrary) file, making parent dirs as needed. */
function touch(relPath: string): void {
  const abs = path.join(root, relPath);
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  fs.writeFileSync(abs, '');
}

const fakeMd5 = (absPath: string) => `md5:${path.basename(absPath)}`;

function walk(preset?: string): LocalAsset[] {
  return walkExportTree(root, { preset, computeMd5: fakeMd5 });
}

beforeEach(() => {
  root = fs.mkdtempSync(path.join(os.tmpdir(), 'export-walk-'));
});

afterEach(() => {
  fs.rmSync(root, { recursive: true, force: true });
});

describe('walkExportTree — D4 mapping', () => {
  it('maps a single-level collection to folder + public_id', () => {
    touch('tennis/atx-open-2025/portfolio/atx-open-2025-7877.jpg');
    const assets = walk();
    expect(assets).toHaveLength(1);
    expect(assets[0]).toMatchObject({
      cloudFolder: 'photo-portfolio/tennis/atx-open-2025',
      publicId: 'photo-portfolio/tennis/atx-open-2025/atx-open-2025-7877',
      md5: 'md5:atx-open-2025-7877.jpg',
    });
    expect(assets[0].absPath).toContain('atx-open-2025-7877.jpg');
  });

  it('handles nested sets at depth', () => {
    touch('sports/tennis/atx-open-2025/portfolio/atx-open-2025-1.jpg');
    const [asset] = walk();
    expect(asset.cloudFolder).toBe('photo-portfolio/sports/tennis/atx-open-2025');
    expect(asset.publicId).toBe('photo-portfolio/sports/tennis/atx-open-2025/atx-open-2025-1');
  });
});

describe('walkExportTree — preset filtering', () => {
  it('ignores files under other presets', () => {
    touch('tennis/atx/portfolio/a.jpg');
    touch('tennis/atx/print/a.jpg');
    touch('tennis/atx/web/a.jpg');
    const assets = walk('portfolio');
    expect(assets.map((a) => a.publicId)).toEqual([
      'photo-portfolio/tennis/atx/a',
    ]);
  });

  it('honours a non-default preset', () => {
    touch('tennis/atx/portfolio/a.jpg');
    touch('tennis/atx/web/b.jpg');
    const assets = walk('web');
    expect(assets.map((a) => a.publicId)).toEqual(['photo-portfolio/tennis/atx/b']);
  });

  it('matches the preset directory case-insensitively', () => {
    touch('tennis/atx/Portfolio/a.jpg');
    expect(walk('portfolio')).toHaveLength(1);
  });
});

describe('walkExportTree — file filtering', () => {
  it('ignores non-jpg files', () => {
    touch('tennis/atx/portfolio/a.jpg');
    touch('tennis/atx/portfolio/b.png');
    touch('tennis/atx/portfolio/c.txt');
    touch('tennis/atx/portfolio/.DS_Store');
    const assets = walk();
    expect(assets.map((a) => a.publicId)).toEqual(['photo-portfolio/tennis/atx/a']);
  });

  it('accepts .jpeg as well as .jpg', () => {
    touch('tennis/atx/portfolio/a.jpeg');
    expect(walk()).toHaveLength(1);
  });

  it('ignores a jpg sitting directly under <preset> with no collection', () => {
    touch('portfolio/orphan.jpg');
    expect(walk()).toHaveLength(0);
  });
});

describe('walkExportTree — public_id derivation & normalization', () => {
  it('slugifies spaces and capitals in set/collection names', () => {
    touch('US Open/ATX Open 2025/portfolio/Shot_01.jpg');
    const [asset] = walk();
    expect(asset.cloudFolder).toBe('photo-portfolio/us-open/atx-open-2025');
    expect(asset.publicId).toBe('photo-portfolio/us-open/atx-open-2025/shot-01');
  });

  it('sorts output by public_id for stable diffs', () => {
    touch('tennis/atx/portfolio/c.jpg');
    touch('tennis/atx/portfolio/a.jpg');
    touch('tennis/atx/portfolio/b.jpg');
    expect(walk().map((a) => path.basename(a.absPath))).toEqual([
      'a.jpg',
      'b.jpg',
      'c.jpg',
    ]);
  });
});

describe('md5File', () => {
  it('computes the MD5 hex of file bytes', () => {
    const abs = path.join(root, 'sample.bin');
    fs.writeFileSync(abs, 'hello');
    // MD5("hello") = 5d41402abc4b2a76b9719d911017c592
    expect(md5File(abs)).toBe('5d41402abc4b2a76b9719d911017c592');
  });
});
