local Utils = {}

local function shellQuote(s)
  s = tostring(s or '')
  s = s:gsub("'", "'\\''")
  return "'" .. s .. "'"
end

-- Probes for npm binary; caches first hit.
-- false = not yet resolved; nil = not found
local _npmPath = false

function Utils.resolveNpm()
  if _npmPath ~= false then return _npmPath end
  local candidates = {
    '/opt/homebrew/bin/npm',
    '/usr/local/bin/npm',
    '/usr/bin/npm',
  }
  -- Attempt to read the nvm default alias to find a versioned npm
  local home = os.getenv('HOME') or ''
  if home ~= '' then
    local af = io.open(home .. '/.nvm/alias/default', 'r')
    if af then
      local ver = af:read('*l')
      af:close()
      if ver then
        ver = ver:gsub('%s+', '')
        if not ver:match('^v') then ver = 'v' .. ver end
        candidates[#candidates + 1] = home .. '/.nvm/versions/node/' .. ver .. '/bin/npm'
      end
    end
  end
  for _, path in ipairs(candidates) do
    local f = io.open(path, 'r')
    if f then
      f:close()
      _npmPath = path
      return _npmPath
    end
  end
  _npmPath = nil
  return nil
end

-- Builds the shell command that runs `npm run sync` from inside the repo.
-- npmPath must be an absolute path (GUI apps don't inherit shell PATH).
-- Both repoPath and exportRoot are single-quote-escaped to handle spaces and
-- special characters (common in iCloud paths).
function Utils.buildSyncCommand(repoPath, exportRoot, npmPath)
  return 'cd ' .. shellQuote(repoPath) ..
    ' && ' .. shellQuote(npmPath) ..
    ' run sync -- --root ' .. shellQuote(exportRoot) ..
    ' --preset portfolio --deploy'
end

function Utils.slugify(s)
  if not s or s == "" then return "" end
  s = s:lower()
  s = s:gsub("[ _]", "-")
  -- Strip anything not ASCII alphanumeric or hyphen (drops accented chars, punctuation)
  s = s:gsub("[^a-zA-Z0-9%-]", "")
  s = s:gsub("%-+", "-")
  s = s:gsub("^%-+", ""):gsub("%-+$", "")
  return s
end

function Utils.extractFileNumber(filename)
  if not filename or filename == "" then return nil end
  -- Strip the final extension (last dot and everything after)
  local basename = filename:match("^(.+)%.[^%.]+$") or filename
  -- Returns the FIRST underscore-prefixed digit run, not the last.
  -- DSC_7877 → "7877", IMG_0001 → "0001", _MG_1234 → "1234".
  -- A name like photo_2024_0042 yields "2024", not "0042" — intentional;
  -- Lightroom source names follow the camera-roll pattern above.
  local digits = basename:match("_(%d+)")
  if digits then return digits end
  -- Fall back to all-numeric basename (e.g. 123.NEF)
  if basename:match("^%d+$") then return basename end
  return nil
end

function Utils.buildCollectionFilename(collectionName, fileNumber, fallbackSeq)
  return Utils.slugify(collectionName) .. "-" .. (fileNumber or fallbackSeq) .. ".jpg"
end

return Utils
