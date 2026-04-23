local ok, LrTasks = pcall(require, 'LrTasks')
local _okLog, LrLogger = pcall(require, 'LrLogger')
local logger = _okLog and type(LrLogger) == 'function' and LrLogger('StructuredExport') or nil

local Metadata = {}

-- Probes for exiftool binary; caches first hit.
local _exiftoolPath = false  -- false = not yet resolved; nil = not found

local function resolveExiftool()
  if _exiftoolPath ~= false then return _exiftoolPath end
  local candidates = {
    '/opt/homebrew/bin/exiftool',
    '/usr/local/bin/exiftool',
    '/usr/bin/exiftool',
    'exiftool',
  }
  for _, path in ipairs(candidates) do
    if path == 'exiftool' then
      -- bare command: probe via shell without touching io.open
      local ok2 = os.execute('command -v exiftool > /dev/null 2>&1')
      if ok2 == 0 or ok2 == true then
        _exiftoolPath = path
        return _exiftoolPath
      end
    else
      local f = io.open(path, 'r')
      if f then
        f:close()
        _exiftoolPath = path
        return _exiftoolPath
      end
    end
  end
  return nil
end

Metadata._resolveExiftool = resolveExiftool

-- Wraps s in single quotes, escaping embedded single quotes.
local function shellEscape(s)
  s = tostring(s or '')
  -- Replace each ' with '\'' (end quote, literal single quote, reopen quote)
  s = s:gsub("'", "'\\''")
  return "'" .. s .. "'"
end

Metadata._shellEscape = shellEscape

-- Returns a sub-table of LR_* metadata keys understood by Lightroom Classic.
function Metadata.buildExportSettings(prefs)
  return {
    LR_embeddedMetadataOption = 'all',
    LR_metadata_copyright     = prefs.copyright,
    LR_removeFaceMetadata     = false,
    LR_removeLocationMetadata = false,
  }
end

local _exiftoolWarned = false

-- Shells out to exiftool to write IPTC fields onto an already-exported file.
-- Returns ok (bool), err (string or nil).
function Metadata.applyIptcFields(filePath, prefs)
  if not ok or not LrTasks then
    if logger then logger:error('LrTasks unavailable; IPTC fields skipped') end
    return true, nil  -- graceful degrade when not in LR environment
  end

  local bin = resolveExiftool()
  if not bin then
    if not _exiftoolWarned then
      _exiftoolWarned = true
      if logger then logger:info('exiftool not found; IPTC fields skipped') end
    end
    return true, nil
  end

  local cmd = table.concat({
    bin,
    '-overwrite_original',
    '-Copyright='     .. shellEscape(prefs.copyright    or ''),
    '-By-line='       .. shellEscape(prefs.creator      or ''),
    '-Rights='        .. shellEscape(prefs.rights       or ''),
    '-Credit='        .. shellEscape(prefs.creator      or ''),
    '-CreatorWorkEmail='   .. shellEscape(prefs.contactEmail  or ''),
    '-WebStatement='  .. shellEscape(prefs.webStatement or ''),
    shellEscape(filePath),
  }, ' ')

  local result = LrTasks.execute(cmd)
  if result ~= 0 then
    return false, 'exiftool exited with code ' .. tostring(result)
  end
  return true, nil
end

return Metadata
