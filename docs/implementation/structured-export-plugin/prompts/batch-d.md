# Batch D — Steps 5 + 6 + 7 + 8: Metadata, Collections, ExportDialog, Info

You are an implementation subagent in a multi-agent pipeline. Execute the work below directly — do not ask for confirmation.

## Working directory
`/Users/rodmachen/code/photo-portfolio`. On `feature/structured-export-plugin`. Batches A, B, C complete: `tools/structured-export.lrplugin/{Utils,Presets,Prefs}.lua` exist and have passing busted tests.

## Setup
```
export PATH="$HOME/.luarocks/bin:/opt/homebrew/opt/lua@5.4/bin:$PATH"
```

## Plan reference
`docs/plans/structured-export-plugin.md` Steps 5, 6, 7, 8. The plan is authoritative; this prompt summarizes.

This batch creates **four files in four commits, in order**: Step 5 → 6 → 7 → 8. After each step, verify locally and commit, then move to the next.

---

## Step 5 — `Metadata.lua` (TDD partial)

### Files
- `tools/structured-export.lrplugin/Metadata.lua`
- `tools/spec/metadata_spec.lua`

### Two concerns in one module:

**1. Pure builder** — `Metadata.buildExportSettings(prefs)` returns a sub-dict of `LR_*` keys that LR Classic understands natively:
```lua
{
  LR_embeddedMetadataOption = 'all',
  LR_metadata_copyright = prefs.copyright,
  LR_removeFaceMetadata = false,
  LR_removeLocationMetadata = false,
}
```
Testable under busted.

**2. exiftool post-process** — `Metadata.applyIptcFields(filePath, prefs)` shells out via `LrTasks.execute`. Resolve the binary by absolute path at module load via `Metadata._resolveExiftool()`, which probes (in order) `/opt/homebrew/bin/exiftool` → `/usr/local/bin/exiftool` → `/usr/bin/exiftool` → bare `exiftool`. Cache the first hit. **This lookup is required**: macOS GUI apps launch with a minimal PATH that does NOT include Homebrew, so bare `exiftool` fails from inside Lightroom even though it works in Terminal.

Command form:
```
<resolved-path> -overwrite_original -Copyright=... -By-line=... -Rights=... -Credit=... -ContactCiEmailWork=... -WebStatement=... <filePath>
```
Returns `ok, err`. If `_resolveExiftool()` finds nothing, log once per export session and return `ok=true` (graceful degrade).

### Shell escaping
Implement a local `shellEscape(s)` helper that wraps in single quotes and escapes any embedded single quote as `'\''`. Use it for every user-supplied string AND for the file path. Export the helper as `Metadata._shellEscape` so it's testable.

### Module load sequencing
At the top of the module, do a guarded `pcall(require, 'LrTasks')` so the file can be `require`d under busted (where LrTasks does not exist) without erroring. The exiftool runner can no-op or skip when `LrTasks` is unavailable, but the builder and the `shellEscape` helper must work in both contexts.

### Tests (`metadata_spec.lua`)
TDD for `buildExportSettings` and `_shellEscape`:
- `buildExportSettings` returns a table with all four expected keys; copyright comes from prefs.
- `_shellEscape("foo bar")` → `"'foo bar'"`.
- `_shellEscape("Rod's photo")` → `"'Rod'\\''s photo'"` (single quote properly escaped).
- `_shellEscape("")` → `"''"`.

Do NOT unit-test `applyIptcFields` — it requires a shell. Verified manually in Step 11.

### Verify
```
cd tools && busted spec/metadata_spec.lua
cd tools && busted   # all specs still pass
cd tools && luacheck structured-export.lrplugin/Metadata.lua spec/metadata_spec.lua
```

### Commit
```
Step 5: Metadata.lua with builder and exiftool post-process

- buildExportSettings(prefs): pure-table builder for LR_* metadata keys
- applyIptcFields(path, prefs): exiftool wrapper that resolves the
  binary by absolute path (macOS GUI PATH is minimal) and shell-
  escapes all user-supplied strings.
- TDD covers builder and shellEscape; runner is verified manually.

Step 5 of docs/plans/structured-export-plugin.md.
```

---

## Step 6 — `Collections.lua` (TDD)

### Files
- `tools/structured-export.lrplugin/Collections.lua`
- `tools/spec/collections_spec.lua`

### Module surface
`Collections.enumerate(selection)` — pure recursive walker. Takes a list of `LrCollection | LrCollectionSet` (or fake objects in tests) and returns a list of `{collection, pathSegments, photos}` records.

- `pathSegments` is an array of slugified names (using `Utils.slugify`) from the **root Set down to but excluding the Collection itself** — the Collection's own slug is the innermost folder, applied separately by the caller.
- A selection containing a Collection Set means: enumerate every descendant Collection of that Set.
- A selection containing a bare Collection means: that Collection becomes one entry with empty `pathSegments`.
- Empty selection returns empty list.

### Duck-typing protocol
Test fakes implement:
- `:type()` → `'LrCollection'` or `'LrCollectionSet'`
- `:getName()` → string
- `:getChildCollectionSets()` → list (sets only)
- `:getChildCollections()` → list (collections only)
- `:getPhotos()` → list (collections only)
- `:getParent()` → set or nil — used to walk back up if needed (you may not need this if you push pathSegments down during recursion)

Prefer pushing pathSegments down during recursion — cleaner and matches LR's own object API.

### Tests (`collections_spec.lua`)
Build small fake-object factories (use a local helper `function fakeCollection(name, photos)` etc.), then cover:
1. Single bare collection (no parent set): one entry, `pathSegments = {}`, `photos` matches input.
2. Collection inside a 1-level set: `pathSegments = {slug(setName)}`.
3. Collection inside a 3-level nested set: `pathSegments = {slug(root), slug(mid), slug(leaf-set)}`.
4. A set with mixed direct children (some sets, some collections): all leaf collections are enumerated.
5. Selection contains a top-level Set: expands to all descendant collections with full pathSegments.
6. Empty selection: empty list.
7. Mixed selection (a Set AND a bare Collection): both contribute entries.

### Verify
```
cd tools && busted spec/collections_spec.lua
cd tools && busted
cd tools && luacheck structured-export.lrplugin/Collections.lua spec/collections_spec.lua
```

### Commit
```
Step 6: Collections.lua recursive walker with tests

Pure walker over the LrCollection/LrCollectionSet protocol that
duck-types the LR objects so tests can supply fakes. Returns
{collection, pathSegments, photos} tuples for each leaf collection
in the selection.

Step 6 of docs/plans/structured-export-plugin.md.
```

---

## Step 7 — `ExportDialog.lua`

### Files
- `tools/structured-export.lrplugin/ExportDialog.lua`

### Module surface
`ExportDialog.run(activePhoto)` returns `{action = "export" | "cancel", values = {...}}` where `values` includes:
- `preset` (`"print" | "portfolio" | "web"`)
- `contentCredentials` (boolean)
- `copyright`, `creator`, `rights`, `webStatement`, `contactEmail` (strings)
- `remember` (boolean)

### UI shape (LrView)
Use `LrView.osFactory()` with a property table bound via `LrBinding.makePropertyTable(context)`. Layout:

```
[ ◉ print  ◯ portfolio  ◯ web ]    (radio_button column bound to 'preset')
[✓] Content Credentials             (checkbox bound to 'contentCredentials')
─────────────────────────────────
Copyright:     [ edit_field bound to 'copyright'    ]
Creator:       [ edit_field bound to 'creator'      ]
Rights:        [ edit_field bound to 'rights'       ]
Web statement: [ edit_field bound to 'webStatement' ]
Contact email: [ edit_field bound to 'contactEmail' ]
─────────────────────────────────
[✓] Remember these settings         (checkbox bound to 'remember')
```

Wrap the whole call in `LrFunctionContext.callWithContext('structuredExportDialog', function(context) ... end)`.

### Pre-fill priority (per Locked Decision #7 in the plan)
1. Start with `Prefs.load()`.
2. If `activePhoto` is non-nil and `activePhoto:getFormattedMetadata('copyright')` returns a non-empty string, **override** the copyright field with that.
3. Display fills via the property table.

### On OK with `remember == true`
Call `Prefs.save({copyright=..., creator=..., rights=..., webStatement=..., contactEmail=..., contentCredentials=...})`. Do NOT save `preset` (per spec defaults — only persist copyright fields and last-used preset; actually spec says "persist copyright fields and last-used preset", so yes do save preset too — re-check `docs/lightroom-export-spec.md` line ~33 and follow it).

### Module guards
`require('LrView')`, `require('LrBinding')`, `require('LrDialogs')`, `require('LrFunctionContext')` at the **top** of the module. The file is only ever loaded from `ExportTask.lua` inside Lightroom — no need to be busted-compatible. (No tests for this file.)

### Verify (no automated tests)
- `cd tools && luacheck structured-export.lrplugin/ExportDialog.lua` exits 0.
- The dialog will be exercised manually in Step 11.

If luacheck flags `LrView`/`LrBinding`/etc. as unknown, allow them in `tools/.luacheckrc` under `read_globals`.

### Commit
```
Step 7: ExportDialog.lua with LrView modal and prefs binding

Modal dialog with preset radio, Content Credentials toggle, five
editable copyright/IPTC fields, and a Remember checkbox. Pre-fills
from Prefs.load() with override from photo:getFormattedMetadata
('copyright') when present.

Step 7 of docs/plans/structured-export-plugin.md.
```

---

## Step 8 — `Info.lua`

### File
- `tools/structured-export.lrplugin/Info.lua`

### Module
Plain Lua return-table:

```lua
return {
  LrSdkVersion = 6.0,
  LrSdkMinimumVersion = 6.0,
  LrToolkitIdentifier = 'com.rodmachen.structured-export',
  LrPluginName = 'Structured Export',
  VERSION = { major = 0, minor = 1, revision = 0 },

  LrLibraryMenuItems = {
    {
      title = 'Structured Export',
      file = 'ExportTask.lua',
    },
  },
  LrExportMenuItems = {
    {
      title = 'Structured Export',
      file = 'ExportTask.lua',
    },
  },
}
```

### Verify
- `cd tools && luacheck structured-export.lrplugin/Info.lua` exits 0.
- `lua -e "local t = dofile('tools/structured-export.lrplugin/Info.lua'); assert(t.LrToolkitIdentifier)"` from repo root — confirms the file parses and returns a table.

### Commit
```
Step 8: Info.lua with SDK manifest and menu registration

Declares the plugin identifier, SDK version requirements, and
registers "Structured Export" under both File → Plug-in Extras
(library menu) and the export menu.

Step 8 of docs/plans/structured-export-plugin.md.
```

---

## Output

After all four steps complete, write `docs/implementation/structured-export-plugin/results/batch-d.json`:

```json
{
  "batch": "D",
  "steps_completed": [5, 6, 7, 8],
  "commits": ["<sha5>", "<sha6>", "<sha7>", "<sha8>"],
  "files_changed": [...],
  "verify": { "busted_exit": 0, "luacheck_exit": 0, "specs_count": <n> },
  "notes": "any deviations or interesting decisions",
  "assumptions": [...],
  "blockers": null
}
```

## Don't
- Don't push.
- Don't write Step 9 code (ExportTask.lua, ContentCredentials.lua) — that's Batch E with Opus.
- Don't change earlier modules unless necessary to make tests pass.
