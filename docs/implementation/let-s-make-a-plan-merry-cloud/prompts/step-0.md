# Batch A — Step 0: Branch Setup

You are a subagent in a multi-agent pipeline executing the v2 plan for the structured-export Lightroom plugin. Your entire job is Step 0 of `docs/plans/let-s-make-a-plan-merry-cloud.md`: create a feature branch and commit the plan files. No implementation work yet.

## Working directory

`/Users/rodmachen/code/photo-portfolio`

## Pre-state (verified by the orchestrator, do not re-check)

- Currently on `main` at commit `53dc6f6`.
- `gh` is authenticated.
- No `feature/structured-export-v2` branch on origin yet.
- Two untracked files exist at HEAD and must end up in your commit:
  - `docs/plans/let-s-make-a-plan-merry-cloud.md` (the implementation plan for v2)
  - `docs/plans/docs-plans-let-s-make-a-plan-merry-clou-clever-lamport.md` (the orchestration plan)

## What to do

1. `git checkout main && git pull --ff-only` — fast-forward to origin in case anything changed. Fail out if this errors.
2. `git checkout -b feature/structured-export-v2`.
3. `git add docs/plans/let-s-make-a-plan-merry-cloud.md docs/plans/docs-plans-let-s-make-a-plan-merry-clou-clever-lamport.md` — stage exactly these two files. Do not use `git add .` or `-A`.
4. Commit with this message (use a HEREDOC exactly):

```
Step 0: branch v2 work + commit plan files

Creates feature/structured-export-v2 for the Structured Export v2
rollout. Commits both the implementation plan
(let-s-make-a-plan-merry-cloud.md) and the multi-agent orchestration
plan (docs-plans-let-s-make-a-plan-merry-clou-clever-lamport.md) so
the branch tracks the full decision record.

No code changes. PR opens after Step 1's first implementation commit.

Verified: git status clean on branch, branch name correct.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

5. `git push -u origin feature/structured-export-v2`.

## Do NOT

- Open a PR (Step 1 does that).
- Touch any plugin or spec files.
- Modify either plan file.
- Use `--no-verify`, `--amend`, or force-push.

## Verify before writing your result

- `git status` — clean.
- `git branch --show-current` — `feature/structured-export-v2`.
- `git log -1 --format=%s` — matches the subject line above.
- `git ls-remote origin feature/structured-export-v2` — returns a SHA.

## Output

Write a single JSON object (and nothing else) to stdout with these fields:

```json
{
  "status": "success" | "failure",
  "branch": "feature/structured-export-v2",
  "commit_sha": "<full sha>",
  "commit_subject": "<subject line>",
  "pushed_to_origin": true | false,
  "verify": {
    "git_status_clean": true | false,
    "branch_current": "<branch name>",
    "remote_sha": "<full sha or empty>"
  },
  "notes": "<anything unexpected — empty string if clean>"
}
```

Execute directly. Do not ask for confirmation.
