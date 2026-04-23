-- DORMANT as of v0.2.0 — Adobe has not exposed Content Credentials in
-- Lightroom Classic's native export dialog. The v1 checkbox sent best-guess
-- SDK keys (LR_embedContentCredentials / LR_contentCredentials) to no visible
-- effect; no CC manifest was generated. To revive:
--   1. Restore `contentCredentials` default (true) in Prefs.getDefaults and Prefs.load.
--   2. Re-add the checkbox row in ExportDialog.lua and pre-fill props.contentCredentials.
--   3. Re-add `local CC = require 'ContentCredentials'` and the CC.apply call in
--      ExportTask.lua buildSettings().
-- Module body below is unchanged.

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
