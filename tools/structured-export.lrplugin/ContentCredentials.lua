local LrLogger = import 'LrLogger'

local logger = LrLogger('StructuredExport')

local M = {}

-- Assigns Content Credentials on an LrExportSession settings table.
-- The canonical SDK key is uncertain across Lightroom Classic versions
-- (observed as LR_embedContentCredentials on 13+, LR_contentCredentials in
-- earlier leaks). Try the modern key first, fall back to the legacy key,
-- pcall-wrap both, and never surface an error to the user. There is no
-- clean SDK-level detection API; rely on Lightroom silently ignoring
-- unknown keys.
function M.apply(settings, enabled)
  if not enabled then return end

  local okModern = pcall(function()
    settings.LR_embedContentCredentials = true
  end)
  if not okModern then
    pcall(function()
      settings.LR_contentCredentials = true
    end)
  end

  logger:info('Content Credentials requested (SDK may silently ignore on older versions)')
end

return M
