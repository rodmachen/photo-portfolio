local script_dir = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') or './'
package.path = script_dir .. '../structured-export.lrplugin/?.lua;' .. package.path

local Metadata = require('Metadata')

describe("Metadata.buildExportSettings", function()
  it("returns a table with all four expected LR_ keys", function()
    local prefs = { copyright = '© 2025 Test' }
    local t = Metadata.buildExportSettings(prefs)
    assert.is_table(t)
    assert.equals('all', t.LR_embeddedMetadataOption)
    assert.equals('© 2025 Test', t.LR_metadata_copyright)
    assert.is_false(t.LR_removeFaceMetadata)
    assert.is_false(t.LR_removeLocationMetadata)
  end)

  it("propagates the copyright field from prefs", function()
    local prefs = { copyright = 'My Custom Copyright' }
    local t = Metadata.buildExportSettings(prefs)
    assert.equals('My Custom Copyright', t.LR_metadata_copyright)
  end)
end)

describe("Metadata._shellEscape", function()
  it("wraps a plain string in single quotes", function()
    assert.equals("'foo bar'", Metadata._shellEscape("foo bar"))
  end)

  it("escapes embedded single quotes", function()
    assert.equals("'Rod'\\''s photo'", Metadata._shellEscape("Rod's photo"))
  end)

  it("handles empty string", function()
    assert.equals("''", Metadata._shellEscape(""))
  end)

  it("handles string with no special characters", function()
    assert.equals("'hello'", Metadata._shellEscape("hello"))
  end)
end)
