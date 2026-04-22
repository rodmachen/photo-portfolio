# Phase 4 — Opus xhigh review pass

You are a code reviewer. Your job is to review the full PR diff for the Structured Export plugin against the plan and spec, and produce a structured findings report.

## Working directory
`/Users/rodmachen/code/photo-portfolio`. On `feature/structured-export-plugin`.

## Inputs to read
- `git diff main...HEAD` — full PR diff
- `git log main..HEAD --oneline` — step-by-step commit history
- `docs/plans/structured-export-plugin.md` — authoritative plan including Locked Decisions
- `docs/lightroom-export-spec.md` — authoritative spec (where the plan defers)
- `docs/implementation/structured-export-plugin/context.md` — orchestration log including assumptions
- All result JSONs under `docs/implementation/structured-export-plugin/results/`
- All Lua files under `tools/structured-export.lrplugin/` and `tools/spec/`

## What to look for

1. **Correctness against the spec/plan**
   - Spec defaults (rights string, copyright, web statement, contact email) match `Prefs.lua` exactly.
   - Slugification rule (Locked Decision #4) applied uniformly to folder names AND filenames.
   - File-numbering rule produces `{slug}-{number}.jpg`; falls back to LR sequence when no digits.
   - Three preset constants match the spec's print/portfolio/web (sizes, DPI, quality).
   - `LR_size_resizeType` uses correct SDK constants. **Flag any value the SDK is known to reject.**
   - Folder root: `~/Library/Mobile Documents/com~apple~CloudDocs/Photos/`.
   - Collision pre-scan covers the **selected preset's** subfolder only (Locked Decision #5).
   - No-collection-selected dialog matches spec wording exactly.
   - Content Credentials key tries the modern key first, falls back, never surfaces error.
   - exiftool resolution probes the documented PATH; degrades gracefully if missing.
   - Shell escaping wraps in single quotes and properly escapes embedded single quotes.

2. **Lua quality**
   - No `LR*` modules `require`d at top-level of files that need to be busted-loadable.
   - Tests use the duck-typed protocol cleanly (no real SDK loading in specs).
   - `pcall` boundaries in the right places (CC key assignment, per-photo apply, etc.).
   - No silent error suppression where a logger:error would be appropriate.

3. **Test coverage**
   - Every TDD module (Utils, Presets, Prefs, Metadata builder/shellEscape, Collections) has at least the cases the plan called out.
   - `cd tools && busted` and `cd tools && luacheck .` both exit 0 (re-run them and capture).
   - No spec file is just a placeholder.

4. **Plugin manifest & wiring**
   - `Info.lua` registers the menu item under both LrLibraryMenuItems AND LrExportMenuItems.
   - `LrToolkitIdentifier` is a valid reverse-DNS string.
   - `ExportTask.lua` properly wraps async work in `LrTasks.startAsyncTask` and `LrFunctionContext.callWithContext`.

5. **README & dev setup**
   - Install instructions are correct (symlink to LR Modules dir).
   - Manual test checklist is complete.
   - Dev setup matches what was actually used (Lua 5.4 via Homebrew + luarocks --local).

6. **Anything else** — security (shell injection paths the escape doesn't cover), performance (loops over all photos with pcalls), maintainability concerns.

## Output format

Write a JSON object to `docs/implementation/structured-export-plugin/review.md` (yes, `.md` — but the contents are valid JSON wrapped in a fenced code block, plus a short prose preamble for human readability).

Structure:

```markdown
# Review — Structured Export Plugin

(One-paragraph human summary: overall verdict, headline issues.)

## Findings

```json
{
  "blocking": [
    {
      "id": "B1",
      "location": "tools/structured-export.lrplugin/Foo.lua:42",
      "description": "...",
      "suggestion": "..."
    }
  ],
  "non_blocking": [
    {
      "id": "N1",
      "location": "tools/structured-export.lrplugin/Bar.lua",
      "description": "...",
      "suggestion": "..."
    }
  ],
  "verify_results": {
    "busted_exit": <code>,
    "busted_specs": <count>,
    "luacheck_exit": <code>,
    "luacheck_warnings": <count>
  }
}
```
```

**`blocking`**: real bugs, spec violations, missing required behavior, broken builds.
**`non_blocking`**: nits, doc improvements, minor refactors, low-risk gaps.

Be specific — point to file:line where possible. Do not be polite to a fault; if something is wrong, say so. Equally, do not invent issues.

## What you don't need to verify
- Lightroom GUI behavior (no LR available here; that's Step 11 manual).
- exiftool runtime behavior (verified manually in Step 11).
- CI pipeline actually running on push (CI exists; whether GH Actions is happy is async).
