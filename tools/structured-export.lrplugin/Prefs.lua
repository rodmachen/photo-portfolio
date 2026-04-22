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
