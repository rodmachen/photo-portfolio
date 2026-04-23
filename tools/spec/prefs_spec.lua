local script_dir = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') or './'
package.path = script_dir .. '../structured-export.lrplugin/?.lua;' .. package.path

local Prefs = require('Prefs')

describe('Prefs', function()
  describe('getDefaults', function()
    before_each(function()
      Prefs._pathUtils = function()
        return { getStandardFilePath = function() return '/Users/testuser' end }
      end
    end)
    after_each(function()
      Prefs._pathUtils = nil
    end)

    it('returns expected defaults with current year embedded in copyright', function()
      local d = Prefs.getDefaults()
      assert.is_string(d.copyright)
      assert.truthy(d.copyright:find(tostring(os.date('%Y')), 1, true))
      assert.are.equal('Rod Machen', d.creator)
      assert.are.equal('No use without written permission. To license this image, contact mail@rodmachen.com', d.rights)
      assert.are.equal('https://rodmachen.com/licensing', d.webStatement)
      assert.are.equal('mail@rodmachen.com', d.contactEmail)
    end)

    it('preset booleans default to print-only', function()
      local d = Prefs.getDefaults()
      assert.is_true(d.presetPrint)
      assert.is_false(d.presetPortfolio)
      assert.is_false(d.presetWeb)
      assert.is_nil(d.preset)
    end)

    it('exportRoot default is non-empty and ends with iCloud Pictures', function()
      local d = Prefs.getDefaults()
      assert.is_string(d.exportRoot)
      assert.truthy(d.exportRoot ~= '')
      assert.truthy(d.exportRoot:find('iCloud Pictures', 1, true))
    end)
  end)

  describe('load/save round trip', function()
    before_each(function()
      Prefs._pathUtils = function()
        return { getStandardFilePath = function() return '/Users/testuser' end }
      end
    end)
    after_each(function()
      Prefs._pathUtils = nil
    end)

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

    it('preset booleans round-trip true and false independently', function()
      local fake = {}
      Prefs._prefsProvider = function() return fake end
      local got = Prefs.load()
      assert.is_true(got.presetPrint)
      assert.is_false(got.presetPortfolio)
      assert.is_false(got.presetWeb)

      Prefs.save({ presetPrint = false, presetPortfolio = true, presetWeb = true })
      got = Prefs.load()
      assert.is_false(got.presetPrint)
      assert.is_true(got.presetPortfolio)
      assert.is_true(got.presetWeb)

      Prefs.save({ presetPrint = true, presetPortfolio = false, presetWeb = false })
      got = Prefs.load()
      assert.is_true(got.presetPrint)
      assert.is_false(got.presetPortfolio)
      assert.is_false(got.presetWeb)
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

    it('exportRoot falls through to default when not saved, overrides when saved', function()
      local fake = {}
      Prefs._prefsProvider = function() return fake end
      local got = Prefs.load()
      assert.is_string(got.exportRoot)
      assert.truthy(got.exportRoot:find('iCloud Pictures', 1, true))
      Prefs.save({ exportRoot = '/tmp/test-export' })
      got = Prefs.load()
      assert.are.equal('/tmp/test-export', got.exportRoot)
      Prefs._prefsProvider = nil
    end)
  end)
end)
