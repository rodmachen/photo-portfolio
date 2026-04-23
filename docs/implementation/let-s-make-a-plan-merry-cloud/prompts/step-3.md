# Batch C — Step 3: Multi-select presets

You are a subagent in a multi-agent pipeline. Your job is Step 3 of `docs/plans/let-s-make-a-plan-merry-cloud.md`: replace the preset radio group with three checkboxes and wrap the existing per-collection export pipeline in an outer loop that iterates over the selected presets.

This is the largest change in the plan. Architectural choices have already been made — do not relitigate them.

## Working directory

`/Users/rodmachen/code/photo-portfolio`

## Pre-state (already done by upstream)

- On branch `feature/structured-export-v2` with Steps 0, 1, 2 committed and pushed.
- PR exists against `main`. Find the number via `gh pr view --json number,url`.
- `exportRoot` pref and dialog picker are in place (Step 2).
- Content Credentials UI is removed (Step 1).

## Canonical spec

Read `docs/plans/let-s-make-a-plan-merry-cloud.md` and execute **Step 3** exactly as written. The plan is authoritative.

## Locked-in decisions from the plan (re-emphasized)

These are decided — do not open them back up:

1. **Three checkboxes**, not re-shown dialog loops or other UX variants. If all three are unchecked on OK click: show `LrDialogs.message('Structured Export', 'Select at least one preset.', 'warning')` and treat as cancel (do not set `result.action = 'export'`, do not re-open the dialog).
2. **No migration from the old `preset` string pref**. Stored prefs from v0.1 simply fall back to defaults. Remove `preset = 'print'` from `getDefaults`; add `presetPrint = true, presetPortfolio = false, presetWeb = false`. Use `coalesce` for all three in `load`.
3. **Fixed preset order**: `print`, `portfolio`, `web`. Build `selectedPresets` in that order.
4. **Collision pre-scan runs once across all selected presets**. Aggregate collisions from every preset's output directory before prompting the user. A single prompt; the user's choice applies uniformly to all presets. `filterSkipExisting` still runs per-preset with that same choice.
5. **Progress title** for per-job progress: `"Structured Export: <collection> (<preset> — <i> of <N>)"`. N is the job count for the current preset iteration, not the grand total.
6. **Cancel semantics**: if `runJob` returns `canceled = true`, break the inner per-job loop AND the outer preset loop. The existing per-job orphan-cleanup handles what partially rendered; no new cleanup sweep at the outer level.
7. **Sequence numbers**: pass `fallbackSeqStart = 1` each preset iteration (per-preset reset is fine since the sequence is only a filename-stem fallback).
8. **Counts table**: one `counts` table for the whole run. Increments accumulate across preset iterations. Summary dialog shows totals across all presets.
9. **Reveal in Finder target**: `values.exportRoot` (already the Step 2 target).

## Files to modify

- `tools/structured-export.lrplugin/ExportDialog.lua`:
  - Replace the `f:group_box { title = 'Export Preset', ... }` radio block with a group box containing three `f:checkbox` items bound to `presetPrint`, `presetPortfolio`, `presetWeb`.
  - Pre-fill from prefs (three booleans, not the old string).
  - Validation on OK: if all three booleans are false, show the warning message and return without setting `result.action = 'export'`.
  - Remove `preset` string from pre-fill, both `Prefs.save` calls, and `result.values`.
  - Add the three booleans to pre-fill, both `Prefs.save` calls, and `result.values`.

- `tools/structured-export.lrplugin/Prefs.lua`:
  - Remove `preset = 'print'` from `getDefaults`.
  - Add `presetPrint = true, presetPortfolio = false, presetWeb = false` to `getDefaults`.
  - Update `load` to `coalesce` each of the three booleans.

- `tools/structured-export.lrplugin/ExportTask.lua`:
  - After the dialog returns, build `local selectedPresets = {}` in fixed order (`print`, `portfolio`, `web`), appending only those whose boolean is true.
  - Wrap the existing `buildJobs` → collision pre-scan → per-job loop in an outer `for _, preset in ipairs(selectedPresets) do`. The outer loop passes `fallbackSeqStart = 1` to each preset's `buildJobs` call.
  - The collision pre-scan moves to **before** the outer loop: build jobs for every selected preset first, collect collisions across all of them, prompt the user once. Store the choice. Inside each preset iteration, `filterSkipExisting` applies the choice.
  - Update `runJob`'s progress title format to include the preset name and per-preset job count.
  - Cancel handling: on `canceled = true` from `runJob`, set `shouldBreak = true` and break both the inner and outer loops.
  - Keep the `counts` table scoped to the whole run.
  - Reveal-in-Finder target is `values.exportRoot` (already correct from Step 2).

- `tools/spec/prefs_spec.lua`: add tests that `getDefaults()` has `presetPrint = true`, `presetPortfolio = false`, `presetWeb = false`, and that `load` round-trips the booleans correctly.

- `tools/structured-export.lrplugin/README.md`: update the preset section — now a set of checkboxes; exports run sequentially per selected preset.

- `docs/lightroom-export-spec.md`: update the spec to describe multi-select presets and the outer-loop execution model.

## Verification

- `cd tools && busted` — exit 0 including new preset-boolean tests.
- `cd tools && luacheck structured-export.lrplugin spec` — exit 0, zero warnings.
- `grep -n "preset = '" tools/structured-export.lrplugin/Prefs.lua` — returns nothing (old string default removed).

## Commit and update PR

Stage only the files you touched. Commit with this HEREDOC message:

```
Step 3: multi-select presets with outer export loop

Replaces the single-preset radio group with three checkboxes bound
to presetPrint/Portfolio/Web booleans. One dialog invocation can now
export the same collection selection at print + portfolio + web
output sizes — a 3x reduction in user clicks for the common case of
printing a photo that also needs a portfolio variant and a web
preview.

Architectural notes:

- ExportTask wraps the existing buildJobs → collision-scan →
  per-job render flow in an outer loop over selectedPresets (fixed
  order: print, portfolio, web).
- Collision pre-scan aggregates across all selected presets and
  prompts the user once. The chosen strategy applies uniformly.
- Cancel from runJob breaks both the inner per-job loop and the
  outer preset loop; existing per-job orphan cleanup covers partial
  renders. No new cleanup sweep at the outer level.
- fallbackSeqStart resets to 1 per preset iteration (sequence is
  only a filename-stem fallback, so per-preset reset is fine).
- counts table is run-scoped so the summary dialog aggregates.
- Progress title format now includes the preset name.
- No migration from the old preset string; v0.1 stored prefs fall
  back to new boolean defaults.

If all three checkboxes are unchecked on OK, the dialog shows a
warning and treats the click as cancel — no re-open loop.

Verified: busted passes including new preset-boolean tests, luacheck
clean, no residual 'preset =' string default in Prefs.lua.

Refs plan: docs/plans/let-s-make-a-plan-merry-cloud.md (Step 3)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

`git push`. Then update the PR description with `gh pr edit <number> --body ...` to tick Step 3 in the checklist. Retrieve the current body, flip `- [ ] Step 3` → `- [x] Step 3`, and write it back.

## Rules

- Never use `--no-verify`, `--amend`, or `push --force`.
- Stage specific files only.
- Do not refactor beyond what the step requires.
- Do not reopen architectural decisions listed above.
- If busted or luacheck fails, fix in place.

## Output

Write a single JSON object to stdout:

```json
{
  "status": "success" | "failure",
  "commit_sha": "<sha>",
  "commit_subject": "<subject>",
  "files": ["..."],
  "busted_ok": true | false,
  "luacheck_ok": true | false,
  "grep_clean": true | false,
  "pr_description_updated": true | false,
  "narrative": "<2-4 sentences: how the outer loop, cancel semantics, and aggregated collision prompt were wired>",
  "notes": "<unexpected issues or empty>"
}
```

Execute directly.
