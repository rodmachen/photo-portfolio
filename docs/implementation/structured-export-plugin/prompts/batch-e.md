# Batch E — Step 9: ExportTask.lua + ContentCredentials.lua (Opus)

You are the implementation subagent for the highest-risk step in the plan. Execute directly — do not ask for confirmation.

## Working directory
`/Users/rodmachen/code/photo-portfolio`. On `feature/structured-export-plugin`. Batches A-D complete: Utils, Presets, Prefs, Metadata, Collections, ExportDialog, Info all in place with passing tests.

## Setup
```
export PATH="$HOME/.luarocks/bin:/opt/homebrew/opt/lua@5.4/bin:$PATH"
```

## Why Opus / high effort
The plan flags this step as the largest risk surface:
- (a) Ambiguous: collision dialog shape, Content Credentials key name, LrExportSession custom-filename wiring.
- (b) Unfamiliar SDK internals: LrExportSession rendition loop, LrProgressScope cancellation.
- (c) Compounding-mistake risk: a single wrong key causes silent no-ops or wrong-sized output.
- (d) Hard-to-verify: only fully testable in Lightroom against real collections.

Take your time. Read the spec and plan carefully. Where the SDK is ambiguous, follow the plan's Locked Decisions exactly.

## Plan reference
`docs/plans/structured-export-plugin.md` Step 9 (and the entire "Locked Decisions" section).
`docs/lightroom-export-spec.md` for end-to-end behavior.

## Files

### `tools/structured-export.lrplugin/ContentCredentials.lua`

Wraps the SDK key assignment in `pcall`. The exact key name is uncertain across SDK versions — try `LR_embedContentCredentials` first, fall back to `LR_contentCredentials`, log on failure, **never** surface to user.

```lua
local logger = require('LrLogger')('StructuredExport')

local M = {}

function M.apply(settings, enabled)
  if not enabled then return end
  -- Try the modern key first, then fall back to legacy.
  local ok = pcall(function() settings.LR_embedContentCredentials = true end)
  if not ok then
    pcall(function() settings.LR_contentCredentials = true end)
  end
  -- We have no clean way to know whether the key was actually accepted by
  -- the runtime; log informationally either way.
  logger:info('Content Credentials requested (SDK may silently ignore on older versions)')
end

return M
```

If a cleaner detection mechanism exists in the SDK docs you can find, use it.

### `tools/structured-export.lrplugin/ExportTask.lua`

Main flow. Run inside `LrTasks.startAsyncTask`. **Top-level structure**:

```lua
local LrApplication      = import 'LrApplication'
local LrTasks            = import 'LrTasks'
local LrDialogs          = import 'LrDialogs'
local LrPathUtils        = import 'LrPathUtils'
local LrFileUtils        = import 'LrFileUtils'
local LrFunctionContext  = import 'LrFunctionContext'
local LrExportSession    = import 'LrExportSession'
local LrProgressScope    = import 'LrProgressScope'
local LrShell            = import 'LrShell'
local LrLogger           = import 'LrLogger'

local Utils       = require 'Utils'
local Presets     = require 'Presets'
local Prefs       = require 'Prefs'
local Metadata    = require 'Metadata'
local Collections = require 'Collections'
local ExportDialog = require 'ExportDialog'
local CC           = require 'ContentCredentials'

local logger = LrLogger('StructuredExport')
logger:enable('logfile')

LrTasks.startAsyncTask(function()
  -- ... main flow
end)
```

### Main flow (numbered to match plan Step 9)

1. **Resolve catalog & selection.** `LrApplication.activeCatalog()`, then `catalog:getActiveSources()`. Filter to `LrCollection`/`LrCollectionSet`. If empty, `LrDialogs.message('Please select one or more Collections or Collection Sets before running Structured Export.')` and return. (Match the spec's exact wording in line ~43.)

2. **Show dialog.** Find the most-recently-selected photo via `catalog:getTargetPhoto()` (may be nil). Call `ExportDialog.run(activePhoto)`. If `result.action == 'cancel'`, return.

3. **Enumerate.** `local entries = Collections.enumerate(selection)`. If empty (selection had only empty sets), show a message and return.

4. **Compute destination paths.** Root: `LrPathUtils.expandPath('~/Library/Mobile Documents/com~apple~CloudDocs/Photos')`. For each entry, the per-collection root is `root/<pathSegments...>/<slug(collection.name)>/<preset>/`. For each photo in `entry.photos`, the filename is `Utils.buildCollectionFilename(collection.name, Utils.extractFileNumber(photo:getFormattedMetadata('fileName')), <fallback sequence>)`. Track all `(photo, destPath)` pairs in a list.

5. **Pre-scan collisions.** Use `LrFileUtils.exists(path)` per dest. If any collisions, present `LrDialogs.confirm`:
   - Message: `"X files already exist at the destination. How would you like to handle them?"`
   - Buttons: primary = `Overwrite All`, secondary = `Skip Existing`, cancel = `Cancel`.
   - On `cancel` → return; on `Skip Existing` → filter the photo list to only non-existing dests; on `Overwrite All` → keep all and proceed.

6. **Build per-preset settings.** Start with `Presets[result.values.preset]`, merge in `Metadata.buildExportSettings(result.values)`. Add:
   - `LR_export_destinationType = 'specificFolder'`
   - `LR_export_destinationPathPrefix = <per-collection-folder-up-to-but-not-including-the-filename>`
   - `LR_useSubfolder = false`
   - `LR_renamingTokensOn = true`
   - `LR_tokens = 'custom'`
   - `LR_tokenCustomString = '{{custom_text}}'`  *(the per-photo filename injection mechanism — see custom filename note below)*

   **Custom filename note**: LR's renaming-tokens system does not directly support per-photo custom strings inside one ExportSession. The cleanest reliable pattern is **one ExportSession per (collection, photo)** — heavyweight but deterministic. A lighter alternative: one ExportSession per collection, using `LR_initialSequenceNumber` + a fixed naming token, then rename the rendered file in a post-loop. **Pick one** and document the choice in a comment. The plan implies one ExportSession per (collection, preset) pair — to make that work with custom per-photo filenames, render the export with whatever name LR chooses, then `LrFileUtils.move(renderedPath, computedDestPath)` after the rendition. That approach is robust; use it.

7. **Apply Content Credentials** if `result.values.contentCredentials` is true: `CC.apply(settings, true)`.

8. **Loop over (collection, preset) groups.** For each, create one `LrExportSession{ photosToExport = group.photos, exportSettings = settings }`. Wrap with `LrProgressScope{ title = 'Structured Export', functionContext = context }` (pass `context` from the outer `callWithContext`). Iterate `for _, rendition in session:renditions() do local ok, pathOrErr = rendition:waitForRender() ...`.

9. **Per-rendered photo**:
   - If `ok`, `LrFileUtils.move(pathOrErr, computedDest)` (or `LrFileUtils.copy` then delete, depending on what works), then `Metadata.applyIptcFields(computedDest, result.values)`. Increment exported count.
   - If `not ok`, `logger:error('Render failed for ' .. tostring(rendition.photo) .. ': ' .. tostring(pathOrErr))`, increment error count, continue. Do not abort.

10. **Summary dialog.** `LrDialogs.messageWithDoNotShow{ message = 'Export complete.', info = 'X exported, Y skipped, Z errors.', actionPrefKey = nil }`. Add a "Reveal in Finder" button via `LrDialogs.confirm` flow (or after the message), calling `LrShell.revealInShell(rootPath)`.

### Error handling
- Wrap the whole top-level body in `LrFunctionContext.callWithContext` so the progress scope cleans up.
- `pcall` each `applyIptcFields` call so an exiftool failure on one photo never aborts the batch.
- Log every non-trivial event via `logger:info` / `logger:error`.

## Verification

This step has no automated tests (orchestration is not unit-testable). Verify:
```
cd tools && busted   # all pre-existing specs still pass
cd tools && luacheck structured-export.lrplugin/ExportTask.lua structured-export.lrplugin/ContentCredentials.lua
lua -e "package.path='./tools/structured-export.lrplugin/?.lua;'..package.path; assert(loadfile('tools/structured-export.lrplugin/ContentCredentials.lua'))"
```
The Lua-level load check catches syntax errors. End-to-end verification happens in the Step 11 manual checklist (Rod runs in Lightroom).

If luacheck flags `import`, `LrApplication`, `LrTasks`, etc. as unknown globals, add them to `tools/.luacheckrc` `read_globals` rather than suppressing the warnings.

## Commit
```
Step 9: ExportTask.lua orchestration + ContentCredentials module

Main async export flow: catalog access → dialog → collision pre-scan
with Overwrite/Skip/Cancel → LrExportSession per (collection, preset)
→ post-rendition file move to computed dest path → exiftool IPTC
post-process → summary dialog with Reveal in Finder.

ContentCredentials.apply pcall-wraps the SDK key assignment, trying
the modern key first and the legacy key as fallback, logging either
way. Never surfaces SDK-version errors to the user.

Step 9 of docs/plans/structured-export-plugin.md.
```

## Output

Write `docs/implementation/structured-export-plugin/results/batch-e.json`:

```json
{
  "batch": "E",
  "steps_completed": [9],
  "commits": ["<sha>"],
  "files_changed": [...],
  "verify": { "busted_exit": 0, "luacheck_exit": 0 },
  "notes": "describe the per-photo filename strategy chosen, any SDK assumptions, etc.",
  "assumptions": [...],
  "blockers": null
}
```

## Don't
- Don't push.
- Don't change non-Step-9 modules unless a bug surfaces (e.g., a Utils helper signature you need adjusted).
- Don't write a manual Lightroom test driver — that's Step 11, Rod-driven.
