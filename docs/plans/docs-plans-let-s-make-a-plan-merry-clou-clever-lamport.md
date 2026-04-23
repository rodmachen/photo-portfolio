# Multi-Agent Orchestration — Structured Export v2

## Context

The user invoked `/multi-agent-plan docs/plans/let-s-make-a-plan-merry-cloud.md`. That plan already specifies a complete v2 implementation for the structured-export Lightroom plugin: remove the Content Credentials UI promise, make the export root configurable via a dialog folder picker, and switch the preset radio group to multi-select with an outer loop.

This document is the **orchestration plan** for executing that implementation plan end-to-end via `claude` subprocess subagents — not a re-plan of the implementation itself. An Explore pass confirmed every file path, line number, and structural reference in the underlying plan still matches the current tree (main @ `53dc6f6`, plan file uncommitted).

Goal: spawn a coordinated pipeline of implementation → review → feedback subagents that produces a green PR against `main` for the v2 scope, with per-step commits, without the orchestrator session itself writing any plugin code.

## Existing Plan Summary

Four steps in `let-s-make-a-plan-merry-cloud.md`:

| Step | Scope | Model | Effort | Context-clear |
|---|---|---|---|---|
| 0 | Branch setup + commit plan file | Sonnet | low | no |
| 1 | Remove CC from UI; bump to 0.2.0; document EXIF threshold | Sonnet | medium | yes |
| 2 | Add folder picker (`exportRoot` pref + dialog Browse row) | Sonnet | medium | no |
| 3 | Multi-select presets (checkboxes + outer loop) | Opus | high | yes |

All line references verified. CI exists (`.github/workflows/lua-tests.yml`). No PR exists yet — Step 0 creates the branch, Step 1 opens the PR.

## Orchestration Layout

Working directory for orchestration artifacts:

```
docs/implementation/let-s-make-a-plan-merry-cloud/
  context.md          # running log — decisions, per-batch summaries, assumptions, blockers
  review.md           # populated by Review Agent (Phase 4)
  feedback-report.md  # populated by Feedback Agent (Phase 5)
  prompts/
    step-0.md         # Branch setup
    step-1-2.md       # Batched: CC removal + folder picker
    step-3.md         # Multi-preset
    review.md         # Review prompt
    feedback.md       # Feedback prompt
  results/
    step-0.json
    step-1-2.json
    step-3.json
    review.json
    feedback.json
```

## Batching

Per the command's rule (same model AND same effort is batchable, only split on conditional branches):

- **Batch A — Step 0** (Sonnet / low). Standalone — effort differs from Step 1.
- **Batch B — Steps 1+2** (Sonnet / medium). Consecutive, identical model/effort, no conditional branch between them. One subagent runs both, committing after each step. Step 1's commit triggers PR creation; Step 2's commit updates it.
- **Batch C — Step 3** (Opus / high). Standalone — different model from Batch B.

The plan's `context-clear` flags (yes on Steps 1 and 3) are a non-issue here: each subprocess starts with fresh context anyway, so the flag collapses into "spawn a new subagent," which is already what happens at every batch boundary.

## Execution Plan

### Phase 0 — Directory setup

Create `docs/implementation/let-s-make-a-plan-merry-cloud/` with the subdirs above. Write a `context.md` header with plan name, start timestamp, and a one-paragraph summary of the v2 scope.

### Phase 1 — Parse and tag

Write the four-step table above into `context.md` under `## Plan`. Nothing to infer — the plan tags model, effort, and context-clear explicitly for every step.

### Phase 2 — Batch

Recorded above. No further splits required.

### Phase 3 — Execution loop

For each batch: `TaskCreate` → write prompt file → set task `in_progress` → spawn subagent → parse JSON result → append summary to `context.md` → mark task `completed`.

**Batch A invocation:**
```bash
claude --model sonnet --effort low \
  --allowedTools "Bash,Write,Edit,Read" \
  -p "$(cat docs/implementation/let-s-make-a-plan-merry-cloud/prompts/step-0.md)" \
  --output-format json \
  > docs/implementation/let-s-make-a-plan-merry-cloud/results/step-0.json
```

Batch A prompt must specify:
- `git checkout main && git pull` (confirm clean working tree first — plan file is untracked; keep it)
- `git checkout -b feature/structured-export-v2`
- `git add docs/plans/let-s-make-a-plan-merry-cloud.md && git commit -m "..."` with a message referencing Step 0
- Push branch with `-u` so subsequent pushes attach
- **Do not** open the PR here — plan says PR opens after the first implementation commit (Step 1)
- Write a JSON result object to the results path containing: branch name, commit SHA, verification snapshot (`git status`, `git branch --show-current`)
- Success criteria: `feature/structured-export-v2` exists locally and on origin; plan file committed; working tree clean

**Batch B invocation:**
```bash
claude --model sonnet --effort medium \
  --allowedTools "Bash,Write,Edit,Read" \
  -p "$(cat docs/implementation/let-s-make-a-plan-merry-cloud/prompts/step-1-2.md)" \
  --output-format json \
  > docs/implementation/let-s-make-a-plan-merry-cloud/results/step-1-2.json
```

Batch B prompt must include:
- The exact Step 1 and Step 2 specs from `let-s-make-a-plan-merry-cloud.md` (quoted verbatim — the file paths, line numbers, and behavior are all there)
- Execute Step 1 fully: edits across `Info.lua`, `ExportDialog.lua`, `ExportTask.lua`, `Prefs.lua`, `ContentCredentials.lua` (header comment only), `tools/spec/prefs_spec.lua`, `docs/lightroom-export-spec.md`, `tools/structured-export.lrplugin/README.md`. Run `cd tools && busted` and `cd tools && luacheck structured-export.lrplugin spec` — both must be clean. Commit with a message referencing Step 1.
- After Step 1 commit, open the PR: `gh pr create --title "Structured Export v2" --body ...`. Body should reference the plan file and include the step checklist (Step 0 ✅, Step 1 ✅, Step 2 pending, Step 3 pending).
- Then execute Step 2 fully: `exportRoot` added to `Prefs.lua` defaults + `load`, destination row added to `ExportDialog.lua` (with `LrDialogs.runOpenPanel` browse handler and missing-folder fallback), `ExportTask.lua` replaces `ROOT` constant with `values.exportRoot` and threads it into `collectionDir(entry, root)`, `line 354` Reveal-in-Finder updated, spec added for the new default. Verify: busted passes, luacheck clean. Commit with a message referencing Step 2. Push (PR description should be updated to mark Step 2 ✅).
- Return JSON listing: commits for Step 1 and Step 2 (SHAs + messages), PR URL, busted/luacheck output tails, files touched per step
- Success criteria: both commits exist on `feature/structured-export-v2`; PR #N is open on GitHub with step checklist updated through Step 2; `grep -r contentCredentials tools/structured-export.lrplugin` returns only the dormancy header

**Batch C invocation:**
```bash
claude --model opus --effort high \
  --allowedTools "Bash,Write,Edit,Read" \
  -p "$(cat docs/implementation/let-s-make-a-plan-merry-cloud/prompts/step-3.md)" \
  --output-format json \
  > docs/implementation/let-s-make-a-plan-merry-cloud/results/step-3.json
```

Batch C prompt must include:
- The full Step 3 spec quoted from the plan, including the key structural points: collision pre-scan runs once across all selected presets, progress title format `"Structured Export: <collection> (<preset> — <i> of <N>)"`, cancel breaks outer loop, `fallbackSeqStart=1` per preset iteration, `counts` table run-scoped, Reveal target uses `values.exportRoot` from Step 2.
- Explicitly call out the cancel-style "no preset selected" warning (not a re-show loop).
- Edit targets: `ExportDialog.lua` (radio → three checkboxes bound to `presetPrint/Portfolio/Web` + validation message), `Prefs.lua` (drop `preset` string, add three booleans; no migration), `ExportTask.lua` (outer loop wrapping `buildJobs` → collision scan → per-job loop; aggregated collision prompt), `tools/spec/prefs_spec.lua` (test new booleans), `tools/structured-export.lrplugin/README.md`, `docs/lightroom-export-spec.md`.
- Verify: busted passes, luacheck clean. Commit referencing Step 3. Push. Update PR description to mark Step 3 ✅.
- Return JSON: commit SHA, files touched, busted/luacheck tails, a short narrative of how the outer loop, cancel semantics, and collision aggregation were wired.
- Success criteria: commit exists; tests pass; dialog logic in the diff shows checkbox bindings + validation message; `ExportTask.lua` contains an outer preset loop that wraps the existing per-job flow.

### Phase 4 — Review Agent

After Batch C completes, spawn Opus at xhigh for review:

```bash
claude --model opus --effort xhigh \
  --allowedTools "Bash,Read,Write" \
  -p "$(cat docs/implementation/let-s-make-a-plan-merry-cloud/prompts/review.md)" \
  --output-format json \
  > docs/implementation/let-s-make-a-plan-merry-cloud/results/review.json
```

Review prompt inputs: `git diff main...feature/structured-export-v2`, the full `context.md`, and the original plan file. Output structured JSON into `review.md` with items tagged `blocking` / `non-blocking`, each carrying `location`, `description`, `suggestion`. Reviewer should pay particular attention to: cancel-across-presets correctness (no orphans in partially-run preset dirs), collision-prompt aggregation (fires once, not per-preset), missing-`exportRoot` fallback behavior, and whether the dormancy header in `ContentCredentials.lua` actually documents a revival path.

### Phase 5 — Feedback Agent

```bash
claude --model sonnet --effort high \
  --allowedTools "Bash,Write,Edit,Read" \
  -p "$(cat docs/implementation/let-s-make-a-plan-merry-cloud/prompts/feedback.md)" \
  --output-format json \
  > docs/implementation/let-s-make-a-plan-merry-cloud/results/feedback.json
```

Feedback agent resolves every `blocking` item, handles non-blocking with judgment, defers only with a recorded reason. Commits the fixes on the same branch, pushes, updates the PR description. Writes `feedback-report.md` listing what changed, what was deferred, and any new issues the fixes surfaced. Verify: busted + luacheck still clean after fixes.

### Phase 6 — Final check

Orchestrator reads `feedback-report.md`, confirms no unresolved `blocking` items. Marks all `TaskCreate` tasks `completed`. Writes a completion summary to `context.md` under `## Completion` with: final PR URL, commit list, CI status, residual non-blocking items that were deferred and why.

## Hard-Blocker Categories

These are the only conditions under which the orchestrator stops and surfaces to the user (write a `## Stopped` entry in `context.md` first):

- Missing credentials (`gh` not authenticated — `gh auth status` should be checked at start of Phase 3)
- Busted or luacheck failures that persist after one retry with a revised prompt
- A subagent returning malformed JSON twice in a row
- Unresolvable merge conflict (unlikely — feature branch is new)
- Any request to delete data or force-push, which is not authorized

For everything else (minor assumption gaps, ambiguous edge cases like the `exportRoot` missing-folder fallback UX): make the judgment call the plan already hinted at, log it under `## Assumptions` in `context.md`, and continue.

## Pre-flight Check

Before Phase 0, orchestrator should verify:
1. Working tree clean except for the untracked plan files (`let-s-make-a-plan-merry-cloud.md` and this orchestration plan). Both get committed on the v2 branch — **including this orchestration plan**, alongside the implementation plan, in Step 0.
2. `gh auth status` green (PR creation needs it).
3. No existing branch named `feature/structured-export-v2` on origin (would collide).

## Verification

End-to-end success for this orchestration run:
- Three commits on `feature/structured-export-v2` (Step 0 plan commit, Step 1, Step 2 — plus Step 3) plus any feedback-round commits.
- PR open against `main` with the step checklist fully ticked.
- CI green on the PR (lua-tests workflow passes busted + luacheck).
- `review.md` and `feedback-report.md` both present under `docs/implementation/let-s-make-a-plan-merry-cloud/`.
- No unresolved `blocking` items in `feedback-report.md`.
- `context.md` contains a `## Completion` entry with final PR URL and commit list.

Manual smoke verification (from the plan's End-to-End Verification section) is **user-initiated** — Lightroom isn't scriptable here. The orchestration ends when the PR is green and clean; the user runs the dialog/folder-picker/multi-preset smoke tests themselves before merging.
