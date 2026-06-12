/** Convert a folder-name segment to a URL slug (kebab-case, lowercase). */
export function toSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/[_\s]+/g, '-')
    .replace(/[^a-z0-9-]/g, '')
    .replace(/^-+|-+$/g, '');
}

/** Convert a slug or folder name to Title Case for display. */
export function toTitle(name: string): string {
  return name
    .replace(/[-_]/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}
