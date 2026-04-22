local Presets = require('Presets')

-- LR_size_resizeType values: "shortEdge" and "longEdge" require SDK 9.0+
-- (LR Classic >= 9.0, well below the plan's stated LR >=13 minimum).
-- Source: community-documented SDK values; local SDK not available for
-- verification. See Utils.lua comment in Presets.lua for provenance.

describe("Presets module keys", function()
  it("has a print preset", function()
    assert.is_table(Presets.print)
  end)

  it("has a portfolio preset", function()
    assert.is_table(Presets.portfolio)
  end)

  it("has a web preset", function()
    assert.is_table(Presets.web)
  end)
end)

describe("Presets shared fields", function()
  local presets = { Presets.print, Presets.portfolio, Presets.web }
  local names   = { "print",       "portfolio",       "web" }

  for i, name in ipairs(names) do
    local p = presets[i]

    it(name .. " is JPEG format", function()
      assert.equals("JPEG", p.LR_format)
    end)

    it(name .. " exports sRGB", function()
      assert.equals("sRGB", p.LR_export_colorSpace)
    end)

    it(name .. " constrains size", function()
      assert.is_true(p.LR_size_doConstrain)
    end)

    it(name .. " uses pixel units", function()
      assert.equals("pixels", p.LR_size_units)
    end)

    it(name .. " sharpening is on", function()
      assert.is_true(p.LR_outputSharpeningOn)
    end)

    it(name .. " sharpening level is Standard (2)", function()
      assert.equals(2, p.LR_outputSharpeningLevel)
    end)

    it(name .. " sharpening media is screen", function()
      assert.equals("screen", p.LR_outputSharpeningMedia)
    end)
  end
end)

describe("Presets.print", function()
  it("quality is 0.8", function()
    assert.equals(0.8, Presets.print.LR_jpeg_quality)
  end)

  it("resize type is shortEdge", function()
    assert.equals("shortEdge", Presets.print.LR_size_resizeType)
  end)

  it("max height is 2400", function()
    assert.equals(2400, Presets.print.LR_size_maxHeight)
  end)

  it("max width is 2400", function()
    assert.equals(2400, Presets.print.LR_size_maxWidth)
  end)

  it("resolution is 300", function()
    assert.equals(300, Presets.print.LR_size_resolution)
  end)

  it("resolution units is inch", function()
    assert.equals("inch", Presets.print.LR_size_resolutionUnits)
  end)
end)

describe("Presets.portfolio", function()
  it("quality is 0.7", function()
    assert.equals(0.7, Presets.portfolio.LR_jpeg_quality)
  end)

  it("resize type is shortEdge", function()
    assert.equals("shortEdge", Presets.portfolio.LR_size_resizeType)
  end)

  it("max height is 2048", function()
    assert.equals(2048, Presets.portfolio.LR_size_maxHeight)
  end)

  it("max width is 2048", function()
    assert.equals(2048, Presets.portfolio.LR_size_maxWidth)
  end)

  it("resolution is 240", function()
    assert.equals(240, Presets.portfolio.LR_size_resolution)
  end)

  it("resolution units is inch", function()
    assert.equals("inch", Presets.portfolio.LR_size_resolutionUnits)
  end)
end)

describe("Presets.web", function()
  it("quality is 0.7", function()
    assert.equals(0.7, Presets.web.LR_jpeg_quality)
  end)

  it("resize type is longEdge", function()
    assert.equals("longEdge", Presets.web.LR_size_resizeType)
  end)

  it("max height is 1350", function()
    assert.equals(1350, Presets.web.LR_size_maxHeight)
  end)

  it("max width is 1350", function()
    assert.equals(1350, Presets.web.LR_size_maxWidth)
  end)

  it("resolution is 72", function()
    assert.equals(72, Presets.web.LR_size_resolution)
  end)

  it("resolution units is inch", function()
    assert.equals("inch", Presets.web.LR_size_resolutionUnits)
  end)
end)
