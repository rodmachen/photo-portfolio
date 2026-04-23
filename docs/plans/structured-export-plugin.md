# Structured Export — Lightroom Classic Plugin

## Context

Rod exports photos from Lightroom Classic into a manually-maintained iCloud folder tree that mirrors his Collection Set hierarchy, in three sizes (print, portfolio, web), with full copyright/licensing IPTC metadata and (when supported) Adobe Content Credentials. The current workflow is entirely manual and error-prone: folders get misnamed, metadata gets skipped, and the three presets have to be re-selected and re-run by hand. The goal is a single-invocation Lightroom plugin that produces a deterministic folder tree, enforces filename and metadata conventions, and fails loudly when something's wrong — so that published images always carry correct licensing metadata and always resolve to a `/licensing` page that Rod is maintaining on the site.

Spec: `/Users/rodmachen/code/photo-portfolio/docs/lightroom-export-spec.md` (authoritative for behavior not restated here).

## Locked Decisions

Resolved in planning:

1. **Scope**: Lightroom plugin only. The spec's Adobe Portfolio footer / licensing page is out of scope; user handles that separately.
2. **Location**: `/Users/rodmachen/code/photo-portfolio/tools/structured-export.lrplugin/` — subdirectory of this Astro repo. Tests and tooling live in sibling paths (`tools/spec/`, `tools/.busted`) so Lightroom does not load them.
3. **Custom IPTC fields** (Credit, Contact Email, Rights, WebStatement): shell out to `exiftool` via `LrTasks.execute` after each rendered file. Plugin logs a warning and proceeds without the extra fields if `exiftool` is not on `PATH`. Copyright + Creator are handled natively by LrExportSession.
4. **Slug rule**: uniform — lowercase, spaces→hyphens everywhere (both folder names and filenames). Diverges from the spec's literal example; documented in README.
5. **Collision scan scope**: the currently selected preset's subfolder only (not all three at once). Spec wording was contradictory; this reading matches the "selected preset being exported" clause.
6. **Keyboard shortcut**: Lightroom Classic SDK does not expose keybinding registration. README documents how to assign one via macOS System Settings → Keyboard → App Shortcuts.
7. **Catalog copyright pre-fill**: if `photo:getFormattedMetadata('copyright')` is non-empty on the most recently selected photo, it wins over stored prefs for the dialog default. Prefs still get written on "Remember".
8. **Test framework**: busted (LuaRocks). TDD for pure-logic modules; manual Lightroom verification for SDK-dependent code.
9. **Single preset per run**: dialog is single-select; one `LrExportSession` per (collection, preset) pair.
10. **Reveal in Finder** target: root `Photos/` folder.

## Prerequisites

**Done** (completed during planning):
- `git init` in `/Users/rodmachen/code/photo-portfolio/`.
- `.claude/settings.local.json` added to `.gitignore`.
- Spec moved from `src/docs/` to `docs/lightroom-export-spec.md`.

**Scripted by Step 0 below**:
- Rename this plan file to `structured-export-plugin.md`.
- Initial commit on `main` with the plan file and `.gitignore`.
- Create and check out the `feature/structured-export-plugin` branch.

**User-owned (outside this plan)**:
- GitHub repo creation and push — Rod indicated "not applicable." Plan works fully local-only; the Step 1 CI workflow file is dormant until a remote is added.
- `brew install exiftool`. No PATH setup needed — the plugin resolves exiftool by absolute path at runtime (see Step 5). If missing at export time, plugin logs once and degrades gracefully (copyright + creator still get embedded, the other IPTC fields are skipped).
- Confirm Lightroom Classic version ≥13 for Content Credentials; ≥11 for core export (SDK 6.0 minimum per spec).

## Target File Structure

```
tools/
  structured-export.lrplugin/          # plugin bundle — this is what gets symlinked to LR
    Info.lua                           # manifest + menu registration
    ExportDialog.lua                   # LrView modal
    ExportTask.lua                     # orchestration entry point
    Collections.lua                    # recursive Set/Collection walker (added vs spec)
    Presets.lua                        # preset → LR_* settings map (added vs spec)
    Metadata.lua                       # copyright/creator builder + exiftool post-process
    Prefs.lua                          # LrPrefs adapter + defaults
    Utils.lua                          # slugify, extractFileNumber, path helpers
    ContentCredentials.lua             # pcall-wrapped CC key assignment + log (added vs spec)
    README.md                          # install + manual-test checklist
  spec/                                # busted tests — NOT loaded by LR
    spec_helper.lua                    # sets package.path to reach ../structured-export.lrplugin/
    utils_spec.lua
    presets_spec.lua
    metadata_spec.lua
    prefs_spec.lua
    collections_spec.lua
  .busted
  .luacheckrc
.github/workflows/
  lua-tests.yml                        # runs busted + luacheck on push
```

Added modules vs the spec: `Collections.lua` (isolates the recursive walker for testability), `Presets.lua` (preset→settings map as plain testable data, where the short-edge-resize gotcha lives), `ContentCredentials.lua` (isolated so the unknown-SDK-key pcall has one place to live).

## Implementation Steps

Each step ends with a commit. Model/effort is re-evaluated at the start of every step — stop and switch if it changes. TDD steps write failing tests first; tests-alongside steps write tests with the implementation in the same commit.

---

### Step 0 — Repo bootstrap

**Files**:
- `docs/plans/make-a-plan-using-sleepy-whale.md` → rename to `docs/plans/structured-export-plugin.md`
- `.gitignore` (already modified during planning; this step is what commits it)

**What**: Rename the plan file, make the initial commit on `main`, create the feature branch. Exact commands:

```
git mv docs/plans/make-a-plan-using-sleepy-whale.md docs/plans/structured-export-plugin.md
git add .gitignore docs/plans/structured-export-plugin.md
git commit -m "Initial: plan for structured-export plugin"
git checkout -b feature/structured-export-plugin
```

**Model / Effort**: Haiku / low. **Justification**: three git commands, no logic, no SDK surface, no compounding risk.

**Context-clear**: no.

**Tests**: none — no code.

**Verify**:
- `git log main --oneline` shows exactly one commit.
- `git branch --show-current` returns `feature/structured-export-plugin`.
- `ls docs/plans/` shows `structured-export-plugin.md` (and no `make-a-plan-using-sleepy-whale.md`).

---

### Step 1 — Scaffold, test harness, and CI

**Files**:
- `tools/structured-export.lrplugin/` (empty dir, placeholder `README.md`)
- `tools/spec/spec_helper.lua`
- `tools/.busted`
- `tools/.luacheckrc`
- `.github/workflows/lua-tests.yml`
- `.gitignore` (append `.claude/settings.local.json`, `*.luac`)

**What**: Create the bundle directory, busted config pointing at `spec/`, luacheck config with Lightroom SDK globals allowed (`import`, `LrDevelopmentPlugin`, etc.), and a GitHub Actions workflow that installs LuaRocks, busted, luacheck, and runs them. README is a one-paragraph stub.

**Model / Effort**: Haiku / low. **Justification**: mechanical scaffolding — no ambiguity, no SDK internals, no compounding-mistake risk. Verification is running `busted` and having it report "0 specs" cleanly.

**Context-clear**: yes (fresh start).

**Tests**: tests-alongside (no logic yet; `busted` must exit 0 with zero specs).

**Verify**:
```
cd tools && busted          # exits 0, reports 0 specs
cd tools && luacheck . --only-globals import lightroom   # exits 0
```
Commit: "Step 1: scaffold plugin bundle, busted harness, CI workflow".

---

### Step 2 — `Utils.lua` (pure logic, TDD) ✅

**Files**:
- `tools/structured-export.lrplugin/Utils.lua`
- `tools/spec/utils_spec.lua`

**What**: Pure functions, zero SDK imports:
- `slugify(s)` → lowercase, spaces and underscores → hyphens, strips punctuation except hyphens, collapses runs of hyphens.
- `extractFileNumber(filename)` → trailing digits before the extension. `DSC_7877.NEF` → `"7877"`; `IMG_0001-Edit.DNG` → `"0001"`; `untitled.jpg` → `nil`.
- `joinPath(...)` → OS-agnostic `/` joining; wraps `LrPathUtils.child` when available, falls back to `table.concat` with `/` for unit-test environments (guarded by `pcall(require, 'LrPathUtils')`).
- `buildCollectionFilename(collectionName, fileNumber, fallbackSeq)` → `{slugify(collectionName)}-{fileNumber or fallbackSeq}.jpg`.

**Model / Effort**: Sonnet / medium. **Justification**: pure logic but edge cases matter (punctuation in set names, files with no trailing digits, mixed separators). Unit tests catch them; medium effort to write enough cases.

**Context-clear**: no (continues from scaffold).

**Tests**: TDD. Write `utils_spec.lua` first with cases for each helper, including: `"ATX Open 2025"` → `"atx-open-2025"`; `"Pet Photos / 2024"` → `"pet-photos-2024"`; DSC_/IMG_/\_MG_ filename prefixes; numeric-only filenames; empty strings.

**Verify**: `busted` shows all `utils_spec` tests green. Commit: "Step 2: Utils.lua with slugify, extractFileNumber, path helpers".

---

### Step 3 — `Presets.lua` (preset → LR_* settings, TDD) ✅

**Files**:
- `tools/structured-export.lrplugin/Presets.lua`
- `tools/spec/presets_spec.lua`

**What**: A table keyed by `"print" | "portfolio" | "web"`, each value is the exact LrExportSession settings dict:
- `print`: JPEG q=0.8, `LR_size_doConstrain=true`, `LR_size_resizeType="shortEdge"`, `LR_size_maxHeight=2400`, `LR_size_maxWidth=2400`, `LR_size_units="pixels"`, `LR_size_resolution=300`, `LR_size_resolutionUnits="inch"`, `LR_export_colorSpace="sRGB"`, `LR_outputSharpeningOn=true`, `LR_outputSharpeningLevel=2` (Standard), `LR_outputSharpeningMedia="screen"`.
- `portfolio`: same shape, short-edge 2048, res 240, q=0.7.
- `web`: `LR_size_resizeType="longEdge"`, long-edge 1350, res 72, q=0.7.

**SDK verification before writing**: read `/Applications/Adobe Lightroom Classic/SDK/Manual/ExportSDK.pdf` (or `API Reference/index.html`) and the sample `ftp_upload.lrdevplugin/FtpUploadExportDialogSections.lua` to confirm exact string values for `LR_size_resizeType` ("shortEdge" vs "short_edge") and sharpening constants. If the constants disagree with what's written here, update the table and the spec.

**Model / Effort**: Sonnet / medium. **Justification**: the SDK constant names are the biggest single risk in the plugin — a typo silently no-ops and the exports are the wrong size. Medium effort on SDK-doc reading; the code itself is a data table.

**Context-clear**: yes (SDK doc reading is a distinct chapter).

**Tests**: TDD. Assert each preset has every required key with the expected value; assert all three presets share `LR_format="JPEG"` and `LR_export_colorSpace="sRGB"`.

**Verify**: `busted` green. Commit: "Step 3: Presets.lua with print/portfolio/web export settings".

---

### Step 4 — `Prefs.lua` (LrPrefs adapter + defaults)

**Files**:
- `tools/structured-export.lrplugin/Prefs.lua`
- `tools/spec/prefs_spec.lua`

**What**: Expose `getDefaults()`, `load()`, `save(values)`. `getDefaults()` returns a pure table (testable) with copyright string containing `{current_year}` tokenized, creator/rights/URL/email per spec. `load`/`save` thinly wrap `LrPrefs.prefsForPlugin()` — use a module-level injection seam (`Prefs._prefsProvider`) so tests can stub `prefsForPlugin` without loading the SDK.

**Model / Effort**: Haiku / low. **Justification**: tiny surface, no ambiguity, thin adapter.

**Context-clear**: no.

**Tests**: tests-alongside. Verify `getDefaults()` shape and year substitution; verify `save` then `load` round-trips through a fake provider.

**Verify**: `busted` green. Commit: "Step 4: Prefs.lua with defaults and LrPrefs adapter".

---

### Step 5 — `Metadata.lua` (builder + exiftool wrapper)

**Files**:
- `tools/structured-export.lrplugin/Metadata.lua`
- `tools/spec/metadata_spec.lua`

**What**: Two concerns in one module:
1. **Pure builder** `buildExportSettings(prefs)` → returns the subset of `LR_*` keys Classic natively understands: `LR_embeddedMetadataOption="all"`, `LR_metadata_copyright`, `LR_removeFaceMetadata=false`, `LR_removeLocationMetadata=false`. Testable under busted.
2. **exiftool post-process** `applyIptcFields(filePath, prefs)` → shells out via `LrTasks.execute`. Resolves the binary by absolute path at module load via `resolveExiftool()`, which probes `/opt/homebrew/bin/exiftool` → `/usr/local/bin/exiftool` → `/usr/bin/exiftool` → bare `exiftool` (last-resort fallback), caches the first hit. **This lookup is required**: macOS GUI apps launch with a minimal PATH (`/usr/bin:/bin:/usr/sbin:/sbin`) that does not include Homebrew, so bare `exiftool` fails from inside Lightroom even when it works in Terminal. Command form: `<resolved-path> -overwrite_original -Copyright=... -By-line=... -Rights=... -Credit=... -ContactCiEmailWork=... -WebStatement=... filePath`. Returns `ok, err`. If `resolveExiftool()` finds nothing, logs once per export session and returns `ok=true` (graceful degrade). All user-supplied strings shell-escaped via a local `shellEscape` helper.

**Model / Effort**: Sonnet / medium. **Justification**: exiftool command construction is well-documented but shell escaping is a compounding-mistake hazard (a stray `'` in a copyright string breaks the call). Medium effort to get escaping + error paths right.

**Context-clear**: yes.

**Tests**: TDD for `buildExportSettings` and `shellEscape`. The `applyIptcFields` wrapper itself is not unit-tested (requires a shell) — verified manually in Step 11.

**Verify**: `busted` green for builder + shellEscape tests. Commit: "Step 5: Metadata.lua with builder and exiftool post-process".

---

### Step 6 — `Collections.lua` (recursive walker, TDD)

**Files**:
- `tools/structured-export.lrplugin/Collections.lua`
- `tools/spec/collections_spec.lua`

**What**: Pure recursive walker `enumerate(selection, options)` that takes a list of `LrCollection | LrCollectionSet` (or fake objects in tests) and returns `{ {collection, pathSegments, photos} }`. `pathSegments` is an array of slugified names from root Set down to the Collection (exclusive of the Collection itself — the Collection name becomes the innermost folder). Uses duck-typing on a small protocol (`:getName()`, `:getChildCollectionSets()`, `:getChildCollections()`, `:getPhotos()`, `:type()`) so tests supply a fake tree.

**Model / Effort**: Sonnet / medium. **Justification**: the walk itself is standard, but the protocol boundary and the "selected Set means all descendants" semantic need careful implementation. Medium effort; fully testable against mocks.

**Context-clear**: yes.

**Tests**: TDD. Cover: single collection not in a set; collection in a 1-level set; collection in a 3-level nested set; a set with mixed child sets and direct collections; a set at the top level of the selection (should expand to all descendants); empty selection (returns empty).

**Verify**: `busted` green. Commit: "Step 6: Collections.lua recursive walker with tests".

---

### Step 7 — `ExportDialog.lua` (LrView modal)

**Files**:
- `tools/structured-export.lrplugin/ExportDialog.lua`

**What**: Exposes `ExportDialog.run()` returning `{action="export"|"cancel", values={...}}`. Builds an `LrView` UI with: a radio_button column bound to `preset`; a checkbox for `contentCredentials` (default ON); five edit_field rows for copyright/creator/rights/webStatement/contactEmail, each bound via `LrBinding`; a "Remember these settings" checkbox; OK + Cancel. Pre-fills from `Prefs.load()` overlaid with `photo:getFormattedMetadata('copyright')` when present (see Locked Decision #7). On OK with "Remember" checked, calls `Prefs.save`.

**Model / Effort**: Sonnet / medium. **Justification**: LrView + LrBinding has a documented but fiddly property-table model; off-by-one errors in bindings compound silently (you get a dialog that looks right but doesn't capture input). Medium effort.

**Context-clear**: yes.

**Tests**: tests-alongside — no automated tests feasible (pure SDK UI). Verified manually in Step 11.

**Verify**: plugin loads without error in Plug-in Manager; dialog opens; all fields editable; Cancel returns `action="cancel"`; "Remember" round-trips across Lightroom restart. Commit: "Step 7: ExportDialog.lua with LrView modal and prefs binding".

---

### Step 8 — `Info.lua` (manifest + menu registration)

**Files**:
- `tools/structured-export.lrplugin/Info.lua`

**What**: Minimal declarative manifest: `LrSdkVersion=6.0`, `LrSdkMinimumVersion=6.0`, `LrToolkitIdentifier="com.rodmachen.structured-export"`, `LrPluginName="Structured Export"`, `VERSION={major=0, minor=1, revision=0}`, `LrExportMenuItems` registering title "Structured Export" and file="ExportTask.lua", and `LrLibraryMenuItems` for the same so it appears in File → Plug-in Extras.

**Model / Effort**: Sonnet / medium. **Justification**: a typo here silently disables the plugin in Plug-in Manager. Small but SDK-contract-sensitive.

**Context-clear**: no.

**Tests**: tests-alongside — none. Verified in Step 11 checklist item 1.

**Verify**: open Plug-in Manager; plugin appears as "Structured Export" with status "Installed and running". File → Plug-in Extras shows the menu item. Commit: "Step 8: Info.lua with SDK manifest and menu registration".

---

### Step 9 — `ExportTask.lua` (orchestration) + `ContentCredentials.lua` ✅

**Files**:
- `tools/structured-export.lrplugin/ExportTask.lua`
- `tools/structured-export.lrplugin/ContentCredentials.lua`

**What**: The main flow, run inside `LrTasks.startAsyncTask`:
1. Resolve active catalog + selected collections. If empty, show error and abort.
2. Open `ExportDialog.run()`. If cancel, abort.
3. Call `Collections.enumerate(selection)` to get `{collection, pathSegments, photos}` tuples.
4. Compute destination paths per photo: `~/Library/Mobile Documents/com~apple~CloudDocs/iCloud Pictures/<pathSegments...>/<slug(collection)>/<preset>/<filename>`. Resolve the home directory via `LrPathUtils.getStandardFilePath('home')` — `LrPathUtils.expandPath` is not a real SDK function.
5. Pre-scan disk for collisions. If any, show `LrDialogs.confirm` with Overwrite/Skip/Cancel buttons.
6. Build the per-preset `LrExportSession` settings: `Presets[preset]` merged with `Metadata.buildExportSettings(prefs)` plus `LR_export_destinationType="specificFolder"`, `LR_export_destinationPathPrefix=<computed>`, `LR_useSubfolder=false`, `LR_renamingTokensOn=true`, `LR_tokens="custom"`, `LR_tokenCustomString=<pre-computed filename>`. Hand each photo explicitly via the session's `photosToExport` parameter.
7. Conditionally apply `ContentCredentials.apply(settings)` — a separate module that pcall-wraps the key assignment (spec key name is uncertain; try `LR_embedContentCredentials`, fall back to `LR_contentCredentials`, log on failure, never surface to user).
8. Wrap the loop in `LrProgressScope`; each rendered photo → call `Metadata.applyIptcFields(path, prefs)`.
9. On any per-photo failure: log, increment error count, continue.
10. On completion: `LrDialogs.messageWithDoNotShow` summary "X exported, Y skipped, Z errors" with a "Reveal in Finder" button that calls `LrShell.revealInShell(rootPath)`.

**Model / Effort**: Opus / high. **Justification**: high on all four axes — (a) ambiguous: collision dialog shape, CC key, LrExportSession custom-filename wiring; (b) unfamiliar SDK internals: LrExportSession rendition loop, LrProgressScope cancellation; (c) compounding-mistake risk: a single wrong key causes silent no-ops or wrong output; (d) hard-to-verify: only testable in Lightroom against real collections. Upgrade to Opus before starting.

**Context-clear**: yes — biggest step, needs fresh context.

**Tests**: tests-alongside — the orchestration itself is not unit-testable. Any pure helpers that emerge (e.g., destination-path computation) should be extracted into `Utils.lua` with tests.

**Verify**: run export on a small collection (2–3 photos) in a test Collection Set; confirm folder structure appears at iCloud path; confirm files exist at all expected sizes; confirm summary dialog appears. Commit: "Step 9: ExportTask.lua orchestration + ContentCredentials module".

---

### Step 10 — README + logging polish ✅

**Files**:
- `tools/structured-export.lrplugin/README.md`
- small tweaks across modules

**What**: Flesh out README with: install (symlink `tools/structured-export.lrplugin/` to `~/Library/Application Support/Adobe/Lightroom/Modules/`), prerequisites (Lightroom Classic ≥13 for CC; `brew install exiftool`), manual test checklist (from Step 11), troubleshooting (where Lightroom writes the plugin log), how to assign a macOS App Shortcut keybinding. Audit all modules for consistent `LrLogger` usage (one named logger, INFO for normal events, ERROR for caught failures).

**Model / Effort**: Sonnet / medium. **Justification**: documentation quality matters; audit pass is a compounding-mistake check.

**Context-clear**: no.

**Tests**: tests-alongside — none.

**Verify**: re-read README end to end; symlink a fresh install and follow the README from scratch on a dummy account to confirm it works. Commit: "Step 10: README and logging audit".

---

### Step 11 — Manual end-to-end verification in Lightroom Classic

**Files**: none (verification only).

**What**: Rod runs the full manual test checklist below. Any failure opens a revision to the appropriate prior step (see global "When Verification Fails" rules).

**Model / Effort**: N/A (human-driven). Verification is not a code step; it produces a bug list, not a commit.

**Context-clear**: yes.

**Manual verification checklist** (must all pass):

1. Plug-in Manager shows "Structured Export" as enabled, no Info.lua errors.
2. `File → Plug-in Extras → Structured Export` opens the dialog; all five text fields pre-filled per spec defaults.
3. "Remember these settings" round-trips across a Lightroom restart.
4. Launching with no collection selected → error dialog with the exact message in the spec.
5. Single un-nested collection → files land at `~/Library/Mobile Documents/com~apple~CloudDocs/iCloud Pictures/<slug(collection)>/<preset>/…`.
6. Collection Set nested ≥2 deep → path segments are lowercase + hyphenated (per Locked Decision #4).
7. All three presets produce files at spec-correct dimensions — verify with `exiftool -ImageWidth -ImageHeight -XResolution` on a sample file each. Print short-edge 2400 / 300 DPI; Portfolio short-edge 2048 / 240 DPI; Web long-edge 1350 / 72 DPI.
8. Filename extraction: `DSC_7877.NEF` → `{slug}-7877.jpg`; non-matching filename falls back to Lightroom sequence number.
9. Collision scan: second run of same (collection, preset) surfaces the Overwrite/Skip/Cancel prompt. Each choice behaves per spec; summary counts match.
10. IPTC fields present in output (`exiftool` check, in one line): `Copyright`, `By-line`, `Rights`, `Credit`, `Contact/CiEmailWork` set to `mail@rodmachen.com`, `WebStatement` set to the licensing URL.
11. Content Credentials: with exiftool side aside, verify the CC manifest via `c2patool verify <file>` on a CC-enabled export; toggle OFF produces no manifest; on SDK that doesn't support CC the log line appears and export still succeeds.
12. Progress bar visible mid-export; "Cancel" button stops the run cleanly.
13. A deliberately broken photo (e.g., a file with a missing source) logs an error, skips, and does not abort the batch.
14. Summary dialog's "Reveal in Finder" opens `Photos/` root.
15. With `exiftool` removed from PATH: plugin runs, logs warning once, exports succeed but lack the extra IPTC fields.

On pass: update PR description to mark Step 11 complete. The plan is done.

---

## Model & Effort Table (at-a-glance)

| Step | Model  | Effort  | Context-clear | Tests         |
|------|--------|---------|---------------|---------------|
| 0    | Haiku  | low     | no            | none          |
| 1    | Haiku  | low     | yes           | alongside     |
| 2    | Sonnet | medium  | no            | **TDD**       |
| 3    | Sonnet | medium  | yes           | **TDD**       |
| 4    | Haiku  | low     | no            | alongside     |
| 5    | Sonnet | medium  | yes           | **TDD** (partial) |
| 6    | Sonnet | medium  | yes           | **TDD**       |
| 7    | Sonnet | medium  | yes           | alongside     |
| 8    | Sonnet | medium  | no            | alongside     |
| 9    | **Opus** | **high** | yes       | alongside     |
| 10   | Sonnet | medium  | no            | alongside     |
| 11   | n/a    | n/a     | yes           | manual only   |

Before starting any step, re-read its row. If the model differs from the prior step, stop and switch. If context-clear=yes, stop and clear context before resuming.

## Out of Scope / Deferred

- Windows support (paths hard-code macOS iCloud location).
- Multiple presets in a single run (dialog is single-select).
- Adobe Portfolio footer / licensing page content (Rod owns separately).
- A PluginInfoProvider settings panel in Plug-in Manager.
- Internationalized strings (`LOC_*`).
- Automated end-to-end testing — LR has no headless mode accessible from busted.

## Critical Files (for reviewer orientation)

- `/Users/rodmachen/code/photo-portfolio/docs/lightroom-export-spec.md` — authoritative spec.
- `/Users/rodmachen/code/photo-portfolio/tools/structured-export.lrplugin/Info.lua` — plugin entry point; if this is wrong nothing loads.
- `/Users/rodmachen/code/photo-portfolio/tools/structured-export.lrplugin/Presets.lua` — SDK-key table; where the short-edge resize gotcha lives.
- `/Users/rodmachen/code/photo-portfolio/tools/structured-export.lrplugin/ExportTask.lua` — orchestration; largest risk surface.
- `/Users/rodmachen/code/photo-portfolio/tools/structured-export.lrplugin/Metadata.lua` — copyright/creator builder + exiftool wrapper.
