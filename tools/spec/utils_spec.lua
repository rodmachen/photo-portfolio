local Utils = require('Utils')

-- Accented characters: ASCII-only stripping. Non-ASCII UTF-8 bytes are
-- dropped by the [a-zA-Z0-9-] character class. This is a deliberate
-- choice — collection names in Lightroom are expected to be ASCII.

describe("Utils.slugify", function()
  it("returns empty string for empty input", function()
    assert.equals("", Utils.slugify(""))
  end)

  it("lowercases plain strings", function()
    assert.equals("atx-open-2025", Utils.slugify("ATX Open 2025"))
  end)

  it("converts spaces to hyphens", function()
    assert.equals("hello-world", Utils.slugify("Hello World"))
  end)

  it("converts underscores to hyphens", function()
    assert.equals("foo-bar", Utils.slugify("foo_bar"))
  end)

  it("strips punctuation except hyphens", function()
    assert.equals("pet-photos-2024", Utils.slugify("Pet Photos / 2024"))
  end)

  it("strips exclamation marks and other punctuation", function()
    assert.equals("wedding-edits", Utils.slugify("  Wedding!! Edits  "))
  end)

  it("collapses runs of separators", function()
    assert.equals("foo-bar", Utils.slugify("foo___bar"))
  end)

  it("trims leading hyphens", function()
    assert.equals("foo", Utils.slugify("---foo"))
  end)

  it("trims trailing hyphens", function()
    assert.equals("foo", Utils.slugify("foo---"))
  end)

  it("handles mixed punctuation and spaces", function()
    assert.equals("atx-open-2025", Utils.slugify("ATX Open 2025"))
  end)

  it("handles slash as punctuation separator", function()
    assert.equals("pet-photos-2024", Utils.slugify("Pet Photos / 2024"))
  end)

  -- Accented characters are stripped (non-ASCII bytes removed)
  it("strips accented characters (ASCII-only output)", function()
    -- 'é' is multi-byte UTF-8; resulting string should be ASCII only
    local result = Utils.slugify("caf\xC3\xA9")  -- "café"
    assert.equals("caf", result)
  end)
end)

describe("Utils.extractFileNumber", function()
  it("returns nil for empty string", function()
    assert.is_nil(Utils.extractFileNumber(""))
  end)

  it("returns nil for nil input", function()
    assert.is_nil(Utils.extractFileNumber(nil))
  end)

  it("extracts digits from DSC_ prefix", function()
    assert.equals("7877", Utils.extractFileNumber("DSC_7877.NEF"))
  end)

  it("extracts first prefix digit group from IMG_ file with -Edit suffix", function()
    -- IMG_0001-Edit.DNG: the relevant number is 0001, not any trailing edit number
    assert.equals("0001", Utils.extractFileNumber("IMG_0001-Edit.DNG"))
  end)

  it("extracts first prefix digit group from file with -Edit-N suffix", function()
    -- IMG_0001-Edit-2.DNG: returns 0001, not 2
    assert.equals("0001", Utils.extractFileNumber("IMG_0001-Edit-2.DNG"))
  end)

  it("returns nil for filename with no digit run", function()
    assert.is_nil(Utils.extractFileNumber("untitled.jpg"))
  end)

  it("returns digits for numeric-only basename", function()
    assert.equals("123", Utils.extractFileNumber("123.NEF"))
  end)

  it("handles _MG_ prefix", function()
    assert.equals("1234", Utils.extractFileNumber("_MG_1234.CR2"))
  end)

  it("works with no extension", function()
    assert.equals("7877", Utils.extractFileNumber("DSC_7877"))
  end)

  it("returns nil for multi-extension with no digit run (photo.tar.gz)", function()
    assert.is_nil(Utils.extractFileNumber("photo.tar.gz"))
  end)

  it("returns the FIRST underscore digit run for multi-underscore names", function()
    -- photo_2024_0042: returns "2024" (first run), not "0042" (last run).
    -- Camera-roll names like DSC_7877 always have exactly one digit group,
    -- so first-match is correct for the expected input domain.
    assert.equals("2024", Utils.extractFileNumber("photo_2024_0042.jpg"))
  end)
end)

describe("Utils.joinPath", function()
  it("joins two segments with a slash", function()
    assert.equals("foo/bar", Utils.joinPath("foo", "bar"))
  end)

  it("joins three segments", function()
    assert.equals("foo/bar/baz", Utils.joinPath("foo", "bar", "baz"))
  end)

  it("single argument returns the argument", function()
    assert.equals("foo", Utils.joinPath("foo"))
  end)

  it("strips trailing slashes from segments before joining", function()
    assert.equals("foo/bar", Utils.joinPath("foo/", "bar"))
  end)
end)

describe("Utils.buildCollectionFilename", function()
  it("uses fileNumber when provided", function()
    assert.equals("my-collection-7877.jpg", Utils.buildCollectionFilename("My Collection", "7877", 1))
  end)

  it("falls back to fallbackSeq when fileNumber is nil", function()
    assert.equals("my-collection-1.jpg", Utils.buildCollectionFilename("My Collection", nil, 1))
  end)

  it("slugifies the collection name", function()
    assert.equals("atx-open-2025-0001.jpg", Utils.buildCollectionFilename("ATX Open 2025", "0001", 1))
  end)

  it("uses fallbackSeq when fileNumber is nil and seq is a string", function()
    assert.equals("portraits-seq001.jpg", Utils.buildCollectionFilename("Portraits", nil, "seq001"))
  end)
end)
