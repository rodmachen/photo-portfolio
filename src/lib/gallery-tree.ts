/**
 * Gallery tree builder — the load-bearing pure transformation that turns a flat
 * list of Cloudinary photo records plus a set of YAML overrides into the nested
 * gallery structure the whole site consumes (routes, nav, sitemap, sync checks).
 *
 * This module is intentionally free of any Astro imports so it can be unit
 * tested in isolation and reused from build scripts. Its only dependency is the
 * pure `toSlug` / `toTitle` helpers in `./utils`.
 *
 * Semantics (binding, per plan D1/D2):
 *  - Photos are grouped by `asset_folder`. Every ancestor folder segment
 *    materializes as a node, so photo-less intermediate folders become section
 *    pages, and a folder with both photos and subfolders carries both.
 *  - The root Cloudinary prefix (default `photo-portfolio`) is stripped from
 *    route paths; the full Cloudinary folder is preserved in `node.folder`.
 *  - Default title = folder name → Title Case. Default slug = folder name →
 *    kebab-case. Default cover = first own photo by natural sort, else the first
 *    visible child's cover (recursive through photo-less sections).
 *  - Ordering: nodes with an explicit `order` come first (ascending by order),
 *    then unordered nodes alphabetically ascending by slug.
 *  - `hidden` nodes still build (they appear in `flattenTree`) but are excluded
 *    from listings/nav/sitemap — use `getVisibleChildren` for listing views.
 *  - Top-level slugs colliding with the reserved set, or sibling slug
 *    collisions (including those produced by `slug:` overrides), throw.
 *
 * Unmatched overrides: an override whose `path` matches no materialized folder
 * is *ignored* rather than fabricating an empty node. Each one is collected into
 * the returned `warnings` array and, if an injectable `warn` callback is
 * supplied, reported through it. The pure module never writes to `console`.
 */

import { toSlug, toTitle } from './utils';

/**
 * A photo record. In production these are Cloudinary Search API resources; only
 * `public_id` and `asset_folder` are required by the tree builder, but any extra
 * Cloudinary fields (`secure_url`, `width`, `display_name`, …) are carried
 * through untouched on `node.photos` for the renderer to use.
 */
export interface PhotoRef {
  public_id: string;
  asset_folder: string;
  display_name?: string;
  secure_url?: string;
  width?: number;
  height?: number;
  format?: string;
  [key: string]: unknown;
}

/** A per-node override, keyed by the route path (e.g. `tennis/atx-open-2025`). */
export interface OverrideRecord {
  path: string;
  title?: string;
  description?: string;
  cover?: string;
  order?: number;
  hidden?: boolean;
  slug?: string;
}

export interface GalleryNode {
  /** Route segment, derived from the folder name unless overridden. */
  slug: string;
  /** Slug segments from the root, e.g. `['tennis', 'atx-open-2025']`. */
  path: string[];
  /** Full Cloudinary folder, e.g. `photo-portfolio/tennis/atx-open-2025`. */
  folder: string;
  /** Display title: override, else folder name → Title Case. */
  title: string;
  description?: string;
  /** public_id of the cover image (own first photo, else child cover). */
  cover: string;
  /** Explicit sort order; ordered nodes precede unordered ones. */
  order?: number;
  /** Unlisted: the page builds but is excluded from nav/listings/sitemap. */
  hidden: boolean;
  /** Photos directly in this folder, natural-sorted by public_id. */
  photos: PhotoRef[];
  children: GalleryNode[];
  /** Recursive photo count (own + all descendants). */
  photoCount: number;
}

export interface BuildOptions {
  /** Cloudinary root prefix stripped from route paths. Default `photo-portfolio`. */
  rootFolder?: string;
  /** Reserved top-level slugs that may not be used by a folder. */
  reservedSlugs?: string[];
  /** Optional sink for non-fatal warnings (e.g. unmatched overrides). */
  warn?: (message: string) => void;
}

export interface GalleryTree {
  /** Top-level gallery nodes, in display order. */
  tree: GalleryNode[];
  /** Non-fatal warnings collected during the build (e.g. unmatched overrides). */
  warnings: string[];
}

const DEFAULT_ROOT_FOLDER = 'photo-portfolio';
const DEFAULT_RESERVED_SLUGS = ['about', 'licensing', 'albums', '404'];

/** Default title derivation: folder name (kebab/underscore) → Title Case. */
export function deriveTitle(folderName: string): string {
  return toTitle(folderName);
}

/**
 * Natural-order string comparison: digit runs are compared numerically so that
 * `atx-801` sorts before `atx-7877`. Non-numeric runs compare lexically.
 */
export function naturalCompare(a: string, b: string): number {
  const re = /(\d+|\D+)/g;
  const ax = a.match(re) ?? [];
  const bx = b.match(re) ?? [];
  const len = Math.max(ax.length, bx.length);
  for (let i = 0; i < len; i++) {
    const as = ax[i];
    const bs = bx[i];
    if (as === undefined) return -1;
    if (bs === undefined) return 1;
    const aNum = /^\d+$/.test(as);
    const bNum = /^\d+$/.test(bs);
    if (aNum && bNum) {
      const diff = Number(as) - Number(bs);
      if (diff !== 0) return diff;
    } else if (as !== bs) {
      return as < bs ? -1 : 1;
    }
  }
  return 0;
}

/** Ordering comparator: ordered nodes first (by order), then alpha by slug. */
function compareNodes(a: GalleryNode, b: GalleryNode): number {
  const ao = a.order;
  const bo = b.order;
  if (ao !== undefined && bo !== undefined) {
    if (ao !== bo) return ao - bo;
    return a.slug.localeCompare(b.slug);
  }
  if (ao !== undefined) return -1;
  if (bo !== undefined) return 1;
  return a.slug.localeCompare(b.slug);
}

/** Normalize an override path to a comparable, slugified key. */
function normalizeOverridePath(path: string): string {
  return path
    .split('/')
    .filter(Boolean)
    .map(toSlug)
    .join('/');
}

/** Strip the root prefix from a Cloudinary folder, returning raw segments. */
function relativeSegments(folder: string, rootFolder: string): string[] {
  let rest = folder;
  const prefix = rootFolder.endsWith('/') ? rootFolder : `${rootFolder}/`;
  if (rest === rootFolder) {
    rest = '';
  } else if (rest.startsWith(prefix)) {
    rest = rest.slice(prefix.length);
  }
  return rest.split('/').filter(Boolean);
}

/** Intermediate mutable tree node, keyed by raw (un-slugified) folder segment. */
interface RawNode {
  rawSegment: string;
  rawSegments: string[];
  photos: PhotoRef[];
  children: Map<string, RawNode>;
}

function makeRawNode(rawSegment: string, rawSegments: string[]): RawNode {
  return { rawSegment, rawSegments, photos: [], children: new Map() };
}

/**
 * Build the gallery tree from photo records and overrides.
 *
 * @param photos    Flat list of photo records; grouped internally by `asset_folder`.
 * @param overrides Override records keyed by route path (e.g. `tennis/atx-open-2025`).
 * @param options   Root prefix, reserved slugs, and an optional warn callback.
 */
export function buildGalleryTree(
  photos: PhotoRef[],
  overrides: OverrideRecord[] = [],
  options: BuildOptions = {},
): GalleryTree {
  const rootFolder = options.rootFolder ?? DEFAULT_ROOT_FOLDER;
  const reservedSlugs = new Set(options.reservedSlugs ?? DEFAULT_RESERVED_SLUGS);
  const warnings: string[] = [];

  // Index overrides by their normalized (slugified) path; later wins on collision.
  const overrideByPath = new Map<string, OverrideRecord>();
  for (const override of overrides) {
    overrideByPath.set(normalizeOverridePath(override.path), override);
  }
  const matchedOverridePaths = new Set<string>();

  // 1. Build the raw folder tree, materializing every ancestor segment.
  const root = makeRawNode('', []);
  for (const p of photos) {
    const segments = relativeSegments(p.asset_folder, rootFolder);
    if (segments.length === 0) continue; // photo sits at the root prefix itself
    let cursor = root;
    for (let i = 0; i < segments.length; i++) {
      const raw = segments[i];
      let child = cursor.children.get(raw);
      if (!child) {
        child = makeRawNode(raw, segments.slice(0, i + 1));
        cursor.children.set(raw, child);
      }
      cursor = child;
    }
    cursor.photos.push(p);
  }

  // 2. Transform raw nodes → GalleryNodes (recursive), applying overrides.
  function transform(raw: RawNode, parentSlugPath: string[]): GalleryNode {
    const defaultSlug = toSlug(raw.rawSegment);
    const defaultPathKey = [...parentSlugPath, defaultSlug].join('/');
    const override = overrideByPath.get(defaultPathKey);
    if (override) matchedOverridePaths.add(defaultPathKey);

    const slug = override?.slug ? toSlug(override.slug) : defaultSlug;
    const path = [...parentSlugPath, slug];

    const ownPhotos = raw.photos
      .slice()
      .sort((a, b) => naturalCompare(a.public_id, b.public_id));

    // Recurse into children, then order them.
    const children = [...raw.children.values()]
      .map((c) => transform(c, path))
      .sort(compareNodes);

    // Sibling slug-collision detection (also catches slug-override collisions).
    assertUniqueSiblingSlugs(children, path);

    // Cover: override, else first own photo, else first visible child's cover.
    let cover = override?.cover ?? ownPhotos[0]?.public_id ?? '';
    if (!cover) {
      const visibleChild = children.find((c) => !c.hidden) ?? children[0];
      cover = visibleChild?.cover ?? '';
    }

    const photoCount =
      ownPhotos.length + children.reduce((sum, c) => sum + c.photoCount, 0);

    return {
      slug,
      path,
      folder: [rootFolder, ...raw.rawSegments].join('/'),
      title: override?.title ?? deriveTitle(raw.rawSegment),
      description: override?.description,
      cover,
      order: override?.order,
      hidden: override?.hidden ?? false,
      photos: ownPhotos,
      children,
      photoCount,
    };
  }

  const tree = [...root.children.values()]
    .map((c) => transform(c, []))
    .sort(compareNodes);

  // 3. Reserved-slug validation (top-level only) and top-level uniqueness.
  for (const node of tree) {
    if (reservedSlugs.has(node.slug)) {
      throw new Error(
        `Top-level slug "${node.slug}" (folder "${node.folder}") collides with a reserved route. ` +
          `Reserved slugs: ${[...reservedSlugs].join(', ')}. Use a slug override to rename it.`,
      );
    }
  }
  assertUniqueSiblingSlugs(tree, []);

  // 4. Report overrides that matched no folder.
  for (const [key, override] of overrideByPath) {
    if (!matchedOverridePaths.has(key)) {
      const message = `Override for path "${override.path}" matched no folder — ignored.`;
      warnings.push(message);
      options.warn?.(message);
    }
  }

  return { tree, warnings };
}

/** Throw if two siblings share a slug (manifests as a route collision). */
function assertUniqueSiblingSlugs(nodes: GalleryNode[], parentPath: string[]): void {
  const seen = new Set<string>();
  for (const node of nodes) {
    if (seen.has(node.slug)) {
      const where = parentPath.length ? `under "${parentPath.join('/')}"` : 'at the top level';
      throw new Error(
        `Duplicate slug "${node.slug}" ${where} — two folders resolve to the same route. ` +
          `Rename one with a slug override.`,
      );
    }
    seen.add(node.slug);
  }
}

/** Non-hidden children, for listing/nav views (preserves order). */
export function getVisibleChildren(node: GalleryNode): GalleryNode[] {
  return node.children.filter((c) => !c.hidden);
}

export interface FlatEntry {
  params: { slug: string };
  node: GalleryNode;
}

/**
 * Flatten the tree into `getStaticPaths`-shaped entries. Hidden nodes ARE
 * included — their pages build, they are simply unlisted elsewhere.
 */
export function flattenTree(nodes: GalleryNode[]): FlatEntry[] {
  const out: FlatEntry[] = [];
  function walk(list: GalleryNode[]): void {
    for (const node of list) {
      out.push({ params: { slug: node.path.join('/') }, node });
      walk(node.children);
    }
  }
  walk(nodes);
  return out;
}
