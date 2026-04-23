local script_dir = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') or './'
package.path = script_dir .. '../structured-export.lrplugin/?.lua;' .. package.path

local Prefs = require('Prefs')

describe('Prefs', function()
  describe('getDefaults', function()
    it('returns expected defaults with current year embedded in copyright', function()
      local d = Prefs.getDefaults()
      assert.is_string(d.copyright)
      assert.truthy(d.copyright:find(tostring(os.date('%Y')), 1, true))
      assert.are.equal('Rod Machen', d.creator)
      assert.are.equal('No use without written permission. To license this image, contact mail@rodmachen.com', d.rights)
      assert.are.equal('https://rodmachen.com/licensing', d.webStatement)
      assert.are.equal('mail@rodmachen.com', d.contactEmail)
      assert.are.equal('print', d.preset)
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

    it('preset round-trips correctly', function()
      local fake = {}
      Prefs._prefsProvider = function() return fake end
      Prefs.save({ preset = 'web' })
      local got = Prefs.load()
      assert.are.equal('web', got.preset)
      Prefs._prefsProvider = nil
    end)

    it('remember round-trips both true and false (default is false)', function()
      local fake = {}
      Prefs._prefsProvider = function() return fake end
      assert.is_false(Prefs.load().remember)
      Prefs.save({ remember = true })
      assert.is_true(Prefs.load().remember)
      Prefs.save({ remember = false })
      assert.is_false(Prefs.load().remember)
      Prefs._prefsProvider = nil
    end)
  end)
end)
