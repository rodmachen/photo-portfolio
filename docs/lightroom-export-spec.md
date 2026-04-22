# Lightroom Classic Export Plugin — Claude Code Spec

## Overview

Build a Lightroom Classic plugin (Lua, using the Lightroom SDK) that exports photos from selected Collections to iCloud Drive, preserving Collection Set hierarchy as folder structure, with three export presets, full IPTC metadata embedding, and a Content Credentials toggle.

---

## Plugin Entry Point

The plugin should appear in **File → Plugin Extras** as **"Structured Export"**. It should also be triggerable via a keyboard shortcut if the SDK allows.

---

## Export Dialog

When triggered, show a modal dialog with:

1. **Preset selector** — radio buttons or dropdown:
   - `print`
   - `portfolio`
   - `web`

2. **Content Credentials toggle** — checkbox, default ON.

3. **Copyright fields** (pre-filled from stored prefs, editable):
   - Copyright string — default: `© {current_year} Rod Machen. All rights reserved.`
   - Creator name — default: `Rod Machen`
   - Rights usage terms — default: `No use without written permission. To license this image, contact mail@rodmachen.com`
   - Web statement URL — default: `https://rodmachen.com/licensing`
   - Contact email — default: `mail@rodmachen.com`

4. **"Remember these settings"** checkbox — persist copyright fields and last-used preset to `LrPrefs`.

5. **Export** and **Cancel** buttons.

---

## Collection Selection

- Export should operate on **all currently selected Collections** in the Collections panel.
- If a Collection Set is selected, export all Collections within it recursively.
- If no Collections are selected, show an error dialog: "Please select one or more Collections or Collection Sets before running Structured Export."

---

## Folder Structure

Root export path: `~/Library/Mobile Documents/com~apple~CloudDocs/Photos/`

> This is the iCloud Drive path on macOS. Use `LrPathUtils` to resolve the home directory dynamically.

Reproduce the full Collection Set hierarchy beneath the root. Example:

```
Photos/
  Sports/
    Tennis/
      atx-open-2025/
        print/
          atx-open-2025-7877.jpg
        portfolio/
          atx-open-2025-7877.jpg
        web/
          atx-open-2025-7877.jpg
```

Rules:
- Each Collection Set becomes a folder, named exactly as the Set name (lowercase, spaces preserved).
- The Collection name becomes the innermost folder (lowercase).
- The selected preset name (`print`, `portfolio`, `web`) becomes a subfolder inside the collection folder.
- Create all intermediate directories if they don't exist.

---

## File Naming

Format: `{collection-name}-{original-file-number}`

- `collection-name`: the Collection name, lowercased, spaces replaced with hyphens.
- `original-file-number`: the numeric sequence extracted from the original source filename.
  - Source filename is available via `photo:getFormattedMetadata('fileName')` or from the `preservedFileName` XMP field.
  - Extract trailing digits: e.g. `DSC_7877.NEF` → `7877`, `DSC_7877.DNG` → `7877`.
  - If extraction fails, fall back to Lightroom's built-in sequence number.

Example: Collection "ATX Open 2025", source file `DSC_7877.NEF` → `atx-open-2025-7877.jpg`

---

## Export Presets

### `print`
- Format: JPEG
- Quality: 80
- Resize: Long Edge — NO. **Short Edge** to 2400px
- Resolution: 300 DPI
- Color space: sRGB
- Sharpening: Standard, Screen

### `portfolio`
- Format: JPEG
- Quality: 70
- Resize: **Short Edge** to 2048px
- Resolution: 240 DPI
- Color space: sRGB
- Sharpening: Standard, Screen

### `web`
- Format: JPEG
- Quality: 70
- Resize: **Long Edge** to 1350px
- Resolution: 72 DPI
- Color space: sRGB
- Sharpening: Standard, Screen

> Note: Lightroom SDK export settings use `LrExportSettings`. For short-edge resizing, set `LR_size_doConstrain = true`, `LR_size_resizeType = "longEdge"` is NOT correct — use the appropriate SDK constant for short edge. Verify in the SDK docs: the correct key may be `LR_size_resizeType = "shortEdge"` or equivalent.

---

## IPTC / XMP Metadata Embedding

Apply the following to every exported file using export post-processing or `LrExportSession` metadata settings:

| Field | SDK Key | Value source |
|---|---|---|
| Copyright | `LR_copyrightInfoUrl` / IPTC Copyright | Dialog input |
| Creator / Artist | `LR_creator` | Dialog input |
| Rights | `LR_rights` | Dialog input |
| Web Statement | `LR_copyrightState` + XMP `xmpRights:WebStatement` | Dialog input |
| Credit Line | IPTC Credit | Creator name |
| Contact Email | IPTC Contact | Dialog input |

Also ensure:
- `LR_embeddedMetadataOption = "all"` — embed all metadata on export.
- Do NOT strip metadata on export.

If the photo already has a copyright string in the catalog, use it as the default pre-fill but still allow override in the dialog.

---

## Content Credentials

If the Content Credentials toggle is ON:

- Set `LR_contentCredentials = true` in export settings (available in Lightroom Classic 13+).
- This attaches Adobe's Content Authenticity Initiative (CAI) provenance data to the exported file.
- If the SDK version does not support this key, catch the error silently and log a warning to the Lightroom log: `"Content Credentials not supported in this version of Lightroom Classic."` Do not surface an error to the user.

---

## File Collision Handling

Before beginning any export, scan all destination paths for the full batch and collect every file that already exists on disk.

If no collisions are found, proceed immediately with no prompt.

If collisions are found, show a pre-export dialog:

> **X files already exist at the destination.**
> How would you like to handle them?
>
> `Overwrite All` — Replace existing files silently.
> `Skip Existing` — Export only new files; leave existing files untouched.
> `Cancel` — Abort the export.

Rules:
- The collision check must cover all three preset subfolders (`print`, `portfolio`, `web`) for the selected preset being exported, not all presets at once.
- Log all skipped files by filename to the Lightroom log.
- The summary dialog on completion should reflect the choice: e.g. `"Export complete. 42 exported, 8 skipped (already existed), 0 errors."`

---

## Progress & Error Handling

- Show a Lightroom-native progress bar during export (`LrProgressScope`).
- If an individual photo fails to export, log the filename and error, skip it, and continue — do not abort the entire batch.
- On completion, show a summary dialog: `"Export complete. X photos exported to [path]. Y errors."` with an option to open the output folder in Finder.

---

## Plugin File Structure

```
structured-export.lrplugin/
  Info.lua          -- plugin metadata, SDK version, menu registration
  ExportDialog.lua  -- dialog UI using LrView
  ExportTask.lua    -- core export logic, folder creation, file naming
  Metadata.lua      -- IPTC/XMP embedding helpers
  Prefs.lua         -- LrPrefs read/write for persisted settings
  Utils.lua         -- path helpers, filename parsing
```

---

## Installation Instructions (include in plugin README)

1. Copy `structured-export.lrplugin` to:
   `~/Library/Application Support/Adobe/Lightroom/Modules/`
2. Restart Lightroom Classic.
3. Confirm the plugin is active: **File → Plug-in Manager** → "Structured Export" should show as enabled.
4. Trigger via **File → Plug-in Extras → Structured Export**.

---

## Adobe Portfolio — Site Footer

Every page of the portfolio should carry a footer with the following elements:

**Left side:**
`© {year} Rod Machen. All rights reserved.`

**Right side (or center on mobile):**
Two links:
- `Licensing` → `/licensing` (or the equivalent page in Adobe Portfolio)
- `Contact` → `mail@rodmachen.com` as a `mailto:` link, or the built-in Adobe Portfolio Contact page if enabled

**Implementation note for Adobe Portfolio:**
Adobe Portfolio doesn't offer full custom HTML footers natively. The closest options are:
- Use the **Footer Text** field in Site Settings → General to add the copyright line
- Add a bottom content block on each page with a text element for the links
- If using a theme that supports custom CSS/HTML blocks, inject a proper footer div there

The copyright year should be updated annually. Consider appending the founding year if the portfolio predates the current year: `© 2024–2025 Rod Machen`.

---

## Licensing Page

Create a page at `/licensing` (titled "Licensing" in the nav, or linked from the footer only if you prefer it out of the main nav).

**Recommended content structure:**

---

### Copyright & Licensing

All photographs on this site are © Rod Machen. All rights reserved.

My images may not be downloaded, reproduced, printed, copied, or distributed in any form without prior written permission.

#### What's not permitted without a license
- Editorial use in publications, blogs, or news outlets
- Commercial use in advertising, marketing, or products
- Print reproduction of any kind
- Posting or sharing on social media without credit and prior approval

#### Licensing & permissions

If you'd like to license an image for editorial, commercial, or personal use, I'd love to hear from you.

**Email:** mail@rodmachen.com

Please include in your inquiry:
- Which image(s) you're interested in
- Intended use (editorial, commercial, personal print, etc.)
- Publication or platform
- Desired usage period

#### Attribution & credit

When permission is granted, credit should read: **© Rod Machen / rodmachen.com**

---

**Implementation notes:**
- This page should be linked from the footer on every page of the portfolio
- The URL `https://rodmachen.com/licensing` is what gets embedded in the XMP Web Statement field of every exported image, so this page must exist and be publicly accessible before images are published
- Keep the page simple and scannable — most visitors will be checking whether they can use an image, not reading carefully

---

## SDK References

- Lightroom Classic SDK documentation: `/Applications/Adobe Lightroom Classic/SDK/`
- Key modules: `LrExportSession`, `LrDialogs`, `LrView`, `LrPrefs`, `LrPathUtils`, `LrProgressScope`, `LrTasks`, `LrFileSystemEntry`
- Minimum SDK version: 6.0 (Lightroom Classic CC)