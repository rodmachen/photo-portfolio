// @ts-check
import { defineConfig } from 'astro/config';
import vercel from '@astrojs/vercel';
import sitemap from '@astrojs/sitemap';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { deriveHiddenPathsFromYaml } from './src/lib/hidden-paths.ts';

// Derive hidden route paths from YAML overrides at config time.
// Uses deriveHiddenPathsFromYaml (which runs toSlug on every segment and
// applies slug: overrides) so the excluded paths match the built routes
// exactly, even when folder names contain capitals or underscores.
const hiddenPaths = new Set();
try {
  const albumsDir = new URL('./src/content/albums/', import.meta.url).pathname;
  for (const f of readdirSync(albumsDir)) {
    if (!f.endsWith('.yaml') && !f.endsWith('.yml')) continue;
    const content = readFileSync(join(albumsDir, f), 'utf8');
    for (const p of deriveHiddenPathsFromYaml(content)) {
      hiddenPaths.add(p);
    }
  }
} catch {
  // No albums directory — treat as no hidden nodes.
}

export default defineConfig({
  site: 'https://photo.rodmachen.com',
  output: 'static',
  adapter: vercel(),
  integrations: [
    sitemap({
      filter: (page) => {
        const url = new URL(page);
        return !hiddenPaths.has(url.pathname);
      },
    }),
  ],
});
