import { toSlug } from './utils';

/**
 * Extract the site route paths for a hidden gallery node from its raw YAML
 * content. Returns both the trailing-slash and non-trailing-slash forms.
 *
 * Uses the same slugification logic as buildGalleryTree so that paths with
 * capitals, underscores, or spaces still match the built routes, and `slug:`
 * overrides are honored on the final segment.
 *
 * Returns an empty array when the YAML is not hidden or has no `path:` field.
 */
export function deriveHiddenPathsFromYaml(content: string): string[] {
  if (!/^hidden:\s*true/m.test(content)) return [];
  const pathMatch = content.match(/^path:\s*(.+)$/m);
  if (!pathMatch) return [];

  const rawSegments = pathMatch[1].trim().replace(/^\/|\/$/g, '').split('/');
  const segments = rawSegments.map(toSlug);

  const slugMatch = content.match(/^slug:\s*(.+)$/m);
  if (slugMatch) {
    segments[segments.length - 1] = toSlug(slugMatch[1].trim());
  }

  const p = segments.join('/');
  return [`/${p}`, `/${p}/`];
}
