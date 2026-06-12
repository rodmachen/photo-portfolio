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
| `npm run sync` | Mirror the local export tree to Cloudinary (see below) |

## Lightroom plugin

`tools/structured-export.lrplugin` is a Lightroom Classic export plugin that exports collections to a structured local folder tree matching the Cloudinary folder convention:

```
<export-root>/<set>/<collection>/<preset>/<filename>.jpg
```

See `tools/structured-export.lrplugin/README.md` and `docs/lightroom-export-spec.md` for installation and usage.

## Sync to Cloudinary

`npm run sync` (`scripts/sync.ts`, run via `tsx`) mirrors the local Lightroom export tree to Cloudinary. The diff logic lives in two pure, unit-tested modules — `scripts/lib/local-walk.ts` (build the local inventory) and `scripts/lib/sync-plan.ts` (classify uploads / updates / deletes / unchanged).

**Mapping (plan decision D4).** A local file at `<root>/<set...>/<collection>/<preset>/<name>.jpg` maps to Cloudinary folder `photo-portfolio/<set...>/<collection>` with a deterministic `public_id` of `<folder>/<filename-stem>`. Every path segment is slugified with the same `toSlug` helper the site uses to derive routes, so folder names, the resulting `asset_folder`, and the site URL stay consistent. The deterministic public_id makes re-runs idempotent (overwrite, not duplicate). Change detection compares the local file MD5 against the remote `etag`.

**Default source preset** is `portfolio` (2048px short edge — large enough that Cloudinary transforms never upscale the lightbox). Override with `--preset`.

**Account folder mode.** This Cloudinary account is in **dynamic folder mode**: assets carry an `asset_folder` and the site's gallery tree groups on it. Uploads therefore pass `asset_folder` plus `use_asset_folder_as_public_id_prefix: false` and an explicit `public_id` that already contains the full folder path (per Cloudinary docs, with that flag false the `asset_folder` does not alter the `public_id`). Legacy assets uploaded through the Cloudinary UI have random public_id suffixes (e.g. `atx-open-2025-6959_q3l63c`) and **no** `photo-portfolio/` public_id prefix, so the prefix-based remote listing does not see them — they are never proposed for deletion. Re-syncing a collection that already has legacy assets creates deterministically-named duplicates in the same folder; converging (re-upload then delete the suffixed originals) is a documented manual step in the cutover runbook, not automated here.

### Flags

| Flag | Effect |
|------|--------|
| `--dry-run` | Print the plan, perform **no** writes. |
| `--root <path>` | Export root. Default: `~/Library/Mobile Documents/com~apple~CloudDocs/Photos`. |
| `--preset <name>` | Preset subfolder to mirror. Default: `portfolio`. |
| `--filter <substring>` | Only act on assets whose `public_id` contains the substring — use this to scope a run to one collection. |
| `--delete` | Allow deletion of remote-only assets (off by default; deletions are otherwise reported but inert). **Footgun**: any managed asset (`photo-portfolio/*`) absent from the current export root is deleted — if the root contains only some collections, unsynced collections are removed. Always combine with `--filter` to scope deletions to one collection, or verify the plan with `--dry-run` first. |
| `--deploy` | POST `VERCEL_DEPLOY_HOOK_URL`, but only when something actually changed. |

### First real run

Always preview with `--dry-run` first. Then scope your **first** real run to one small collection with `--filter`, and do **not** pass `--delete`:

```
npm run sync -- \
  --root "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Photos" \
  --preset portfolio \
  --filter atx-open-2023
```

Pick the smallest collection you have exported with the `portfolio` preset (substitute its folder slug for `atx-open-2023`). Verify the upload in the Cloudinary console and confirm the new page appears after `npm run build`, then proceed to a full run. If you have only exported the `web` preset so far, either re-export with the `portfolio` preset or add `--preset web` for the test run.

## Deploy

The site deploys automatically on push to `main` via Vercel's GitHub integration. Manual rebuilds can be triggered via a Vercel deploy hook (see `VERCEL_DEPLOY_HOOK_URL` in `.env.example`).

Production URL: `https://photo.rodmachen.com`
