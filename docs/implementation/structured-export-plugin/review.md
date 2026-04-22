# Review — Structured Export Plugin

Overall the implementation tracks the plan and spec closely. The Lua modules cleanly separate pure logic from SDK-dependent surface, the busted harness is in place with 88 passing specs and 0 luacheck warnings, and the orchestration flow in `ExportTask.lua` correctly handles async wrapping, progress scoping, collision pre-scan, overwrite-via-delete+move, per-photo error isolation, and the Reveal-in-Finder summary. Two real bugs stand out: **(1) `Prefs.lua` silently drops `preset` on load, so "last-used preset" never round-trips** despite being explicitly listed in spec line 33 and stored by `ExportDialog.save`, and **(2) `Collections.enumerate` only recognizes the string `'LrCollectionSet'`, so a selected `LrPublishedCollectionSet` (accepted upstream by `filterSelection`) will fall into the bare-collection branch and crash when `:getPhotos()` is invoked on it**. Everything else is polish: the Content Credentials fallback is effectively dead code (pcall around a plain table assignment cannot fail), a leaked `/dev/null` handle in the exiftool probe, minor UX gaps in `LrDialogs.message` calls, and some thin test coverage gaps. No shell-injection, no security concerns, and the escaping in `Metadata.shellEscape` is correct.

## Findings

```json
{
  "blocking": [
    {
      "id": "B1",
      "location": "tools/structured-export.lrplugin/Prefs.lua:22-33",
      "description": "Prefs.load() does not read or return the `preset` key, so the last-used preset never round-trips. ExportDialog saves it on 'Remember' (ExportDialog.lua:112), but on the next invocation Prefs.load() omits it and the dialog falls back to `savedPrefs.preset or 'print'` — which is always 'print'. Spec line 33 and Locked Decision #7 both require the last-used preset to persist. The Batch D run log in docs/implementation/structured-export-plugin/context.md flagged this as 'fine since Prefs.save() will persist it for next load' — that reasoning is incorrect because load() never reads it back.",
      "suggestion": "Add `preset = (p.preset or d.preset)` in Prefs.load() and a `preset = 'print'` default in Prefs.getDefaults(). Add a prefs_spec test that Prefs.save({preset='web'}); Prefs.load().preset == 'web'."
    },
    {
      "id": "B2",
      "location": "tools/structured-export.lrplugin/Collections.lua:37-46",
      "description": "Collections.enumerate only branches on `item:type() == 'LrCollectionSet'`. ExportTask.filterSelection (ExportTask.lua:40-46) also lets `LrPublishedCollection` and `LrPublishedCollectionSet` through. A selected Published Collection Set falls into the else branch, is treated as a bare collection, and `item:getPhotos()` will raise because Published Collection Sets do not expose that method. Either filterSelection is too permissive or Collections.enumerate is too strict — the two modules disagree.",
      "suggestion": "Tighten by treating any value whose `:type()` ends in 'CollectionSet' as a set (`type:match('CollectionSet$')`), or explicitly list 'LrPublishedCollectionSet' alongside 'LrCollectionSet'. Add a collections_spec test with a fake `LrPublishedCollectionSet` to cover it."
    }
  ],
  "non_blocking": [
    {
      "id": "N1",
      "location": "tools/structured-export.lrplugin/ContentCredentials.lua:17-24",
      "description": "The pcall-wrapped fallback from LR_embedContentCredentials to LR_contentCredentials is dead code. Setting a key on a plain Lua table never errors, so pcall always returns true and the legacy-key branch never runs. On an older SDK that wants the legacy key, CC will never be enabled. The plan explicitly called for 'try modern key first, fall back to legacy'.",
      "suggestion": "Either set both keys unconditionally (belt and suspenders, since Lightroom silently ignores unknown keys — which is already the detection strategy), or drop the fallback block and the comment. Setting both is safer and matches the 'SDK silently ignoring' model the plan relies on."
    },
    {
      "id": "N2",
      "location": "tools/structured-export.lrplugin/Metadata.lua:18-32",
      "description": "resolveExiftool opens `/dev/null` during the bare-'exiftool' iteration and never closes the handle (`f` is assigned but only closed on the `path ~= 'exiftool' and f` branch). Minor fd leak on probe — only triggered if the first three absolute paths miss.",
      "suggestion": "Close `f` in the elseif branch, or skip the io.open entirely for the 'exiftool' case. Simpler: use `os.execute('test -x ' .. path)` for the three absolute paths and drop the io.open approach."
    },
    {
      "id": "N3",
      "location": "tools/structured-export.lrplugin/ExportTask.lua:206",
      "description": "LrDialogs.message(NO_SELECTION_MSG) passes the message as the title argument with no body. The spec (line 43) gives the exact error text verbatim, but LrDialogs.message's first arg is displayed as the title — the user sees a modal titled with the full sentence, no body. Technically still shows the message but reads poorly.",
      "suggestion": "Use `LrDialogs.message('Structured Export', NO_SELECTION_MSG, 'warning')` or the three-arg `messageWithDoNotShow` variant. Same nit for ExportTask.lua:228 ('The selected collections contain no photos')."
    },
    {
      "id": "N4",
      "location": "tools/structured-export.lrplugin/ExportTask.lua:279-286",
      "description": "Plan Step 9 item 10 specifies LrDialogs.messageWithDoNotShow for the summary; implementation uses LrDialogs.confirm with 'Reveal in Finder'/'OK'. Functionally equivalent and arguably better UX (user gets the Reveal button directly), but diverges from plan.",
      "suggestion": "Either update the plan to reflect the chosen approach or switch to messageWithDoNotShow + a follow-up revealInShell prompt. Low-stakes."
    },
    {
      "id": "N5",
      "location": "tools/spec/prefs_spec.lua:1",
      "description": "prefs_spec.lua uses its own package.path line (`./structured-export.lrplugin/?.lua`) instead of the spec_helper.lua pattern used by the other specs (which anchor via debug.getinfo). Works from `tools/` but is inconsistent — a future reorg breaks this file first.",
      "suggestion": "Replace line 1 with `require('spec_helper')` or the debug.getinfo anchor used in utils_spec/metadata_spec/collections_spec."
    },
    {
      "id": "N6",
      "location": "tools/spec/prefs_spec.lua",
      "description": "prefs_spec only has 2 test cases. It covers defaults shape and a load/save round-trip on copyright+creator, but it doesn't verify the contentCredentials round-trip (including the nil-vs-false distinction in Prefs.lua:31) or the (missing) preset field. Given that contentCredentials has special nil-handling and preset has the B1 bug, tests would have caught both.",
      "suggestion": "Add tests: (a) Prefs.save({contentCredentials=false}) round-trips as false (not falling back to default=true); (b) Prefs.save({preset='web'}).preset == 'web' after load."
    },
    {
      "id": "N7",
      "location": "tools/structured-export.lrplugin/Utils.lua:20-25",
      "description": "extractFileNumber extracts the first underscore-prefixed digit run, not 'trailing digits before the extension' as the spec phrases it. For the documented examples (DSC_7877.NEF, IMG_0001.DNG) the results are identical, but filenames like 'photo_2024_0042.jpg' would yield '2024' rather than '0042' — probably not what a user means. Context.md flags this as a subagent decision; worth calling out so Rod knows the behavior if he ever drops in unusually-named source files.",
      "suggestion": "No code change required; add a comment and a test case asserting the chosen behavior so it is explicit rather than implicit. Alternatively switch to the spec's literal interpretation (`(%d+)[^%d]*$` against the basename), which would return '0042' for the multi-underscore case."
    },
    {
      "id": "N8",
      "location": "tools/structured-export.lrplugin/ExportTask.lua:240-247",
      "description": "Collision confirm dialog uses 'Overwrite All' as actionVerb (primary button). A mis-click on the primary button irreversibly overwrites files. The spec leaves button order unspecified — it just lists the three options — but 'Overwrite' as the default action is a sharp edge.",
      "suggestion": "Consider swapping so 'Skip Existing' is the primary (actionVerb), 'Overwrite All' is the 'other' verb. Low priority; a matter of taste."
    },
    {
      "id": "N9",
      "location": "tools/structured-export.lrplugin/ExportTask.lua:1-10 vs ExportDialog.lua:1-6",
      "description": "Style inconsistency: ExportTask uses `import 'LrX'`; ExportDialog uses `import('LrX')`. Both valid Lua; just jars when reading adjacent files.",
      "suggestion": "Pick one (project-wide). The rest of the bundle (ContentCredentials.lua) uses `import 'LrX'`, so standardize on that."
    },
    {
      "id": "N10",
      "location": "tools/structured-export.lrplugin/Metadata.lua:64-65",
      "description": "The early-return when LrTasks is unavailable (`if not ok or not LrTasks then return true, nil end`) means applyIptcFields returns ok in non-LR environments. That's desired for busted tests that never call it, but it also means if LrTasks fails to load at plugin startup inside LR itself (unlikely, but possible on an SDK mismatch), the plugin silently skips IPTC application with no log. Consider logging that case explicitly.",
      "suggestion": "Add `if logger then logger:error('LrTasks unavailable; IPTC fields skipped') end` before the return. Low risk of triggering but a dead-silent degrade is harder to debug than a logged one."
    }
  ],
  "verify_results": {
    "busted_exit": 0,
    "busted_specs": 88,
    "luacheck_exit": 0,
    "luacheck_warnings": 0
  }
}
```
