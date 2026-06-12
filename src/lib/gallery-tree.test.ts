import { describe, it, expect, vi } from 'vitest';
import {
  buildGalleryTree,
  deriveTitle,
  naturalCompare,
  flattenTree,
  getVisibleChildren,
  type PhotoRef,
  type GalleryNode,
  type OverrideRecord,
} from './gallery-tree';

// --- fixtures -------------------------------------------------------------

/** Build a minimal photo record. Extra Cloudinary fields are carried through. */
function photo(public_id: string, asset_folder: string, extra: Record<string, unknown> = {}): PhotoRef {
  return { public_id, asset_folder, ...extra };
}

/** Depth-first find of a node by its slug path (e.g. 'tennis/atx-open-2025'). */
function findNode(nodes: GalleryNode[], path: string): GalleryNode | undefined {
  for (const n of nodes) {
    if (n.path.join('/') === path) return n;
    const hit = findNode(n.children, path);
    if (hit) return hit;
  }
  return undefined;
}

// --- naturalCompare -------------------------------------------------------

describe('naturalCompare', () => {
  it('sorts -801 before -7877 (numeric runs compared as numbers)', () => {
    expect(naturalCompare('atx-801', 'atx-7877')).toBeLessThan(0);
    const sorted = ['atx-7877', 'atx-801'].sort(naturalCompare);
    expect(sorted).toEqual(['atx-801', 'atx-7877']);
  });

  it('compares non-numeric segments lexically', () => {
    expect(naturalCompare('apple', 'banana')).toBeLessThan(0);
  });
});

// --- deriveTitle ----------------------------------------------------------

describe('deriveTitle', () => {
  it('converts kebab-case folder names to Title Case', () => {
    expect(deriveTitle('atx-open-2025')).toBe('Atx Open 2025');
  });

  it('converts underscore folder names to Title Case', () => {
    expect(deriveTitle('my_photos')).toBe('My Photos');
  });
});

// --- buildGalleryTree: structure -----------------------------------------

describe('buildGalleryTree — single-level tree', () => {
  it('creates one node for one folder with its photos', () => {
    const { tree } = buildGalleryTree([
      photo('tennis-2', 'photo-portfolio/tennis'),
      photo('tennis-1', 'photo-portfolio/tennis'),
    ]);
    expect(tree).toHaveLength(1);
    const t = tree[0];
    expect(t.slug).toBe('tennis');
    expect(t.path).toEqual(['tennis']);
    expect(t.folder).toBe('photo-portfolio/tennis');
    expect(t.photos).toHaveLength(2);
    expect(t.children).toEqual([]);
  });
});

describe('buildGalleryTree — three-deep nesting', () => {
  it('materializes every ancestor segment as a node', () => {
    const { tree } = buildGalleryTree([
      photo('p1', 'photo-portfolio/events/2025/spring'),
    ]);
    const events = findNode(tree, 'events')!;
    const year = findNode(tree, 'events/2025')!;
    const spring = findNode(tree, 'events/2025/spring')!;
    expect(events).toBeDefined();
    expect(year).toBeDefined();
    expect(spring).toBeDefined();
    expect(events.path).toEqual(['events']);
    expect(year.path).toEqual(['events', '2025']);
    expect(spring.path).toEqual(['events', '2025', 'spring']);
    // intermediate nodes carry no own photos
    expect(events.photos).toHaveLength(0);
    expect(year.photos).toHaveLength(0);
    expect(spring.photos).toHaveLength(1);
  });
});

describe('buildGalleryTree — mixed photo+children nodes', () => {
  it('a node can have both own photos and children', () => {
    const { tree } = buildGalleryTree([
      photo('cover', 'photo-portfolio/tennis'),
      photo('child', 'photo-portfolio/tennis/atx-open-2025'),
    ]);
    const tennis = findNode(tree, 'tennis')!;
    expect(tennis.photos).toHaveLength(1);
    expect(tennis.children).toHaveLength(1);
    expect(tennis.children[0].path).toEqual(['tennis', 'atx-open-2025']);
  });
});

// --- defaults: title / cover / order -------------------------------------

describe('buildGalleryTree — default cover', () => {
  it('uses the first own photo by natural sort', () => {
    const { tree } = buildGalleryTree([
      photo('atx-7877', 'photo-portfolio/tennis'),
      photo('atx-801', 'photo-portfolio/tennis'),
    ]);
    expect(tree[0].cover).toBe('atx-801');
    // photos are themselves natural-sorted
    expect(tree[0].photos.map((p) => p.public_id)).toEqual(['atx-801', 'atx-7877']);
  });
});

describe('buildGalleryTree — cover fallback recursion', () => {
  it('a photo-less section borrows the first child cover, recursively', () => {
    const { tree } = buildGalleryTree([
      photo('deep-1', 'photo-portfolio/events/2025/spring'),
    ]);
    const events = findNode(tree, 'events')!;
    const year = findNode(tree, 'events/2025')!;
    const spring = findNode(tree, 'events/2025/spring')!;
    expect(spring.cover).toBe('deep-1');
    expect(year.cover).toBe('deep-1');
    expect(events.cover).toBe('deep-1');
  });
});

describe('buildGalleryTree — default title derivation', () => {
  it('derives Title Case titles from folder names by default', () => {
    const { tree } = buildGalleryTree([
      photo('p', 'photo-portfolio/atx-open-2025'),
    ]);
    expect(tree[0].title).toBe('Atx Open 2025');
  });
});

describe('buildGalleryTree — default ordering (alpha ascending)', () => {
  it('sorts unordered siblings alphabetically by slug', () => {
    const { tree } = buildGalleryTree([
      photo('p1', 'photo-portfolio/charlie'),
      photo('p2', 'photo-portfolio/alpha'),
      photo('p3', 'photo-portfolio/bravo'),
    ]);
    expect(tree.map((n) => n.slug)).toEqual(['alpha', 'bravo', 'charlie']);
  });
});

describe('buildGalleryTree — order overrides', () => {
  it('places ordered nodes first (by order), then unordered alpha', () => {
    const { tree } = buildGalleryTree(
      [
        photo('p1', 'photo-portfolio/alpha'),
        photo('p2', 'photo-portfolio/bravo'),
        photo('p3', 'photo-portfolio/charlie'),
      ],
      [
        { path: 'charlie', order: 1 },
        { path: 'bravo', order: 2 },
      ],
    );
    // charlie(1), bravo(2) ordered first; alpha unordered last
    expect(tree.map((n) => n.slug)).toEqual(['charlie', 'bravo', 'alpha']);
  });
});

// --- hidden ---------------------------------------------------------------

describe('buildGalleryTree — hidden handling', () => {
  it('excludes hidden nodes from visible children but keeps them in flattenTree', () => {
    const { tree } = buildGalleryTree(
      [
        photo('p1', 'photo-portfolio/gallery/public-set'),
        photo('p2', 'photo-portfolio/gallery/secret-set'),
      ],
      [{ path: 'gallery/secret-set', hidden: true }],
    );
    const gallery = findNode(tree, 'gallery')!;
    const secret = findNode(tree, 'gallery/secret-set')!;
    expect(secret.hidden).toBe(true);

    // visible children exclude the hidden node
    const visible = getVisibleChildren(gallery);
    expect(visible.map((n) => n.slug)).toEqual(['public-set']);
    // but it remains in the structural children array
    expect(gallery.children.map((n) => n.slug).sort()).toEqual(['public-set', 'secret-set']);

    // flattenTree includes the hidden node so its page still builds
    const flat = flattenTree(tree);
    const params = flat.map((e) => e.params.slug);
    expect(params).toContain('gallery/secret-set');
  });
});

// --- flattenTree ----------------------------------------------------------

describe('flattenTree', () => {
  it('returns one entry per node with getStaticPaths-shaped params', () => {
    const { tree } = buildGalleryTree([
      photo('p1', 'photo-portfolio/tennis/atx-open-2025'),
    ]);
    const flat = flattenTree(tree);
    const slugs = flat.map((e) => e.params.slug).sort();
    expect(slugs).toEqual(['tennis', 'tennis/atx-open-2025']);
    const leaf = flat.find((e) => e.params.slug === 'tennis/atx-open-2025')!;
    expect(leaf.node.photos).toHaveLength(1);
  });
});

// --- photoCount -----------------------------------------------------------

describe('buildGalleryTree — recursive photoCount', () => {
  it('counts own photos plus all descendant photos', () => {
    const { tree } = buildGalleryTree([
      photo('a', 'photo-portfolio/tennis'),
      photo('b', 'photo-portfolio/tennis/atx-open-2025'),
      photo('c', 'photo-portfolio/tennis/atx-open-2025'),
      photo('d', 'photo-portfolio/tennis/atx-open-2024'),
    ]);
    const tennis = findNode(tree, 'tennis')!;
    expect(tennis.photoCount).toBe(4);
    expect(findNode(tree, 'tennis/atx-open-2025')!.photoCount).toBe(2);
    expect(findNode(tree, 'tennis/atx-open-2024')!.photoCount).toBe(1);
  });
});

// --- overrides ------------------------------------------------------------

describe('buildGalleryTree — title/description/cover/slug overrides', () => {
  it('applies each override field and routes by the overridden slug', () => {
    const overrides: OverrideRecord[] = [
      {
        path: 'tennis',
        title: 'Tennis Photography',
        description: 'Match coverage',
        cover: 'custom-cover-id',
        slug: 'racquet',
      },
    ];
    const { tree } = buildGalleryTree(
      [photo('p1', 'photo-portfolio/tennis')],
      overrides,
    );
    const node = tree[0];
    expect(node.title).toBe('Tennis Photography');
    expect(node.description).toBe('Match coverage');
    expect(node.cover).toBe('custom-cover-id');
    expect(node.slug).toBe('racquet');
    expect(node.path).toEqual(['racquet']);
  });
});

// --- validation -----------------------------------------------------------

describe('buildGalleryTree — reserved-slug validation', () => {
  it('throws when a top-level folder collides with a reserved slug', () => {
    expect(() =>
      buildGalleryTree([photo('p', 'photo-portfolio/about')]),
    ).toThrow(/reserved/i);
  });

  it('throws when a slug override collides with a reserved slug', () => {
    expect(() =>
      buildGalleryTree(
        [photo('p', 'photo-portfolio/info')],
        [{ path: 'info', slug: 'licensing' }],
      ),
    ).toThrow(/reserved/i);
  });
});

describe('buildGalleryTree — duplicate-slug validation', () => {
  it('throws when a slug override collides with a sibling slug', () => {
    expect(() =>
      buildGalleryTree(
        [
          photo('p1', 'photo-portfolio/tennis/atx-open-2025'),
          photo('p2', 'photo-portfolio/tennis/atx-open-2024'),
        ],
        [{ path: 'tennis/atx-open-2024', slug: 'atx-open-2025' }],
      ),
    ).toThrow(/duplicate/i);
  });
});

// --- override match-key under slug-renamed parent -------------------------

describe('buildGalleryTree — child override under slug-renamed parent', () => {
  it('matches child override by default folder-derived path even when parent has a slug override', () => {
    const { tree } = buildGalleryTree(
      [photo('p', 'photo-portfolio/tennis/atx-open-2025')],
      [
        { path: 'tennis', slug: 'sport' },
        { path: 'tennis/atx-open-2025', title: 'ATX Open 2025 Championship' },
      ],
    );
    // Parent renamed to 'sport' via slug override — route is /sport/atx-open-2025
    const sport = findNode(tree, 'sport');
    expect(sport).toBeDefined();
    expect(sport!.slug).toBe('sport');
    // Child override keyed by default path 'tennis/atx-open-2025' must still apply
    const child = findNode(tree, 'sport/atx-open-2025');
    expect(child).toBeDefined();
    expect(child!.title).toBe('ATX Open 2025 Championship');
  });
});

// --- unmatched overrides --------------------------------------------------

describe('buildGalleryTree — unmatched overrides', () => {
  it('collects a warning (and calls warn) for overrides matching no folder', () => {
    const warn = vi.fn();
    const { warnings } = buildGalleryTree(
      [photo('p', 'photo-portfolio/tennis')],
      [{ path: 'does/not/exist', title: 'Ghost' }],
      { warn },
    );
    expect(warnings.some((w) => w.includes('does/not/exist'))).toBe(true);
    expect(warn).toHaveBeenCalledOnce();
  });
});
