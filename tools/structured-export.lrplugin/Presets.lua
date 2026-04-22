-- LR_size_resizeType values "shortEdge" and "longEdge" are valid from
-- SDK 9.0+ (Lightroom Classic 9.0+). This plugin targets LR Classic >=13
-- per the plan, so these identifiers are safe to use.
-- Source: community-documented SDK values; local SDK not available for
-- direct verification (checked /Applications/Adobe Lightroom Classic/SDK/).
-- If Lightroom ignores the resize type, verify the SDK version and
-- replace with "wh" for shortEdge behavior on older SDKs.

local Presets = {}

Presets.print = {
  LR_format                  = "JPEG",
  LR_jpeg_quality            = 0.8,
  LR_size_doConstrain        = true,
  LR_size_resizeType         = "shortEdge",
  LR_size_maxHeight          = 2400,
  LR_size_maxWidth           = 2400,
  LR_size_units              = "pixels",
  LR_size_resolution         = 300,
  LR_size_resolutionUnits    = "inch",
  LR_export_colorSpace       = "sRGB",
  LR_outputSharpeningOn      = true,
  LR_outputSharpeningLevel   = 2,
  LR_outputSharpeningMedia   = "screen",
}

Presets.portfolio = {
  LR_format                  = "JPEG",
  LR_jpeg_quality            = 0.7,
  LR_size_doConstrain        = true,
  LR_size_resizeType         = "shortEdge",
  LR_size_maxHeight          = 2048,
  LR_size_maxWidth           = 2048,
  LR_size_units              = "pixels",
  LR_size_resolution         = 240,
  LR_size_resolutionUnits    = "inch",
  LR_export_colorSpace       = "sRGB",
  LR_outputSharpeningOn      = true,
  LR_outputSharpeningLevel   = 2,
  LR_outputSharpeningMedia   = "screen",
}

Presets.web = {
  LR_format                  = "JPEG",
  LR_jpeg_quality            = 0.7,
  LR_size_doConstrain        = true,
  LR_size_resizeType         = "longEdge",
  LR_size_maxHeight          = 1350,
  LR_size_maxWidth           = 1350,
  LR_size_units              = "pixels",
  LR_size_resolution         = 72,
  LR_size_resolutionUnits    = "inch",
  LR_export_colorSpace       = "sRGB",
  LR_outputSharpeningOn      = true,
  LR_outputSharpeningLevel   = 2,
  LR_outputSharpeningMedia   = "screen",
}

return Presets
