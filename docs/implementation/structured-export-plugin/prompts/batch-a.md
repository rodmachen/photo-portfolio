# Batch A — Steps 0 + 1: Repo bootstrap + scaffold + CI

You are an implementation subagent in a multi-agent pipeline. Execute the work below directly — do not ask for confirmation.

## Working directory
`/Users/rodmachen/code/photo-portfolio` (already a git repo, currently on `main`, clean tree, has remote `origin` → `git@github.com:rodmachen/photo-portfolio.git`).

## Context you should know
- The full plan lives at `docs/plans/make-a-plan-using-sleepy-whale.md` — read it for the authoritative spec, especially the "Target File Structure" and "Step 0/1" sections.
- The initial commit `f6b259d` already exists. `.gitignore` already contains `.claude/settings.local.json`.
- Local testing tools are installed: `busted` 2.3.0 and `luacheck` 1.2.0 against Lua 5.4. Before running them, **export PATH**: `export PATH="$HOME/.luarocks/bin:/opt/homebrew/opt/lua@5.4/bin:$PATH"`. CI must target Lua 5.4 too.

## Step 0 — Repo bootstrap (adapted)

The plan's Step 0 says to do an initial commit too, but it is already done. So Step 0 collapses to:

1. `git mv docs/plans/make-a-plan-using-sleepy-whale.md docs/plans/structured-export-plugin.md`
2. `git checkout -b feature/structured-export-plugin`
3. Commit the rename on the feature branch with message: `Step 0: rename plan file to structured-export-plugin.md`
4. **Update the in-file references**: the plan file mentions its own old filename in lines like `git mv docs/plans/make-a-plan-using-sleepy-whale.md ...` — leave those literal command examples alone (they document history). But also fix any other reference inside the plan file that points to the old filename (none expected — verify).

**Verify**: `git branch --show-current` returns `feature/structured-export-plugin`; `ls docs/plans/structured-export-plugin.md` succeeds; `ls docs/plans/make-a-plan-using-sleepy-whale.md` fails.

## Step 1 — Scaffold + busted harness + CI workflow

Create exactly these files:

### `tools/structured-export.lrplugin/README.md` (stub)

One-paragraph placeholder. Real README is filled out in Step 10. Something like:

```
# Structured Export — Lightroom Classic Plugin

One-invocation export from Lightroom Classic to a structured iCloud folder
tree across three preset sizes (print, portfolio, web), with full IPTC
metadata. See `docs/plans/structured-export-plugin.md` and
`docs/lightroom-export-spec.md` for the full design. Install instructions are
filled out in Step 10.
```

### `tools/spec/spec_helper.lua`

Sets `package.path` so `require("Utils")` etc. find the modules in the sibling `structured-export.lrplugin/` directory. Example pattern (adjust as needed):

```lua
local lfs = require('lfs')
local script_dir = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') or './'
package.path = script_dir .. '../structured-export.lrplugin/?.lua;' .. package.path
```

If `lfs` (luafilesystem) ends up unused, drop the require.

### `tools/.busted`

Tell busted where to find specs. Lua return-table form, e.g.:

```lua
return {
  default = {
    ROOT = {'spec'},
    helper = 'spec/spec_helper.lua',
    pattern = '_spec%.lua$',
  },
}
```

### `tools/.luacheckrc`

Allow Lightroom SDK globals so luacheck doesn't complain. Include at minimum: `import`, `_PLUGIN`, `LOC`, plus a stub for the `LR*` namespace that gets accessed as `import 'LrFoo'`. Example:

```lua
std = 'lua54'
globals = { 'import', '_PLUGIN', 'LOC', 'pairs', 'ipairs' }
read_globals = {
  -- LR SDK globals if any are referenced as globals; most arrive via `import`
}
exclude_files = { '.luarocks/' }
ignore = {
  '212', -- unused argument (LR callbacks)
}
```

### `.github/workflows/lua-tests.yml`

GitHub Actions workflow that runs `busted` and `luacheck` on push and pull_request to `main`/`feature/**`. Use `leafo/gh-actions-lua@v10` and `leafo/gh-actions-luarocks@v4`, target **Lua 5.4** (the working version locally). Example:

```yaml
name: Lua tests
on:
  push:
    branches: [main, 'feature/**']
  pull_request:
    branches: [main]
jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: tools
    steps:
      - uses: actions/checkout@v4
      - uses: leafo/gh-actions-lua@v10
        with:
          luaVersion: '5.4'
      - uses: leafo/gh-actions-luarocks@v4
      - run: luarocks install busted
      - run: luarocks install luacheck
      - run: luacheck .
      - run: busted
```

### `.gitignore` additions

Append `*.luac` and `tools/.luarocks/` (in case a local rock tree gets created in the project). Keep `.claude/settings.local.json` (already there).

## Verification

Run from the repo root:

```
export PATH="$HOME/.luarocks/bin:/opt/homebrew/opt/lua@5.4/bin:$PATH"
cd tools && busted   # must exit 0 with 0 specs found
cd tools && luacheck .   # must exit 0
cd ..
git status   # should show staged scaffold files only
```

If `busted` complains about `lfs` not being found, remove the `lfs` require from `spec_helper.lua` (busted ships with a fallback for the directory walk we don't actually need yet).

## Commit message

```
Step 1: scaffold plugin bundle, busted harness, CI workflow

- tools/structured-export.lrplugin/ bundle root with stub README
- tools/spec/ busted test directory with spec_helper
- tools/.busted, tools/.luacheckrc
- .github/workflows/lua-tests.yml targeting Lua 5.4
- .gitignore updates

Step 1 of docs/plans/structured-export-plugin.md.
```

## Output

When done, write a JSON object to `docs/implementation/structured-export-plugin/results/batch-a.json` with this shape:

```json
{
  "batch": "A",
  "steps_completed": [0, 1],
  "commits": ["<sha1>", "<sha2>"],
  "files_changed": ["..."],
  "verify": {
    "busted_exit": 0,
    "luacheck_exit": 0,
    "branch": "feature/structured-export-plugin"
  },
  "assumptions": ["..."],
  "blockers": null
}
```

If anything is unclear or fails, do your best to resolve it (e.g., adjust luacheckrc if luacheck flags something) and record what you did in `assumptions`. Only fill `blockers` if you genuinely cannot proceed.

## Don't

- Don't push to remote (orchestrator will handle that after the batch).
- Don't open a PR (orchestrator will).
- Don't modify files outside the scaffold spec above.
- Don't commit `tools/.luarocks/` or any installed rocks.
