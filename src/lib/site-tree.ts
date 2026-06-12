import { getCollection } from 'astro:content';
import {
  buildGalleryTree,
  flattenTree,
  getVisibleChildren,
} from './gallery-tree';
import type { GalleryNode, GalleryTree, OverrideRecord } from './gallery-tree';

let _cache: GalleryTree | null = null;

export async function getGalleryTree(): Promise<GalleryTree> {
  if (_cache) return _cache;

  const photoEntries = await getCollection('photos');
  const albumEntries = await getCollection('albums');

  const photos = photoEntries.map((e) => e.data);
  const overrides: OverrideRecord[] = albumEntries.map((e) => e.data as OverrideRecord);

  _cache = buildGalleryTree(photos, overrides, {
    warn: (msg) => console.warn(`[gallery-tree] ${msg}`),
  });

  return _cache;
}

export { flattenTree, getVisibleChildren };
export type { GalleryNode, GalleryTree };
