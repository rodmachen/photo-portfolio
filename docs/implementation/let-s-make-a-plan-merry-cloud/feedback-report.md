# Feedback Report — feature/structured-export-v2

## Addressed

### Item 1 — README numbering gap and stale item count
- Severity: non-blocking
- Change: Updated preamble from "15 items" to "14 items" (`README.md:67`). Renumbered items 13–15 to 12–14 in the manual test checklist (`README.md:80-82`).
- Verification: Visual diff confirms sequential numbering 1–14 with no gap.

### Item 2 — README describes export destination as fixed iCloud Pictures
- Severity: non-blocking
- Change: Four stale references updated in `README.md`:
  - Line 40: "open the `iCloud Pictures/` root" → "open the chosen Destination root"
  - Lines 44–46: code block path replaced with `<Destination>/<set-slug>/.../<collection-slug>/<preset>/<slug>-<num>.jpg`
  - Line 73 (test item 5): path replaced with `<Destination>/<slug(collection)>/<preset>/…`
  - Line 81 (formerly test item 14, now 13): "opens `iCloud Pictures/` root" → "opens the chosen Destination root"
- Verification: `grep -n 'iCloud Pictures' README.md` returns zero hits inside Usage/checklist sections (the only remaining occurrences are in the Destination field description "Pre-fills with the iCloud Pictures path by default" and the Troubleshooting/ContentCredentials sections, which are correct).

### Item 3 — README checklist missing multi-preset collision test
- Severity: non-blocking
- Change: Extended item 9 to include: "With two or more presets selected and collisions in each, the prompt fires once; the chosen strategy applies uniformly to all preset folders." (`README.md:77`)
- Verification: Item 9 now covers both single-preset and multi-preset collision behavior.

### Item 4 — Plan file missing ✅ on Steps 0, 1, 2
- Severity: non-blocking
- Change: Appended ` ✅` to the heading lines of Step 0, Step 1, and Step 2 in `docs/plans/let-s-make-a-plan-merry-cloud.md`. Step 3 already had ✅ from Batch C.
- Verification: All four step headings now have ✅; plan reads as complete for `/work-log` and archive-on-merge purposes.

### Item 5 — Unreachable defensive fallback in ExportTask duplicates dialog validation
- Severity: non-blocking
- Change: Replaced the 6-line `if #selectedPresets == 0` block and its `LrDialogs.message` call (`ExportTask.lua:279-284`) with `assert(#selectedPresets > 0, 'dialog must validate preset selection')`. Preserves the invariant without a dead UX path.
- Verification: busted 94/0/0; luacheck clean; the assert fires only in a test context where the dialog is bypassed, not in normal runtime.

### Item 6 — `result.values.remember` dead field
- Severity: non-blocking
- Change: Removed `remember = props.remember,` from `result.values` in `ExportDialog.lua:167`. Persistence is already handled by `Prefs.save({ remember = props.remember })` on line 141; the task never reads this field.
- Verification: busted 94/0/0; luacheck clean; `ExportTask.lua` has no reference to `values.remember`.

### Item 7 — Redundant `or false` on already-coalesced boolean
- Severity: non-blocking
- Change: Changed `props.remember = savedPrefs.remember or false` to `props.remember = savedPrefs.remember` in `ExportDialog.lua:38`. `Prefs.load` → `coalesce` already guarantees a boolean via `d.remember = false` in defaults.
- Verification: busted 94/0/0; luacheck clean; no behavior change — the value was already a boolean.

### Item 8 — `LrFileUtils.exists` truthiness accepts files at directory paths
- Severity: non-blocking
- Change: Changed fallback guard in `ExportDialog.lua:26` from `if not LrFileUtils.exists(exportRoot) then` to `if LrFileUtils.exists(exportRoot) ~= 'directory' then`. Now only accepts an actual directory; a file at the same path falls back to the default.
- Verification: busted 94/0/0; luacheck clean. The spec's mock `_pathUtils` returns a valid home path that exercises the happy path; the guard change has no effect on the test values.

## Deferred

None. All 8 items addressed.

## New issues surfaced during fixes

None.

## Verification

- Busted: pass — 94 successes / 0 failures / 0 errors
- Luacheck: pass — 0 warnings / 0 errors in 16 files
- Commit: (see below after commit)
- PR description updated: yes
