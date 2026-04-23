# Batch C — Step 4: Prefs.lua

You are an implementation subagent in a multi-agent pipeline. Execute the work below directly — do not ask for confirmation.

## Working directory
`/Users/rodmachen/code/photo-portfolio`. On `feature/structured-export-plugin`. Batches A and B complete.

## Setup
```
export PATH="$HOME/.luarocks/bin:/opt/homebrew/opt/lua@5.4/bin:$PATH"
```

## Plan reference
`docs/plans/structured-export-plugin.md` Step 4.

## Files
- `tools/structured-export.lrplugin/Prefs.lua`
- `tools/spec/prefs_spec.lua`

## Module surface

```lua
-- Prefs.lua
local Prefs = {}
Prefs._prefsProvider = nil  -- test-injection seam

local function provider()
  if Prefs._prefsProvider then return Prefs._prefsProvider() end
  local LrPrefs = require('LrPrefs')
  return LrPrefs.prefsForPlugin()
end

function Prefs.getDefaults()
  local year = tostring(os.date('%Y'))
  return {
    copyright    = '© ' .. year .. ' Rod Machen. All rights reserved.',
    creator      = 'Rod Machen',
    rights       = 'No use without written permission. To license this image, contact mail@rodmachen.com',
    webStatement = 'https://rodmachen.com/licensing',
    contactEmail = 'mail@rodmachen.com',
    contentCredentials = true,
  }
end

function Prefs.load()
  local p = provider()
  local d = Prefs.getDefaults()
  return {
    copyright    = p.copyright    or d.copyright,
    creator      = p.creator      or d.creator,
    rights       = p.rights       or d.rights,
    webStatement = p.webStatement or d.webStatement,
    contactEmail = p.contactEmail or d.contactEmail,
    contentCredentials = (p.contentCredentials == nil) and d.contentCredentials or p.contentCredentials,
  }
end

function Prefs.save(values)
  local p = provider()
  for k, v in pairs(values) do p[k] = v end
end

return Prefs
```

Confirm exact default values against `docs/lightroom-export-spec.md`. The web statement URL and contact email come from the spec; if the spec specifies different defaults, use those.

## Tests

```lua
-- prefs_spec.lua
package.path = './structured-export.lrplugin/?.lua;' .. package.path
local Prefs = require('Prefs')

describe('Prefs', function()
  describe('getDefaults', function()
    it('returns expected defaults with current year embedded in copyright', function()
      local d = Prefs.getDefaults()
      assert.is_string(d.copyright)
      assert.truthy(d.copyright:find(tostring(os.date('%Y')), 1, true))
      assert.are.equal('Rod Machen', d.creator)
      assert.are.equal('mail@rodmachen.com', d.contactEmail)
      assert.is_true(d.contentCredentials)
    end)
  end)

  describe('load/save round trip', function()
    it('save then load returns saved values via injected provider', function()
      local fake = {}
      Prefs._prefsProvider = function() return fake end
      Prefs.save({ copyright = 'X', creator = 'Y' })
      local got = Prefs.load()
      assert.are.equal('X', got.copyright)
      assert.are.equal('Y', got.creator)
      -- Unset values fall through to defaults
      assert.are.equal('mail@rodmachen.com', got.contactEmail)
      Prefs._prefsProvider = nil
    end)
  end)
end)
```

## Verify
```
cd tools && busted spec/prefs_spec.lua
cd tools && busted    # all specs pass
cd tools && luacheck structured-export.lrplugin/Prefs.lua spec/prefs_spec.lua
```

If `luacheck` complains about `pairs`, `os`, or other Lua stdlib that are accidentally listed as missing, update `tools/.luacheckrc` to allow them — these are Lua standard, not Lightroom SDK.

## Commit
```
Step 4: Prefs.lua with defaults and LrPrefs adapter

Pure-table defaults (testable) plus thin LrPrefs.prefsForPlugin
adapter with an injection seam (Prefs._prefsProvider) so unit
tests can stub the provider without loading the SDK.

Step 4 of docs/plans/structured-export-plugin.md.
```

## Output

Write `docs/implementation/structured-export-plugin/results/batch-c.json`:

```json
{
  "batch": "C",
  "steps_completed": [4],
  "commits": ["<sha>"],
  "files_changed": [...],
  "verify": { "busted_exit": 0, "luacheck_exit": 0, "specs_count": <n> },
  "spec_defaults_match": true,
  "assumptions": [...],
  "blockers": null
}
```

## Don't
- Don't push.
- Don't import any LR SDK module at the top level — only inside `provider()`, so spec tests don't try to load it.
