# Structured Export Plugin — v2

## Context

v1 shipped a working plugin (merged in PR #1) that exports selected Collections and Collection Sets into a structured iCloud folder tree, with one preset per run and full IPTC metadata. Real-world use surfaced three rough edges:

1. **Content Credentials is dormant**: Adobe has not exposed CC in Lightroom Classic's native export yet. The v1 checkbox sends best-guess SDK keys and logs an attempt, but no manifest is actually generated. The UI promises a feature that does nothing.
2. **Export root is hardcoded**: `~/Library/Mobile Documents/com~apple~CloudDocs/iCloud Pictures` is baked into `ExportTask.lua`. Moving the folder, using a different iCloud path, or testing against a scratch directory requires code edits.
3. **Single preset per run is clunky**: exporting the same selection at print + portfolio + web means opening the dialog three times and clicking Export three times. The three preset output directories are already independent, so running them sequentially in one invocation is purely an orchestration change.

A fourth concern — per-image `exiftool` invocation — is noted but deferred. v2 keeps the v1 model and documents the threshold at which it becomes a problem (see Known Follow-ups).

v2 scope is deliberately small: remove a broken promise, add one configurable input, and let the dialog produce multiple runs.

## Decisions

Confirmed with user during planning (2026-04-23):

1. **Folder selection lives in the dialog only.** No `PluginInfoProvider` settings panel. The dialog gets a destination row with a Browse button; the last-used path is persisted via the existing Remember mechanism.
2. **Content Credentials removed from UI; module kept dormant.** Checkbox and pref default gone, call site in `ExportTask` gone. `ContentCredentials.lua` and its spec stay on disk with a header comment explaining the dormant state and how to revive it. Re-enabling requires re-adding the checkbox, pref, and call — no rewrite.
3. **EXIF per-image stays in v2.** Document the threshold in the spec; batch-per-directory is a known follow-up to implement when real usage hits it.
4. **Remember checkbox stays** with current wording and semantics (writes all dialog values to prefs when checked). With no separate settings panel, there's no other place for defaults to live.

## Out of Scope

- `PluginInfoProvider` settings panel (explicitly rejected; dialog is the only UI).
- Exiftool batching (see Known Follow-ups for threshold).
- Windows support (v1 limitation unchanged).
- Content Credentials functional work (waiting on Adobe).
- New preset definitions or altered preset dimensions.
- i18n (`LOC_*` strings).

## Target Changes

```
tools/structured-export.lrplugin/
  Info.lua                    # VERSION → 0.2.0
  ExportDialog.lua            # + destination row; - CC checkbox; radios → checkboxes
  ExportTask.lua              # + outer preset loop; - hardcoded ROOT; - CC.apply call
  Prefs.lua                   # + exportRoot; - contentCredentials; - preset string, + presetPrint/Portfolio/Web booleans
  ContentCredentials.lua      # + dormancy header comment (module body unchanged)
  README.md                   # + v2 behavior notes
docs/
  lightroom-export-spec.md    # + multi-preset, folder picker, EXIF perf note
tools/spec/
  prefs_spec.lua              # updated for new defaults
```

`ContentCredentials.lua`, `content_credentials_spec.lua`, `Presets.lua`, `Collections.lua`, `Metadata.lua`, `Utils.lua` — unchanged behavior.

## Implementation Steps

Each step ends with a commit on `feature/structured-export-v2`. Re-evaluate model/effort/context-clear at the start of every step per the global workflow.

---

### Step 0 — Branch setup

**Files**: none (git state only).

**Actions**:
- `git checkout main && git pull`
- `git checkout -b feature/structured-export-v2`
- Commit this plan file on the branch.
- After the first implementation commit in Step 1, open PR (not draft) with the plan in the description.

**Model / effort**: Sonnet / low. **Context-clear**: no. **Effort justification**: mechanical git; no ambiguity.

**Verify**: `git status` clean; `git branch --show-current` returns `feature/structured-export-v2`.

---

### Step 1 — Remove Content Credentials from UI, bump version, document EXIF threshold

Single commit bundling cleanup that doesn't change export behavior.

**Files**:
- `tools/structured-export.lrplugin/Info.lua` — bump `VERSION` to `{ major = 0, minor = 2, revision = 0 }`.
- `tools/structured-export.lrplugin/ExportDialog.lua` — remove the `f:checkbox { title = 'Content Credentials', ... }` block (lines 64–68) and the `props.contentCredentials = ...` pre-fill (line 24). Remove `contentCredentials` from both `Prefs.save` calls and from `result.values`.
- `tools/structured-export.lrplugin/ExportTask.lua` — remove `local CC = require 'ContentCredentials'` (line 17) and the `CC.apply(settings, values.contentCredentials)` call (line 152).
- `tools/structured-export.lrplugin/Prefs.lua` — remove `contentCredentials = true` from `getDefaults` (line 18) and the corresponding line in `load` (line 40).
- `tools/structured-export.lrplugin/ContentCredentials.lua` — add a top-of-file comment block explaining the module is dormant as of v0.2.0, why (Adobe hasn't exposed CC in LR Classic), and how to revive (re-add require + pref + dialog checkbox + call site).
- `tools/spec/prefs_spec.lua` — update expectations: no `contentCredentials` key in `getDefaults`; existing CC-related assertions removed or retargeted.
- `tools/spec/content_credentials_spec.lua` — no changes (module itself is unchanged).
- `docs/lightroom-export-spec.md` — add a "Performance notes" section documenting the current per-image `exiftool` model and the threshold at which to migrate to batch-per-directory (~200 output files per run starts to feel slow; 1000+ adds multiple minutes of shell overhead).
- `tools/structured-export.lrplugin/README.md` — remove the Content Credentials bullet from the test checklist; add a note that CC support is deferred.

**Model / effort**: Sonnet / medium. **Context-clear**: yes (first implementation step, start of distinct chapter).

**Effort justification**: (a) low ambiguity — mechanical removals across well-understood files; (b) no third-party internals; (c) low compounding risk — diff is small and contained; (d) easy to verify (grep for removed symbols, run tests). Sonnet / medium is sufficient; Opus not needed.

**TDD mode**: tests-alongside. No new behavior to drive with tests; only existing spec file gets updated to reflect removed defaults.

**Verify**:
- `cd tools && busted` — all specs pass, including updated `prefs_spec.lua`.
- `cd tools && luacheck structured-export.lrplugin spec` — zero warnings.
- `grep -r contentCredentials tools/structured-export.lrplugin` — returns only the dormancy header comment in `ContentCredentials.lua`.
- Manual smoke: open Lightroom, run menu command, confirm dialog shows no Content Credentials checkbox; export a small collection and confirm JPEG output is unchanged.

---

### Step 2 — Add folder picker to dialog

The hardcoded `ROOT` constant in `ExportTask.lua` becomes a configurable value that flows through the dialog.

**Files**:
- `tools/structured-export.lrplugin/Prefs.lua` — add `exportRoot` to `getDefaults` (default: the current hardcoded iCloud Pictures path, computed from `LrPathUtils.getStandardFilePath('home')`); add corresponding line in `load`. The default computation needs to live in `Prefs.lua` now; `LrPathUtils` must be imported there. Preserve the test-injection seam so the spec can override without pulling in LR SDK.
- `tools/structured-export.lrplugin/ExportDialog.lua` — add a new row at the top of the dialog body (above the preset group box) with `f:static_text { title = 'Destination:' }`, `f:edit_field { value = LrView.bind('exportRoot'), fill_horizontal = 1 }`, and `f:push_button { title = 'Browse...', action = ... }`. The button handler calls `LrDialogs.runOpenPanel { title = 'Choose export folder', canChooseFiles = false, canChooseDirectories = true, allowsMultipleSelection = false, initialDirectory = props.exportRoot }` and sets `props.exportRoot = result[1]` when the user picks a path. Add `exportRoot` to the pre-fill, to both `Prefs.save` calls (so `remember` can persist it), and to `result.values`.
- `tools/structured-export.lrplugin/ExportTask.lua` — replace the top-level `local ROOT = ...` constant with reading `values.exportRoot` after the dialog returns. Pass it into `collectionDir(entry, root)` as a parameter. Update the `Reveal in Finder` call at line 354 to use `values.exportRoot` instead of `ROOT`.
- `tools/spec/prefs_spec.lua` — add test: `getDefaults().exportRoot` is non-empty and ends with `iCloud Pictures`; injected prefs override.
- `tools/structured-export.lrplugin/README.md` — document the new Destination field.

**Model / effort**: Sonnet / medium. **Context-clear**: no (continuing from Step 1, same architectural shape).

**Effort justification**: (a) low ambiguity on the approach; (b) `LrDialogs.runOpenPanel` is documented SDK surface — moderate unfamiliarity but behavior is predictable; (c) low compounding risk — changes are localized to three files; (d) verification is straightforward (pick a folder, see files land there). Sonnet / medium fits. Watch for edge cases: stored `exportRoot` pointing at a now-missing folder — handle by falling back to the default when `LrFileUtils.exists` returns false at dialog-open time, rather than after the user clicks Export.

**TDD mode**: TDD for `Prefs.lua` changes (test the new default first). Tests-alongside for dialog and orchestration wiring.

**Verify**:
- `busted` passes including the new `exportRoot` spec.
- `luacheck` clean.
- Manual: open dialog, confirm Destination row pre-fills with the iCloud Pictures path. Click Browse, pick `/tmp/structured-export-test`, click Export on a 1-photo collection. File lands at `/tmp/structured-export-test/<collection-path>/<preset>/<name>.jpg`. With Remember checked, re-open dialog — new path is still there.
- Manual edge: rename the stored folder out from under the plugin, re-open dialog — confirm it falls back to default (or shows the stored path and errors clearly on Export, whichever the implementation picks; pick the fallback path for lower friction).

---

### Step 3 — Multi-select presets ✅

Replace the three radio buttons with three checkboxes, validate at least one is selected, and iterate the export pipeline once per selected preset.

**Files**:
- `tools/structured-export.lrplugin/ExportDialog.lua` — replace the `f:group_box { title = 'Export Preset', ... }` with a group box containing three `f:checkbox` items bound to `presetPrint`, `presetPortfolio`, `presetWeb`. Pre-fill from prefs (not from old `preset` string). On OK click: if all three are false, call `LrDialogs.message('Structured Export', 'Select at least one preset.', 'warning')` and return without setting `result.action = 'export'` — caller will treat as cancel and not re-invoke the dialog automatically. (Alternative: re-show the dialog in a loop; pick the simpler cancel-style path.) Remove the `preset` string from pre-fill, `Prefs.save`, and `result.values`; emit the three booleans instead.
- `tools/structured-export.lrplugin/Prefs.lua` — remove `preset = 'print'` from `getDefaults`, add `presetPrint = true, presetPortfolio = false, presetWeb = false`. Use `coalesce` for booleans in `load`. No migration from the old `preset` string is attempted; stored prefs from v0.1 simply fall back to defaults. (Acceptable because the plugin is single-developer-single-machine.)
- `tools/structured-export.lrplugin/ExportTask.lua` — after dialog returns, build `local selectedPresets = {}` from the three booleans in a fixed order: `print`, `portfolio`, `web`. Wrap the existing `buildJobs` → collision pre-scan → per-job loop in an outer loop over `selectedPresets`. Key structural points:
  - **Collision pre-scan** runs once, aggregating collisions across all selected presets (each preset's output dir is independent). One user prompt handles all of them; the choice applies uniformly. `filterSkipExisting` runs per-preset with the same choice.
  - **Progress reporting** updates the per-job progress title to `"Structured Export: <collection> (<preset> — <i> of <N>)"` so the user sees which preset is running. Existing per-job `LrProgressScope` stays; it's created inside `runJob`.
  - **Cancel semantics**: if `runJob` returns `canceled = true`, set `shouldBreak = true` AND break out of the outer preset loop. The cleanup sweep already handles orphans per-job; no additional sweep needed at the outer level.
  - **Sequence numbers** (`fallbackSeqStart`): reset per preset? Share across presets? v1 used `buildJobs(nonEmpty, preset, 1)`, so sequence is per-run. Keep sequence per-preset-run (pass `1` each iteration). The sequence is only used as filename stem fallback via `%05d`, which isn't exposed — same-stem behavior preserved.
  - **Summary aggregation**: `counts` table stays scoped to the whole run; increments accumulate across all preset iterations. Summary dialog shows total exported/skipped/errors across all presets.
  - **Reveal in Finder** target: `values.exportRoot` (from Step 2), same as today.
- `tools/spec/prefs_spec.lua` — test the three new preset booleans in defaults and in `load`.
- `tools/structured-export.lrplugin/README.md` — update preset section: now a set of checkboxes; exports run sequentially.
- `docs/lightroom-export-spec.md` — update the spec to reflect multi-select presets.

**Model / effort**: Opus / high. **Context-clear**: yes (biggest change; distinct chapter with real-world failure modes).

**Effort justification**: (a) ambiguity on cancel-across-presets UX and collision-prompt behavior; (b) LrExportSession orchestration has documented gotchas (parallel rendering, cancel-iterator semantics) that v1 already hit — second-order effects when wrapping in an outer loop aren't obvious; (c) moderate compounding risk — a wrong cancel path leaves orphans across multiple preset folders; (d) hard to verify purely via unit tests — real LR required for the interesting failure modes. Opus / high is warranted; Opus / max is overkill for a scoped change in a well-understood codebase.

**TDD mode**: tests-alongside. `Prefs.lua` defaults get updated tests. Orchestration logic in `ExportTask.lua` has no unit tests by design (integration module); manual verification in Lightroom covers it.

**Verify**:
- `busted` passes.
- `luacheck` clean.
- Manual: open dialog with fresh prefs — only `print` is checked. Export a 1-photo collection with just print → file lands in `/print/`.
- Manual: check all three presets, export same collection → three files, one per preset subfolder, all with correct IPTC.
- Manual: check two presets (print + web), cancel during print render → confirm print folder is clean of orphans, web never runs, summary dialog says 0 exported plus whatever was moved before cancel.
- Manual: check two presets, both have pre-existing files at destinations → confirm the collision dialog fires once (not twice) and the user's choice (overwrite/skip/cancel) applies to both.
- Manual: uncheck all three presets, click Export → confirm warning dialog and no export runs.

## End-to-End Verification

After all steps commit and CI passes:

1. **Install**: plugin symlink already exists at `~/Library/Application Support/Adobe/Lightroom/Modules/`; no re-install needed, just restart Lightroom.
2. **Smoke**: select one small Collection (5–10 photos), run menu command. Dialog shows: Destination row with iCloud Pictures path, three preset checkboxes (print default on), IPTC fields, Remember checkbox. No Content Credentials row.
3. **Folder picker**: click Browse, pick `~/Desktop/structured-export-test`, check all three presets, click Export. Verify files land under `~/Desktop/structured-export-test/<collection-path>/{print,portfolio,web}/`.
4. **Remember**: re-open dialog — new path and multi-preset selection are pre-filled.
5. **IPTC**: right-click a rendered JPEG in Finder → Get Info → confirm copyright and author visible. Run `exiftool -Copyright -Artist -Rights -CreatorWorkEmail <file>` → all four populated.
6. **Cancel**: export a 30+ photo collection across 3 presets, cancel during first preset. Verify: current preset's folder has no orphan JPEGs; remaining presets did not run; summary counts match what was completed.
7. **Collision**: re-run the same export — collision dialog fires once, choice applies across all three preset folders.
8. **CI**: GitHub Actions green on the PR.

## Known Follow-ups

Deferred work called out explicitly so future-you remembers why:

- **Exiftool batching**: currently one shell invocation per rendered file. Approximate threshold where it becomes noticeable: 200–500 output files per run (multi-preset multiplies this — 3 presets × 200 photos = 600 invocations). Fix: call `exiftool -overwrite_original -Copyright=... -Artist=... ... -ext jpg <dir>` once per collection-preset directory after the move/cleanup phase. Reduces N invocations to one. Re-open when a real export run feels slow.
- **Content Credentials revival**: when Adobe exposes CC in Lightroom Classic's native export dialog, revert the dormancy by restoring the checkbox in `ExportDialog.lua`, the `contentCredentials` default in `Prefs.lua`, and the `CC.apply` call in `ExportTask.lua`. Module and spec are already in place.
- **Per-preset custom overrides**: if the three presets start diverging in what metadata or filenames they get (e.g., web preset adds `-web` suffix), revisit the single `values` blob that feeds all three preset runs.
- **Windows support**: not on the roadmap; the `LrPathUtils.getStandardFilePath('home')` default still works, but iCloud Pictures is macOS-specific. Would need a per-OS default picker if Windows ever matters.
