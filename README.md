# photo-portfolio

Astro 5 static site for [photo.rodmachen.com](https://photo.rodmachen.com), deployed on Vercel. Site structure is auto-derived from the Cloudinary folder tree — creating a new gallery page means uploading photos to a new folder.

## Architecture

```
Cloudinary folder tree
  photo-portfolio/
    tennis/
      atx-open-2025/
      us-open-2024/
    travel/
```

At build time the Cloudinary Search API is queried for all assets under `photo-portfolio/`. The folder tree is walked to produce `GalleryNode` objects, which drive `getStaticPaths` for a catch-all `[...slug].astro` route. Top-level slugs map to root routes (`/tennis`, `/travel`); deeper folders produce nested routes (`/tennis/atx-open-2025`).

Optional YAML files under `src/content/albums/` override per-node title, description, cover image, display order, and visibility.

## Prerequisites

- Node.js 20+
- A [Cloudinary](https://cloudinary.com) account with photos uploaded under a `photo-portfolio/` folder prefix

## Environment setup

Copy `.env.example` to `.env` and fill in your values:

```
PUBLIC_CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

**Deprecation note:** `PUBLIC_CLOUDINARY_API_KEY` has been renamed to `CLOUDINARY_API_KEY`. The build loader accepts both names during transition and emits a warning when the old name is used. Update your Vercel project env vars to `CLOUDINARY_API_KEY` to silence the warning and remove the old var.

For Vercel deployments, add these three variables in the Vercel project settings under Environment Variables. The build step is skipped (with a warning, not an error) when credentials are absent — CI runs without secrets for type checking and unit tests.

## npm scripts

| Script | Purpose |
|--------|---------|
| `npm run dev` | Local dev server with HMR |
| `npm run build` | Production build (queries Cloudinary) |
| `npm run preview` | Serve the built `dist/` locally |
| `npm run check` | Astro type checking via `astro check` |
| `npm test` | Run Vitest unit tests |

## Lightroom plugin

`tools/structured-export.lrplugin` is a Lightroom Classic export plugin that exports collections to a structured local folder tree matching the Cloudinary folder convention:

```
<export-root>/<set>/<collection>/<preset>/<filename>.jpg
```

See `tools/structured-export.lrplugin/README.md` and `docs/lightroom-export-spec.md` for installation and usage.

A future sync script (`npm run sync`) will mirror the local export tree to Cloudinary and optionally trigger a Vercel rebuild via `VERCEL_DEPLOY_HOOK_URL`.

## Deploy

The site deploys automatically on push to `main` via Vercel's GitHub integration. Manual rebuilds can be triggered via a Vercel deploy hook (see `VERCEL_DEPLOY_HOOK_URL` in `.env.example`).

Production URL: `https://photo.rodmachen.com`
