# Batch B — Steps 1 + 2: CC removal + folder picker

You are a subagent in a multi-agent pipeline. You execute **both** Step 1 and Step 2 of the implementation plan sequentially. Commit after each step. After Step 1's commit, open the PR. After Step 2's commit, update it.

## Working directory

`/Users/rodmachen/code/photo-portfolio`

## Pre-state (already done by upstream, do not redo)

- On branch `feature/structured-export-v2` at commit `e2f7601`.
- Plan files are already committed on the branch.
- No PR exists yet.
- `gh` is authenticated.

## Canonical spec

Read `docs/plans/let-s-make-a-plan-merry-cloud.md` in full and execute **Step 1** and **Step 2** exactly as written. The plan is authoritative — file paths, line numbers, exact text edits, and verification commands are all there. This prompt does not duplicate them; it adds orchestration-specific requirements.

## Orchestration requirements

### Step 1 — execution order

1. Make the Step 1 edits across:
   - `tools/structured-export.lrplugin/Info.lua` (VERSION bump to `{ major = 0, minor = 2, revision = 0 }`)
   - `tools/structured-export.lrplugin/ExportDialog.lua` (remove CC checkbox block, pre-fill, `Prefs.save` keys, `result.values`)
   - `tools/structured-export.lrplugin/ExportTask.lua` (remove `require 'ContentCredentials'` and `CC.apply` call)
   - `tools/structured-export.lrplugin/Prefs.lua` (remove `contentCredentials` from `getDefaults` and `load`)
   - `tools/structured-export.lrplugin/ContentCredentials.lua` (add a dormancy header comment — module body unchanged)
   - `tools/spec/prefs_spec.lua` (drop CC-related assertions)
   - `docs/lightroom-export-spec.md` (add "Performance notes" section with EXIF threshold)
   - `tools/structured-export.lrplugin/README.md` (remove CC bullet, add deferred note)
2. Verify:
   - `cd tools && busted` — exit 0
   - `cd tools && luacheck structured-export.lrplugin spec` — exit 0, zero warnings
   - `grep -rn contentCredentials tools/structured-export.lrplugin` — returns only the dormancy header comment line(s) in `ContentCredentials.lua`
3. Stage exactly the files you touched (no `git add -A`), commit with this message (HEREDOC):

```
Step 1: remove Content Credentials UI; bump to v0.2.0

Adobe has not exposed Content Credentials in Lightroom Classic's
native export, so the v1 checkbox sent best-guess SDK keys to no
effect. Remove the checkbox, pref, and call site so the UI stops
promising a feature that does nothing.

ContentCredentials.lua and its spec remain on disk with a dormancy
header comment explaining how to revive (re-add the require, pref,
checkbox, and call site). Module body is unchanged.

Also bumps VERSION to 0.2.0 and documents the per-image exiftool
perf threshold in docs/lightroom-export-spec.md (Performance notes)
so the batch-per-directory migration trigger is recorded.

Verified: busted passes, luacheck clean, grep confirms no residual
contentCredentials references outside the dormancy header.

Refs plan: docs/plans/let-s-make-a-plan-merry-cloud.md (Step 1)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

4. `git push` to update the remote branch.

### After Step 1 commit: open the PR

Open a **non-draft** PR with `gh pr create`:

```
gh pr create --base main --head feature/structured-export-v2 \
  --title "Structured Export v2" \
  --body "$(cat <<'EOF'
## Summary

Structured Export plugin v2 — three scoped changes:
1. Remove the dormant Content Credentials checkbox (Adobe has not exposed CC in LR Classic's native export).
2. Make the export root configurable via a dialog folder picker (replaces the hardcoded iCloud Pictures path).
3. Replace the preset radio group with multi-select checkboxes so one invocation can export print + portfolio + web.

Plan: docs/plans/let-s-make-a-plan-merry-cloud.md

## Steps

- [x] Step 0 — Branch setup
- [x] Step 1 — Remove Content Credentials UI; bump to v0.2.0; document EXIF threshold
- [ ] Step 2 — Add folder picker (exportRoot pref + dialog Browse row)
- [ ] Step 3 — Multi-select presets (checkboxes + outer loop)

## Test plan

- [ ] CI (lua-tests workflow) green on the PR — busted + luacheck
- [ ] Manual smoke in Lightroom (user-run after merge-ready):
  - [ ] Dialog shows no Content Credentials row
  - [ ] Destination row pre-fills, Browse picks a folder, files land there
  - [ ] Re-open dialog with Remember checked — destination persists
  - [ ] Multi-preset: check all three, one invocation produces three output subfolders
  - [ ] Cancel during multi-preset run leaves no orphans
  - [ ] Collision dialog fires once across presets, not per preset
  - [ ] Uncheck all presets → warning dialog, no export

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Capture the PR URL from the `gh` output.

### Step 2 — execution order

1. Make the Step 2 edits:
   - `tools/structured-export.lrplugin/Prefs.lua` — add `exportRoot` to `getDefaults` (default computed from `LrPathUtils.getStandardFilePath('home')` joined to `Library/Mobile Documents/com~apple~CloudDocs/iCloud Pictures`). Add corresponding `coalesce` line in `load`. Preserve the existing test-injection seam so `prefs_spec.lua` can override without pulling in the LR SDK.
   - `tools/structured-export.lrplugin/ExportDialog.lua` — add a destination row at the top of the dialog body (above the preset group box) with `f:static_text { title = 'Destination:' }`, `f:edit_field { value = LrView.bind('exportRoot'), fill_horizontal = 1 }`, and `f:push_button { title = 'Browse...', action = ... }`. The action uses `LrDialogs.runOpenPanel { canChooseFiles = false, canChooseDirectories = true, allowsMultipleSelection = false, initialDirectory = props.exportRoot }` and sets `props.exportRoot = result[1]` on selection. Add `exportRoot` to pre-fill, both `Prefs.save` calls, and `result.values`. On dialog open, if stored `exportRoot` does not exist on disk (check via `LrFileUtils.exists`), fall back to the default silently.
   - `tools/structured-export.lrplugin/ExportTask.lua` — remove the module-level `local ROOT = ...` constant. Read `values.exportRoot` from the dialog result. Thread it through `collectionDir(entry, root)` (currently single-param). Update the `LrShell.revealInShell` call at the end of the export (was `revealInShell(ROOT)`) to use `values.exportRoot`.
   - `tools/spec/prefs_spec.lua` — add a test that `getDefaults().exportRoot` is non-empty and ends with `iCloud Pictures`, and that injected prefs override.
   - `tools/structured-export.lrplugin/README.md` — document the Destination field.
2. Verify:
   - `cd tools && busted` — exit 0 including the new `exportRoot` test
   - `cd tools && luacheck structured-export.lrplugin spec` — exit 0
3. Stage the files you touched, commit with this message (HEREDOC):

```
Step 2: configurable export root via dialog folder picker

Replaces the hardcoded ~/Library/Mobile Documents/.../iCloud Pictures
constant in ExportTask.lua with an exportRoot value flowing from the
dialog. Adds a Destination row to ExportDialog.lua (static text +
edit field + Browse button that calls LrDialogs.runOpenPanel).

The default is still iCloud Pictures, computed at getDefaults()
time from LrPathUtils so the path is derivable on any machine.
Remember checkbox persists the chosen path via existing Prefs.save
flow. If a stored exportRoot no longer exists on disk, the dialog
silently falls back to the default on open rather than erroring at
export time.

collectionDir(entry, root) now takes the root as a parameter and
the Reveal-in-Finder call at export end uses values.exportRoot.

Verified: busted passes including new exportRoot default test,
luacheck clean.

Refs plan: docs/plans/let-s-make-a-plan-merry-cloud.md (Step 2)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

4. `git push`.

### After Step 2 commit: update PR description

Use `gh pr edit` to tick Step 2 in the checklist:

```
gh pr edit <pr-number> --body "$(cat <<'EOF'
...same body as before with [x] Step 2...
EOF
)"
```

(Copy the previous body and change `- [ ] Step 2` → `- [x] Step 2`.)

## Verification commands (run exactly)

After each step's edits, before committing:
- `cd tools && busted` — must exit 0
- `cd tools && luacheck structured-export.lrplugin spec` — must exit 0, no warnings

## Rules

- Never use `--no-verify`, `--amend`, or `push --force`.
- Stage specific files (no `git add -A` / `git add .`).
- Do not touch `ContentCredentials.lua`'s logic — only add a header comment in Step 1.
- Do not attempt Lightroom smoke tests (can't automate).
- Do not touch files outside what each step specifies.
- If busted or luacheck fails, fix in place; do not suppress or skip.

## Output

Write a single JSON object to stdout with these fields:

```json
{
  "status": "success" | "failure",
  "step_1": {
    "commit_sha": "<sha>",
    "commit_subject": "<subject>",
    "files": ["..."],
    "busted_ok": true | false,
    "luacheck_ok": true | false,
    "grep_clean": true | false
  },
  "pr": {
    "url": "<https://github.com/... >",
    "number": <number>
  },
  "step_2": {
    "commit_sha": "<sha>",
    "commit_subject": "<subject>",
    "files": ["..."],
    "busted_ok": true | false,
    "luacheck_ok": true | false
  },
  "pushed_to_origin": true | false,
  "pr_description_updated": true | false,
  "notes": "<anything unexpected — empty string if clean>"
}
```

Execute directly. Do not ask for confirmation.
