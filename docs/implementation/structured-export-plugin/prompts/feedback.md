# Phase 5 — Sonnet feedback pass

You are an implementation subagent. The Opus reviewer just produced findings at `docs/implementation/structured-export-plugin/review.md`. Your job is to address them.

## Working directory
`/Users/rodmachen/code/photo-portfolio`. On `feature/structured-export-plugin`.

## Setup
```
export PATH="$HOME/.luarocks/bin:/opt/homebrew/opt/lua@5.4/bin:$PATH"
```

## Inputs
- `docs/implementation/structured-export-plugin/review.md` — review findings (blocking + non_blocking)
- All Lua files under `tools/structured-export.lrplugin/` and `tools/spec/`
- `docs/plans/structured-export-plugin.md` and `docs/lightroom-export-spec.md` for ground truth

## Task

1. **Address every `blocking` item.** No exceptions. If a "blocking" finding is genuinely wrong (the reviewer misread the code or the spec), document why in the report rather than making a change — but the bar for that is high. Default to fixing.

2. **Address `non_blocking` items with best judgment.** Apply the cheap, clear ones. Defer expensive or ambiguous ones with a written reason. Do NOT pad the diff with cosmetic changes that weren't called out.

3. **Run verification after every fix batch:**
   ```
   cd tools && busted
   cd tools && luacheck .
   ```
   If either fails, fix it before moving on.

4. **Commit each logical group of fixes separately.** Reference review IDs in the message:
   ```
   Review fixes: B1, B3, N2

   - B1: <one-line description>
   - B3: <one-line description>
   - N2: <one-line description>

   See docs/implementation/structured-export-plugin/review.md.
   ```

## Output

Write `docs/implementation/structured-export-plugin/feedback-report.md`:

```markdown
# Feedback report

## Summary
(One paragraph.)

## Addressed
- B1 — <fix description> — commit <sha>
- B2 — <fix description> — commit <sha>
- N1 — <fix description> — commit <sha>

## Deferred
- N3 — <reason for not addressing>

## New issues surfaced
(Anything you noticed while fixing that wasn't in the original review.)

## Verification
- busted: exit 0, N specs
- luacheck: exit 0, N warnings
```

## Don't
- Don't push.
- Don't refactor beyond what the review called out.
- Don't introduce new dependencies.
- Don't suppress test failures or lint warnings — fix the underlying issue.
