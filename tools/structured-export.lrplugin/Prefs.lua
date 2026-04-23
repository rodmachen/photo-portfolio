local Prefs = {}
Prefs._prefsProvider = nil  -- test-injection seam
Prefs._pathUtils     = nil  -- test-injection seam

local function provider()
  if Prefs._prefsProvider then return Prefs._prefsProvider() end
  local LrPrefs = import 'LrPrefs'
  return LrPrefs.prefsForPlugin()
end

local function pathUtils()
  if Prefs._pathUtils then return Prefs._pathUtils() end
  return import 'LrPathUtils'
end

function Prefs.getDefaults()
  local year = tostring(os.date('%Y'))
  local pu = pathUtils()
  local exportRoot = pu.getStandardFilePath('home') ..
    '/Library/Mobile Documents/com~apple~CloudDocs/iCloud Pictures'
  return {
    copyright    = '© ' .. year .. ' Rod Machen. All rights reserved.',
    creator      = 'Rod Machen',
    rights       = 'No use without written permission. To license this image, contact mail@rodmachen.com',
    webStatement = 'https://rodmachen.com/licensing',
    contactEmail = 'mail@rodmachen.com',
    exportRoot         = exportRoot,
    presetPrint        = true,
    presetPortfolio    = false,
    presetWeb          = false,
    remember           = false,
  }
end

-- `p.key or d.key` swallows a legitimate false value, so use an explicit
-- nil-check helper for boolean fields whose default may be false.
local function coalesce(v, default)
  if v == nil then return default end
  return v
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
    exportRoot         = p.exportRoot or d.exportRoot,
    presetPrint        = coalesce(p.presetPrint, d.presetPrint),
    presetPortfolio    = coalesce(p.presetPortfolio, d.presetPortfolio),
    presetWeb          = coalesce(p.presetWeb, d.presetWeb),
    remember           = coalesce(p.remember, d.remember),
  }
end

function Prefs.save(values)
  local p = provider()
  -- pairs skips nil values — save({ key = nil }) is a no-op, not a reset.
  for k, v in pairs(values) do p[k] = v end
end

return Prefs
