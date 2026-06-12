// @ts-check
import { defineConfig } from 'astro/config';
import vercel from '@astrojs/vercel';
import sitemap from '@astrojs/sitemap';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

// Derive hidden route paths from YAML overrides at config time.
// These pages build but must be excluded from the sitemap.
const hiddenPaths = new Set();
try {
  const albumsDir = new URL('./src/content/albums/', import.meta.url).pathname;
  for (const f of readdirSync(albumsDir)) {
    if (!f.endsWith('.yaml') && !f.endsWith('.yml')) continue;
    const content = readFileSync(join(albumsDir, f), 'utf8');
    if (/^hidden:\s*true/m.test(content)) {
      const match = content.match(/^path:\s*(.+)$/m);
      if (match) {
        const p = match[1].trim().replace(/^\/|\/$/g, '');
        hiddenPaths.add(`/${p}`);
        hiddenPaths.add(`/${p}/`);
      }
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
