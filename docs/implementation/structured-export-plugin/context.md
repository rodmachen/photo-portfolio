# Structured Export Plugin — Multi-Agent Run Context

**Plan**: `docs/plans/make-a-plan-using-sleepy-whale.md` (will be renamed to `structured-export-plugin.md` in Step 0)
**Started**: 2026-04-22
**Orchestrator**: Opus 4.7 / xhigh (default)

## Summary

Builds a Lightroom Classic plugin (`tools/structured-export.lrplugin/`) that exports selected collections to a structured iCloud folder tree across three preset sizes (print, portfolio, web), embedding copyright/IPTC metadata via native LR settings + an `exiftool` post-process for custom IPTC fields. Includes a busted-based test harness in `tools/spec/`, a luacheck config, and a GitHub Actions CI workflow.

## Repo State at Start

- Branch: `main` (clean)
- Remote: `origin` → `git@github.com:rodmachen/photo-portfolio.git` (despite the plan's "not applicable" note — the remote DOES exist)
- `gh` authenticated as `rodmachen`
- Initial commit `f6b259d` already present with the plan file at `docs/plans/make-a-plan-using-sleepy-whale.md` and `.gitignore` (already containing `.claude/settings.local.json`)
- Spec at `docs/lightroom-export-spec.md` (275 lines)
- `exiftool` installed at `/opt/homebrew/bin/exiftool`
- `busted`, `luacheck`, `lua` NOT installed locally — see Assumptions

## Assumptions

1. **busted/luacheck install**: The plan calls for busted-based TDD on Lua modules. Installing locally via Homebrew (`brew install lua luarocks` then `luarocks install busted luacheck`) is necessary for any local verification of TDD steps. Will install during Batch A. If install fails or is too invasive, fall back to relying solely on the GitHub Actions CI for verification.
2. **Step 0 adaptation**: The initial commit already exists; Step 0 collapses to `git mv` of the plan file (under its new name) plus a rename commit, then `git checkout -b feature/structured-export-plugin`.
3. **GitHub remote IS available**: contrary to the plan's prerequisite note, the remote is configured. Will push the feature branch and open a PR after the first implementation commit, per global workflow rules. Plan's "dormant CI" framing no longer applies — CI will run on push.
4. **Plan name slug for orchestration dir**: Using `structured-export-plugin` to match the post-rename plan filename.

## Plan (Tagged)

| Step | Title | Model | Effort | Context-clear | Tests | Dependencies |
|------|-------|-------|--------|---------------|-------|--------------|
| 0    | Repo bootstrap (rename plan, branch) | Haiku | low | no | none | — |
| 1    | Scaffold + busted + CI | Haiku | low | yes | alongside | 0 |
| 2    | `Utils.lua` | Sonnet | medium | no | TDD | 1 |
| 3    | `Presets.lua` | Sonnet | medium | yes | TDD | 1 |
| 4    | `Prefs.lua` | Haiku | low | no | alongside | 1 |
| 5    | `Metadata.lua` | Sonnet | medium | yes | TDD (partial) | 4 |
| 6    | `Collections.lua` | Sonnet | medium | yes | TDD | 1 |
| 7    | `ExportDialog.lua` | Sonnet | medium | yes | alongside | 4, 5 |
| 8    | `Info.lua` | Sonnet | medium | no | alongside | 1 |
| 9    | `ExportTask.lua` + `ContentCredentials.lua` | Opus | high | yes | alongside | 2,3,4,5,6,7,8 |
| 10   | README + logging audit | Sonnet | medium | no | none | 9 |
| 11   | Manual end-to-end verification | n/a (human) | n/a | yes | manual | 10 |

## Batches

- **Batch A** (Haiku/low): Steps 0 + 1
- **Batch B** (Sonnet/medium): Steps 2 + 3
- **Batch C** (Haiku/low): Step 4
- **Batch D** (Sonnet/medium): Steps 5 + 6 + 7 + 8
- **Batch E** (Opus/high): Step 9
- **Batch F** (Sonnet/medium): Step 10
- **Step 11**: Skipped — requires running Lightroom Classic GUI; will be flagged in PR description for Rod.

## Run Log

## Completion

All implementation, review, and feedback phases complete. Step 11 (manual verification in Lightroom Classic) is Rod-driven and is the only remaining item before merge.

- **Final state**: 92 busted specs pass, 0 luacheck warnings, branch pushed to origin, PR #1 description updated with the full plan checklist.
- **Commits on branch**: 17 (10 plan steps + 5 review-fix groups + 1 feedback report + 1 orchestration trail).
- **Total subagent runs**: 7 implementation + 1 review + 1 feedback = 9 invocations.
- **Cost note**: Batch B used cache aggressively (~1.5M cache reads). Per-batch cost figures are inside each `results/*.json`.

### Phase 5 (Task #9) — completed
- Both blocking findings fixed: B1 (`Prefs.preset` round-trip) and B2 (`Collections.enumerate` accepts `LrPublishedCollectionSet` via `:type():match('CollectionSet$')`).
- 7 non-blocking items fixed: N1, N2, N3, N5, N6, N7, N9, N10. (Spec count grew 88 → 92.)
- 2 deferred with rationale: N4 (summary dialog API choice — implementation is strictly better UX), N8 (collision button order — taste).
- Initial spawn failed with `cat: ... No such file or directory` because bash CWD had drifted. Re-spawned with absolute `cd /Users/rodmachen/code/photo-portfolio &&` prefix. CWD drift is the dominant friction in this orchestration; future runs should always prepend the absolute cd.

### Phase 4 (Task #8) — completed
- Opus xhigh review found 2 blocking + 10 non-blocking issues in 4 minutes.
- Output written to `review.md` with structured JSON.
- Caught a real bug (B1) that the Batch D subagent had explicitly rationalized as "fine" — illustrating why the review pass is worth the cost.

### Batch F (Task #7) — completed
- Step 10 (README + logging audit) done. Commit: `80034ec`.
- Logger audit notably caught a real bug in `Metadata.lua`: the original code shelled out to `LrTasks.execute('logger -t ...')` (the macOS `logger` binary) instead of using `LrLogger`. Replaced with proper `LrLogger('StructuredExport')` via pcall-require guard.
- 88 specs / 0 luacheck warnings.

### Batch E (Task #6) — completed
- Step 9 (ExportTask.lua + ContentCredentials.lua) done. 288 + 29 lines.
- 88 specs pass; luacheck clean; loadfile parse-check passes.
- Commit: `75c7512`.
- Per-photo filename strategy: render with LR default name → `LrFileUtils.move` to slug-based name during the rendition loop. Overwrite collision = delete-then-move.
- Content Credentials apply tries `LR_embedContentCredentials` first, falls back to `LR_contentCredentials`; both pcall-wrapped.

### Batch D (Task #5) — completed
- Steps 5 (Metadata), 6 (Collections), 7 (ExportDialog), 8 (Info) all done.
- 88 specs pass; luacheck clean across 13 files.
- Commits: `889a1a5`, `9e894e7`, `ffd92a6`, `f89cd94`.
- Notable: ExportDialog persists `preset` on Remember (matches spec line 33). Collections walker pushes pathSegments down (cleaner than parent walk).
- Pending wiring: ExportDialog defaults to `'print'` via `or` fallback because `Prefs.load()` doesn't yet return a `preset` key — fine since `Prefs.save()` will persist it for next load.

### Batch C (Task #4) — completed
- Step 4 (Prefs.lua) done. 74 specs pass; luacheck clean.
- Commit: `1c7d6e2`. Defaults verified against spec lines 27-31.

### Batch B (Task #3) — completed
- Steps 2 (Utils.lua) + 3 (Presets.lua) done.
- 72 busted specs pass; luacheck clean (0 warnings, 0 errors).
- Commits: `a0544b8` (Step 2), `c73d02d` (Step 3), plus 2 housekeeping commits (plan checkbox + results).
- Key assumptions logged by subagent: `LR_size_resizeType="shortEdge"` requires SDK 9.0+ (fine — plan requires 13+); `extractFileNumber` returns the **first** prefix-digit run (so `IMG_0001-Edit-2.DNG` → `0001`); slugify is ASCII-only.

### Batch A (Task #2) — completed
- Steps 0 + 1 done. Branch `feature/structured-export-plugin` created. Scaffold + busted + luacheck + GitHub Actions workflow in place. PR #1 opened: https://github.com/rodmachen/photo-portfolio/pull/1.
- Subagent created a placeholder `utils_spec.lua` to satisfy busted's file-discovery (replaced in Batch B).

### Prep (Task #1) — completed

- Installed `lua` 5.5 (Homebrew default) and `lua@5.4` (compatibility version) and `luarocks` 3.13.
- `busted` 2.3.0 and `luacheck` 1.2.0 installed via `luarocks --lua-version=5.4 --lua-dir=/opt/homebrew/opt/lua@5.4 install --local`. Lua 5.5 is too new for `argparse` (luacheck dep), so 5.4 is the working version.
- **Subagents must export PATH before running busted/luacheck**: `export PATH="$HOME/.luarocks/bin:/opt/homebrew/opt/lua@5.4/bin:$PATH"`.
- CI (GitHub Actions) workflow in Step 1 should target Lua 5.4 to match.

