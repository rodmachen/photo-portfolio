local LrApplication      = import 'LrApplication'
local LrTasks            = import 'LrTasks'
local LrDialogs          = import 'LrDialogs'
local LrPathUtils        = import 'LrPathUtils'
local LrFileUtils        = import 'LrFileUtils'
local LrFunctionContext  = import 'LrFunctionContext'
local LrExportSession    = import 'LrExportSession'
local LrProgressScope    = import 'LrProgressScope'
local LrShell            = import 'LrShell'
local LrLogger           = import 'LrLogger'

local Utils        = require 'Utils'
local Presets      = require 'Presets'
local Metadata     = require 'Metadata'
local Collections  = require 'Collections'
local ExportDialog = require 'ExportDialog'
local CC           = require 'ContentCredentials'

local logger = LrLogger('StructuredExport')
logger:enable('logfile')

local ROOT = LrPathUtils.expandPath('~/Library/Mobile Documents/com~apple~CloudDocs/Photos')

local NO_SELECTION_MSG =
  'Please select one or more Collections or Collection Sets before running Structured Export.'

-- Custom filename strategy:
-- Lightroom's renaming tokens do not support a per-photo custom string from
-- inside a single LrExportSession. The plan's chosen approach (documented in
-- docs/plans/structured-export-plugin.md Step 9) is one ExportSession per
-- collection, letting Lightroom render each file with its default name, then
-- LrFileUtils.move-ing the rendered file to the computed destination name
-- during the rendition loop. Deterministic and robust.

local function filterSelection(sources)
  local out = {}
  if not sources then return out end
  for _, src in ipairs(sources) do
    local okType, t = pcall(function() return src:type() end)
    if okType and (t == 'LrCollection' or t == 'LrCollectionSet'
                   or t == 'LrPublishedCollection'
                   or t == 'LrPublishedCollectionSet') then
      out[#out + 1] = src
    end
  end
  return out
end

local function collectionDir(entry)
  local segments = entry.pathSegments or {}
  local collectionSlug = Utils.slugify(entry.collection:getName())
  local dir = ROOT
  for _, seg in ipairs(segments) do
    dir = LrPathUtils.child(dir, seg)
  end
  dir = LrPathUtils.child(dir, collectionSlug)
  return dir
end

-- Builds a list of export jobs keyed per-collection-preset. Each entry:
-- { entry = <collections.enumerate row>, dir = <abs dir>, photos = {photo,...},
--   dests = { [photo] = <abs file path> } }
local function buildJobs(entries, preset, fallbackSeqStart)
  local jobs = {}
  local seq = fallbackSeqStart or 1
  for _, entry in ipairs(entries) do
    local baseDir = LrPathUtils.child(collectionDir(entry), preset)
    local job = { entry = entry, dir = baseDir, photos = {}, dests = {} }
    local collectionName = entry.collection:getName()
    for _, photo in ipairs(entry.photos) do
      local srcName = photo:getFormattedMetadata('fileName') or ''
      local fileNum = Utils.extractFileNumber(srcName)
      local filename = Utils.buildCollectionFilename(
        collectionName, fileNum, string.format('%05d', seq)
      )
      seq = seq + 1
      local dest = LrPathUtils.child(baseDir, filename)
      job.photos[#job.photos + 1] = photo
      job.dests[photo] = dest
    end
    jobs[#jobs + 1] = job
  end
  return jobs
end

local function countCollisions(jobs)
  local existing = {}
  for _, job in ipairs(jobs) do
    for _, photo in ipairs(job.photos) do
      local dest = job.dests[photo]
      if LrFileUtils.exists(dest) then
        existing[#existing + 1] = dest
      end
    end
  end
  return existing
end

-- Removes photos whose dest already exists; returns removed count and a
-- jobs list with only new photos.
local function filterSkipExisting(jobs)
  local skipped = 0
  local filtered = {}
  for _, job in ipairs(jobs) do
    local kept = { entry = job.entry, dir = job.dir, photos = {}, dests = {} }
    for _, photo in ipairs(job.photos) do
      local dest = job.dests[photo]
      if LrFileUtils.exists(dest) then
        skipped = skipped + 1
        logger:info('Skipping (already exists): ' .. tostring(dest))
      else
        kept.photos[#kept.photos + 1] = photo
        kept.dests[photo] = dest
      end
    end
    if #kept.photos > 0 then
      filtered[#filtered + 1] = kept
    end
  end
  return filtered, skipped
end

local function buildSettings(preset, values)
  local settings = {}
  for k, v in pairs(Presets[preset] or {}) do settings[k] = v end
  for k, v in pairs(Metadata.buildExportSettings(values)) do
    settings[k] = v
  end
  settings.LR_export_destinationType = 'specificFolder'
  settings.LR_useSubfolder = false
  settings.LR_renamingTokensOn = false
  CC.apply(settings, values.contentCredentials)
  return settings
end

local function runJob(job, preset, values, counts, context)
  LrFileUtils.createAllDirectories(job.dir)
  local settings = buildSettings(preset, values)
  settings.LR_export_destinationPathPrefix = job.dir

  local session = LrExportSession {
    photosToExport = job.photos,
    exportSettings = settings,
  }

  local progress = LrProgressScope {
    title = string.format('Structured Export: %s',
                          job.entry.collection:getName()),
    functionContext = context,
  }
  progress:setCancelable(true)

  local total = #job.photos
  local done = 0

  for _, rendition in session:renditions() do
    if progress:isCanceled() then
      logger:info('Export canceled by user')
      break
    end

    local ok, pathOrErr = rendition:waitForRender()
    if ok then
      local dest = job.dests[rendition.photo]
      local moveOk, moveErr = true, nil
      if pathOrErr ~= dest then
        -- Overwrite: remove any existing file at dest first, since
        -- LrFileUtils.move does not overwrite.
        if LrFileUtils.exists(dest) then
          pcall(function() LrFileUtils.delete(dest) end)
        end
        moveOk, moveErr = LrFileUtils.move(pathOrErr, dest)
      end
      if moveOk then
        local iptcOk, iptcErr = pcall(Metadata.applyIptcFields, dest, values)
        if not iptcOk then
          logger:error('applyIptcFields raised: ' .. tostring(iptcErr))
        end
        counts.exported = counts.exported + 1
      else
        logger:error(string.format(
          'Failed to move %s -> %s: %s',
          tostring(pathOrErr), tostring(dest), tostring(moveErr)))
        counts.errors = counts.errors + 1
      end
    else
      logger:error('Render failed for ' ..
        tostring(rendition.photo and rendition.photo.localIdentifier or '?') ..
        ': ' .. tostring(pathOrErr))
      counts.errors = counts.errors + 1
    end

    done = done + 1
    progress:setPortionComplete(done, total)
  end

  progress:done()
end

LrTasks.startAsyncTask(function()
  LrFunctionContext.callWithContext('StructuredExportTask', function(context)
    local catalog = LrApplication.activeCatalog()

    local selection = filterSelection(catalog:getActiveSources())
    if #selection == 0 then
      LrDialogs.message('Structured Export', NO_SELECTION_MSG, 'warning')
      return
    end

    local activePhoto = catalog:getTargetPhoto()
    local dialogResult = ExportDialog.run(activePhoto)
    if dialogResult.action ~= 'export' then
      return
    end

    local values = dialogResult.values
    local preset = values.preset

    local entries = Collections.enumerate(selection)
    -- Keep only entries that have at least one photo.
    local nonEmpty = {}
    for _, e in ipairs(entries) do
      if e.photos and #e.photos > 0 then
        nonEmpty[#nonEmpty + 1] = e
      end
    end
    if #nonEmpty == 0 then
      LrDialogs.message(
        'Structured Export', 'The selected collections contain no photos.', 'warning')
      return
    end

    local jobs = buildJobs(nonEmpty, preset, 1)

    local counts = { exported = 0, skipped = 0, errors = 0 }

    -- Pre-scan collisions.
    local collisions = countCollisions(jobs)
    if #collisions > 0 then
      local choice = LrDialogs.confirm(
        string.format(
          '%d files already exist at the destination. How would you like to handle them?',
          #collisions),
        nil,
        'Overwrite All',
        'Cancel',
        'Skip Existing')
      if choice == 'cancel' then
        return
      elseif choice == 'other' then
        local filteredJobs, skippedCount = filterSkipExisting(jobs)
        jobs = filteredJobs
        counts.skipped = skippedCount
        if #jobs == 0 then
          LrDialogs.message(
            'All selected files already exist. Nothing to export.',
            string.format('%d skipped.', counts.skipped))
          return
        end
      end
      -- 'ok' = Overwrite All: keep jobs unchanged; moves handle overwrite.
    end

    for _, job in ipairs(jobs) do
      local jobOk, jobErr = pcall(runJob, job, preset, values, counts, context)
      if not jobOk then
        logger:error('Job failed for collection ' ..
          tostring(job.entry.collection:getName()) ..
          ': ' .. tostring(jobErr))
        counts.errors = counts.errors + 1
      end
    end

    local summary = string.format(
      '%d exported, %d skipped, %d errors.',
      counts.exported, counts.skipped, counts.errors)
    logger:info('Export complete. ' .. summary)

    local action = LrDialogs.confirm(
      'Export complete.',
      summary,
      'Reveal in Finder',
      'OK')
    if action == 'ok' then
      LrShell.revealInShell(ROOT)
    end
  end)
end)
