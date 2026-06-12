# Cutover Runbook — photo.rodmachen.com

Replaces the live Adobe Portfolio site with the Astro/Vercel build on this branch.
DNS flip is at Rod's discretion; this document is the gate and the guide.

---

## 1. Content Parity Checklist

### How parity was assessed

Adobe Portfolio pages are JS-rendered; image counts were obtained by fetching raw HTML and counting `grid__item-container` elements (the per-photo wrapper Adobe injects server-side). Local build counts are from `data-pswp-width` attributes in `dist/` HTML (one per photo). All automated rows were executed at time of writing.

### Adobe Portfolio site structure

Top-level nav: **Tennis**, **Theatre**, **Europe**  
Adobe Portfolio uses flat URLs — sub-galleries sit at the root path, not nested under their section.

### Parity table

| Adobe URL | Adobe photos | Local route | Local photos | Status |
|-----------|-------------|-------------|--------------|--------|
| `/tennis` (section) | — (index only) | `/tennis` | — (index only) | ✅ equal |
| `/atx-open-2023` | 12 | `/tennis/atx-open-2023` | 12 | ✅ equal |
| `/atx-open-2024` | 12 | `/tennis/atx-open-2024` | 18 | ℹ️ local has more — additional photos were uploaded to Cloudinary after Adobe Portfolio was last updated; not a regression |
| `/atx-open-2025` | 27 | `/tennis/atx-open-2025` | 34 | ℹ️ local has more — same reason as above |
| `/2025-austin-125` | 9 | *(not in local build)* | — | ⚠️ deferred — this collection is not yet in Cloudinary; upload via sync before cutover or accept as post-cutover work |
| `/theatre` (section) | — (index only) | *(not in local build)* | — | ⚠️ deferred — Theatre collections not yet in Cloudinary; see note below |
| `/our-town` | 14 | *(not in local build)* | — | [ ] visual check — Rod |
| `/all-is-calm` | 14 | *(not in local build)* | — | [ ] visual check — Rod |
| `/into-the-woods` | 16 | *(not in local build)* | — | [ ] visual check — Rod |
| `/lone-riders` | 16 | *(not in local build)* | — | [ ] visual check — Rod |
| `/fiddler-on-the-roof` | 11 | *(not in local build)* | — | [ ] visual check — Rod |
| `/shadowlands` | 14 | *(not in local build)* | — | [ ] visual check — Rod |
| `/europe` (section) | — (index only) | *(not in local build)* | — | ⚠️ deferred — Europe collections not yet in Cloudinary; see note below |
| `/england` | 17 | *(not in local build)* | — | [ ] visual check — Rod |
| `/paris` | 34 | *(not in local build)* | — | [ ] visual check — Rod |
| `/ile-de-france` | 10 | *(not in local build)* | — | [ ] visual check — Rod |
| `/the-netherlands` | 15 | *(not in local build)* | — | [ ] visual check — Rod |
| `/belgium` | 17 | *(not in local build)* | — | [ ] visual check — Rod |
| `/austria` | 20 | *(not in local build)* | — | [ ] visual check — Rod |

### Notes on deferred galleries

**Theatre and Europe** (12 galleries, ~194 photos): These collections exist on Adobe Portfolio but have not been exported through the Lightroom plugin or synced to Cloudinary. They will not appear in the local build until they are exported and synced. **Decision required:** either (a) sync these collections before DNS cutover to achieve full parity at launch, or (b) cut over with Tennis-only and add Theatre/Europe post-launch. Option (b) is safe — Adobe Portfolio remains live until the DNS flip, so these galleries stay accessible until new builds include them.

**`/2025-austin-125`** (9 photos): Present on Adobe Portfolio but absent from the Cloudinary account. This may be an older upload that predates the sync workflow. Export from Lightroom and sync, or accept as a post-cutover gap.

**URL shape change**: Adobe Portfolio uses flat slugs (`/atx-open-2023`) while the new site uses nested paths (`/tennis/atx-open-2023`). The old flat URLs will 404 after cutover. If these URLs have been shared, add redirects in `vercel.json`:
```json
{ "source": "/atx-open-2023", "destination": "/tennis/atx-open-2023", "permanent": true },
{ "source": "/atx-open-2024", "destination": "/tennis/atx-open-2024", "permanent": true },
{ "source": "/atx-open-2025", "destination": "/tennis/atx-open-2025", "permanent": true }
```

---

## 2. Vercel Production Setup

Complete these steps before the DNS flip. All changes are in the Vercel dashboard for the `photo-portfolio` project.

### Environment variables

| Variable | Value | Note |
|----------|-------|------|
| `PUBLIC_CLOUDINARY_CLOUD_NAME` | `dke4phurv` | Already set if preview builds work |
| `CLOUDINARY_API_KEY` | (from Cloudinary dashboard) | Set for Production + Preview |
| `CLOUDINARY_API_SECRET` | (from Cloudinary dashboard) | Set for Production + Preview |
| `VERCEL_DEPLOY_HOOK_URL` | (see below) | Set for Production only |
| `PUBLIC_CLOUDINARY_API_KEY` | — | **Remove** after confirming `CLOUDINARY_API_KEY` works; it is a deprecated alias emitting a build warning |

### Deploy hook

1. In Vercel → project → Settings → Git → Deploy Hooks, create a hook named `sync-trigger` scoped to the `main` branch.
2. Copy the generated URL.
3. Set `VERCEL_DEPLOY_HOOK_URL=<url>` in the Vercel project environment variables (Production).
4. Copy the same URL into your local `.env` for testing the sync script with `--deploy`.

The sync script (`npm run sync`) posts to this URL only when `--deploy` is passed and at least one asset changed. It is safe to call repeatedly (Vercel queues and deduplicates rapid webhook calls).

### Custom domain

1. Vercel → project → Settings → Domains → Add `photo.rodmachen.com`.
2. Vercel will show a CNAME target: `cname.vercel-dns.com` (confirm in the dashboard — Vercel occasionally changes this).
3. Leave the domain in "Pending" state until the DNS step below.

### GitHub Actions repo secrets

CI runs `npm run build` only when Cloudinary credentials are present (the build step is gated on their presence). To enable build verification in CI:

Go to the GitHub repository → Settings → Secrets and variables → Actions and add:

- `PUBLIC_CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

These names match the workflow's `env:` block in `.github/workflows/site-ci.yml`.

---

## 3. DNS Cutover

### Pre-flight

- Vercel project has `photo.rodmachen.com` added (step 2).
- Vercel preview URL builds green with Production env vars.
- Smoke list below passes on the Vercel preview URL.

### Change the CNAME

Log into the DNS provider that controls `rodmachen.com` (check current records with `dig CNAME photo.rodmachen.com` to identify the registrar/DNS host).

Change the CNAME for `photo.rodmachen.com`:

| Field | Old value | New value |
|-------|-----------|-----------|
| Type | CNAME | CNAME |
| Name | `photo` | `photo` |
| Value | *(current Adobe Portfolio target)* | `cname.vercel-dns.com` |
| TTL | *(current)* | 300 (lower before the flip if possible) |

### Propagation check

```bash
# Poll until the new CNAME resolves
watch -n 10 dig CNAME photo.rodmachen.com +short

# Once CNAME resolves, check the A record
dig A photo.rodmachen.com +short
```

Propagation is typically 5–15 minutes for a TTL of 300. For longer TTLs, wait the full TTL before the flip if you need a clean cutover.

### TLS certificate

Vercel auto-provisions a Let's Encrypt certificate once DNS resolves. This typically completes within 60 seconds of the CNAME propagating. The Vercel dashboard shows certificate status under the domain entry. Do not proceed to smoke testing until the cert is green (HTTPS without a browser warning).

---

## 4. Rollback

Adobe Portfolio is not modified by this cutover — it remains live and functional. To roll back:

1. Revert the CNAME at the DNS provider to its previous value (the old Adobe Portfolio CNAME target).
2. TTL permitting, traffic resumes to Adobe Portfolio within minutes.
3. No Vercel changes needed — the domain simply stops resolving to Vercel.

Keep the old CNAME value noted before you change it.

---

## 5. Post-Cutover Smoke List

Run these checks against `https://photo.rodmachen.com` after the DNS flip and cert provisioning complete.

- [ ] **Home page** — loads, shows Tennis section card(s), no console errors
- [ ] **Deep gallery** — navigate to `/tennis/atx-open-2025`, confirm photos render and photo count matches expectations (34 in current build)
- [ ] **Lightbox** — click a photo in the gallery, confirm PhotoSwipe opens, swipe/arrow navigation works, close button works
- [ ] **Licensing page** — `/licensing` loads, content correct
- [ ] **404** — navigate to `/does-not-exist`, confirm the custom 404 page renders (not a Vercel default)
- [ ] **Sitemap** — `https://photo.rodmachen.com/sitemap-index.xml` returns XML, lists gallery URLs
- [ ] **OG share preview** — paste `https://photo.rodmachen.com` into the [Facebook Sharing Debugger](https://developers.facebook.com/tools/debug/) or [Twitter Card Validator](https://cards-dev.twitter.com/validator); confirm title, description, and OG image render correctly
- [ ] **Security headers** — `curl -I https://photo.rodmachen.com` shows `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy: strict-origin-when-cross-origin`
- [ ] **Mobile** — at 375px viewport: nav disclosure menu opens/closes, gallery grid collapses to one column, lightbox swipe gesture works
- [ ] **About page** — placeholder copy replaced with real content before DNS flip (`/about` must not show `[Placeholder...]` text on launch)

---

## 6. Optional: Legacy Asset Convergence

*This section is optional and manual. Do not run it before verifying the cutover smoke list.*

### Background

Assets that were uploaded to Cloudinary through the Cloudinary UI (before the sync workflow existed) have random public_id suffixes, e.g.:
```
atx-open-2025-6959_q3l63c      ← legacy UI-uploaded
photo-portfolio/tennis/atx-open-2025/atx-open-2025-6959  ← deterministic sync target
```

Both public_ids live in the same `asset_folder` so the site tree picks them both up via the `asset_folder` grouping. This means the page works, but the same photo may appear twice if you re-sync the collection, and the remote inventory has duplicate entries.

### Steps to converge a collection

1. **Export the collection** from Lightroom Classic using the `portfolio` preset. This produces deterministic filenames under the export root.

2. **Dry-run the sync** to confirm what will be uploaded:
   ```bash
   npm run sync -- \
     --root "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Photos" \
     --preset portfolio \
     --filter atx-open-2025 \
     --dry-run
   ```
   The plan should show `uploads: N` for the deterministic public_ids and `unchanged: 0` (since legacy assets have different public_ids).

3. **Run the sync** (without `--delete`):
   ```bash
   npm run sync -- \
     --root "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Photos" \
     --preset portfolio \
     --filter atx-open-2025
   ```

4. **Verify in Cloudinary console** that the deterministic assets exist alongside the legacy ones.

5. **Delete the legacy suffixed assets** manually in the Cloudinary Media Library (select by asset_folder, sort by public_id to spot the suffixed ones, delete). Alternatively, use the Cloudinary API:
   ```bash
   # List legacy assets (public_ids not matching photo-portfolio/* prefix)
   # Then delete individually or via bulk delete API
   ```

6. **Rebuild** (`npm run build`) and confirm the page renders correctly with only the deterministic assets.

Repeat per collection. Reference the Step 9 sync flags (`--filter`, `--delete`) in the README for details.

---

## 7. WebStatement URL Transition

The Lightroom export plugin embeds a `WebStatement` XMP field in every exported image pointing to the licensing page. As of plugin v0.3.0 the default URL is `https://photo.rodmachen.com/licensing`.

Images exported **before v0.3.0** contain the old URL: `https://rodmachen.com/licensing`.

**Suggested fix**: Add a redirect on `rodmachen.com`:
```
/licensing  →  https://photo.rodmachen.com/licensing  (301 permanent)
```

This covers existing distributed images without requiring a re-export. No action needed on this repo.

---

## 8. First Sync Verification Run

*Step 9 (the sync script) was implemented and dry-run verified. No real Cloudinary writes were authorized in-session. Follow this runbook before attempting a bulk sync.*

### Goal

Verify the sync script works end-to-end against the real Cloudinary account on one small collection, confirm idempotency, and confirm the resulting page appears in the build.

### Steps

**1. Export the smallest collection from Lightroom**

In Lightroom Classic, select a small collection (the fewer photos the better for this test — `atx-open-2023` with ~12 photos is a good candidate). Run the `structured-export.lrplugin` export with the `portfolio` preset. Confirm the files appear under the export root:

```
~/Library/Mobile Documents/com~apple~CloudDocs/Photos/<set>/<collection>/portfolio/*.jpg
```

**2. Dry-run first**

```bash
npm run sync -- \
  --root "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Photos" \
  --preset portfolio \
  --filter atx-open-2023 \
  --dry-run
```

Review the output. Expected: some uploads (the deterministic public_ids do not yet exist), zero deletes, zero unchanged. If you see unexpected deletes, stop and investigate — do not proceed without `--dry-run` being clean.

**3. First real run (no --delete, no --deploy)**

```bash
npm run sync -- \
  --root "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Photos" \
  --preset portfolio \
  --filter atx-open-2023
```

**4. Verify in Cloudinary console**

Open the Cloudinary Media Library, navigate to `photo-portfolio/tennis/atx-open-2023` (or the relevant folder). Confirm the uploaded assets appear with deterministic public_ids (no random suffix).

**5. Confirm idempotency**

Re-run the same sync command. Expected output: `unchanged: N, uploads: 0, updates: 0, deletes (skipped): 0`. If uploads > 0 on the second run, there is a public_id or MD5 mismatch — investigate before proceeding.

**6. Build and check the page**

```bash
npm run build
```

Open `dist/tennis/atx-open-2023/index.html` and confirm the photo count is correct. If the page previously showed legacy-uploaded photos alongside the new ones, the count may increase — this is expected (both public_id schemes are present in the same folder).

**7. Gate on this run before bulk sync**

Only after steps 1–6 pass cleanly should you proceed to sync the remaining collections (Theatre, Europe, etc.).
