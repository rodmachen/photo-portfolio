# Review — feature/structured-export-v2

## Summary

Overall quality is high and the plan was followed closely. Each of the three implementation steps landed in its own commit with a clear message, `busted` is green (94 successes / 0 failures), `luacheck` is clean on all 16 files, and the reflog shows no amend or force-push. The folder-picker fallback, the one-shot aggregated collision prompt, cancel-breaks-both-loops, per-preset sequence reset, run-scoped counts, and the `values.exportRoot` reveal target all match Step 2/3 specs verbatim. The `ContentCredentials.lua` dormancy header documents the full revival recipe (pref + checkbox + require + call site). No blocking issues; the remaining items are README drift from Steps 1–2 that did not get cleaned up, a missing-tick hygiene gap on the plan file, and a small pile of harmless dead code.

## Items

### 1. README manual-test-checklist has a numbering gap and a stale item count

- **Severity**: `non-blocking`
- **Location**: `tools/structured-export.lrplugin/README.md:65-82`
- **Description**: Step 1 removed the Content Credentials test item but the surrounding list wasn't renumbered, leaving the checklist as `1…11, 13, 14, 15` (no item 12). The preamble still reads "These 15 items must all pass before a release is considered complete." when only 14 items remain.
- **Suggestion**: Renumber items 13–15 to 12–14 and update the preamble count to 14:
  ```markdown
  These 14 items must all pass before a release is considered complete.
  ...
  11. Progress bar visible mid-export; "Cancel" button stops the run cleanly.
  12. A deliberately broken photo (e.g., a file with a missing source) logs an error, skips, and does not abort the batch.
  13. Summary dialog's "Reveal in Finder" opens the chosen Destination root.
  14. With `exiftool` removed from PATH: plugin runs, logs warning once, exports succeed but lack the extra IPTC fields.
  ```

### 2. README still describes export destination as fixed iCloud Pictures after Step 2 made it configurable

- **Severity**: `non-blocking`
- **Location**: `tools/structured-export.lrplugin/README.md:40`, `:45`, `:73`, `:81`
- **Description**: Step 2 moved the destination from a hardcoded `ROOT` constant to `values.exportRoot`, but four README passages still present the iCloud Pictures path as the single fixed output location:
  - Line 40 — "Click **Reveal in Finder** to open the `iCloud Pictures/` root."
  - Lines 44–46 — the "Exported files land at:" code block hardcodes the iCloud Pictures path.
  - Line 73 (test item 5) — "files land at `~/Library/Mobile Documents/com~apple~CloudDocs/iCloud Pictures/<slug(collection)>/<preset>/…`".
  - Line 81 (test item 14) — "Summary dialog's 'Reveal in Finder' opens `iCloud Pictures/` root."
- **Suggestion**: Swap each to reference the configurable Destination, for example replace the code block with `<Destination>/<set-slug>/.../<collection-slug>/<preset>/<slug>-<num>.jpg` and change line 40 to "…open the chosen Destination root."

### 3. README manual-test-checklist does not exercise multi-preset collision aggregation

- **Severity**: `non-blocking`
- **Location**: `tools/structured-export.lrplugin/README.md:77` (item 9)
- **Description**: Item 9 still reads "second run of same (collection, preset) surfaces the Overwrite/Skip/Cancel prompt." Step 3's headline user-visible behavior is that the prompt fires **once** across every selected preset, not per-preset. The plan's End-to-End Verification covers this (step 7), and `docs/lightroom-export-spec.md` now documents it, but the per-plugin release checklist omits it.
- **Suggestion**: Add a multi-preset collision case to item 9 (or a new item 10) — e.g., "…with two presets selected and collisions in both, the prompt fires once and the chosen strategy applies to both preset folders."

### 4. Plan file does not mark Steps 0, 1, 2 complete — only Step 3 has ✅

- **Severity**: `non-blocking`
- **Location**: `docs/plans/let-s-make-a-plan-merry-cloud.md` (Step 0 line 57, Step 1 line 73, Step 2 line 102; Step 3 line 127 already has ✅)
- **Description**: The global workflow requires each completed step's heading to gain a trailing ✅ so the `/work-log` skill and the archive-on-merge rule can tell when a plan is complete. `context.md` §"Minor drift logged" flags this explicitly. Right now only Step 3 is ticked, so the plan reads as partial even though every step committed successfully.
- **Suggestion**: Append ` ✅` to the Step 0, 1, and 2 heading lines:
  ```markdown
  ### Step 0 — Branch setup ✅
  ### Step 1 — Remove Content Credentials from UI, bump version, document EXIF threshold ✅
  ### Step 2 — Add folder picker to dialog ✅
  ```

### 5. Unreachable defensive fallback in ExportTask duplicates dialog-level validation

- **Severity**: `non-blocking`
- **Location**: `tools/structured-export.lrplugin/ExportTask.lua:279-284`
- **Description**: `ExportDialog.run` already returns `{ action = 'cancel', values = {} }` when the user clicks OK with no preset checked (ExportDialog.lua:132-136), and the task returns on line 262 whenever `dialogResult.action ~= 'export'`. The `#selectedPresets == 0` check and its `LrDialogs.message` call can therefore never fire. The in-code comment already flags this as "Dialog validation should catch this; defensive fallback." Our "don't add validation for scenarios that can't happen" rule says to drop it. Keeping it is mostly harmless but it does add a second warning-dialog path for the same condition.
- **Suggestion**: Replace the block with a plain `assert(#selectedPresets > 0, 'dialog must validate preset selection')`, or just delete lines 279–284. Either removes the dead UX path while preserving the invariant.

### 6. `result.values.remember` is emitted by the dialog but never read by the task

- **Severity**: `non-blocking`
- **Location**: `tools/structured-export.lrplugin/ExportDialog.lua:167`
- **Description**: The dialog packs `remember = props.remember` into `result.values`. `ExportTask.lua` never reads `values.remember` — persistence is already handled inside the dialog via `Prefs.save({ remember = props.remember })` on line 141. This is dead field.
- **Suggestion**: Drop `remember` from `result.values`. It's a one-line delete and keeps the result shape in sync with what the task actually consumes.

### 7. Redundant `or false` on a field that's already coalesced

- **Severity**: `non-blocking`
- **Location**: `tools/structured-export.lrplugin/ExportDialog.lua:38`
- **Description**: `savedPrefs.remember` comes from `Prefs.load`, which runs `coalesce(p.remember, d.remember)` and `d.remember = false` in defaults. So `savedPrefs.remember` is guaranteed to be a boolean already; `savedPrefs.remember or false` is a no-op. None of the other `savedPrefs.*` fields use the `or …` pattern, so this is also inconsistent.
- **Suggestion**: Change to `props.remember = savedPrefs.remember`. Minor readability fix; no behavior change.

### 8. `LrFileUtils.exists` returns `'file'` / `'directory'` / `false`, not boolean — truthy check accepts files

- **Severity**: `non-blocking`
- **Location**: `tools/structured-export.lrplugin/ExportDialog.lua:26`
- **Description**: The fallback guard `if not LrFileUtils.exists(exportRoot)` treats both `'file'` and `'directory'` as existing. If a stored `exportRoot` has been replaced by a regular file at the same path (unlikely in practice but possible), the dialog will happily use it as the destination root and `initialDirectory` for `runOpenPanel`, which may misbehave. Practically unreachable given normal iCloud folder usage, but it's a subtle edge case the plan's "silent fallback to default" intent doesn't cover.
- **Suggestion**: Tighten the check to require a directory: `if LrFileUtils.exists(exportRoot) ~= 'directory' then exportRoot = Prefs.getDefaults().exportRoot end`. Matches the plan's "check via `LrFileUtils.exists` or equivalent" wording without changing the happy path.
