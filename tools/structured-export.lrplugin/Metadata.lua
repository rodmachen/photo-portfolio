-- SDK namespaces load via the Lightroom-provided global `import`; fall back to
-- nil when running under plain Lua (busted tests), which makes applyIptcFields
-- early-return cleanly so pure-logic tests don't need a Lightroom runtime.
local LrTasks = _G.import and import 'LrTasks' or nil
local LrLogger = _G.import and import 'LrLogger' or nil
local logger = LrLogger and LrLogger('StructuredExport') or nil

local Metadata = {}

-- Probes for exiftool binary; caches first hit.
local _exiftoolPath = false  -- false = not yet resolved; nil = not found

local function resolveExiftool()
  if _exiftoolPath ~= false then return _exiftoolPath end
  -- Probe known absolute paths only. A bare `exiftool` fallback via PATH
  -- lookup is unreachable from inside Lightroom anyway — macOS GUI apps
  -- launch with a minimal PATH that does not include Homebrew. (Also,
  -- `os.execute` is nil in Lightroom's sandboxed Lua, so the PATH probe
  -- would crash before ever returning a result.)
  local candidates = {
    '/opt/homebrew/bin/exiftool',
    '/usr/local/bin/exiftool',
    '/usr/bin/exiftool',
  }
  for _, path in ipairs(candidates) do
    local f = io.open(path, 'r')
    if f then
      f:close()
      _exiftoolPath = path
      return _exiftoolPath
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
  if not LrTasks then
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

  -- Creator is written across three namespaces so it shows up regardless of
  -- what the reader consults: EXIF IFD0 Artist (Finder Preview, macOS Photos),
  -- XMP dc:Creator (Bridge, modern catalogers), IPTC By-line + Credit (legacy
  -- photo workflows).
  local cmd = table.concat({
    bin,
    '-overwrite_original',
    '-Copyright='        .. shellEscape(prefs.copyright    or ''),
    '-Artist='           .. shellEscape(prefs.creator      or ''),
    '-XMP:Creator='      .. shellEscape(prefs.creator      or ''),
    '-By-line='          .. shellEscape(prefs.creator      or ''),
    '-Credit='           .. shellEscape(prefs.creator      or ''),
    '-Rights='           .. shellEscape(prefs.rights       or ''),
    '-CreatorWorkEmail=' .. shellEscape(prefs.contactEmail or ''),
    '-WebStatement='     .. shellEscape(prefs.webStatement or ''),
    shellEscape(filePath),
  }, ' ')

  local result = LrTasks.execute(cmd)
  if result ~= 0 then
    return false, 'exiftool exited with code ' .. tostring(result)
  end
  return true, nil
end

return Metadata
