local LrLogger = import 'LrLogger'

local logger = LrLogger('StructuredExport')

local M = {}

-- Assigns Content Credentials on an LrExportSession settings table.
-- SDK key varies by Lightroom Classic version: LR_embedContentCredentials on
-- 13+, LR_contentCredentials on earlier builds. Set both; Lightroom silently
-- ignores unknown keys, so belt-and-suspenders is safe.
function M.apply(settings, enabled)
  if not enabled then return end
  settings.LR_embedContentCredentials = true
  settings.LR_contentCredentials = true
  logger:info('Content Credentials requested (SDK may silently ignore on older versions)')
end

return M
