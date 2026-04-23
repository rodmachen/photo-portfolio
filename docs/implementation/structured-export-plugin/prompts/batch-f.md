# Batch F — Step 10: README + logging audit

You are an implementation subagent. Execute directly — do not ask for confirmation.

## Working directory
`/Users/rodmachen/code/photo-portfolio`. On `feature/structured-export-plugin`. All implementation steps (0-9) complete.

## Setup
```
export PATH="$HOME/.luarocks/bin:/opt/homebrew/opt/lua@5.4/bin:$PATH"
```

## Plan reference
`docs/plans/structured-export-plugin.md` Step 10.

## Two concerns

### 1. Flesh out `tools/structured-export.lrplugin/README.md`

Replace the stub with a real README. Sections:

- **Overview** — one paragraph on what the plugin does.
- **Prerequisites**
  - Lightroom Classic ≥ 11 (core export); ≥ 13 for Content Credentials
  - `brew install exiftool` (resolved by absolute path at runtime; macOS GUI PATH is minimal, so a Terminal-only PATH does not help LR)
- **Install**
  ```
  ln -s "$(pwd)/tools/structured-export.lrplugin" \
        "$HOME/Library/Application Support/Adobe/Lightroom/Modules/structured-export.lrplugin"
  ```
  Then restart Lightroom Classic and confirm in Plug-in Manager.
- **Usage** — File → Plug-in Extras → Structured Export. Briefly describe the dialog and its toggles.
- **Keyboard shortcut** — Lightroom Classic SDK does not expose binding registration. Document how to assign one via macOS System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts (target Lightroom Classic, exact menu title `Structured Export`).
- **Manual test checklist** — copy verbatim from plan Step 11 (15 items).
- **Troubleshooting**
  - Where Lightroom writes the plugin log: `~/Documents/LrClassicLogs/StructuredExport.log` (or whatever location the LrLogger 'logfile' target uses; document the actual path).
  - exiftool not found: install via Homebrew; the plugin probes `/opt/homebrew/bin/exiftool` then `/usr/local/bin/exiftool` then `/usr/bin/exiftool`.
  - Content Credentials silently absent on older LR Classic versions (<13).
- **Dev**
  ```
  brew install lua@5.4 luarocks
  luarocks --lua-version=5.4 --lua-dir=/opt/homebrew/opt/lua@5.4 install --local busted luacheck
  export PATH="$HOME/.luarocks/bin:/opt/homebrew/opt/lua@5.4/bin:$PATH"
  cd tools && busted && luacheck .
  ```

### 2. Logging audit

Walk every `*.lua` file under `tools/structured-export.lrplugin/`. For each:

- Should use **one named logger**: `local logger = LrLogger('StructuredExport')` (or `import 'LrLogger'(...)` depending on whether the file is loaded in LR or busted).
- `logger:info(...)` for normal events: dialog opened, export started, photo rendered, summary.
- `logger:error(...)` for caught failures.
- Should NOT use raw `print(...)` for runtime logging (test-only `print` is OK).

Make any edits needed to standardize. Keep the diff small — only touch files that need it.

## Verification
```
cd tools && busted
cd tools && luacheck .
```

Re-read the README end to end. Does it cover install + manual test + troubleshooting? Is the path syntax correct?

## Commit
```
Step 10: README and logging audit

- Full plugin README with prereqs, install, usage, keyboard shortcut,
  manual test checklist, troubleshooting, and dev setup.
- Standardized LrLogger usage across all modules: one named logger,
  info for normal events, error for caught failures.

Step 10 of docs/plans/structured-export-plugin.md.
```

## Output

Write `docs/implementation/structured-export-plugin/results/batch-f.json`:

```json
{
  "batch": "F",
  "steps_completed": [10],
  "commits": ["<sha>"],
  "files_changed": [...],
  "verify": { "busted_exit": 0, "luacheck_exit": 0 },
  "logger_audit_changes": [...],
  "assumptions": [...],
  "blockers": null
}
```

## Don't
- Don't push.
- Don't add new functionality during the audit.
- Don't reformat code unnecessarily.
