Generated: June 12, 2026
Saved: June 12, 2026

# Step 12: Review Feedback Report

## Summary

All 9 non-blocking findings addressed. No deferrals. Zero new issues surfaced.

Full sweep before commit: `npm run check` (0 errors), `npx vitest run` (52 tests, 5 files), `npm run build` (8 pages, sitemap OK), `busted` (101 successes), `luacheck` (0 warnings/errors).

---

## Findings addressed

### #1 — Silent empty build (cloudinary-search-loader.ts)

Added a `VERCEL`-gated throw: if `import.meta.env.VERCEL` is set and any credential is missing, the loader now throws with an explicit message rather than warning and returning zero photos. The warn-and-skip path remains for CI runs (no `VERCEL` env var in GitHub Actions).

**File changed**: `src/lib/cloudinary-search-loader.ts`

---

### #2 — Export-root path mismatch

Empirically verified: `~/Library/Mobile Documents/com~apple~CloudDocs/Photos/` contains `tennis/` (the structured export tree). `iCloud Pictures/` contains unrelated personal content. `docs/lightroom-export-spec.md` line 59 also specifies `Photos/` as the canonical root.

Changed `Prefs.lua` default `exportRoot` from `iCloud Pictures` to `Photos`. Updated `prefs_spec.lua` assertions to match. `sync.ts`, `README.md`, and `cutover.md` were already using `Photos/` — no changes needed there.

**Files changed**: `tools/structured-export.lrplugin/Prefs.lua`, `tools/spec/prefs_spec.lua`

---

### #3 — npm shebang/PATH

`buildSyncCommand` now prepends `PATH="<npmDir>:$PATH"` before the npm invocation so that Homebrew/nvm node is on the subprocess PATH when Lightroom executes the command under its minimal GUI shell. The npm binary's parent directory is extracted via Lua pattern `(.*)/'` (greedy, returns longest directory prefix). Updated all three `buildSyncCommand` test cases to include the new PATH prefix in their expected strings.

**Files changed**: `tools/structured-export.lrplugin/Utils.lua`, `tools/spec/utils_spec.lua`

---

### #4 — --delete footgun

Added a loud multi-line warning printed to stdout before any deletion is applied, stating the count and the risk (unsynced collections will be deleted). Updated the `--delete` row in the README to include the footgun explanation and explicit recommendation to use `--filter`.

**Files changed**: `scripts/sync.ts`, `README.md`

---

### #5 — Sitemap hidden-route derivation

Extracted the hidden-path YAML-reading logic into `src/lib/hidden-paths.ts` — a pure function `deriveHiddenPathsFromYaml(content)` that runs `toSlug` on every path segment and applies any `slug:` override to the final segment. `astro.config.mjs` now imports and calls this helper instead of using the raw regex path. Added 8 tests in `src/lib/hidden-paths.test.ts` covering: non-hidden YAML, missing path, simple path, segments with capitals/underscores, slug override, slugified slug override, leading/trailing slash stripping, and top-level node.

**Files changed**: `astro.config.mjs`, `src/lib/hidden-paths.ts` (new), `src/lib/hidden-paths.test.ts` (new)

---

### #6 — Override match-key contract

Fixed `transform` in `gallery-tree.ts` to track a parallel `parentDefaultPath` array (the default folder-derived path, never modified by `slug:` overrides) alongside `parentSlugPath` (the rendered route path). Override lookup now uses `defaultPathKey` derived from `parentDefaultPath`, so a child override keyed by `tennis/atx-open-2025` matches correctly even when the `tennis` node has been renamed to `sport` via a slug override. Added a test in `gallery-tree.test.ts` covering exactly this case.

**Files changed**: `src/lib/gallery-tree.ts`, `src/lib/gallery-tree.test.ts`

---

### #7 — hidden-leaf prev/next

Added `if (idx !== -1)` guard around the `prevNode`/`nextNode` derivation in `[...slug].astro`. Previously, a hidden leaf (not in the visible-siblings list) returned `idx === -1`, and `-1 < siblings.length - 1` would incorrectly assign `nextNode = siblings[0]`.

**Files changed**: `src/pages/[...slug].astro`

---

### #8 — About placeholder

Kept the placeholder copy in `src/pages/about.astro` (user's content to write). Added "About page" entry to the cutover smoke list in `docs/cutover.md` so it gates the DNS flip.

**Files changed**: `docs/cutover.md`

---

### #9 — Home og:image

`src/pages/index.astro` now derives an `ogImage` from the first visible top-level node's cover via `getCldImageUrl` with the same `c_fill 1200×630` transform used on gallery pages. Passed as `ogImage` prop to `BaseLayout`.

**Files changed**: `src/pages/index.astro`

---

## Deferrals

None.

---

## New issues surfaced

None.
