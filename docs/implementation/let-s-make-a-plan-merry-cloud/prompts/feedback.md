# Phase 5 — Feedback Agent

You are a Sonnet/high implementation agent. Read the review report and resolve every `blocking` item. Judge-call every `non-blocking` item — address it unless you have a concrete reason to defer. Record deferrals with their reasons in a feedback report.

## Working directory

`/Users/rodmachen/code/photo-portfolio`

## Pre-state

- On branch `feature/structured-export-v2` with Steps 0–3 committed and pushed.
- PR is open against `main`.
- `docs/implementation/let-s-make-a-plan-merry-cloud/review.md` contains the review items.

## Inputs to read

1. `docs/implementation/let-s-make-a-plan-merry-cloud/review.md` — your work queue.
2. `docs/implementation/let-s-make-a-plan-merry-cloud/context.md` — execution history.
3. `docs/plans/let-s-make-a-plan-merry-cloud.md` — authoritative plan.
4. Any source files referenced by review items.

## Procedure

1. For each review item:
   - **Blocking**: resolve it. Make the code change. If unclear, re-read the plan and the surrounding code before editing.
   - **Non-blocking**: evaluate. If the fix is small and clearly correct, apply it. If it's a judgment call the plan would reject (e.g., adds scope the plan explicitly deferred), skip it and record the reason.
   - **Reject**: if a review item appears to misread the code, verify with the actual file, and — if confident — skip it and record a clear explanation.
2. After changes:
   - `cd tools && busted` — must exit 0.
   - `cd tools && luacheck structured-export.lrplugin spec` — must exit 0, zero warnings.
3. Stage only the files you touched.
4. Commit with a message that lists which review items were addressed and any deferrals with reasons. Message template:

```
Review feedback: <short headline>

Addresses review items N, M, ... (see
docs/implementation/let-s-make-a-plan-merry-cloud/review.md):

- <item N title>: <one-line description of the fix>
- <item M title>: <one-line description of the fix>

Deferred (with reasons):
- <item X title>: <reason the plan or scope makes this wrong to do here>

Verified: busted passes, luacheck clean.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

5. `git push`.
6. Update the PR description. Add a "Review feedback" section at the bottom listing addressed items and deferrals.

## Write feedback-report.md

Write `docs/implementation/let-s-make-a-plan-merry-cloud/feedback-report.md`:

```markdown
# Feedback Report — feature/structured-export-v2

## Addressed

### <Item N title>
- Severity: blocking | non-blocking
- Change: <what you did, with file:line>
- Verification: <how you confirmed the fix>

(repeat)

## Deferred

### <Item X title>
- Severity: non-blocking (blocking items cannot be deferred)
- Reason: <why deferring is the right call here — cite plan or scope>

## New issues surfaced during fixes

<bullet list, or "None">

## Verification

- Busted: <pass/fail, tail of output>
- Luacheck: <pass/fail>
- Commit: <sha>
- PR description updated: <yes/no>
```

If a review item claims blocking severity but your investigation shows it's based on a misread of the code, do NOT silently skip. Mark it Deferred with severity `blocking-but-incorrect` and explain in detail why the review was wrong, citing specific file:line evidence. The orchestrator will surface this for human review rather than treating it as resolved.

## Rules

- Never use `--no-verify`, `--amend`, or force-push.
- Stage specific files.
- Do not alter the implementation plan file.
- Do not relitigate architectural decisions from Step 3 (see the locked-in decisions list in `prompts/step-3.md`).
- Do not touch files outside what the review items reference.

## Output

Stdout: single JSON object.

```json
{
  "status": "success" | "failure",
  "addressed_count": <int>,
  "deferred_count": <int>,
  "blocking_incorrect_count": <int>,
  "commit_sha": "<sha>",
  "busted_ok": true | false,
  "luacheck_ok": true | false,
  "pr_description_updated": true | false,
  "feedback_report_path": "docs/implementation/let-s-make-a-plan-merry-cloud/feedback-report.md",
  "notes": "<anything the orchestrator should know for final check>"
}
```

Execute directly.
