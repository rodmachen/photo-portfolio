# Production Site: Cloudinary-Driven Photo Portfolio

Proposed plan filename for Step 0: `production-site.md`

## Context

The site at photo.rodmachen.com currently runs on Adobe Portfolio, whose core structural limitation is a single-level page hierarchy (subject page → child page, nothing deeper) with no control over custom code, URL structure, or page placement. This repo already contains the replacement's foundations: an Astro 5 static site on Vercel that loads photos at build time from Cloudinary's Search API, plus a mature, well-tested Lightroom Classic export plugin (`tools/structured-export.lrplugin`) that exports collections to a structured local folder tree.

This plan completes the repo as a production app that replaces Adobe Portfolio:

- **Structure beyond Adobe Portfolio's limits**: site structure auto-derived from the Cloudinary folder tree at arbitrary depth. Creating a new page = uploading photos to a new folder. Optional YAML overrides per node for title, description, cover, order, and visibility.
- **Publish pipeline**: Lightroom Classic → existing export plugin → new sync script that mirrors the export tree to Cloudinary and triggers a Vercel rebuild — eventually one click from inside Lightroom.
- **Production quality**: JS test framework + CI, env hygiene, mobile responsiveness, responsive images, SEO/sitemap, licensing page and footer (required — the plugin embeds the licensing URL in every exported image's XMP), 404, security headers, and a DNS cutover runbook. No dark mode. Claude Design not used; the existing minimal design is extended by hand.

Decisions confirmed with Rod: auto-discovery + YAML overrides; sync script first, then one-click plugin upload; domain cutover included in this plan; extend current design by hand.

## Architecture decisions

**D1 — Root-level routes (drop `/albums` prefix).** A catch-all `src/pages/[...slug].astro` serves `/tennis`, `/tennis/atx-open-2025`, etc. Matches Adobe Portfolio's URL shape (preserves external links after cutover) and reads better on a dedicated photo domain. Static routes (`/about`, `/licensing`) take priority over the catch-all in Astro. The tree builder fails the build if a top-level folder slug collides with a reserved set (`about`, `licensing`, `albums`, `404`). `vercel.json` 301-redirects `/albums` → `/` and `/albums/:path*` → `/:path*`.

**D2 — Data model.** Pure module `src/lib/gallery-tree.ts`, no Astro imports:

```ts
interface GalleryNode {
  slug: string;          // route segment, derived from folder name, overridable
  path: string[];        // segments from root, e.g. ['tennis', 'atx-open-2025']
  folder: string;        // full Cloudinary folder, e.g. 'photo-portfolio/tennis/atx-open-2025'
  title: string;         // override ?? kebab/underscore → Title Case
  description?: string;
  cover: string;         // override ?? first own photo ?? first child's cover (recursive)
  order?: number;        // ordered nodes first, then alpha ascending
  hidden: boolean;       // unlisted: page builds, excluded from nav/listings/sitemap
  photos: PhotoRef[];    // photos directly in this folder, natural-sorted by public_id
  children: GalleryNode[];
  photoCount: number;    // recursive
}
```

Photos are grouped by `asset_folder`; every ancestor segment materializes as a node, so photo-less intermediate folders become section pages, and folders with both photos and subfolders render both a child grid and a gallery. Overrides come from a reworked `albums` content collection: YAML files keyed by explicit `path:` (e.g. `path: tennis/atx-open-2025`), schema `{path, title?, description?, cover?, order?, hidden?, slug?}`. A memoized `getGalleryTree()` accessor in `src/lib/site-tree.ts` feeds `getStaticPaths`, the home page, header nav, and sitemap.

**D3 — Migration.** `src/content/albums/tennis.yaml` is rewritten to the new override format; the children get explicit `order` values to keep reverse-chronological display (default ordering is alphabetical ascending, which would put 2023 first). Old nested-children schema and both `albums/` routes are deleted in the same step the catch-all lands, so every commit builds green.

**D4 — Sync mapping.** Local `<root>/<set...>/<collection>/<preset>/<name>.jpg` → Cloudinary folder `photo-portfolio/<set...>/<collection>` with deterministic `public_id` (folder path + filename stem), making uploads idempotent. Source preset: `portfolio` (2048px short edge) — large enough that Cloudinary transforms never upscale for the lightbox. Change detection: local MD5 vs remote etag. Deletions only behind `--delete`; deploy hook only behind `--deploy` and only when something changed. Existing UI-uploaded assets with random public_id suffixes keep working (the tree keys on `asset_folder`); the cutover runbook covers optional one-time re-upload of legacy collections to converge naming.

## Steps

### Step 0 — Branch, rename, and first commit ✅
1. Confirm plan filename `production-site.md` (or corrected name).
2. `git checkout -b feature/production-site`.
3. Rename this file to the confirmed name; commit as the sole first commit; push; open the PR.

Sonnet / low, tests-alongside (no tests), context-clear: no.

### Step 1 — JS quality infra: Vitest, astro check, CI ✅
- Add devDeps: `vitest`, `@astrojs/check`, `typescript`. Scripts: `test`, `check`.
- New `.github/workflows/site-ci.yml`: `npm ci`, `astro check`, `vitest run`, then `astro build` conditional on Cloudinary secrets being present (document adding `PUBLIC_CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` as repo secrets). Tests and check must pass without network.
- One smoke spec so the harness demonstrably runs.
- **Files**: `package.json`, `package-lock.json`, `vitest.config.ts`, `.github/workflows/site-ci.yml`, one spec under `src/lib/`.
- **Verify**: `npm run check` exits 0; `npx vitest run` passes; pushed branch shows both Lua and site CI jobs green on the PR.
- **Model/effort**: Sonnet / medium. Config wiring; one mildly unfamiliar corner (Vitest alongside Astro virtual modules — avoided by testing only pure modules); failures are loudly visible in CI, so verification is cheap.
- **Context-clear**: yes (first implementation step). **TDD**: tests-alongside.

### Step 2 — Env hygiene, README, .env.example ✅
- Rename `PUBLIC_CLOUDINARY_API_KEY` → `CLOUDINARY_API_KEY` in `src/lib/cloudinary-search-loader.ts` (build-time only; the PUBLIC_ prefix needlessly exposes it). Read both names during transition with a deprecation warning; document updating Vercel env.
- Add `.env.example` (names only, no values). Root `README.md`: overview, architecture (Cloudinary folder tree → auto-discovered site), env setup, scripts, plugin pointer, deploy notes.
- **Files**: `src/lib/cloudinary-search-loader.ts`, `.env.example`, `README.md`.
- **Verify**: `npm run build` succeeds with renamed var in local `.env`; `grep -r PUBLIC_CLOUDINARY_API_KEY src/` returns nothing.
- **Model/effort**: Sonnet / low. Mechanical rename plus docs; any mistake surfaces immediately as a build failure.
- **Context-clear**: no. **TDD**: tests-alongside (nothing to test).

### Step 3 — Gallery tree builder (TDD) ✅
- `src/lib/gallery-tree.ts` per D2, pure functions: `buildGalleryTree()`, `deriveTitle()`, natural sort, recursive cover resolution, ordering comparator, reserved-slug validation (throw with clear message on collision, including post-override duplicate slugs), hidden handling, and `flattenTree()` returning `[{params, node}]` for `getStaticPaths` (hidden nodes included — they build but are unlisted).
- Tests first covering: single-level, three-deep, mixed photo+children nodes, default title/cover/order derivation, cover fallback recursion through photo-less sections, hidden exclusion from children listings, reserved-slug throw, duplicate-slug throw, natural sort (`-801` before `-7877`).
- **Files**: `src/lib/gallery-tree.ts`, `src/lib/gallery-tree.test.ts`.
- **Verify**: `npx vitest run` green with every enumerated case visible as a test name.
- **Model/effort**: Opus / high. The load-bearing transformation everything else consumes; real design ambiguity (cover/order/hidden semantics, mixed nodes) and maximal compounding risk — routes, nav, SEO, and sync all sit on it. Verifiability via unit tests is excellent, which is why TDD is mandatory here.
- **Context-clear**: yes (new chapter). **TDD**: TDD (data transformation).

### Step 4 — Data-model integration + catch-all routes ✅
Single step so every commit builds green (schema and routes must swap together):
- `src/content.config.ts`: replace `albums` schema with the override schema (D2). Loader hardening in `cloudinary-search-loader.ts`: raise limit to 5000, throw instead of silently truncating at the limit, log the loaded count.
- `src/lib/site-tree.ts`: memoized `getGalleryTree()` bridging `getCollection('photos')`/`getCollection('albums')` into the pure builder.
- New `src/pages/[...slug].astro`: renders breadcrumbs (new `src/components/Breadcrumbs.astro`), child `AlbumCard` grid when children exist, masonry gallery + lightbox when photos exist, both for mixed nodes. Prev/next links between sibling galleries on leaf pages.
- Rewrite `src/pages/index.astro` from the tree; give `AlbumCard` an `href` prop. Delete `src/pages/albums/` (all three files). Add `vercel.json` redirects per D1. Migrate `tennis.yaml` per D3.
- **Files**: `src/content.config.ts`, `src/lib/cloudinary-search-loader.ts`, `src/lib/site-tree.ts`, `src/pages/[...slug].astro`, `src/pages/index.astro`, `src/components/Breadcrumbs.astro`, `src/components/AlbumCard.astro`, `vercel.json`, `src/content/albums/tennis.yaml`, deleted `src/pages/albums/*`.
- **Verify**: `npm run check` and `npx vitest run` green; `npm run build` log shows photo count with no truncation; `dist/tennis/index.html` and `dist/tennis/atx-open-2025/index.html` exist and `dist/albums/` does not; `npm run dev` click-through home → tennis → atx-open-2025 → lightbox opens, breadcrumbs resolve.
- **Model/effort**: Sonnet / high. Multi-file route surgery with three rendering branches; ambiguity is low (design fixed in D1/D2, logic tested in Step 3) but the blast radius is the whole site and part of verification is manual.
- **Context-clear**: no (continuation of Step 3's model). **TDD**: tests-alongside (wiring; logic was TDD'd in Step 3).

### Step 5 — Header nav + mobile responsiveness pass ✅
- Header nav: brand, top-level tree sections from `getGalleryTree()` (replacing the static Albums link; active state by path prefix), About. CSS-first mobile disclosure menu.
- Audit breakpoints in `global.css`/`masonry.css`; verify PhotoSwipe touch gestures at phone width.
- **Files**: `src/components/Header.astro`, `src/styles/global.css`, possibly `src/styles/masonry.css`.
- **Verify**: `npm run dev` at 375/768/1280px: nav usable, no horizontal scroll, grid collapses to one column, lightbox swipes; `npm run build` green.
- **Model/effort**: Sonnet / medium. Pure presentation; verification is manual but each check is fast; no unfamiliar internals.
- **Context-clear**: no. **TDD**: tests-alongside.

### Step 6 — Image delivery polish ✅
- `PhotoCard`: verify `CldImage` emits `f_auto`/`q_auto` + srcset; tune `sizes` to the real grid. Add `data-pswp-srcset` so the lightbox serves responsive sizes; cap lightbox dimensions at the source's native size (no upscaling).
- `Lightbox.astro`: replace the jsDelivr CDN stylesheet link with a bundled `import 'photoswipe/style.css'` (removes a third-party runtime dependency).
- Eager-load/`fetchpriority` for above-the-fold covers on the home page.
- **Files**: `src/components/PhotoCard.astro`, `src/components/Lightbox.astro`, possibly `src/components/AlbumCard.astro`.
- **Verify**: grep a built gallery page for `srcset` and `f_auto,q_auto`; dev-tools network tab shows size-appropriate images at mobile width; no request to cdn.jsdelivr.net.
- **Model/effort**: Sonnet / medium. astro-cloudinary/PhotoSwipe interop is the one unfamiliar-internals area — requires reading emitted HTML; low compounding risk; directly verifiable in built output.
- **Context-clear**: yes (distinct topic; Steps 3–5 context is noise here). **TDD**: tests-alongside.

### Step 7 — Site completeness: licensing, footer, 404, about ✅
- `src/pages/licensing.astro` with the content structure specified in `docs/lightroom-export-spec.md`. Footer per spec: `© {year} Rod Machen. All rights reserved.` left; `Licensing` + `Contact` (mailto) right; stacked on mobile. `src/pages/404.astro`. About page real copy (placeholder marked for Rod).
- Fix the WebStatement URL mismatch: the plugin embeds `https://rodmachen.com/licensing` but this site is photo.rodmachen.com — change the plugin default to `https://photo.rodmachen.com/licensing` in `Prefs.lua`, update `prefs_spec.lua` and the spec doc. (Images already exported keep the old URL; the runbook notes a redirect option on rodmachen.com.)
- **Files**: `src/pages/licensing.astro`, `src/pages/404.astro`, `src/components/Footer.astro`, `src/pages/about.astro`, `tools/structured-export.lrplugin/Prefs.lua`, `tools/spec/prefs_spec.lua`, `docs/lightroom-export-spec.md`.
- **Verify**: `dist/licensing/index.html` and `dist/404.html` exist; footer links present on every built page (grep dist); `cd tools && busted && luacheck .` green.
- **Model/effort**: Sonnet / medium. Content-heavy and low ambiguity (the spec supplies the copy); the one judgment call (WebStatement URL) is decided above.
- **Context-clear**: no. **TDD**: tests-alongside (prefs_spec updated with the new default).

### Step 8 — SEO: meta, OG, sitemap, canonical, security headers ✅
- `BaseLayout` head: canonical URL, OG/Twitter tags; gallery pages pass `og:image` built from the node cover via a Cloudinary `c_fill` ~1200×630 transform.
- `astro.config.mjs`: `site: 'https://photo.rodmachen.com'`; add `@astrojs/sitemap` with a filter excluding hidden nodes. Fix `public/robots.txt` to point at `/sitemap-index.xml`.
- `vercel.json` headers: `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `X-Frame-Options: SAMEORIGIN`, minimal `Permissions-Policy`. Strict CSP deferred (Astro inline scripts make it churn-prone) — noted as follow-up.
- **Files**: `src/layouts/BaseLayout.astro`, `src/pages/[...slug].astro`, `astro.config.mjs`, `package.json`, `public/robots.txt`, `vercel.json`.
- **Verify**: `dist/sitemap-index.xml` exists, lists gallery URLs, omits hidden ones; grep a built gallery page for `og:image` and `rel="canonical"`; after deploy, `curl -I` on the preview shows the headers.
- **Model/effort**: Sonnet / medium. Standard integrations; the only thought required is the og:image transform; everything is grep-verifiable in dist.
- **Context-clear**: no. **TDD**: tests-alongside. **Dependency note**: adds `@astrojs/sitemap` (runtime integration, small).

### Step 9 — Cloudinary sync script (TDD for diff logic) ✅
- Pure modules first: `scripts/lib/local-walk.ts` (walk export root, find `<.../collection>/<preset>/*.jpg`, map to `{cloudFolder, publicId, absPath, md5}` per D4) and `scripts/lib/sync-plan.ts` (`computeSyncPlan(local, remote)` → `{uploads, updates, deletes, unchanged}` via MD5-vs-etag). Both fully unit-tested.
- `scripts/sync.ts` CLI (run via `tsx`): fetch remote inventory with the Admin API `resources?prefix=` (paginated; friendlier rate limits than Search), print the plan, apply unless `--dry-run`. Flags: `--delete`, `--deploy` (POSTs `VERCEL_DEPLOY_HOOK_URL`, only when changes occurred), `--root`, `--preset` (default `portfolio`). Upload with explicit `public_id`, `overwrite: true`, `invalidate: true`. **First real run verifies the account's folder mode (dynamic vs fixed — `asset_folder` on existing assets suggests dynamic) against one small collection before any bulk run.**
- Add devDeps `cloudinary`, `tsx`; script `"sync"`. README section.
- **Files**: `scripts/sync.ts`, `scripts/lib/local-walk.ts`, `scripts/lib/sync-plan.ts`, `scripts/lib/*.test.ts`, `package.json`, `README.md`.
- **Verify**: `npx vitest run` green; `npm run sync -- --dry-run` against the real iCloud export prints a sensible plan touching zero assets; real run on one small collection uploads correctly (visible in Cloudinary console); `npm run build` then picks the new folder up as a page.
- **Model/effort**: Opus / high. Side effects against the production Cloudinary account, account-mode ambiguity, idempotency requirements, and genuine diff business logic; dry-run + unit tests make it verifiable but mistakes (mass mis-uploads) are costly.
- **Context-clear**: yes (independent subsystem; only D4 needed). **TDD**: TDD for `sync-plan.ts` and `local-walk.ts`; tests-alongside for the CLI shell. **Dependency note**: adds `cloudinary` (official SDK) and `tsx` as devDeps.

### Step 10 — Plugin one-click upload (v0.3.0) ✅
- New dialog checkbox "Upload to Cloudinary after export" (pref `uploadAfterExport`, default false) + pref `siteRepoPath`. After all preset passes succeed, shell out via the existing `LrTasks.execute` pattern: `cd <siteRepoPath> && npm run sync -- --root <exportRoot> --preset portfolio --deploy`, output logged. Resolve `node`/`npm` by absolute-path probe (same pattern as the exiftool probe — GUI apps don't inherit shell PATH).
- Build the command string in a pure, busted-testable `Utils.buildSyncCommand(repoPath, exportRoot)` including path quoting. Sync failure surfaces in the summary dialog but does not mark the export failed. Bump `Info.lua`; update plugin README and spec.
- **Files**: `tools/structured-export.lrplugin/{ExportDialog,ExportTask,Prefs,Utils,Info}.lua`, `tools/spec/{utils_spec,prefs_spec}.lua`, `tools/structured-export.lrplugin/README.md`, `docs/lightroom-export-spec.md`.
- **Verify**: `cd tools && busted && luacheck .` green (command-builder + pref tests); manual: export a tiny collection from Lightroom with the box checked → sync runs, Cloudinary shows uploads, deploy hook fires.
- **Model/effort**: Sonnet / medium. Dialog, prefs, and shell-out patterns all exist in-repo; main risks (quoting, PATH inside Lightroom) are covered by the pure-function tests and the documented probe pattern.
- **Context-clear**: yes (different language/toolchain). **TDD**: TDD for `buildSyncCommand` and pref defaults; tests-alongside for dialog/task wiring.

### Step 11 — Parity check, production config, cutover runbook ✅
- `docs/cutover.md`: (1) content parity checklist — every gallery on the live Adobe Portfolio site vs the Vercel preview, page by page (presence, photo counts, covers, titles), executed and recorded; (2) Vercel production setup — env vars, deploy hook creation, `photo.rodmachen.com` added to the project; (3) DNS cutover — repoint the CNAME to `cname.vercel-dns.com`, propagation check via `dig`, cert auto-provision; (4) rollback — revert CNAME (Adobe Portfolio untouched as fallback); (5) post-cutover smoke list (home, deep gallery, lightbox, licensing, 404, sitemap, OG share preview); (6) optional legacy-asset convergence (re-upload UI-uploaded collections through sync, delete suffixed originals).
- **Files**: `docs/cutover.md`, possibly small YAML fixes found during parity.
- **Verify**: parity checklist complete with every row checked or explicitly waived; preview passes the smoke list. The DNS flip itself happens when Rod chooses; the merge gate is parity-complete + runbook reviewed.
- **Model/effort**: Sonnet / low. Documentation plus methodical manual comparison; no code ambiguity; the checklist is the verification.
- **Context-clear**: no. **TDD**: n/a (docs).

### Step 12 — Fix review feedback
- Address PR review comments (self-review + any external). Final sweep: `npm run check && npx vitest run && npm run build && (cd tools && busted && luacheck .)`.
- Commit as "Fix review feedback: <summary>", push, complete only after pushed.
- **Model/effort**: Sonnet / medium (bump to Opus if review flags tree-builder semantics).
- **Context-clear**: yes. **TDD**: match the code touched.

## Risks / open items

1. **Default ordering** is alphabetical ascending; reverse-chronological display requires `order` overrides (tennis gets them in Step 4). A newest-photo-first default was rejected as unstable — every sync would reshuffle pages.
2. **Cover defaulting** (first photo by natural sort) is deterministic but aesthetically arbitrary; expect to add two-line `cover:` override YAMLs for top-level sections.
3. **`hidden` = unlisted** (page builds, not linked/indexed). If fully-absent is wanted later, it is a one-line change in `flattenTree`.
4. **Cloudinary folder mode** (dynamic vs fixed) changes upload parameter semantics; Step 9 verifies on one small collection before any bulk run.
5. **Mixed public_id schemes**: legacy UI-uploaded assets coexist fine (tree keys on `asset_folder`), but re-exporting an old collection through sync would create duplicates with different ids — convergence is a documented manual step in the runbook, not automated.
6. **CI build hits Cloudinary** on every push once secrets are added; acceptable at this scale, and the build step is skipped when secrets are absent.
7. **Strict CSP deferred** — noted in Step 8; revisit after launch.

## Verification (end-to-end)

1. `npm run check && npx vitest run && npm run build` green locally and in CI; `cd tools && busted && luacheck .` green.
2. Built `dist/` contains root-level gallery routes at arbitrary depth, sitemap, licensing, 404; no `/albums` paths.
3. Full publish pipeline exercised once: Lightroom export (plugin, checkbox on) → sync uploads to Cloudinary → deploy hook → new page appears on the Vercel preview without touching the repo.
4. Mobile click-through at 375px: nav, galleries, lightbox swipe.
5. Parity checklist vs Adobe Portfolio complete; cutover runbook ready; DNS flip at Rod's discretion.
