local Utils = require('Utils')

local Collections = {}

-- Recursively walks a CollectionSet, collecting all descendant leaf collections.
-- pathSegments accumulates slugified set names from root down (not including the
-- collection's own name — the caller uses the collection's slug as the leaf folder).
local function walkSet(set, pathSegments, out)
  local setSlug = Utils.slugify(set:getName())
  local childSegments = {}
  for _, seg in ipairs(pathSegments) do
    childSegments[#childSegments + 1] = seg
  end
  childSegments[#childSegments + 1] = setSlug

  for _, childSet in ipairs(set:getChildCollectionSets()) do
    walkSet(childSet, childSegments, out)
  end

  for _, col in ipairs(set:getChildCollections()) do
    out[#out + 1] = {
      collection   = col,
      pathSegments = childSegments,
      photos       = col:getPhotos(),
    }
  end
end

-- Returns a flat list of {collection, pathSegments, photos} for every leaf
-- collection reachable from the items in `selection`.
-- selection: list of LrCollection | LrCollectionSet objects (duck-typed).
function Collections.enumerate(selection)
  local out = {}
  if not selection or #selection == 0 then return out end

  for _, item in ipairs(selection) do
    if item:type():match('CollectionSet$') then
      walkSet(item, {}, out)
    else
      -- bare LrCollection or LrPublishedCollection
      out[#out + 1] = {
        collection   = item,
        pathSegments = {},
        photos       = item:getPhotos(),
      }
    end
  end

  return out
end

return Collections
