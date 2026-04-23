# Structured Export — Lightroom Classic Plugin

## Overview

Structured Export is a Lightroom Classic plugin that exports selected photos to a structured folder tree in up to three preset sizes (print, portfolio, web). It mirrors your Collection Set hierarchy as lowercase-hyphenated folder names, enforces consistent filenames derived from the source camera file number, and embeds full IPTC copyright metadata via exiftool. Pick any combination of presets from a single dialog invocation — each selected preset runs sequentially against the same selection.

## Prerequisites

- **Lightroom Classic ≥ 11** for core export functionality (SDK 6.0 minimum).
- **Lightroom Classic ≥ 13** for Content Credentials support. On older versions the CC toggle is accepted without error but has no effect; the plugin log records the attempt.
- **exiftool** for extended IPTC fields (Credit, Contact Email, Rights, WebStatement). Install via Homebrew:

  ```sh
  brew install exiftool
  ```

  The plugin resolves exiftool by absolute path at runtime — a Terminal `PATH` is not sufficient because macOS launches GUI apps with a minimal `PATH` (`/usr/bin:/bin:/usr/sbin:/sbin`) that does not include Homebrew.

## Install

Run from the repo root:

```sh
ln -s "$(pwd)/tools/structured-export.lrplugin" \
      "$HOME/Library/Application Support/Adobe/Lightroom/Modules/structured-export.lrplugin"
```

Then restart Lightroom Classic and open **File → Plug-in Manager**. Confirm "Structured Export" appears with status "Installed and running."

## Usage

1. In the Library module, select one or more Collections or Collection Sets in the left panel.
2. Go to **File → Plug-in Extras → Structured Export**.
3. Configure the dialog:
   - **Destination** — the folder where files will be exported. Pre-fills with the iCloud Pictures path by default; click **Browse** to choose a different folder. With Remember enabled, the chosen path persists across sessions.
   - **Export Presets** — three checkboxes: `print` (short-edge 2400 px / 300 DPI), `portfolio` (short-edge 2048 px / 240 DPI), `web` (long-edge 1350 px / 72 DPI). Pick any combination; each selected preset runs sequentially against the same selection. At least one must be checked; on a no-preset OK click the dialog shows a warning and treats the click as cancel. When multiple presets are selected, the collision pre-scan runs once across all of them — one prompt, one choice that applies uniformly.
   - **Copyright / Creator / Rights / Web statement / Contact email** — IPTC fields applied to every exported file. Pre-filled from saved preferences; Copyright overrides with the active photo's catalog value when present.
   - **Remember these settings** — persists current values for the next invocation.
4. Click **OK** to begin. A progress bar appears; **Cancel** aborts mid-batch cleanly.
5. On completion a summary reports exported / skipped / error counts. Click **Reveal in Finder** to open the chosen Destination root.

Exported files land at:

```
<Destination>/<set-slug>/.../<collection-slug>/<preset>/<slug>-<num>.jpg
```

Folder and filename segments are uniformly lowercase with spaces and underscores converted to hyphens.

## Keyboard shortcut

The Lightroom Classic SDK does not expose keybinding registration for plugin menu items. Assign one via macOS:

1. Open **System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts**.
2. Click **+**, set Application to **Adobe Lightroom Classic**, and set Menu Title to exactly:

   ```
   Structured Export
   ```

3. Assign the desired key combination.

The shortcut fires the item registered under **File → Plug-in Extras**.

## Manual test checklist

These 14 items must all pass before a release is considered complete.

1. Plug-in Manager shows "Structured Export" as enabled, no Info.lua errors.
2. `File → Plug-in Extras → Structured Export` opens the dialog; all five text fields pre-filled per spec defaults.
3. "Remember these settings" round-trips across a Lightroom restart.
4. Launching with no collection selected → error dialog with the exact message in the spec.
5. Single un-nested collection → files land at `<Destination>/<slug(collection)>/<preset>/…`.
6. Collection Set nested ≥2 deep → path segments are lowercase + hyphenated (per Locked Decision #4).
7. All three presets produce files at spec-correct dimensions — verify with `exiftool -ImageWidth -ImageHeight -XResolution` on a sample file each. Print short-edge 2400 / 300 DPI; Portfolio short-edge 2048 / 240 DPI; Web long-edge 1350 / 72 DPI.
8. Filename extraction: `DSC_7877.NEF` → `{slug}-7877.jpg`; non-matching filename falls back to Lightroom sequence number.
9. Collision scan: second run of same (collection, preset) surfaces the Overwrite/Skip/Cancel prompt. Each choice behaves per spec; summary counts match. With two or more presets selected and collisions in each, the prompt fires once; the chosen strategy applies uniformly to all preset folders.
10. IPTC fields present in output (`exiftool` check, in one line): `Copyright`, `By-line`, `Rights`, `Credit`, `CreatorWorkEmail` set to `mail@rodmachen.com`, `WebStatement` set to the licensing URL.
11. Progress bar visible mid-export; "Cancel" button stops the run cleanly.
12. A deliberately broken photo (e.g., a file with a missing source) logs an error, skips, and does not abort the batch.
13. Summary dialog's "Reveal in Finder" opens the chosen Destination root.
14. With `exiftool` removed from PATH: plugin runs, logs warning once, exports succeed but lack the extra IPTC fields.

## Troubleshooting

**Plugin log location**

Lightroom writes the plugin log (via `LrLogger` `logfile` target) to:

```
~/Documents/LrClassicLogs/StructuredExport.log
```

Tail it in Terminal while exporting:

```sh
tail -f ~/Documents/LrClassicLogs/StructuredExport.log
```

**exiftool not found**

The plugin probes in this order:

1. `/opt/homebrew/bin/exiftool`
2. `/usr/local/bin/exiftool`
3. `/usr/bin/exiftool`

Install via Homebrew to satisfy probe #1:

```sh
brew install exiftool
```

When exiftool is missing the plugin logs one warning per session and continues — copyright and creator are still embedded natively by Lightroom, but the additional IPTC fields (Credit, Contact Email, Rights, WebStatement) are skipped.

**Content Credentials (deferred)**

Content Credentials support has been removed from the UI as of v0.2.0. Adobe has not exposed CC in Lightroom Classic's native export dialog, so the v1 checkbox had no visible effect. CC revival is a known follow-up — see `ContentCredentials.lua` for the re-enablement instructions.

## Dev

Install dependencies:

```sh
brew install lua@5.4 luarocks
luarocks --lua-version=5.4 --lua-dir=/opt/homebrew/opt/lua@5.4 install --local busted luacheck
export PATH="$HOME/.luarocks/bin:/opt/homebrew/opt/lua@5.4/bin:$PATH"
```

Run tests and linter from `tools/`:

```sh
cd tools && busted
cd tools && luacheck .
```
