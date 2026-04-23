# Phase 4 — Review Agent

You are an Opus reviewer at xhigh effort. Read the full diff of the feature branch against main and produce a structured review report.

## Working directory

`/Users/rodmachen/code/photo-portfolio`

## Inputs to read

1. `git fetch origin main` then `git diff origin/main...feature/structured-export-v2` — the full change set.
2. `docs/implementation/let-s-make-a-plan-merry-cloud/context.md` — the execution log, including per-batch summaries and any logged assumptions.
3. `docs/plans/let-s-make-a-plan-merry-cloud.md` — the implementation plan.
4. Key source files as needed to check context around diff hunks:
   - `tools/structured-export.lrplugin/ExportTask.lua`
   - `tools/structured-export.lrplugin/ExportDialog.lua`
   - `tools/structured-export.lrplugin/Prefs.lua`
   - `tools/structured-export.lrplugin/ContentCredentials.lua`
   - `tools/spec/prefs_spec.lua`

## Review focus

Evaluate every change against the plan's Step 1 / Step 2 / Step 3 specs. For each, verify:

- **Step 1 cleanup completeness**: no stale `contentCredentials` references outside the dormancy header. `require 'ContentCredentials'` fully removed from `ExportTask.lua`. VERSION bumped to 0.2.0. EXIF perf note present in `lightroom-export-spec.md`. README updated. Specs updated.
- **Step 2 folder picker**:
  - Default for `exportRoot` is computed via `LrPathUtils.getStandardFilePath('home')` and not hardcoded.
  - Dialog falls back to default silently when stored `exportRoot` no longer exists (check via `LrFileUtils.exists` or equivalent at dialog open, not at export time).
  - `collectionDir(entry, root)` threads the root through — no stale references to the old module-level `ROOT` constant anywhere.
  - Reveal-in-Finder uses `values.exportRoot`.
  - Spec tests cover the new default.
- **Step 3 multi-select**:
  - **Cancel-across-presets**: does `canceled = true` break both the inner and outer loops? Are there any code paths where an error in one preset's iteration would silently continue to the next?
  - **Collision prompt aggregation**: does the pre-scan gather collisions from every selected preset before prompting, so the user sees one prompt not N? Does the chosen strategy apply uniformly? Is the pre-scan outside the outer loop?
  - **Orphan handling on cancel**: per-job cleanup handles partial renders in the canceled preset's folder. Are earlier-preset folders (for presets that completed before cancel) left intact? They should be.
  - **Progress title**: reflects the per-preset position, e.g. `"Structured Export: <collection> (print — 3 of 7)"`.
  - **fallbackSeqStart**: reset to 1 each preset iteration.
  - **Counts**: run-scoped, so the summary dialog aggregates across presets.
  - **No-preset-selected UX**: warning dialog + treat as cancel. No re-show loop.
  - **Pref migration**: absence of migration from old `preset` string is expected per the plan — do not flag its absence.

## Cross-cutting checks

- Luacheck warnings (run `cd tools && luacheck structured-export.lrplugin spec` and flag anything).
- Busted tests pass (run `cd tools && busted`).
- Any new public functions without specs where the plan's TDD guidance called for them.
- Commit messages match the plan steps; each step has its own commit.
- No `--no-verify`, `--amend`, or force-push in the reflog.

## Dormancy header in ContentCredentials.lua

Verify the header comment actually documents revival steps: re-add require, pref default, checkbox, and call site. If it's vague ("this module is disabled") without the revival recipe, that's a non-blocking issue.

## Output format

Write a Markdown file to `docs/implementation/let-s-make-a-plan-merry-cloud/review.md` with this structure:

```markdown
# Review — feature/structured-export-v2

## Summary

<2-3 sentences: overall quality, whether the plan was followed, headline concerns if any>

## Items

### 1. <short title>

- **Severity**: `blocking` | `non-blocking`
- **Location**: `<file>:<line-or-range>` or `n/a`
- **Description**: <what the issue is>
- **Suggestion**: <recommended fix — be specific; if code, show it>

### 2. ...
```

Use consecutive integers. Put blocking items first.

If there are no issues, still write the file with `## Summary` and an `## Items` section that says `No issues found.`

## Stdout output

In addition to writing review.md, emit a single JSON object to stdout:

```json
{
  "status": "success" | "failure",
  "blocking_count": <integer>,
  "non_blocking_count": <integer>,
  "review_md_path": "docs/implementation/let-s-make-a-plan-merry-cloud/review.md",
  "summary": "<one sentence>",
  "notes": "<anything the feedback agent should know>"
}
```

Do not commit review.md — the orchestrator will handle artifact commits. Do not modify any plugin or spec files in this phase. Your job is read-and-write-review.
