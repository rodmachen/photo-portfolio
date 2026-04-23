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
local logger = LrLogger('StructuredExport')
logger:enable('logfile')

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

local function collectionDir(entry, root)
  local segments = entry.pathSegments or {}
  local collectionSlug = Utils.slugify(entry.collection:getName())
  local dir = root
  for _, seg in ipairs(segments) do
    dir = LrPathUtils.child(dir, seg)
  end
  dir = LrPathUtils.child(dir, collectionSlug)
  return dir
end

-- Builds a list of export jobs keyed per-collection-preset. Each entry:
-- { entry = <collections.enumerate row>, dir = <abs dir>, photos = {photo,...},
--   dests = { [photo] = <abs file path> } }
local function buildJobs(entries, preset, fallbackSeqStart, root)
  local jobs = {}
  local seq = fallbackSeqStart or 1
  for _, entry in ipairs(entries) do
    local usedDests = {}
    local baseDir = LrPathUtils.child(collectionDir(entry, root), preset)
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
      if usedDests[dest] then
        -- LR_format=JPEG guarantees a lowercase .jpg extension here.
        local stem = dest:match('^(.+)%.jpg$') or dest
        local n = 2
        local candidate = stem .. '-' .. n .. '.jpg'
        while usedDests[candidate] do
          n = n + 1
          candidate = stem .. '-' .. n .. '.jpg'
        end
        dest = candidate
      end
      usedDests[dest] = true
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
  -- Disable subfolder across both the legacy and LR_export_-prefixed keys,
  -- and clear any lingering path suffix — without these, Lightroom renders
  -- files under an "Untitled Export" subfolder that we then move out of,
  -- leaving the empty dir behind.
  settings.LR_useSubfolder = false
  settings.LR_export_useSubfolder = false
  settings.LR_export_destinationPathSuffix = ''
  settings.LR_renamingTokensOn = false
  return settings
end

local function runJob(job, preset, values, counts, context, jobIdx, jobTotal)
  LrFileUtils.createAllDirectories(job.dir)
  local settings = buildSettings(preset, values)
  settings.LR_export_destinationPathPrefix = job.dir

  local session = LrExportSession {
    photosToExport = job.photos,
    exportSettings = settings,
  }

  local progress = LrProgressScope {
    title = string.format('Structured Export: %s (%s — %d of %d)',
                          job.entry.collection:getName(),
                          preset, jobIdx, jobTotal),
    functionContext = context,
  }
  progress:setCancelable(true)

  local total = #job.photos
  local done = 0
  local canceled = false

  for _, rendition in session:renditions() do
    if canceled or progress:isCanceled() then
      -- Don't break — Lightroom renders photos in parallel ahead of our
      -- iterator, and breaking leaves its render queue draining onto disk
      -- as raw-named orphans. Instead, fully consume the iterator and mark
      -- each remaining rendition done-with-failure so Lightroom abandons
      -- the rest of the queue.
      if not canceled then
        canceled = true
        logger:info('Export canceled by user')
      end
      rendition:renditionIsDone(false, 'Canceled by user')
      done = done + 1
      progress:setPortionComplete(done, total)
    else
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
          -- Direct call (no pcall): applyIptcFields yields via LrTasks.execute,
          -- and yielding through plain pcall corrupts the Lightroom task.
          -- applyIptcFields returns (ok, err) for its anticipated failures.
          local applyOk, applyErr = Metadata.applyIptcFields(dest, values)
          if not applyOk then
            logger:error('applyIptcFields failed: ' .. tostring(applyErr))
            counts.errors = counts.errors + 1
          else
            counts.exported = counts.exported + 1
          end
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
  end

  progress:done()

  if canceled then
    -- Some photos may have been rendered by Lightroom (in parallel, ahead
    -- of our iterator) before we saw the cancel signal. Those files sit
    -- in the destination folder under their raw camera filenames (e.g.
    -- DSC_7980.jpg) because we never reached the move step for them.
    -- Sweep the folder: delete any .jpg that isn't in the expected
    -- final-name set for this job. Sweep multiple times with a short
    -- sleep between passes: LR's render workers can keep writing files
    -- to disk after our iterator exits, so a single sweep races the
    -- queue and leaves late-arriving orphans behind.
    local expected = {}
    for _, dest in pairs(job.dests) do expected[dest] = true end
    local function sweepOnce()
      local removed = 0
      for file in LrFileUtils.files(job.dir) do
        if not expected[file] and file:lower():match('%.jpe?g$') then
          logger:info('Removing cancel orphan: ' .. file)
          if LrFileUtils.delete(file) then removed = removed + 1 end
        end
      end
      return removed
    end
    for _ = 1, 3 do
      LrTasks.sleep(1)
      sweepOnce()
    end
  end

  return canceled
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

    -- Fixed preset order; only include those the user selected.
    local selectedPresets = {}
    if values.presetPrint then
      selectedPresets[#selectedPresets + 1] = 'print'
    end
    if values.presetPortfolio then
      selectedPresets[#selectedPresets + 1] = 'portfolio'
    end
    if values.presetWeb then
      selectedPresets[#selectedPresets + 1] = 'web'
    end
    assert(#selectedPresets > 0, 'dialog must validate preset selection')

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

    -- Build jobs for every selected preset up front so the collision
    -- pre-scan can aggregate across all of them and prompt the user once.
    -- Sequence numbers reset per preset — they are only used as a
    -- filename-stem fallback via buildCollectionFilename.
    local jobsByPreset = {}
    local totalCollisions = 0
    for _, preset in ipairs(selectedPresets) do
      local jobs = buildJobs(nonEmpty, preset, 1, values.exportRoot)
      jobsByPreset[preset] = jobs
      totalCollisions = totalCollisions + #countCollisions(jobs)
    end

    local counts = { exported = 0, skipped = 0, errors = 0 }

    -- Single aggregated collision prompt; the user's choice applies to
    -- all selected presets.
    if totalCollisions > 0 then
      local choice = LrDialogs.confirm(
        string.format(
          '%d files already exist at the destination. How would you like to handle them?',
          totalCollisions),
        nil,
        'Overwrite All',
        'Cancel',
        'Skip Existing')
      if choice == 'cancel' then
        return
      elseif choice == 'other' then
        local anyRemaining = false
        for _, preset in ipairs(selectedPresets) do
          local filtered, skipped = filterSkipExisting(jobsByPreset[preset])
          jobsByPreset[preset] = filtered
          counts.skipped = counts.skipped + skipped
          if #filtered > 0 then anyRemaining = true end
        end
        if not anyRemaining then
          LrDialogs.message(
            'Structured Export',
            string.format('All selected files already exist. Nothing to export. %d skipped.', counts.skipped),
            'info')
          return
        end
      end
      -- 'ok' = Overwrite All: keep jobs unchanged; moves handle overwrite.
    end

    -- pcallWithContext is yield-safe across Lightroom's cooperative tasks;
    -- plain pcall is not. LrExportSession:renditions() yields internally,
    -- and yielding through plain pcall triggers
    -- "AgExportSession:addRenditionsForPhotos: must not call on main UI task".
    local shouldBreak = false
    for _, preset in ipairs(selectedPresets) do
      if shouldBreak then break end
      local jobs = jobsByPreset[preset]
      local jobTotal = #jobs
      for idx, job in ipairs(jobs) do
        if shouldBreak then break end
        local jobOk, jobResult = LrFunctionContext.pcallWithContext(
          'structuredExport:' .. preset .. ':' ..
            tostring(job.entry.collection:getName()),
          function(jobContext)
            return runJob(job, preset, values, counts, jobContext, idx, jobTotal)
          end
        )
        if not jobOk then
          logger:error('Job failed for collection ' ..
            tostring(job.entry.collection:getName()) ..
            ' (' .. preset .. '): ' .. tostring(jobResult))
          counts.errors = counts.errors + 1
        elseif jobResult then
          shouldBreak = true
        end
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
      LrShell.revealInShell(values.exportRoot)
    end
  end)
end)
