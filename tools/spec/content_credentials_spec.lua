local script_dir = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') or './'
package.path = script_dir .. '../structured-export.lrplugin/?.lua;' .. package.path

-- Stub the `import` global so ContentCredentials can load LrLogger without LR runtime.
_G.import = function(name)
  if name == 'LrLogger' then
    return setmetatable({}, {
      __call = function() return { info = function() end } end,
    })
  end
  return {}
end

local CC = require('ContentCredentials')

describe("ContentCredentials.apply", function()
  it("sets both SDK keys when enabled", function()
    local settings = {}
    CC.apply(settings, true)
    assert.is_true(settings.LR_embedContentCredentials)
    assert.is_true(settings.LR_contentCredentials)
  end)

  it("does not mutate settings when disabled", function()
    local settings = {}
    CC.apply(settings, false)
    assert.is_nil(settings.LR_embedContentCredentials)
    assert.is_nil(settings.LR_contentCredentials)
  end)

  it("does not mutate settings when enabled is nil", function()
    local settings = {}
    CC.apply(settings, nil)
    assert.is_nil(settings.LR_embedContentCredentials)
    assert.is_nil(settings.LR_contentCredentials)
  end)
end)
