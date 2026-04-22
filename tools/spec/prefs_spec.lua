package.path = './structured-export.lrplugin/?.lua;' .. package.path
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
