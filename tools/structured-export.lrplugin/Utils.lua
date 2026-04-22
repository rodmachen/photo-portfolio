local ok, LrPathUtils = pcall(require, 'LrPathUtils')

local Utils = {}

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
  -- Prefer first underscore-prefixed digit run (DSC_7877, IMG_0001, _MG_1234)
  local digits = basename:match("_(%d+)")
  if digits then return digits end
  -- Fall back to all-numeric basename (e.g. 123.NEF)
  if basename:match("^%d+$") then return basename end
  return nil
end

function Utils.joinPath(...)
  local parts = {...}
  if #parts == 0 then return "" end
  if ok and LrPathUtils then
    local result = parts[1]
    for i = 2, #parts do
      result = LrPathUtils.child(result, parts[i])
    end
    return result
  end
  local cleaned = {}
  for _, p in ipairs(parts) do
    cleaned[#cleaned + 1] = (p:gsub("/$", ""))
  end
  return table.concat(cleaned, "/")
end

function Utils.buildCollectionFilename(collectionName, fileNumber, fallbackSeq)
  return Utils.slugify(collectionName) .. "-" .. (fileNumber or fallbackSeq) .. ".jpg"
end

return Utils
