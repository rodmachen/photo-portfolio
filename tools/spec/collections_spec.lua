local script_dir = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') or './'
package.path = script_dir .. '../structured-export.lrplugin/?.lua;' .. package.path

local Collections = require('Collections')
local Utils = require('Utils')

-- Fake object factories
local function fakeCollection(name, photos)
  return {
    type        = function() return 'LrCollection' end,
    getName     = function() return name end,
    getPhotos   = function() return photos or {} end,
  }
end

local function fakeSet(name, childSets, childCollections)
  return {
    type                  = function() return 'LrCollectionSet' end,
    getName               = function() return name end,
    getChildCollectionSets = function() return childSets or {} end,
    getChildCollections   = function() return childCollections or {} end,
  }
end

describe("Collections.enumerate", function()
  it("returns empty list for empty selection", function()
    local result = Collections.enumerate({})
    assert.equals(0, #result)
  end)

  it("handles nil selection", function()
    local result = Collections.enumerate(nil)
    assert.equals(0, #result)
  end)

  it("single bare collection has empty pathSegments", function()
    local photos = { 'photo1', 'photo2' }
    local col = fakeCollection("My Collection", photos)
    local result = Collections.enumerate({ col })
    assert.equals(1, #result)
    assert.equals(col, result[1].collection)
    assert.equals(0, #result[1].pathSegments)
    assert.equals(photos, result[1].photos)
  end)

  it("collection inside a 1-level set has one pathSegment", function()
    local col = fakeCollection("Portraits", {})
    local set = fakeSet("Travel 2025", {}, { col })
    local result = Collections.enumerate({ set })
    assert.equals(1, #result)
    assert.equals(1, #result[1].pathSegments)
    assert.equals(Utils.slugify("Travel 2025"), result[1].pathSegments[1])
  end)

  it("collection inside a 3-level nested set has three pathSegments", function()
    local col    = fakeCollection("Finals", {})
    local inner  = fakeSet("Leaf Set",  {}, { col })
    local mid    = fakeSet("Mid Level", { inner }, {})
    local root   = fakeSet("Root Set",  { mid }, {})
    local result = Collections.enumerate({ root })
    assert.equals(1, #result)
    assert.equals(3, #result[1].pathSegments)
    assert.equals(Utils.slugify("Root Set"),  result[1].pathSegments[1])
    assert.equals(Utils.slugify("Mid Level"), result[1].pathSegments[2])
    assert.equals(Utils.slugify("Leaf Set"),  result[1].pathSegments[3])
  end)

  it("set with mixed children enumerates all leaf collections", function()
    local colA = fakeCollection("Alpha", {})
    local colB = fakeCollection("Beta",  {})
    local colC = fakeCollection("Gamma", {})
    local subSet = fakeSet("Sub", {}, { colC })
    local root   = fakeSet("Root", { subSet }, { colA, colB })
    local result = Collections.enumerate({ root })
    assert.equals(3, #result)
  end)

  it("top-level set expands to all descendant collections with full pathSegments", function()
    local colX = fakeCollection("X", {})
    local colY = fakeCollection("Y", {})
    local setA = fakeSet("A", {}, { colX })
    local setB = fakeSet("B", {}, { colY })
    local top  = fakeSet("Top", { setA, setB }, {})
    local result = Collections.enumerate({ top })
    assert.equals(2, #result)
    -- Both should have 2 path segments (Top + child set)
    assert.equals(2, #result[1].pathSegments)
    assert.equals(2, #result[2].pathSegments)
    assert.equals(Utils.slugify("Top"), result[1].pathSegments[1])
    assert.equals(Utils.slugify("Top"), result[2].pathSegments[1])
  end)

  it("mixed selection of a set and a bare collection contributes both", function()
    local bareCol = fakeCollection("Solo", { 'p1' })
    local setCol  = fakeCollection("InSet", {})
    local set     = fakeSet("TheSet", {}, { setCol })
    local result  = Collections.enumerate({ set, bareCol })
    assert.equals(2, #result)
    -- one from the set, one bare
    local bare, fromSet
    for _, r in ipairs(result) do
      if #r.pathSegments == 0 then
        bare = r
      else
        fromSet = r
      end
    end
    assert.is_not_nil(bare)
    assert.is_not_nil(fromSet)
    assert.equals(bareCol, bare.collection)
    assert.equals(setCol, fromSet.collection)
  end)
end)
