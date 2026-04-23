local LrView            = import 'LrView'
local LrBinding         = import 'LrBinding'
local LrDialogs         = import 'LrDialogs'
local LrFileUtils       = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrLogger          = import 'LrLogger'

local Prefs = require('Prefs')

local logger = LrLogger('StructuredExport')

local ExportDialog = {}

function ExportDialog.run(activePhoto)
  local result = { action = 'cancel', values = {} }
  logger:info('ExportDialog opened')

  LrFunctionContext.callWithContext('structuredExportDialog', function(context)
    local f  = LrView.osFactory()
    local props = LrBinding.makePropertyTable(context)

    -- Pre-fill from saved prefs
    local savedPrefs = Prefs.load()
    -- If stored exportRoot no longer exists on disk, fall back to default silently.
    local exportRoot = savedPrefs.exportRoot
    if not LrFileUtils.exists(exportRoot) then
      exportRoot = Prefs.getDefaults().exportRoot
    end
    props.exportRoot         = exportRoot
    props.presetPrint        = savedPrefs.presetPrint
    props.presetPortfolio    = savedPrefs.presetPortfolio
    props.presetWeb          = savedPrefs.presetWeb
    props.copyright          = savedPrefs.copyright
    props.creator            = savedPrefs.creator
    props.rights             = savedPrefs.rights
    props.webStatement       = savedPrefs.webStatement
    props.contactEmail       = savedPrefs.contactEmail
    props.remember           = savedPrefs.remember or false

    -- Override copyright from active photo metadata when available
    if activePhoto then
      local photoCopyright = activePhoto:getFormattedMetadata('copyright')
      if photoCopyright and photoCopyright ~= '' then
        props.copyright = photoCopyright
      end
    end

    local contents = f:column {
      bind_to_object = props,
      spacing = f:dialog_spacing(),

      -- Destination folder
      f:row {
        f:static_text { title = 'Destination:', width = 110 },
        f:edit_field { value = LrView.bind('exportRoot'), fill_horizontal = 1 },
        f:push_button {
          title = 'Browse...',
          action = function()
            local picked = LrDialogs.runOpenPanel {
              title = 'Choose export folder',
              canChooseFiles = false,
              canChooseDirectories = true,
              allowsMultipleSelection = false,
              initialDirectory = props.exportRoot,
            }
            if picked then
              props.exportRoot = picked[1]
            end
          end,
        },
      },

      -- Preset checkboxes (multi-select; exports run sequentially per preset)
      f:group_box {
        title = 'Export Presets',
        f:checkbox {
          title = 'print',
          value = LrView.bind('presetPrint'),
        },
        f:checkbox {
          title = 'portfolio',
          value = LrView.bind('presetPortfolio'),
        },
        f:checkbox {
          title = 'web',
          value = LrView.bind('presetWeb'),
        },
      },

      f:separator { fill_horizontal = 1 },

      -- IPTC / copyright fields
      f:row {
        f:static_text { title = 'Copyright:', width = 110 },
        f:edit_field { value = LrView.bind('copyright'), fill_horizontal = 1 },
      },
      f:row {
        f:static_text { title = 'Creator:', width = 110 },
        f:edit_field { value = LrView.bind('creator'), fill_horizontal = 1 },
      },
      f:row {
        f:static_text { title = 'Rights:', width = 110 },
        f:edit_field { value = LrView.bind('rights'), fill_horizontal = 1 },
      },
      f:row {
        f:static_text { title = 'Web statement:', width = 110 },
        f:edit_field { value = LrView.bind('webStatement'), fill_horizontal = 1 },
      },
      f:row {
        f:static_text { title = 'Contact email:', width = 110 },
        f:edit_field { value = LrView.bind('contactEmail'), fill_horizontal = 1 },
      },

      f:separator { fill_horizontal = 1 },

      -- Remember checkbox
      f:checkbox {
        title = 'Remember these settings',
        value = LrView.bind('remember'),
      },
    }

    local action = LrDialogs.presentModalDialog {
      title   = 'Structured Export',
      contents = contents,
    }
    logger:info('ExportDialog result: ' .. tostring(action))

    if action == 'ok' then
      -- At least one preset must be selected. Simpler than re-showing the
      -- dialog in a loop: warn and treat as cancel.
      if not (props.presetPrint or props.presetPortfolio or props.presetWeb) then
        LrDialogs.message(
          'Structured Export', 'Select at least one preset.', 'warning')
        return
      end

      -- Always persist the remember-checkbox state itself so the box stays
      -- checked across runs; only persist the other field values when the
      -- user opted in.
      Prefs.save({ remember = props.remember })
      if props.remember then
        Prefs.save({
          exportRoot         = props.exportRoot,
          presetPrint        = props.presetPrint,
          presetPortfolio    = props.presetPortfolio,
          presetWeb          = props.presetWeb,
          copyright          = props.copyright,
          creator            = props.creator,
          rights             = props.rights,
          webStatement       = props.webStatement,
          contactEmail       = props.contactEmail,
        })
      end

      result.action = 'export'
      result.values = {
        exportRoot         = props.exportRoot,
        presetPrint        = props.presetPrint,
        presetPortfolio    = props.presetPortfolio,
        presetWeb          = props.presetWeb,
        copyright          = props.copyright,
        creator            = props.creator,
        rights             = props.rights,
        webStatement       = props.webStatement,
        contactEmail       = props.contactEmail,
        remember           = props.remember,
      }
    end
  end)

  return result
end

return ExportDialog
