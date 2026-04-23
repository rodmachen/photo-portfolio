# Batch B — Steps 2 + 3: Utils.lua + Presets.lua (TDD)

You are an implementation subagent in a multi-agent pipeline. Execute the work below directly — do not ask for confirmation.

## Working directory
`/Users/rodmachen/code/photo-portfolio`. Currently on branch `feature/structured-export-plugin`. Batch A scaffolding (`tools/structured-export.lrplugin/`, `tools/spec/`, busted/luacheck config, CI) is in place.

## Setup
Before running tests:
```
export PATH="$HOME/.luarocks/bin:/opt/homebrew/opt/lua@5.4/bin:$PATH"
```

## Plan reference
Read `docs/plans/structured-export-plugin.md` Steps 2 and 3 for the authoritative spec. This prompt summarizes; if there is any conflict, the plan wins.

---

## Step 2 — `Utils.lua` (TDD)

### Files
- `tools/structured-export.lrplugin/Utils.lua`
- `tools/spec/utils_spec.lua`

### Module surface
Pure functions, **zero SDK imports**. Module returns a table:

- `slugify(s)` — lowercase; spaces and underscores → hyphens; strip punctuation except hyphens; collapse runs of hyphens; trim leading/trailing hyphens. Examples:
  - `"ATX Open 2025"` → `"atx-open-2025"`
  - `"Pet Photos / 2024"` → `"pet-photos-2024"`
  - `"  Wedding!! Edits  "` → `"wedding-edits"`
  - `"foo___bar"` → `"foo-bar"`
- `extractFileNumber(filename)` — trailing digits before the extension. Examples:
  - `"DSC_7877.NEF"` → `"7877"`
  - `"IMG_0001-Edit.DNG"` → `"0001"` (strip the `-Edit` suffix; the digits we want are the original numeric tail of the prefix-and-number block, **before** any non-digit trailing tokens). NB: read the spec carefully — Lightroom edits often produce names like `IMG_0001-Edit-2.DNG`; the function returns the digit run from the original filename's prefix-with-digits group (e.g., `0001`), not the trailing `2`. If the spec is silent on which digit run wins, prefer the **first** prefixed digit run (i.e., grouped after `DSC_`, `IMG_`, `_MG_`, etc.). Make the test cases explicit so the choice is documented.
  - `"untitled.jpg"` → `nil`
  - `"123.NEF"` → `"123"`
  - `""` → `nil`
- `joinPath(...)` — OS-agnostic path join. Wrap `LrPathUtils.child` if available, else `table.concat({...}, "/")` for unit-test environments. Use `pcall(require, 'LrPathUtils')`. (Under busted, the require will fail and the fallback runs.)
- `buildCollectionFilename(collectionName, fileNumber, fallbackSeq)` — returns `slugify(collectionName) .. "-" .. (fileNumber or fallbackSeq) .. ".jpg"`.

### Tests (`utils_spec.lua`)
Use busted style. Cover at minimum:
- `slugify`: empty string, plain string, spaces, underscores, mixed punctuation, runs of separators, leading/trailing whitespace, accented characters (decide whether to strip; document choice in a comment in the spec — ASCII-only stripping is fine).
- `extractFileNumber`: each of the example cases above; numeric-only filename; filename without an extension (e.g., `DSC_7877`); multi-extension (`photo.tar.gz` — return digits only if a clear digit run exists before the final extension).
- `joinPath`: 2 args, 3 args, trailing slashes ignored; single-arg returns the arg.
- `buildCollectionFilename`: with `fileNumber`, with `fallbackSeq`, with collection name needing slugification.

### Verify
```
cd tools && busted spec/utils_spec.lua   # all green
cd tools && luacheck structured-export.lrplugin/Utils.lua spec/utils_spec.lua
```

### Commit
```
Step 2: Utils.lua with slugify, extractFileNumber, path helpers

Pure-logic helpers used by the rest of the plugin. TDD; tests cover
edge cases for slug stripping, file-number extraction, path joining,
and filename building.

Step 2 of docs/plans/structured-export-plugin.md.
```

---

## Step 3 — `Presets.lua` (TDD)

### Files
- `tools/structured-export.lrplugin/Presets.lua`
- `tools/spec/presets_spec.lua`

### Module surface
Returns a table keyed by `"print" | "portfolio" | "web"`. Each value is the **exact** LrExportSession settings dict — these constants are the single biggest risk in the plugin.

#### `print`
- `LR_format = "JPEG"`
- `LR_jpeg_quality = 0.8`
- `LR_size_doConstrain = true`
- `LR_size_resizeType = "wh"` ← short edge equivalent (see SDK note below)
- `LR_size_maxHeight = 2400`
- `LR_size_maxWidth = 2400`
- `LR_size_units = "pixels"`
- `LR_size_resolution = 300`
- `LR_size_resolutionUnits = "inch"`
- `LR_export_colorSpace = "sRGB"`
- `LR_outputSharpeningOn = true`
- `LR_outputSharpeningLevel = 2`
- `LR_outputSharpeningMedia = "screen"`

#### `portfolio`
Same shape as print but: `LR_size_maxHeight=2048`, `LR_size_maxWidth=2048`, `LR_size_resolution=240`, `LR_jpeg_quality=0.7`.

#### `web`
Same shape but: `LR_size_resizeType` = the long-edge equivalent (see SDK note), `LR_size_maxHeight=1350`, `LR_size_maxWidth=1350`, `LR_size_resolution=72`, `LR_jpeg_quality=0.7`.

### **SDK constant verification (do this BEFORE writing values)**
The plan's draft uses `"shortEdge"` / `"longEdge"` for `LR_size_resizeType`, but the actual Lightroom SDK uses different identifiers (commonly `"wh"`, `"longEdge"`, etc.). **Read the SDK reference** to pick the correct strings:

1. Check if `/Applications/Adobe Lightroom Classic/SDK/` exists locally. If so, read `Manual/ExportSDK.pdf` (use a brief grep) or `API Reference/index.html` for the `LR_size_resizeType` enum values and sharpening constants.
2. If the SDK is **not** installed at that path (likely in this CI-style environment), fall back to the well-documented community values, which are:
   - `LR_size_resizeType` valid values include `"wh"` (constrain by width AND height — used for short-edge style), `"longEdge"`, `"shortEdge"`, `"dimensions"`, `"percentage"`, `"megapixels"`. Recent SDK versions (≥9.0) accept `"longEdge"` and `"shortEdge"` directly. Use `"shortEdge"` for print/portfolio and `"longEdge"` for web — and **document in a comment** above the table that this requires LR Classic SDK 9.0+ (which is well below the 13.0 LR ≥13 minimum).
   - `LR_outputSharpeningLevel` valid values: 1=Low, 2=Standard, 3=High.
   - `LR_outputSharpeningMedia` valid values: `"screen"`, `"matte"`, `"glossy"`.

If the SDK reference disagrees with anything above, **trust the SDK**, update the table, and note the change in the results JSON.

### Tests (`presets_spec.lua`)
Use busted. Cover:
- All three keys (`print`, `portfolio`, `web`) exist.
- Each preset has every required key with the expected value (one assertion per field).
- All three share `LR_format = "JPEG"`, `LR_export_colorSpace = "sRGB"`, `LR_size_doConstrain = true`.
- `print.LR_size_maxHeight == 2400`, `portfolio.LR_size_maxHeight == 2048`, `web.LR_size_maxHeight == 1350`.

### Verify
```
cd tools && busted spec/presets_spec.lua
cd tools && luacheck structured-export.lrplugin/Presets.lua spec/presets_spec.lua
cd tools && busted   # all specs (utils + presets) still pass
```

### Commit
```
Step 3: Presets.lua with print/portfolio/web export settings

LrExportSession setting tables for each preset. Constants verified
against [SDK reference / fallback documented values — note which].
TDD asserts every required key on every preset.

Step 3 of docs/plans/structured-export-plugin.md.
```

---

## Output

Write `docs/implementation/structured-export-plugin/results/batch-b.json`:

```json
{
  "batch": "B",
  "steps_completed": [2, 3],
  "commits": ["<sha2>", "<sha3>"],
  "files_changed": [...],
  "verify": {
    "busted_exit": 0,
    "luacheck_exit": 0,
    "specs_count": <number>
  },
  "sdk_resize_type_source": "SDK doc | community fallback",
  "assumptions": [...],
  "blockers": null
}
```

## Don't
- Don't push or open PRs.
- Don't modify scaffold files from Batch A unless luacheckrc needs adjustment for new code.
- Don't write the plugin orchestration code (that's Batch E).
